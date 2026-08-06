import Foundation

enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case limits
    case reset
    case usage
    case tasks
    case vpn

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .limits: "widget.limits"
        case .reset: "widget.reset"
        case .usage: "widget.usage"
        case .tasks: "widget.tasks"
        case .vpn: "widget.vpn"
        }
    }

    var systemImage: String {
        switch self {
        case .limits: "gauge.with.dots.needle.50percent"
        case .reset: "clock.arrow.circlepath"
        case .usage: "chart.xyaxis.line"
        case .tasks: "bolt.horizontal.circle"
        case .vpn: "network"
        }
    }
}

enum DashboardDensity: String, Codable, CaseIterable, Sendable {
    case compact
    case expanded
}

enum TaskDetailsSizing {
    private static let rowHeight: CGFloat = 68
    private static let maximumListHeight: CGFloat = 252

    static func listHeight(taskCount: Int) -> CGFloat {
        guard taskCount > 0 else { return 0 }
        return min(CGFloat(taskCount) * rowHeight, maximumListHeight)
    }
}

enum DashboardSizing {
    static let collapsedMinimumHeight: CGFloat = 60
    static let expandedMinimumHeight: CGFloat = 320
    static let maximumHeight: CGFloat = 900

    static func minimumHeight(isCollapsed: Bool) -> CGFloat {
        isCollapsed ? collapsedMinimumHeight : expandedMinimumHeight
    }

    static func panelHeight(
        contentHeight: CGFloat,
        availableScreenHeight: CGFloat,
        isCollapsed: Bool
    ) -> CGFloat {
        let minimumHeight = minimumHeight(isCollapsed: isCollapsed)
        let upperBound = min(
            maximumHeight,
            max(availableScreenHeight, minimumHeight)
        )
        return min(max(contentHeight, minimumHeight), upperBound)
    }
}

struct DashboardLayoutMeasurement: Equatable {
    let contentHeight: CGFloat
    let isCollapsed: Bool
}

enum DataQuality: String, Codable, Sendable {
    case direct
    case local
    case estimated
    case experimental
    case unavailable
}

struct RateLimitWindowPayload: Codable, Equatable, Sendable {
    let usedPercent: Int
    let windowDurationMins: Int64?
    let resetsAt: Int64?
}

struct CreditsSnapshot: Codable, Equatable, Sendable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

struct RateLimitSnapshotPayload: Codable, Equatable, Sendable {
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: RateLimitWindowPayload?
    let secondary: RateLimitWindowPayload?
    let credits: CreditsSnapshot?
    let rateLimitReachedType: String?
}

struct RateLimitsResponse: Codable, Equatable, Sendable {
    let rateLimits: RateLimitSnapshotPayload
    let rateLimitsByLimitId: [String: RateLimitSnapshotPayload]?
}

struct DisplayRateLimitWindow: Identifiable, Equatable, Sendable {
    enum Slot: String, Codable, Sendable {
        case primary
        case secondary
    }

    let id: String
    let limitId: String
    let limitName: String?
    let slot: Slot
    let usedPercent: Int
    let durationMinutes: Int64?
    let resetAt: Date?
    let planType: String?
    let creditsBalance: String?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    var isDormantModelSpecificWindow: Bool {
        guard
            usedPercent == 0,
            let limitName,
            !limitName.isEmpty
        else {
            return false
        }
        return limitName.caseInsensitiveCompare(limitId) != .orderedSame
    }
}

extension Array where Element == DisplayRateLimitWindow {
    var dashboardWindows: [DisplayRateLimitWindow] {
        let relevant = filter { !$0.isDormantModelSpecificWindow }
        return relevant.isEmpty ? Array(prefix(1)) : relevant
    }
}

extension RateLimitsResponse {
    var displayWindows: [DisplayRateLimitWindow] {
        let snapshots: [(String, RateLimitSnapshotPayload)]
        if let buckets = rateLimitsByLimitId, !buckets.isEmpty {
            snapshots = buckets.sorted { $0.key < $1.key }
        } else {
            snapshots = [(rateLimits.limitId ?? "codex", rateLimits)]
        }

        var result: [DisplayRateLimitWindow] = []
        for (key, snapshot) in snapshots {
            let limitID = snapshot.limitId ?? key
            let balance = snapshot.credits?.balance
            var windows: [DisplayRateLimitWindow] = []

            if let primary = snapshot.primary {
                windows.append(
                    DisplayRateLimitWindow(
                        id: "\(limitID):primary",
                        limitId: limitID,
                        limitName: snapshot.limitName,
                        slot: .primary,
                        usedPercent: primary.usedPercent,
                        durationMinutes: primary.windowDurationMins,
                        resetAt: primary.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                        planType: snapshot.planType,
                        creditsBalance: balance
                    )
                )
            }

            if let secondary = snapshot.secondary {
                windows.append(
                    DisplayRateLimitWindow(
                        id: "\(limitID):secondary",
                        limitId: limitID,
                        limitName: snapshot.limitName,
                        slot: .secondary,
                        usedPercent: secondary.usedPercent,
                        durationMinutes: secondary.windowDurationMins,
                        resetAt: secondary.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                        planType: snapshot.planType,
                        creditsBalance: balance
                    )
                )
            }

            result.append(contentsOf: windows)
        }

        return result.sorted { lhs, rhs in
            let leftDuration = lhs.durationMinutes ?? Int64.max
            let rightDuration = rhs.durationMinutes ?? Int64.max
            if leftDuration != rightDuration { return leftDuration < rightDuration }
            if lhs.limitId != rhs.limitId { return lhs.limitId < rhs.limitId }
            return lhs.slot.rawValue < rhs.slot.rawValue
        }
    }
}

struct AccountTokenUsageSummary: Codable, Equatable, Sendable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let longestRunningTurnSec: Int64?
    let currentStreakDays: Int64?
    let longestStreakDays: Int64?
}

struct DailyUsageBucket: Codable, Equatable, Identifiable, Sendable {
    let startDate: String
    let tokens: Int64

    var id: String { startDate }
}

struct TokenUsageResponse: Codable, Equatable, Sendable {
    let summary: AccountTokenUsageSummary
    let dailyUsageBuckets: [DailyUsageBucket]?
}

struct AccountReadResponse: Codable, Equatable, Sendable {
    struct Account: Codable, Equatable, Sendable {
        let type: String
        let email: String?
        let planType: String?
    }

    let account: Account?
    let requiresOpenaiAuth: Bool
}

struct ThreadListResponse: Codable, Equatable, Sendable {
    let data: [CodexThread]
}

struct CodexThread: Codable, Equatable, Identifiable, Sendable {
    struct Status: Codable, Equatable, Sendable {
        let type: String
        let activeFlags: [String]?
    }

    let id: String
    let name: String?
    let status: Status?
}

struct RunningTask: Identifiable, Equatable, Sendable {
    let id: String
    let title: String?
    let model: String?
    let reasoningEffort: String?
    let startedAt: Date
    let tokenCount: Int64?
}

struct TaskSummary: Equatable, Sendable {
    var runningTasks: [RunningTask] = []
    var waiting: Int = 0
    var failed: Int = 0
    var observed: Int = 0
    var updatedAt: Date?

    var active: Int { runningTasks.count }

    var modelCount: Int {
        Set(runningTasks.compactMap(\.model)).count
    }

    var totalTaskTokens: Int64? {
        let counts = runningTasks.compactMap(\.tokenCount)
        guard !counts.isEmpty else { return nil }
        return counts.reduce(0, +)
    }

    var oldestTaskStart: Date? {
        runningTasks.map(\.startedAt).min()
    }

    static let unavailable = TaskSummary()
}

struct VPNStatusSnapshot: Equatable, Sendable {
    enum State: String, Sendable {
        case connected
        case partial
        case disconnected
        case unavailable
    }

    let state: State
    let provider: String
    let mode: String?
    let group: String?
    let node: String?
    let latencyMilliseconds: Int?
    let nodeAlive: Bool?
    let systemProxyEnabled: Bool
    let tunnelEnabled: Bool
    let updatedAt: Date
}

struct RateLimitSample: Codable, Equatable, Sendable {
    let windowID: String
    let capturedAt: Date
    let usedPercent: Int
    let resetAt: Date?
}

struct UsageEstimate: Equatable, Sendable {
    enum Risk: String, Codable, Sendable {
        case ample
        case watch
        case critical
        case unknown
    }

    let lowerHours: Double
    let upperHours: Double
    let risk: Risk
    let sampleCount: Int
}

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value, DataQuality)
    case failed(String)
}

struct AppServerEvent: Sendable {
    let method: String
    let params: Data
}
