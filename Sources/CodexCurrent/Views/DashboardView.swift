import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: WidgetPreferences

    init(model: AppModel) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(preferences.visibleWidgets) { kind in
                        WidgetCardView(
                            kind: kind,
                            model: model,
                            density: preferences.density
                        )
                    }
                }
                .padding(16)
            }

            Divider().opacity(0.45)
            footer
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 320, idealHeight: 620)
        .background(.ultraThinMaterial)
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
                Text(L10n.text("app.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
