import Charts
import SwiftUI

struct WidgetCardView: View {
    let kind: WidgetKind
    @ObservedObject var model: AppModel
    let density: DashboardDensity

    var body: some View {
        CardContainer(
            title: L10n.text(kind.titleKey),
            systemImage: kind.systemImage,
            quality: quality
        ) {
            switch kind {
            case .limits:
                LimitsContent(state: model.limits, density: density)
            case .reset:
                ResetContent(state: model.limits, density: density)
            case .usage:
                UsageContent(
                    state: model.usage,
                    estimates: model.estimates,
                    windows: loadedWindows,
                    density: density
                )
            case .tasks:
                TasksContent(state: model.tasks, density: density)
            case .vpn:
                VPNContent(state: model.vpn, density: density)
            }
        }
    }

    private var loadedWindows: [DisplayRateLimitWindow] {
        guard case let .loaded(windows, _) = model.limits else { return [] }
        return windows.dashboardWindows
    }

    private var quality: DataQuality {
        switch kind {
        case .limits, .reset:
            quality(of: model.limits)
        case .usage:
            quality(of: model.usage)
        case .tasks:
            quality(of: model.tasks)
        case .vpn:
            quality(of: model.vpn)
        }
    }

    private func quality<Value>(of state: LoadState<Value>) -> DataQuality {
        switch state {
        case let .loaded(_, quality): quality
        case .failed: .unavailable
        default: .unavailable
        }
    }
}

private struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    let quality: DataQuality
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                QualityBadge(quality: quality)
            }
            content()
        }
        .padding(14)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var tint: Color {
        switch quality {
        case .direct, .local: .green
        case .estimated: .orange
        case .experimental: .blue
        case .unavailable: .secondary
        }
    }
}

private struct QualityBadge: View {
    let quality: DataQuality

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }

    private var label: String {
        switch quality {
        case .direct: L10n.text("label.direct")
        case .local: L10n.text("label.local")
        case .estimated: L10n.text("label.estimated")
        case .experimental: L10n.text("label.experimental")
        case .unavailable: L10n.text("label.unavailable")
        }
    }

    private var color: Color {
        switch quality {
        case .direct, .local: .green
        case .estimated: .orange
        case .experimental: .blue
        case .unavailable: .secondary
        }
    }
}

private struct LimitsContent: View {
    let state: LoadState<[DisplayRateLimitWindow]>
    let density: DashboardDensity

    var body: some View {
        StateContent(state: state) { windows in
            let visibleWindows = windows.dashboardWindows
            if let first = visibleWindows.first, density == .compact {
                HStack(alignment: .firstTextBaseline) {
                    Text(DisplayFormatters.windowName(first))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.format("label.remaining", first.remainingPercent))
                        .font(.title3.weight(.semibold))
                }
                ProgressView(value: Double(first.remainingPercent), total: 100)
                    .tint(limitColor(first.remainingPercent))
            } else {
                ForEach(visibleWindows) { window in
                    RateLimitRow(window: window)
                }
            }
        }
    }
}

private struct RateLimitRow: View {
    let window: DisplayRateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DisplayFormatters.windowName(window))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("label.remaining", window.remainingPercent))
                    .font(.body.weight(.semibold))
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(limitColor(window.remainingPercent))
            HStack {
                Text(L10n.format("label.used", window.usedPercent))
                Spacer()
                Text(L10n.format("label.reset_at", DisplayFormatters.resetTime(window.resetAt)))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct ResetContent: View {
    let state: LoadState<[DisplayRateLimitWindow]>
    let density: DashboardDensity

    var body: some View {
        StateContent(state: state) { windows in
            let dated = windows.dashboardWindows.filter { $0.resetAt != nil }
            if density == .compact, let next = dated.min(by: resetSooner) {
                HStack {
                    Text(DisplayFormatters.windowName(next))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(DisplayFormatters.resetTime(next.resetAt))
                        .font(.body.weight(.semibold))
                }
            } else {
                ForEach(dated) { window in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DisplayFormatters.windowName(window))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let resetAt = window.resetAt {
                                Text(DisplayFormatters.relativeTime(resetAt))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(DisplayFormatters.resetTime(window.resetAt))
                            .font(.body.weight(.medium))
                    }
                }
            }
        }
    }

    private func resetSooner(_ lhs: DisplayRateLimitWindow, _ rhs: DisplayRateLimitWindow) -> Bool {
        (lhs.resetAt ?? .distantFuture) < (rhs.resetAt ?? .distantFuture)
    }
}

private struct UsageContent: View {
    let state: LoadState<TokenUsageResponse>
    let estimates: [String: UsageEstimate]
    let windows: [DisplayRateLimitWindow]
    let density: DashboardDensity

    var body: some View {
        StateContent(state: state) { usage in
            let buckets = usage.dailyUsageBuckets ?? []
            let today = buckets.last?.tokens
            let estimate = windows.compactMap { estimates[$0.id] }.first

            HStack(alignment: .firstTextBaseline) {
                if let today {
                    Text(L10n.format("label.today_tokens", today))
                        .font(.body.weight(.semibold))
                } else if let lifetime = usage.summary.lifetimeTokens {
                    Text(L10n.format("label.lifetime_tokens", lifetime))
                        .font(.body.weight(.semibold))
                } else {
                    Text(L10n.text("label.unavailable"))
                }
                Spacer()
                if let streak = usage.summary.currentStreakDays {
                    Text(L10n.format("label.streak", streak))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if density == .expanded, !buckets.isEmpty {
                Chart(buckets.suffix(14)) { bucket in
                    BarMark(
                        x: .value("Date", bucket.startDate),
                        y: .value("Tokens", bucket.tokens)
                    )
                    .foregroundStyle(.purple.gradient)
                    .cornerRadius(2)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 54)
            }

            if let estimate {
                HStack {
                    Label(
                        L10n.format(
                            "label.estimate_range",
                            estimate.lowerHours,
                            estimate.upperHours
                        ),
                        systemImage: "wand.and.stars"
                    )
                    Spacer()
                    Text(riskLabel(estimate.risk))
                }
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Text(L10n.text("label.not_enough_history"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func riskLabel(_ risk: UsageEstimate.Risk) -> String {
        switch risk {
        case .ample: L10n.text("label.risk_ample")
        case .watch: L10n.text("label.risk_watch")
        case .critical: L10n.text("label.risk_critical")
        case .unknown: L10n.text("label.not_enough_history")
        }
    }
}

private struct TasksContent: View {
    let state: LoadState<TaskSummary>
    let density: DashboardDensity
    @State private var showsDetails = false

    var body: some View {
        StateContent(state: state) { tasks in
            if tasks.runningTasks.isEmpty {
                Label(L10n.text("label.no_active_tasks"), systemImage: "moon.zzz")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsDetails.toggle()
                        }
                    } label: {
                        TaskSummaryRow(tasks: tasks, showsDetails: showsDetails)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .help(
                        L10n.text(
                            showsDetails ? "action.collapse_tasks" : "action.expand_tasks"
                        )
                    )

                    if showsDetails {
                        Divider().opacity(0.45)
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(tasks.runningTasks) { task in
                                    RunningTaskRow(task: task)
                                    if task.id != tasks.runningTasks.last?.id {
                                        Divider().opacity(0.45)
                                    }
                                }
                            }
                        }
                        .frame(height: detailsHeight(taskCount: tasks.runningTasks.count))
                    }
                }
            }
            if density == .expanded, showsDetails {
                Text(L10n.text("tasks.beta_detail"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detailsHeight(taskCount: Int) -> CGFloat {
        min(CGFloat(taskCount) * 68, 252)
    }
}

private struct TaskSummaryRow: View {
    let tasks: TaskSummary
    let showsDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.format("label.active_tasks", tasks.active), systemImage: "circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Text(showsDetails ? L10n.text("action.collapse") : L10n.text("action.details"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsDetails ? 180 : 0))
            }

            HStack(spacing: 12) {
                Label(L10n.format("label.task_models", tasks.modelCount), systemImage: "cpu")
                if let oldestTaskStart = tasks.oldestTaskStart {
                    Label(
                        L10n.format(
                            "label.task_longest",
                            DisplayFormatters.taskDuration(since: oldestTaskStart)
                        ),
                        systemImage: "clock"
                    )
                }
                if let totalTokens = tasks.totalTaskTokens {
                    Label(
                        L10n.format(
                            "label.task_total_tokens",
                            DisplayFormatters.tokens(totalTokens)
                        ),
                        systemImage: "number"
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct RunningTaskRow: View {
    let task: RunningTask

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(task.title ?? L10n.text("label.untitled_task"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Label(modelLabel, systemImage: "cpu")
                    .lineLimit(1)
                Label(
                    DisplayFormatters.taskDuration(since: task.startedAt),
                    systemImage: "clock"
                )
                if let tokenCount = task.tokenCount {
                    Label(
                        L10n.format("label.task_tokens", DisplayFormatters.tokens(tokenCount)),
                        systemImage: "number"
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var modelLabel: String {
        let model = task.model ?? L10n.text("label.unknown_model")
        guard let effort = task.reasoningEffort, !effort.isEmpty else { return model }
        return "\(model) · \(effort)"
    }
}

private struct VPNContent: View {
    let state: LoadState<VPNStatusSnapshot>
    let density: DashboardDensity

    var body: some View {
        StateContent(state: state) { snapshot in
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Label {
                    Text(vpnLabel(snapshot.state))
                        .font(.body.weight(.semibold))
                } icon: {
                    Circle()
                        .fill(vpnColor(snapshot.state))
                        .frame(width: 9, height: 9)
                }
                Spacer()
                if let latency = snapshot.latencyMilliseconds {
                    Text(L10n.format("label.vpn_latency", latency))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(latencyColor(latency))
                }
            }
            if density == .expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let node = snapshot.node {
                        HStack(alignment: .top) {
                            Text(L10n.text("label.vpn_node"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(node)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }
                    HStack {
                        Text(snapshot.provider)
                        Spacer()
                        if let mode = snapshot.mode {
                            Text(mode.uppercased())
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.1), in: Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                if snapshot.state == .partial {
                    Text(L10n.text("vpn.partial_detail"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct StateContent<Value, Content: View>: View {
    let state: LoadState<Value>
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            HStack {
                ProgressView().controlSize(.small)
                Text(L10n.text("label.loading"))
                    .foregroundStyle(.secondary)
            }
        case let .loaded(value, _):
            content(value)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private func limitColor(_ remaining: Int) -> Color {
    if remaining <= 10 { return .red }
    if remaining <= 25 { return .orange }
    return .purple
}

private func vpnColor(_ state: VPNStatusSnapshot.State) -> Color {
    switch state {
    case .connected: .green
    case .partial: .orange
    case .disconnected: .red
    case .unavailable: .secondary
    }
}

private func vpnLabel(_ state: VPNStatusSnapshot.State) -> String {
    switch state {
    case .connected: L10n.text("vpn.connected")
    case .partial: L10n.text("vpn.partial")
    case .disconnected: L10n.text("vpn.disconnected")
    case .unavailable: L10n.text("vpn.unavailable")
    }
}

private func latencyColor(_ latency: Int) -> Color {
    if latency >= 1_000 { return .red }
    if latency >= 500 { return .orange }
    return .green
}
