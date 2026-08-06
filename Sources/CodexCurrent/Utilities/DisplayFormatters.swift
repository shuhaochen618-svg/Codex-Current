import Foundation

enum DisplayFormatters {
    static func windowName(_ window: DisplayRateLimitWindow) -> String {
        if let name = window.limitName, !name.isEmpty, name != window.limitId {
            return name
        }
        guard let minutes = window.durationMinutes else { return window.limitId }
        if minutes % 10_080 == 0 {
            return L10n.format("label.window_days", minutes / 10_080 * 7)
        }
        if minutes % 60 == 0 {
            return L10n.format("label.window_hours", minutes / 60)
        }
        return L10n.format("label.window_minutes", minutes)
    }

    static func resetTime(_ date: Date?) -> String {
        guard let date else { return L10n.text("label.unavailable") }
        return date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .hour()
                .minute()
        )
    }

    static func relativeTime(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }

    static func tokens(_ value: Int64) -> String {
        value.formatted(.number.notation(.compactName))
    }

    static func taskDuration(since start: Date, now: Date = Date()) -> String {
        let total = max(0, Int64(now.timeIntervalSince(start)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return L10n.format("label.task_duration_hours", hours, minutes)
        }
        if minutes > 0 {
            return L10n.format("label.task_duration_minutes", minutes, seconds)
        }
        return L10n.format("label.task_duration_seconds", seconds)
    }
}
