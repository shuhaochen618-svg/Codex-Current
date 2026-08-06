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
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }

    private var menuBarSymbol: String {
        switch model.limits {
        case let .loaded(windows, _):
            guard let remaining = windows.first?.remainingPercent else {
                return "waveform.path.ecg.rectangle"
            }
            if remaining <= 10 { return "exclamationmark.circle.fill" }
            if remaining <= 25 { return "gauge.with.dots.needle.67percent" }
            return "gauge.with.dots.needle.33percent"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "waveform.path.ecg.rectangle"
        }
    }
}
