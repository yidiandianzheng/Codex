import Foundation
import CoreGraphics

enum SelfTest {
    static func run() -> Bool {
        var failures: [String] = []

        check(EnergyLogic.remainingPercent(fromUsedPercent: 0) == 100, "0% used should leave 100%", into: &failures)
        check(EnergyLogic.remainingPercent(fromUsedPercent: 66) == 34, "66% used should leave 34%", into: &failures)
        check(EnergyLogic.remainingPercent(fromUsedPercent: 99.6) == 0, "remaining percentage should round", into: &failures)
        check(EnergyLogic.remainingPercent(fromUsedPercent: -5) == 100, "remaining percentage should clamp high", into: &failures)
        check(EnergyLogic.remainingPercent(fromUsedPercent: 120) == 0, "remaining percentage should clamp low", into: &failures)

        let toneCases: [(Int?, EnergyTone)] = [
            (nil, .unavailable), (0, .red), (19, .red), (20, .yellow),
            (49, .yellow), (50, .green), (99, .green), (100, .green),
        ]
        for (value, expected) in toneCases {
            check(EnergyLogic.tone(for: value) == expected, "wrong tone for \(value.map(String.init) ?? "nil")", into: &failures)
        }

        let overallWindow = RateLimitWindow(usedPercent: 10, windowDurationMins: 10_080, resetsAt: 2_000)
        let legacyShortWindow = RateLimitWindow(usedPercent: 66, windowDurationMins: 300, resetsAt: 1_000)
        let overall = EnergyLogic.overallReading(
            from: RateLimitSnapshot(limitId: "codex", primary: overallWindow, secondary: legacyShortWindow)
        )
        check(overall.remainingPercent == 90, "longest available window should be selected as the overall quota", into: &failures)
        check(overall.resetsAt == Date(timeIntervalSince1970: 2_000), "overall reset date should decode", into: &failures)

        let sparseUpdate = RateLimitSnapshot(
            limitId: nil,
            primary: RateLimitWindow(usedPercent: 12, windowDurationMins: 300, resetsAt: 3_000),
            secondary: nil
        )
        let mergedUpdate = EnergyLogic.mergingSparseUpdate(
            sparseUpdate,
            into: RateLimitSnapshot(limitId: "codex", primary: legacyShortWindow, secondary: overallWindow)
        )
        check(mergedUpdate.limitId == "codex", "sparse updates should retain the known limit id", into: &failures)
        check(mergedUpdate.primary == sparseUpdate.primary, "sparse updates should replace provided windows", into: &failures)
        check(mergedUpdate.secondary == overallWindow, "sparse updates should retain omitted windows", into: &failures)
        check(
            !EnergyLogic.belongsToSameLimit(
                RateLimitSnapshot(limitId: "other", primary: nil, secondary: nil),
                as: RateLimitSnapshot(limitId: "codex", primary: nil, secondary: nil)
            ),
            "updates for a different limit bucket should not replace the Codex quota",
            into: &failures
        )

        let missing = EnergyLogic.overallReading(
            from: RateLimitSnapshot(limitId: "codex", primary: nil, secondary: nil)
        )
        check(missing == .unavailable, "missing windows should be unavailable", into: &failures)
        checkQuotaDetails(into: &failures)
        checkCompactStatus(into: &failures)
        checkPanelInteraction(into: &failures)
        checkTokenFormatting(into: &failures)
        check(EnergyPanelMetrics.baseSize == CGSize(width: 260, height: 38), "compact panel should fit overall and GPT-5.3 percentages on one line", into: &failures)
        check(EnergyPanelMetrics.expandedSize == CGSize(width: 420, height: 304), "expanded panel size should fit five project rows", into: &failures)
        check(EnergyPanelMetrics.quotaSize == CGSize(width: 420, height: 240), "quota panel size should fit overall and model limits", into: &failures)

        let codexLocation = CodexWindowLocation(
            frame: CGRect(x: 100, y: 200, width: 1_200, height: 800),
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1_500, height: 1_100)
        )
        let compactOrigin = CodexHeaderLayout.panelOrigin(
            for: codexLocation,
            panelSize: EnergyPanelMetrics.baseSize,
            offset: .zero
        )
        let expectedHeaderSlotCenterX = (
            codexLocation.frame.minX + CodexHeaderLayout.headerLeadingReservedWidth
            + codexLocation.frame.maxX - CodexHeaderLayout.headerTrailingReservedWidth
        ) / 2
        check(
            compactOrigin.x + EnergyPanelMetrics.baseSize.width / 2 == expectedHeaderSlotCenterX,
            "compact panel should be centered in the marked header slot, not the whole window",
            into: &failures
        )
        check(
            compactOrigin.y == codexLocation.frame.maxY - CodexHeaderLayout.compactTopInset - EnergyPanelMetrics.baseSize.height,
            "compact panel should be vertically centered in the marked single header row",
            into: &failures
        )
        let expandedOrigin = CodexHeaderLayout.panelOrigin(
            for: codexLocation,
            panelSize: EnergyPanelMetrics.expandedSize,
            offset: .zero
        )
        check(
            compactOrigin.x + EnergyPanelMetrics.baseSize.width / 2
                == expandedOrigin.x + EnergyPanelMetrics.expandedSize.width / 2,
            "expanded panel should keep the same horizontal center",
            into: &failures
        )
        check(
            compactOrigin.y + EnergyPanelMetrics.baseSize.height
                == expandedOrigin.y + EnergyPanelMetrics.expandedSize.height,
            "expanded panel should grow downward while preserving its top edge",
            into: &failures
        )
        let quotaOrigin = CodexHeaderLayout.panelOrigin(
            for: codexLocation,
            panelSize: EnergyPanelMetrics.quotaSize,
            offset: .zero
        )
        check(
            compactOrigin.y + EnergyPanelMetrics.baseSize.height
                == quotaOrigin.y + EnergyPanelMetrics.quotaSize.height,
            "quota panel should grow downward while preserving its top edge",
            into: &failures
        )
        let movedOrigin = CodexHeaderLayout.panelOrigin(
            for: codexLocation,
            panelSize: EnergyPanelMetrics.baseSize,
            offset: CGSize(width: 48, height: -36)
        )
        check(
            movedOrigin.x == compactOrigin.x + 48 && movedOrigin.y == compactOrigin.y - 36,
            "custom position should remain relative to the default header slot",
            into: &failures
        )
        let positionTestSuite = "CodexPetEnergy.SelfTest.Position"
        if let positionDefaults = UserDefaults(suiteName: positionTestSuite) {
            positionDefaults.removePersistentDomain(forName: positionTestSuite)
            let savedOffset = CGSize(width: 52, height: -24)
            EnergyPanelPositionStore.save(savedOffset, defaults: positionDefaults)
            check(
                EnergyPanelPositionStore.load(defaults: positionDefaults) == savedOffset,
                "dragged position should persist across launches",
                into: &failures
            )
            EnergyPanelPositionStore.reset(defaults: positionDefaults)
            check(
                EnergyPanelPositionStore.load(defaults: positionDefaults) == .zero,
                "reset should restore the default header position",
                into: &failures
            )
            positionDefaults.removePersistentDomain(forName: positionTestSuite)
        } else {
            failures.append("position persistence test defaults should be available")
        }
        let titleRestrictedWindow: [String: Any] = [
            kCGWindowOwnerName as String: "ChatGPT",
            kCGWindowLayer as String: 0,
            kCGWindowBounds as String: [
                "X": 0, "Y": 30, "Width": 1_200, "Height": 800,
            ],
            kCGWindowAlpha as String: 1,
        ]
        check(
            CodexWindowTracker.codexMainWindowCandidate(titleRestrictedWindow) != nil,
            "main-window detection should not require the protected window-title field",
            into: &failures
        )

        checkProjectUsage(into: &failures)

        if failures.isEmpty {
            print("Self-test passed: quota buckets, compact GPT-5.3 status, right-click details, layout, persistence")
            return true
        }
        failures.forEach { print("Self-test failed: \($0)") }
        return false
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String, into failures: inout [String]) {
        if !condition() { failures.append(message) }
    }

    private static func checkCompactStatus(into failures: inout [String]) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 12)),
              let reset = calendar.date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 11))
        else {
            failures.append("compact status test dates should be constructible")
            return
        }

        let reading = EnergyReading(remainingPercent: 31, resetsAt: reset)
        let modelReading = QuotaLimitReading(
            id: "codex_bengalfox",
            title: "GPT-5.3-Codex-Spark 限额",
            remainingPercent: 86,
            resetsAt: reset,
            windowDurationMins: 10_080
        )
        check(
            EnergyLogic.compactStatusText(for: reading, now: now, calendar: calendar) == "31% · 7月25日 · 4天",
            "compact status should match the screenshot-style percentage, date, and rounded-up days",
            into: &failures
        )
        check(
            EnergyLogic.compactStatusText(
                for: reading,
                modelReading: modelReading,
                now: now,
                calendar: calendar
            ) == "总 31% · 7月25日 · 4天 · 5.3 86%",
            "combined compact status should label overall and GPT-5.3 values",
            into: &failures
        )
        check(
            EnergyLogic.compactStatusText(for: .unavailable, now: now, calendar: calendar) == "— · — · —",
            "unavailable compact status should not invent live data",
            into: &failures
        )
        check(
            EnergyLogic.compactStatusText(
                for: .unavailable,
                modelReading: nil,
                now: now,
                calendar: calendar
            ) == "总 — · — · — · 5.3 —",
            "combined compact status should preserve explicit unavailable markers",
            into: &failures
        )
        check(
            EnergyLogic.remainingDays(until: now.addingTimeInterval(-1), from: now) == 0,
            "past reset times should show zero remaining days",
            into: &failures
        )
    }

    private static func checkPanelInteraction(into failures: inout [String]) {
        var mode = EnergyPanelMode.compact
        mode.toggleProjects()
        check(mode == .projects, "right-click project action should show project details", into: &failures)
        mode.toggleProjects()
        check(mode == .compact, "repeating the project action should collapse the panel", into: &failures)
        mode.toggleQuota()
        check(mode == .quota, "right-click quota action should show remaining usage", into: &failures)
        mode.toggleProjects()
        check(mode == .projects, "project action should switch directly from quota details", into: &failures)
        mode.toggleQuota()
        check(mode == .quota, "quota action should switch directly from project details", into: &failures)
        mode.toggleQuota()
        check(mode == .compact, "repeating the quota action should close remaining usage", into: &failures)
    }

    private static func checkQuotaDetails(into failures: inout [String]) {
        let overall = RateLimitSnapshot(
            limitId: "codex",
            primary: RateLimitWindow(
                usedPercent: 63,
                windowDurationMins: 10_080,
                resetsAt: 4_000
            ),
            secondary: nil
        )
        let model = RateLimitSnapshot(
            limitId: "codex_bengalfox",
            limitName: "GPT-5.3-Codex-Spark",
            primary: RateLimitWindow(
                usedPercent: 6,
                windowDurationMins: 10_080,
                resetsAt: 3_000
            ),
            secondary: nil
        )
        let result = RateLimitReadResult(
            rateLimits: overall,
            rateLimitsByLimitId: [
                "codex": overall,
                "codex_bengalfox": model,
            ],
            rateLimitResetCredits: RateLimitResetCreditsSummary(availableCount: 1)
        )
        let summary = EnergyLogic.quotaDetailSummary(from: result)
        check(summary.overall?.remainingPercent == 37, "overall quota should show remaining rather than used percentage", into: &failures)
        check(summary.modelLimits.count == 1, "named model quota should appear once", into: &failures)
        check(summary.modelLimits.first?.title == "GPT-5.3-Codex-Spark 限额", "model quota should retain its backend name", into: &failures)
        check(summary.modelLimits.first?.remainingPercent == 94, "model quota should convert used percentage to remaining", into: &failures)
        check(summary.featuredCompactLimit?.id == "codex_bengalfox", "compact quota should prefer the stable GPT-5.3 limit id", into: &failures)
        check(summary.availableResetCount == 1, "available reset credit count should be retained", into: &failures)
        check(EnergyLogic.windowDurationText(10_080) == "1周", "weekly quota should use a readable duration", into: &failures)

        let fallbackModel = QuotaLimitReading(
            id: "renamed-limit-id",
            title: "GPT-5.3-Codex-Spark 限额",
            remainingPercent: 82,
            resetsAt: nil,
            windowDurationMins: 10_080
        )
        let fallbackSummary = QuotaDetailSummary(
            overall: nil,
            modelLimits: [fallbackModel],
            availableResetCount: nil
        )
        check(
            fallbackSummary.featuredCompactLimit == fallbackModel,
            "compact quota should fall back to the GPT-5.3 display name",
            into: &failures
        )
        let unrelatedSummary = QuotaDetailSummary(
            overall: nil,
            modelLimits: [
                QuotaLimitReading(
                    id: "other",
                    title: "Other Model 限额",
                    remainingPercent: 70,
                    resetsAt: nil,
                    windowDurationMins: 10_080
                ),
            ],
            availableResetCount: nil
        )
        check(
            unrelatedSummary.featuredCompactLimit == nil,
            "compact quota should not substitute an unrelated model",
            into: &failures
        )

        let modelUpdate = RateLimitSnapshot(
            limitId: "codex_bengalfox",
            primary: RateLimitWindow(
                usedPercent: 10,
                windowDurationMins: 10_080,
                resetsAt: 3_500
            ),
            secondary: nil
        )
        let merged = EnergyLogic.mergingSparseUpdate(modelUpdate, into: result)
        let mergedModel = merged?.rateLimitsByLimitId?["codex_bengalfox"]
        check(mergedModel?.limitName == "GPT-5.3-Codex-Spark", "sparse model update should retain its display name", into: &failures)
        check(mergedModel?.primary?.usedPercent == 10, "sparse model update should refresh its own bucket", into: &failures)
        check(merged?.rateLimits.primary?.usedPercent == 63, "model update should not overwrite overall quota", into: &failures)
        check(merged?.rateLimitResetCredits?.availableCount == 1, "sparse update should retain reset credits", into: &failures)

        let unknown = RateLimitSnapshot(
            limitId: "unknown",
            primary: RateLimitWindow(
                usedPercent: 20,
                windowDurationMins: 10_080,
                resetsAt: 5_000
            ),
            secondary: nil
        )
        check(
            EnergyLogic.mergingSparseUpdate(unknown, into: result) == nil,
            "unknown quota bucket should trigger a complete refresh",
            into: &failures
        )
    }

    private static func checkTokenFormatting(into failures: inout [String]) {
        check(TokenFormatting.compact(999) == "999", "small Token values should remain exact", into: &failures)
        check(TokenFormatting.compact(1_250) == "1.2K", "thousands should use compact K notation", into: &failures)
        check(TokenFormatting.compact(12_500) == "12K", "large thousands should avoid noisy decimals", into: &failures)
        check(TokenFormatting.compact(1_250_000) == "1.2M", "millions should use compact M notation", into: &failures)
        check(TokenFormatting.exact(1_234) == "1,234", "detail values should use grouped digits", into: &failures)
    }

    private static func checkProjectUsage(into failures: inout [String]) {
        let now = Date()
        let active = now.addingTimeInterval(-60)
        let older = ProjectUsageLogic.startOfDay(containing: now).addingTimeInterval(-1)
        let sessionA = ProjectUsageMonitor.parseSession(
            sessionLog(id: "a", cwd: "/tmp/alpha", events: [(active, 100, 20, 5, 80), (active.addingTimeInterval(10), 40, 10, 2, 30)]),
            fallbackID: "fallback-a",
            now: now
        )
        let sessionB = ProjectUsageMonitor.parseSession(
            sessionLog(id: "b", cwd: "/tmp/alpha", events: [(active.addingTimeInterval(20), 30, 7, 1, 20)]),
            fallbackID: "fallback-b",
            now: now
        )
        let expired = ProjectUsageMonitor.parseSession(
            sessionLog(id: "old", cwd: "/tmp/old", events: [(older, 500, 20, 0, 0)]),
            fallbackID: "fallback-old",
            now: now
        )
        check(sessionA?.totals.totalTokens == 170, "turn usage should be summed within a session", into: &failures)
        check(expired == nil, "usage before today's Shanghai boundary should be excluded", into: &failures)

        let sessions = [sessionA, sessionB].compactMap { $0 }
        let alpha = ProjectUsageLogic.aggregate(sessions).first
        check(alpha?.projectName == "alpha", "directory name should become project name", into: &failures)
        check(alpha?.totals.totalTokens == 207, "sessions in one project should be merged", into: &failures)
        check(ProjectUsageMonitor.parseSession("not json", fallbackID: "bad", now: now) == nil, "malformed logs should be ignored", into: &failures)

        let ranked = (0..<6).map { index in
            ProjectUsageSession(
                id: "rank-\(index)",
                directory: "/tmp/project-\(index)",
                totals: ProjectUsageTotals(inputTokens: 1, outputTokens: 1, reasoningTokens: 0, cachedInputTokens: 0, turnCount: 1, maximumTurnTokens: 2),
                lastActivity: active.addingTimeInterval(TimeInterval(index))
            )
        }
        let top = ProjectUsageLogic.aggregate(ranked)
        check(top.count == 5 && top.first?.projectName == "project-5", "only five most recently active projects should remain", into: &failures)

        let highUsageButOld = ProjectUsageSession(
            id: "high-but-old",
            directory: "/tmp/high-but-old",
            totals: ProjectUsageTotals(inputTokens: 1_000_000, outputTokens: 1, reasoningTokens: 0, cachedInputTokens: 0, turnCount: 1, maximumTurnTokens: 1_000_001),
            lastActivity: active.addingTimeInterval(-100)
        )
        let recent = ProjectUsageLogic.aggregate([highUsageButOld] + ranked)
        check(!recent.contains(where: { $0.projectName == "high-but-old" }), "project limit should prefer recent activity over historical token volume", into: &failures)

        let newerPartial = ProjectUsageSession(
            id: "duplicate",
            directory: "/tmp/alpha",
            totals: ProjectUsageTotals(inputTokens: 10, outputTokens: 1, reasoningTokens: 0, cachedInputTokens: 0, turnCount: 1, maximumTurnTokens: 11),
            lastActivity: active.addingTimeInterval(100)
        )
        let olderComplete = ProjectUsageSession(
            id: "duplicate",
            directory: "/tmp/alpha",
            totals: ProjectUsageTotals(inputTokens: 100, outputTokens: 20, reasoningTokens: 0, cachedInputTokens: 0, turnCount: 2, maximumTurnTokens: 80),
            lastActivity: active
        )
        check(
            ProjectUsageLogic.preferredVersion(newerPartial, olderComplete) == olderComplete,
            "duplicate session selection should keep the more complete log deterministically",
            into: &failures
        )
    }

    private static func sessionLog(id: String, cwd: String, events: [(Date, Int, Int, Int, Int)]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let meta = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(id)\",\"cwd\":\"\(cwd)\"}}"
        let rows = events.map { event in
            "{\"timestamp\":\"\(formatter.string(from: event.0))\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"last_token_usage\":{\"input_tokens\":\(event.1),\"output_tokens\":\(event.2),\"reasoning_output_tokens\":\(event.3),\"cached_input_tokens\":\(event.4)}}}}"
        }
        return ([meta] + rows).joined(separator: "\n")
    }
}
