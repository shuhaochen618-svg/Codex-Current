import SwiftUI

@MainActor
final class DashboardPresentationState: ObservableObject {
    @Published var isCollapsed = false
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: WidgetPreferences
    @ObservedObject private var presentation: DashboardPresentationState
    private let onToggleCollapsed: () -> Void
    private let onLayoutChange: (DashboardLayoutMeasurement) -> Void

    init(
        model: AppModel,
        presentation: DashboardPresentationState,
        onToggleCollapsed: @escaping () -> Void,
        onLayoutChange: @escaping (DashboardLayoutMeasurement) -> Void = { _ in }
    ) {
        self.model = model
        _presentation = ObservedObject(wrappedValue: presentation)
        self.onToggleCollapsed = onToggleCollapsed
        self.onLayoutChange = onLayoutChange
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        VStack(spacing: 0) {
            header.reportDashboardHeight()

            if !presentation.isCollapsed {
                Divider().opacity(0.45)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(preferences.visibleWidgets) { kind in
                            WidgetCardView(
                                kind: kind,
                                model: model,
                                density: preferences.density
                            )
                            .reportDashboardHeight()
                        }

                        Divider()
                            .opacity(0.35)
                            .padding(.top, 2)
                            .reportDashboardHeight()

                        footer.reportDashboardHeight()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(
            minWidth: 360,
            idealWidth: 420,
            minHeight: DashboardSizing.minimumHeight(
                isCollapsed: presentation.isCollapsed
            )
        )
        .background(.ultraThinMaterial)
        .onPreferenceChange(DashboardMeasuredHeightKey.self) { measuredHeight in
            guard measuredHeight > 0 else { return }
            onLayoutChange(
                DashboardLayoutMeasurement(
                    contentHeight: ceil(measuredHeight)
                        + (presentation.isCollapsed
                            ? 0
                            : DashboardSizing.bodyLayoutAllowance(
                                widgetCount: preferences.visibleWidgets.count
                            )),
                    isCollapsed: presentation.isCollapsed
                )
            )
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.purple)
                .frame(width: 34, height: 34)
                .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.text("app.name"))
                    .font(.headline)
                if presentation.isCollapsed {
                    compactMetrics
                } else {
                    Text(L10n.text("app.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleCollapsed()
                }
            } label: {
                Image(
                    systemName: presentation.isCollapsed
                        ? "rectangle.expand.vertical"
                        : "rectangle.compress.vertical"
                )
            }
            .buttonStyle(.plain)
            .help(
                L10n.text(
                    presentation.isCollapsed
                        ? "action.expand_dashboard"
                        : "action.collapse_dashboard"
                )
            )

            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(model.isRefreshing ? .degrees(360) : .zero)
                    .animation(
                        model.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: model.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.text("action.refresh"))

            Toggle(
                isOn: Binding(
                    get: { preferences.isPinned },
                    set: { preferences.isPinned = $0 }
                )
            ) {
                Image(systemName: preferences.isPinned ? "pin.fill" : "pin")
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .help(L10n.text("label.pinned"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var compactMetrics: some View {
        HStack(spacing: 9) {
            compactMetric(
                systemImage: "gauge.with.dots.needle.50percent",
                value: compactRemainingPercent.map { "\($0)%" } ?? "—",
                color: compactRemainingPercent.map(compactLimitColor) ?? .secondary,
                help: L10n.text("widget.limits")
            )
            compactMetric(
                systemImage: "bolt.horizontal.circle.fill",
                value: compactActiveTasks.map(String.init) ?? "—",
                color: compactActiveTasks.map { $0 > 0 ? .green : .secondary } ?? .secondary,
                help: L10n.text("widget.tasks")
            )
            compactMetric(
                systemImage: "network",
                value: compactVPNLatency.map { "\($0) ms" } ?? "—",
                color: compactVPNLatency.map(compactLatencyColor) ?? .secondary,
                help: L10n.text("widget.vpn")
            )
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
        .lineLimit(1)
    }

    private func compactMetric(
        systemImage: String,
        value: String,
        color: Color,
        help: String
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(value)
                .foregroundStyle(.primary)
        }
        .help(help)
    }

    private var compactRemainingPercent: Int? {
        guard case let .loaded(windows, _) = model.limits else { return nil }
        return windows.dashboardWindows.first?.remainingPercent
    }

    private var compactActiveTasks: Int? {
        guard case let .loaded(tasks, _) = model.tasks else { return nil }
        return tasks.active
    }

    private var compactVPNLatency: Int? {
        guard case let .loaded(snapshot, _) = model.vpn else { return nil }
        return snapshot.latencyMilliseconds
    }

    private func compactLimitColor(_ remaining: Int) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 25 { return .orange }
        return .purple
    }

    private func compactLatencyColor(_ latency: Int) -> Color {
        if latency >= 1_000 { return .red }
        if latency >= 500 { return .orange }
        return .green
    }

    private var footer: some View {
        HStack {
            Label(L10n.text("label.local_only"), systemImage: "lock.shield")
            Spacer()
            if let lastUpdated = model.lastUpdated {
                Text(L10n.format("label.updated", DisplayFormatters.relativeTime(lastUpdated)))
            } else {
                Text(L10n.text("label.loading"))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}

private struct DashboardMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension View {
    func reportDashboardHeight() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: DashboardMeasuredHeightKey.self,
                    value: geometry.size.height
                )
            }
        }
    }
}
