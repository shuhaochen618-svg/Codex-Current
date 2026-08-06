import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: WidgetPreferences
    @State private var didClearHistory = false

    init(model: AppModel) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        Form {
            Section(L10n.text("settings.widgets")) {
                ForEach(preferences.order) { kind in
                    HStack {
                        Toggle(
                            isOn: Binding(
                                get: { !preferences.hidden.contains(kind) },
                                set: { preferences.setVisible(kind, visible: $0) }
                            )
                        ) {
                            Label(L10n.text(kind.titleKey), systemImage: kind.systemImage)
                        }
                        Spacer()
                        Button {
                            preferences.move(kind, direction: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.plain)
                        .disabled(preferences.order.first == kind)
                        .help(L10n.text("action.move_up"))

                        Button {
                            preferences.move(kind, direction: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.plain)
                        .disabled(preferences.order.last == kind)
                        .help(L10n.text("action.move_down"))
                    }
                }
            }

            Section(L10n.text("settings.display")) {
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
                Toggle(
                    L10n.text("label.pinned"),
                    isOn: Binding(
                        get: { preferences.isPinned },
                        set: { preferences.isPinned = $0 }
                    )
                )
            }

            Section(L10n.text("settings.privacy")) {
                Text(L10n.text("settings.privacy_detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.text("action.clear_history"), role: .destructive) {
                    Task {
                        await model.clearHistory()
                        didClearHistory = true
                    }
                }
                if didClearHistory {
                    Label(L10n.text("label.local_only"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 520)
    }
}
