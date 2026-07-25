import Foundation

enum EnergyTone: Equatable {
    case green
    case yellow
    case red
    case unavailable
}

struct EnergyReading: Equatable {
    let remainingPercent: Int?
    let resetsAt: Date?

    static let unavailable = EnergyReading(remainingPercent: nil, resetsAt: nil)
}

struct ProjectUsageReading: Identifiable, Equatable {
    let directory: String
    let projectName: String
    let totals: ProjectUsageTotals
    let lastActivity: Date

    var id: String { directory }
}

struct ProjectUsageTotals: Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let cachedInputTokens: Int
    let turnCount: Int
    let maximumTurnTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    static let zero = ProjectUsageTotals(
        inputTokens: 0,
        outputTokens: 0,
        reasoningTokens: 0,
        cachedInputTokens: 0,
        turnCount: 0,
        maximumTurnTokens: 0
    )

    func adding(_ other: ProjectUsageTotals) -> ProjectUsageTotals {
        ProjectUsageTotals(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningTokens: reasoningTokens + other.reasoningTokens,
            cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
            turnCount: turnCount + other.turnCount,
            maximumTurnTokens: max(maximumTurnTokens, other.maximumTurnTokens)
        )
    }
}

struct RateLimitWindow: Codable, Equatable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?
}

struct RateLimitSnapshot: Codable, Equatable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    init(
        limitId: String?,
        limitName: String? = nil,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
    }
}

struct RateLimitReadResult: Codable, Equatable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCreditsSummary?

    init(
        rateLimits: RateLimitSnapshot,
        rateLimitsByLimitId: [String: RateLimitSnapshot]? = nil,
        rateLimitResetCredits: RateLimitResetCreditsSummary? = nil
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
        self.rateLimitResetCredits = rateLimitResetCredits
    }
}

enum EnergyLogic {
    static func remainingPercent(fromUsedPercent usedPercent: Double) -> Int {
        Int((100 - usedPercent).rounded()).clamped(to: 0...100)
    }

    static func tone(for remainingPercent: Int?) -> EnergyTone {
        guard let remainingPercent else { return .unavailable }
        if remainingPercent >= 50 { return .green }
        if remainingPercent >= 20 { return .yellow }
        return .red
    }

    static func overallReading(from snapshot: RateLimitSnapshot) -> EnergyReading {
        guard let window = preferredWindow(from: snapshot) else {
            return .unavailable
        }
        return EnergyReading(
            remainingPercent: remainingPercent(fromUsedPercent: window.usedPercent),
            resetsAt: window.resetsAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    static func remainingDays(until reset: Date?, from now: Date = .now) -> Int? {
        guard let reset else { return nil }
        let remainingSeconds = max(0, reset.timeIntervalSince(now))
        return Int(ceil(remainingSeconds / 86_400))
    }

    static func compactResetDateText(
        _ reset: Date?,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        guard let reset else { return "—" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: reset)
    }

    static func compactStatusText(
        for reading: EnergyReading,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let percent = reading.remainingPercent.map { "\($0)%" } ?? "—"
        let resetDate = compactResetDateText(reading.resetsAt, calendar: calendar)
        let days = remainingDays(until: reading.resetsAt, from: now).map { "\($0)天" } ?? "—"
        return "\(percent) · \(resetDate) · \(days)"
    }

    static func compactStatusText(
        for reading: EnergyReading,
        modelReading: QuotaLimitReading?,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let overall = compactStatusText(for: reading, now: now, calendar: calendar)
        let model = modelReading.map { "\($0.remainingPercent)%" } ?? "—"
        return "总 \(overall) · 5.3 \(model)"
    }

    static func belongsToSameLimit(_ update: RateLimitSnapshot, as current: RateLimitSnapshot) -> Bool {
        guard let currentID = current.limitId, let updateID = update.limitId else { return true }
        return currentID == updateID
    }

    static func mergingSparseUpdate(
        _ update: RateLimitSnapshot,
        into current: RateLimitSnapshot
    ) -> RateLimitSnapshot {
        RateLimitSnapshot(
            limitId: update.limitId ?? current.limitId,
            limitName: update.limitName ?? current.limitName,
            primary: update.primary ?? current.primary,
            secondary: update.secondary ?? current.secondary
        )
    }

    static func mergingSparseUpdate(
        _ update: RateLimitSnapshot,
        into current: RateLimitReadResult
    ) -> RateLimitReadResult? {
        var rateLimits = current.rateLimits
        var rateLimitsByLimitId = current.rateLimitsByLimitId
        var mergedAnyBucket = false

        if belongsToSameLimit(update, as: current.rateLimits) {
            rateLimits = mergingSparseUpdate(update, into: current.rateLimits)
            mergedAnyBucket = true
        }

        if let limitId = update.limitId,
           let existing = rateLimitsByLimitId?[limitId] {
            rateLimitsByLimitId?[limitId] = mergingSparseUpdate(update, into: existing)
            mergedAnyBucket = true
        }

        guard mergedAnyBucket else { return nil }
        return RateLimitReadResult(
            rateLimits: rateLimits,
            rateLimitsByLimitId: rateLimitsByLimitId,
            rateLimitResetCredits: current.rateLimitResetCredits
        )
    }

    static func quotaDetailSummary(from result: RateLimitReadResult) -> QuotaDetailSummary {
        let overall = quotaReading(
            id: "overall",
            title: "总额度",
            snapshot: result.rateLimits
        )
        let modelLimits = (result.rateLimitsByLimitId ?? [:])
            .values
            .filter { snapshot in
                snapshot.limitId != result.rateLimits.limitId
                    && !(snapshot.limitName?.isEmpty ?? true)
            }
            .compactMap { snapshot -> QuotaLimitReading? in
                guard let name = snapshot.limitName else { return nil }
                return quotaReading(
                    id: snapshot.limitId ?? name,
                    title: "\(name) 限额",
                    snapshot: snapshot
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return QuotaDetailSummary(
            overall: overall,
            modelLimits: modelLimits,
            availableResetCount: result.rateLimitResetCredits?.availableCount
        )
    }

    static func windowDurationText(_ minutes: Int?) -> String {
        guard let minutes else { return "—" }
        if minutes.isMultiple(of: 10_080) {
            return "\(minutes / 10_080)周"
        }
        if minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440)天"
        }
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)小时"
        }
        return "\(minutes)分钟"
    }

    private static func preferredWindow(from snapshot: RateLimitSnapshot) -> RateLimitWindow? {
        [snapshot.primary, snapshot.secondary]
            .compactMap { $0 }
            .max { ($0.windowDurationMins ?? 0) < ($1.windowDurationMins ?? 0) }
    }

    private static func quotaReading(
        id: String,
        title: String,
        snapshot: RateLimitSnapshot
    ) -> QuotaLimitReading? {
        guard let window = preferredWindow(from: snapshot) else { return nil }
        return QuotaLimitReading(
            id: id,
            title: title,
            remainingPercent: remainingPercent(fromUsedPercent: window.usedPercent),
            resetsAt: window.resetsAt.map(Date.init(timeIntervalSince1970:)),
            windowDurationMins: window.windowDurationMins
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
