import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var panel: FloatingPanelController
    @ObservedObject private var preferences: WidgetPreferences

    init(model: AppModel, panel: FloatingPanelController) {
        self.model = model
        self.panel = panel
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.text("app.name"))
                        .font(.headline)
                    menuStatus
                }
                Spacer()
            }

            Button {
                panel.toggle()
            } label: {
                Label(
                    panel.isVisible ? L10n.text("action.hide") : L10n.text("action.show"),
                    systemImage: panel.isVisible ? "eye.slash" : "eye"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            Toggle(
                L10n.text("label.pinned"),
                isOn: Binding(
                    get: { preferences.isPinned },
                    set: { preferences.isPinned = $0 }
                )
            )

            Picker(
                L10n.text("settings.display"),
                selection: Binding(
                    get: { preferences.density },
                    set: { preferences.density = $0 }
                )
            ) {
                Text(L10n.text("label.compact")).tag(DashboardDensity.compact)
                Text(L10n.text("label.expanded")).tag(DashboardDensity.expanded)
            }
            .pickerStyle(.segmented)

            Divider()

            HStack {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label(L10n.text("action.refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing)

                Spacer()

                SettingsLink {
                    Label(L10n.text("action.settings"), systemImage: "slider.horizontal.3")
                }
            }

            Button(role: .destructive) {
                Task {
                    await model.shutdown()
                    NSApp.terminate(nil)
                }
            } label: {
                Label(L10n.text("action.quit"), systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 290)
    }

    @ViewBuilder
    private var menuStatus: some View {
        switch model.limits {
        case let .loaded(windows, _):
            if let first = windows.first {
                Text(L10n.format("label.remaining", first.remainingPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.text("label.unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            Text(L10n.text("label.loading"))
                .font(.caption)
                .foregroundStyle(.secondary)
        case .idle:
            Text(L10n.text("app.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .failed(message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
