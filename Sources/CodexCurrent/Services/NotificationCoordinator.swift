import Foundation
import UserNotifications

@MainActor
final class NotificationCoordinator {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func notifyLimitIfNeeded(window: DisplayRateLimitWindow) {
        let threshold: Int?
        if window.remainingPercent <= 10 {
            threshold = 10
        } else if window.remainingPercent <= 20 {
            threshold = 20
        } else {
            threshold = nil
        }
        guard let threshold else {
            defaults.removeObject(forKey: notificationKey(for: window))
            return
        }

        let key = notificationKey(for: window)
        guard defaults.integer(forKey: key) != threshold else { return }
        defaults.set(threshold, forKey: key)
        schedule(
            id: "limit-\(window.id)-\(threshold)",
            title: L10n.text("widget.limits"),
            body: L10n.format("label.remaining", window.remainingPercent)
        )
    }

    func notifyTaskCompleted(failed: Bool) {
        schedule(
            id: "task-finished-\(Int(Date().timeIntervalSince1970))",
            title: L10n.text("widget.tasks"),
            body: failed
                ? L10n.text("notification.task_failed")
                : L10n.text("notification.task_completed")
        )
    }

    func notifyVPNDisconnected() {
        schedule(
            id: "vpn-disconnected-\(Int(Date().timeIntervalSince1970))",
            title: L10n.text("widget.vpn"),
            body: L10n.text("notification.vpn_disconnected")
        )
    }

    private func notificationKey(for window: DisplayRateLimitWindow) -> String {
        "notification.limit.\(window.id)"
    }

    private func schedule(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
