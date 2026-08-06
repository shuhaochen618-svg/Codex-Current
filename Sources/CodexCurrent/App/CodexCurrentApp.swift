import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onLaunch: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Self.onLaunch?()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        Self.onLaunch?()
        return true
    }
}

@main
@MainActor
struct CodexCurrentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel
    @StateObject private var panel: FloatingPanelController

    init() {
        let model = AppModel()
        let panel = FloatingPanelController(model: model)
        _model = StateObject(wrappedValue: model)
        _panel = StateObject(wrappedValue: panel)
        AppDelegate.onLaunch = {
            model.start()
            panel.show()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            model.start()
            panel.show()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model, panel: panel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg.rectangle")
                Text(menuBarQuota)
                    .monospacedDigit()
            }
            .accessibilityLabel(
                "\(L10n.text("app.name")), \(L10n.text("widget.limits")) \(menuBarQuota)"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }

    private var menuBarQuota: String {
        switch model.limits {
        case let .loaded(windows, _):
            guard let remaining = windows.dashboardWindows.first?.remainingPercent else {
                return "—"
            }
            return "\(remaining)%"
        default:
            return "—"
        }
    }
}
