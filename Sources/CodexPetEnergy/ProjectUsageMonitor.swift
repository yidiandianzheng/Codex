import Foundation

final class ProjectUsageMonitor {
    var onUpdate: ((ProjectUsageDaySummary) -> Void)?

    private let queue = DispatchQueue(label: "codex.pet.energy.project-usage", qos: .utility)
    private let roots: [URL]
    private var timer: DispatchSourceTimer?

    init(roots: [URL] = ProjectUsageMonitor.defaultRoots) {
        self.roots = roots
    }

    func start() {
        refresh()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(3))
        timer.setEventHandler { [weak self] in self?.refreshOnQueue() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func refresh() {
        queue.async { [weak self] in self?.refreshOnQueue() }
    }

    private func refreshOnQueue() {
        let summary = Self.readToday(from: roots, now: Date())
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(summary) }
    }

    static var defaultRoots: [URL] {
        let codex = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return [codex.appendingPathComponent("sessions"), codex.appendingPathComponent("archived_sessions")]
    }

    static func readToday(from roots: [URL], now: Date, fileManager: FileManager = .default) -> ProjectUsageDaySummary {
        var uniqueSessions: [String: ProjectUsageSession] = [:]
        let start = ProjectUsageLogic.startOfDay(containing: now)

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let file as URL in enumerator {
                guard file.pathExtension == "jsonl",
                      let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let modified = values.contentModificationDate,
                      modified >= start,
                      let text = try? String(contentsOf: file, encoding: .utf8),
                      let session = parseSession(text, fallbackID: file.path, now: now)
                else { continue }

                if let existing = uniqueSessions[session.id] {
                    uniqueSessions[session.id] = ProjectUsageLogic.preferredVersion(existing, session)
                } else {
                    uniqueSessions[session.id] = session
                }
            }
        }
        let sessions = Array(uniqueSessions.values)
        return ProjectUsageDaySummary(
            projects: ProjectUsageLogic.aggregate(sessions),
            sessionSwitchCount: ProjectUsageLogic.sessionSwitchCount(sessions)
        )
    }

    static func parseSession(_ text: String, fallbackID: String, now: Date) -> ProjectUsageSession? {
        let start = ProjectUsageLogic.startOfDay(containing: now)
        var sessionID = fallbackID
        var directory: String?
        var totals = ProjectUsageTotals.zero
        var lastActivity: Date?

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String,
                  let payload = object["payload"] as? [String: Any]
            else { continue }

            if type == "session_meta" {
                sessionID = (payload["id"] as? String) ?? (payload["session_id"] as? String) ?? sessionID
                directory = payload["cwd"] as? String
                continue
            }

            guard type == "event_msg",
                  payload["type"] as? String == "token_count",
                  let timestamp = parseTimestamp(object["timestamp"] as? String),
                  timestamp >= start,
                  let info = (payload["info"] as? [String: Any]) ?? ((payload["payload"] as? [String: Any])?["info"] as? [String: Any]),
                  let usage = info["last_token_usage"] as? [String: Any]
            else { continue }

            let turnTotals = ProjectUsageTotals(
                inputTokens: integer(usage["input_tokens"]),
                outputTokens: integer(usage["output_tokens"]),
                reasoningTokens: integer(usage["reasoning_output_tokens"]),
                cachedInputTokens: integer(usage["cached_input_tokens"]),
                turnCount: 1,
                maximumTurnTokens: integer(usage["input_tokens"]) + integer(usage["output_tokens"])
            )
            totals = totals.adding(turnTotals)
            lastActivity = max(lastActivity ?? timestamp, timestamp)
        }

        guard let directory, let lastActivity, totals.totalTokens > 0 else { return nil }
        return ProjectUsageSession(id: sessionID, directory: directory, totals: totals, lastActivity: lastActivity)
    }

    private static func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}

struct ProjectUsageSession: Equatable {
    let id: String
    let directory: String
    let totals: ProjectUsageTotals
    let lastActivity: Date
}

struct ProjectUsageDaySummary: Equatable {
    let projects: [ProjectUsageReading]
    let sessionSwitchCount: Int

    static let empty = ProjectUsageDaySummary(projects: [], sessionSwitchCount: 0)
}

enum ProjectUsageLogic {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    static func startOfDay(containing date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    static func aggregate(_ sessions: [ProjectUsageSession], limit: Int = 5) -> [ProjectUsageReading] {
        var grouped: [String: ProjectUsageReading] = [:]
        for session in sessions {
            let name = URL(fileURLWithPath: session.directory).lastPathComponent
            if let existing = grouped[session.directory] {
                grouped[session.directory] = ProjectUsageReading(
                    directory: session.directory,
                    projectName: existing.projectName,
                    totals: existing.totals.adding(session.totals),
                    lastActivity: max(existing.lastActivity, session.lastActivity)
                )
            } else {
                grouped[session.directory] = ProjectUsageReading(
                    directory: session.directory,
                    projectName: name.isEmpty ? session.directory : name,
                    totals: session.totals,
                    lastActivity: session.lastActivity
                )
            }
        }
        return grouped.values
            .sorted {
                if $0.lastActivity != $1.lastActivity {
                    return $0.lastActivity > $1.lastActivity
                }
                if $0.totals.totalTokens != $1.totals.totalTokens {
                    return $0.totals.totalTokens > $1.totals.totalTokens
                }
                return $0.directory < $1.directory
            }
            .prefix(limit)
            .map { $0 }
    }

    static func preferredVersion(
        _ lhs: ProjectUsageSession,
        _ rhs: ProjectUsageSession
    ) -> ProjectUsageSession {
        if lhs.totals.totalTokens != rhs.totals.totalTokens {
            return lhs.totals.totalTokens > rhs.totals.totalTokens ? lhs : rhs
        }
        return lhs.lastActivity >= rhs.lastActivity ? lhs : rhs
    }

    static func sessionSwitchCount(_ sessions: [ProjectUsageSession]) -> Int {
        let ordered = sessions.sorted { $0.lastActivity < $1.lastActivity }
        var previousDirectory: String?
        return ordered.reduce(into: 0) { count, session in
            if let previousDirectory, previousDirectory != session.directory { count += 1 }
            previousDirectory = session.directory
        }
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
