import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var limits: LoadState<[DisplayRateLimitWindow]> = .idle
    @Published private(set) var usage: LoadState<TokenUsageResponse> = .idle
    @Published private(set) var tasks: LoadState<TaskSummary> = .idle
    @Published private(set) var vpn: LoadState<VPNStatusSnapshot> = .idle
    @Published private(set) var estimates: [String: UsageEstimate] = [:]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var accountPlan: String?
    @Published private(set) var connectionMessage: String?

    let preferences: WidgetPreferences

    private let appServer: CodexAppServerClient
    private let vpnClient: VPNStatusClient
    private let taskMonitor: CodexDesktopTaskMonitor
    private let historyStore: HistoryStore
    private let notifications: NotificationCoordinator
    private var refreshLoop: Task<Void, Never>?
    private var taskLoop: Task<Void, Never>?
    private var vpnLoop: Task<Void, Never>?
    private var eventLoop: Task<Void, Never>?
    private var hasStarted = false
    private var previousTaskSummary: TaskSummary?
    private var previousVPNState: VPNStatusSnapshot.State?

    init(
        preferences: WidgetPreferences? = nil,
        appServer: CodexAppServerClient = CodexAppServerClient(),
        vpnClient: VPNStatusClient = VPNStatusClient(),
        taskMonitor: CodexDesktopTaskMonitor = CodexDesktopTaskMonitor(),
        historyStore: HistoryStore = HistoryStore(),
        notifications: NotificationCoordinator? = nil
    ) {
        self.preferences = preferences ?? WidgetPreferences()
        self.appServer = appServer
        self.vpnClient = vpnClient
        self.taskMonitor = taskMonitor
        self.historyStore = historyStore
        self.notifications = notifications ?? NotificationCoordinator()
    }

    deinit {
        refreshLoop?.cancel()
        taskLoop?.cancel()
        vpnLoop?.cancel()
        eventLoop?.cancel()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task {
            await notifications.requestAuthorization()
            await refresh()
        }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
        taskLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await self?.refreshTaskActivity()
            }
        }
        vpnLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await self?.refreshVPN()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if case .idle = vpn { vpn = .loading }
        if case .idle = limits { limits = .loading }
        if case .idle = usage { usage = .loading }
        if case .idle = tasks { tasks = .loading }

        async let codex: Void = refreshCodex()
        async let vpnStatus: Void = refreshVPN()
        async let taskStatus: Void = refreshTaskActivity()
        _ = await (codex, vpnStatus, taskStatus)
        lastUpdated = Date()
        isRefreshing = false
    }

    func clearHistory() async {
        try? await historyStore.clear()
        estimates = [:]
    }

    func shutdown() async {
        refreshLoop?.cancel()
        taskLoop?.cancel()
        vpnLoop?.cancel()
        eventLoop?.cancel()
        refreshLoop = nil
        taskLoop = nil
        vpnLoop = nil
        eventLoop = nil
        await appServer.stop()
    }

    private func refreshCodex() async {
        do {
            try await appServer.start()
            startEventLoopIfNeeded()

            let account = try await appServer.readAccount()
            guard let accountInfo = account.account else {
                let message = account.requiresOpenaiAuth
                    ? L10n.text("error.not_logged_in")
                    : L10n.text("error.generic")
                applyCodexFailure(message)
                return
            }
            guard accountInfo.type == "chatgpt" else {
                applyCodexFailure(L10n.text("error.unsupported_auth"))
                return
            }
            accountPlan = accountInfo.planType
            connectionMessage = nil

            async let rateLimitsRequest = appServer.readRateLimits()
            async let usageRequest = appServer.readTokenUsage()
            let rateLimits = try await rateLimitsRequest
            let tokenUsage = try await usageRequest
            let windows = rateLimits.displayWindows

            limits = windows.isEmpty
                ? .failed(L10n.text("label.unavailable"))
                : .loaded(windows, .direct)
            usage = .loaded(tokenUsage, .direct)

            try? await historyStore.record(windows: windows, usage: tokenUsage)
            let archive = await historyStore.current()
            estimates = Dictionary(
                uniqueKeysWithValues: windows.compactMap { window in
                    UsageEstimator.estimate(
                        samples: archive.rateLimitSamples,
                        for: window
                    ).map { (window.id, $0) }
                }
            )
            windows.forEach(notifications.notifyLimitIfNeeded)
        } catch {
            applyCodexFailure(error.localizedDescription)
        }
    }

    private func refreshVPN() async {
        let snapshot = await vpnClient.fetch()
        vpn = .loaded(snapshot, .local)
        if
            let previousVPNState,
            previousVPNState != snapshot.state,
            snapshot.state == .disconnected || snapshot.state == .unavailable
        {
            notifications.notifyVPNDisconnected()
        }
        previousVPNState = snapshot.state
    }

    private func refreshTaskActivity() async {
        let summary = await taskMonitor.snapshot()
        tasks = .loaded(summary, .experimental)
        if let previousTaskSummary {
            if previousTaskSummary.active > summary.active {
                notifications.notifyTaskCompleted(failed: false)
            }
            if previousTaskSummary.failed < summary.failed {
                notifications.notifyTaskCompleted(failed: true)
            }
        }
        previousTaskSummary = summary
    }

    private func startEventLoopIfNeeded() {
        guard eventLoop == nil else { return }
        eventLoop = Task { [weak self, appServer] in
            let stream = await appServer.events()
            for await event in stream {
                guard !Task.isCancelled else { break }
                self?.handle(event: event)
            }
        }
    }

    private func handle(event: AppServerEvent) {
        switch event.method {
        case "account/rateLimits/updated":
            Task { await refresh() }
        default:
            break
        }
    }

    private func applyCodexFailure(_ message: String) {
        limits = .failed(message)
        usage = .failed(message)
        connectionMessage = message
    }
}
