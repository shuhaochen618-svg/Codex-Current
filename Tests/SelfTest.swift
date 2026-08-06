import Foundation

private enum SelfTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): message
        }
    }
}

@main
struct SelfTestRunner {
    static func main() async throws {
        try testRateLimitPayloadBuildsAllOfficialWindows()
        try testDormantModelSpecificWindowIsHiddenFromDashboard()
        try testEstimatorReturnsRangeOnlyAfterEnoughObservedChange()
        try testEstimatorRejectsSamplesFromPreviousResetWindow()
        try testTaskBoundaryIgnoresMessageContent()
        try testRunningTaskDetailsAndTurnTokenDelta()
        try testTaskSummaryAggregatesCollapsedMetrics()
        try testAdaptivePanelSizingAndTaskDetailCap()
        try await testHistoryStoreMergesDailyBucketsWithoutSessionContent()
        try await testHistoryStoreMigratesLegacyArchive()
        print("CodexCurrent self-tests passed (10/10).")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw SelfTestFailure.failed(message) }
    }

    private static func testRateLimitPayloadBuildsAllOfficialWindows() throws {
        let json = #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "planType": "plus",
            "primary": {
              "usedPercent": 25,
              "windowDurationMins": 300,
              "resetsAt": 1786024800
            },
            "secondary": {
              "usedPercent": 42,
              "windowDurationMins": 10080,
              "resetsAt": 1786543200
            },
            "credits": null,
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": null
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: json)
        try require(response.displayWindows.count == 2, "Expected two rate-limit windows")
        try require(response.displayWindows[0].remainingPercent == 75, "Primary remaining mismatch")
        try require(response.displayWindows[0].durationMinutes == 300, "Primary duration mismatch")
        try require(response.displayWindows[1].remainingPercent == 58, "Secondary remaining mismatch")
        try require(response.displayWindows[1].durationMinutes == 10_080, "Secondary duration mismatch")
    }

    private static func testDormantModelSpecificWindowIsHiddenFromDashboard() throws {
        let reset = Date(timeIntervalSince1970: 1_786_543_200)
        let primary = DisplayRateLimitWindow(
            id: "codex:secondary",
            limitId: "codex",
            limitName: nil,
            slot: .secondary,
            usedPercent: 79,
            durationMinutes: 10_080,
            resetAt: reset,
            planType: "plus",
            creditsBalance: nil
        )
        let dormant = DisplayRateLimitWindow(
            id: "spark:secondary",
            limitId: "spark",
            limitName: "GPT-5.3-Codex-Spark",
            slot: .secondary,
            usedPercent: 0,
            durationMinutes: 10_080,
            resetAt: reset,
            planType: "plus",
            creditsBalance: nil
        )
        let active = DisplayRateLimitWindow(
            id: "spark:secondary",
            limitId: "spark",
            limitName: "GPT-5.3-Codex-Spark",
            slot: .secondary,
            usedPercent: 1,
            durationMinutes: 10_080,
            resetAt: reset,
            planType: "plus",
            creditsBalance: nil
        )

        try require(
            [primary, dormant].dashboardWindows == [primary],
            "Unused model-specific quota should be hidden"
        )
        try require(
            [primary, active].dashboardWindows == [primary, active],
            "Used model-specific quota should remain visible"
        )
    }

    private static func testEstimatorReturnsRangeOnlyAfterEnoughObservedChange() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        let reset = now.addingTimeInterval(24 * 3600)
        let window = DisplayRateLimitWindow(
            id: "codex:primary",
            limitId: "codex",
            limitName: nil,
            slot: .primary,
            usedPercent: 30,
            durationMinutes: 300,
            resetAt: reset,
            planType: "plus",
            creditsBalance: nil
        )
        let samples = [
            RateLimitSample(
                windowID: window.id,
                capturedAt: now.addingTimeInterval(-2 * 3600),
                usedPercent: 10,
                resetAt: reset
            ),
            RateLimitSample(
                windowID: window.id,
                capturedAt: now.addingTimeInterval(-3600),
                usedPercent: 20,
                resetAt: reset
            ),
            RateLimitSample(
                windowID: window.id,
                capturedAt: now,
                usedPercent: 30,
                resetAt: reset
            )
        ]

        guard let estimate = UsageEstimator.estimate(samples: samples, for: window, now: now) else {
            throw SelfTestFailure.failed("Expected an estimate")
        }
        try require(estimate.sampleCount == 3, "Estimate sample count mismatch")
        try require(abs(estimate.lowerHours - 4.69) <= 0.01, "Estimate lower bound mismatch")
        try require(abs(estimate.upperHours - 10.5) <= 0.01, "Estimate upper bound mismatch")
        try require(estimate.risk == .watch, "Estimate risk mismatch")
    }

    private static func testEstimatorRejectsSamplesFromPreviousResetWindow() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        let currentReset = now.addingTimeInterval(3600)
        let oldReset = now.addingTimeInterval(-3600)
        let window = DisplayRateLimitWindow(
            id: "codex:primary",
            limitId: "codex",
            limitName: nil,
            slot: .primary,
            usedPercent: 30,
            durationMinutes: 300,
            resetAt: currentReset,
            planType: "plus",
            creditsBalance: nil
        )
        let samples = (0..<3).map { index in
            RateLimitSample(
                windowID: window.id,
                capturedAt: now.addingTimeInterval(TimeInterval(-index * 1800)),
                usedPercent: 10 + index * 10,
                resetAt: oldReset
            )
        }

        try require(
            UsageEstimator.estimate(samples: samples, for: window, now: now) == nil,
            "Previous reset-window samples must be rejected"
        )
    }

    private static func testTaskBoundaryIgnoresMessageContent() throws {
        let data = #"""
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}
        {"type":"response_item","payload":{"type":"message","text":"literal task_complete text"}}
        """#.data(using: .utf8)!
        try require(
            CodexDesktopTaskMonitor.lastBoundary(in: data) == .started,
            "Message content must not be treated as a task boundary"
        )

        let completed = #"""
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}
        {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}
        """#.data(using: .utf8)!
        try require(
            CodexDesktopTaskMonitor.lastBoundary(in: completed) == .completed,
            "Latest task boundary should win"
        )
    }

    private static func testRunningTaskDetailsAndTurnTokenDelta() throws {
        let data = #"""
        {"timestamp":"2026-08-06T07:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1000},"last_token_usage":{"total_tokens":100}}}}
        {"timestamp":"2026-08-06T07:00:30Z","type":"event_msg","payload":{"type":"user_message","message":"Previous completed request"}}
        {"timestamp":"2026-08-06T07:01:01Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-2","started_at":1785999661}}
        {"timestamp":"2026-08-06T07:01:01Z","type":"turn_context","payload":{"turn_id":"turn-2","model":"gpt-test","effort":"high"}}
        {"timestamp":"2026-08-06T07:01:02Z","type":"event_msg","payload":{"type":"user_message","message":"# Files mentioned by the user:\n\n## screenshot.png\n\n## My request for Codex:\n  Build   the task dashboard with model and token details  "}}
        {"timestamp":"2026-08-06T07:01:03Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1425},"last_token_usage":{"total_tokens":425}}}}
        {"timestamp":"2026-08-06T07:01:04Z","type":"event_msg","payload":{"type":"user_message","message":"请你继续"}}
        """#.data(using: .utf8)!

        let observation = CodexDesktopTaskMonitor.parseSession(in: data)
        try require(observation.boundary == .started, "Task should still be running")
        guard let task = observation.runningTask else {
            throw SelfTestFailure.failed("Expected parsed running-task details")
        }
        try require(
            task.title == "Build the task dashboard with model and token details",
            "Task title normalization mismatch"
        )
        try require(task.model == "gpt-test", "Task model mismatch")
        try require(task.reasoningEffort == "high", "Task effort mismatch")
        try require(task.tokenCount == 425, "Per-turn token delta mismatch")
        try require(
            task.startedAt == Date(timeIntervalSince1970: 1_785_999_661),
            "Task start time mismatch"
        )
    }

    private static func testTaskSummaryAggregatesCollapsedMetrics() throws {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let summary = TaskSummary(
            runningTasks: [
                RunningTask(
                    id: "a",
                    title: "A",
                    model: "gpt-a",
                    reasoningEffort: nil,
                    startedAt: newer,
                    tokenCount: 300
                ),
                RunningTask(
                    id: "b",
                    title: "B",
                    model: "gpt-b",
                    reasoningEffort: nil,
                    startedAt: older,
                    tokenCount: 700
                ),
                RunningTask(
                    id: "c",
                    title: "C",
                    model: "gpt-a",
                    reasoningEffort: nil,
                    startedAt: newer,
                    tokenCount: nil
                )
            ]
        )

        try require(summary.active == 3, "Collapsed task count mismatch")
        try require(summary.modelCount == 2, "Collapsed model count mismatch")
        try require(summary.totalTaskTokens == 1_000, "Collapsed token total mismatch")
        try require(summary.oldestTaskStart == older, "Collapsed longest-task start mismatch")
    }

    private static func testAdaptivePanelSizingAndTaskDetailCap() throws {
        try require(
            TaskDetailsSizing.listHeight(taskCount: 0) == 0,
            "An empty task list should not request detail height"
        )
        try require(
            TaskDetailsSizing.listHeight(taskCount: 1) == 68,
            "A single task should request one row of detail height"
        )
        try require(
            TaskDetailsSizing.listHeight(taskCount: 8) == 252,
            "A long task list should cap its internal detail height"
        )
        try require(
            DashboardSizing.panelHeight(
                contentHeight: 240,
                availableScreenHeight: 1_000,
                isCollapsed: false
            ) == 320,
            "Short content should respect the panel minimum height"
        )
        try require(
            DashboardSizing.panelHeight(
                contentHeight: 720,
                availableScreenHeight: 1_000,
                isCollapsed: false
            ) == 720,
            "The outer panel should follow the measured component height"
        )
        try require(
            DashboardSizing.panelHeight(
                contentHeight: 1_200,
                availableScreenHeight: 780,
                isCollapsed: false
            ) == 780,
            "Tall content should stay within the current screen"
        )
        try require(
            DashboardSizing.panelHeight(
                contentHeight: 48,
                availableScreenHeight: 1_000,
                isCollapsed: true
            ) == 60,
            "Collapsed mode should reduce the dashboard to a compact status bar"
        )
    }

    private static func testHistoryStoreMergesDailyBucketsWithoutSessionContent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(directory: directory)
        let usage = TokenUsageResponse(
            summary: AccountTokenUsageSummary(
                lifetimeTokens: 100,
                peakDailyTokens: 100,
                longestRunningTurnSec: nil,
                currentStreakDays: 1,
                longestStreakDays: 1
            ),
            dailyUsageBuckets: [
                DailyUsageBucket(startDate: "2026-08-06", tokens: 100)
            ]
        )

        try await store.record(windows: [], usage: usage)
        let archive = await store.current()
        try require(archive.dailyUsage == usage.dailyUsageBuckets, "Daily usage merge mismatch")
        try require(archive.rateLimitSamples.isEmpty, "History should not invent rate-limit samples")
    }

    private static func testHistoryStoreMigratesLegacyArchive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let currentDirectory = root.appendingPathComponent("CodexCurrent", isDirectory: true)
        let legacyDirectory = root.appendingPathComponent("CodexBar", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        let legacyJSON = #"{"rateLimitSamples":[],"dailyUsage":[{"startDate":"2026-08-05","tokens":42}]}"#
        try Data(legacyJSON.utf8).write(
            to: legacyDirectory.appendingPathComponent("history.json")
        )

        let store = HistoryStore(
            directory: currentDirectory,
            legacyDirectory: legacyDirectory
        )
        let migrated = await store.current()
        try require(migrated.dailyUsage.first?.tokens == 42, "Legacy history should load")

        try await store.record(windows: [], usage: nil)
        try require(
            FileManager.default.fileExists(
                atPath: currentDirectory.appendingPathComponent("history.json").path
            ),
            "Legacy history should persist at the Codex Current path"
        )
    }
}
