import Foundation

enum UsageEstimator {
    static func estimate(
        samples: [RateLimitSample],
        for window: DisplayRateLimitWindow,
        now: Date = Date()
    ) -> UsageEstimate? {
        let relevant = samples
            .filter { sample in
                sample.windowID == window.id
                    && sample.capturedAt <= now
                    && sample.capturedAt >= now.addingTimeInterval(-7 * 24 * 60 * 60)
                    && sameReset(sample.resetAt, window.resetAt)
            }
            .sorted { $0.capturedAt < $1.capturedAt }

        guard relevant.count >= 3, let first = relevant.first, let last = relevant.last else {
            return nil
        }
        let observedHours = last.capturedAt.timeIntervalSince(first.capturedAt) / 3600
        let usedDelta = Double(last.usedPercent - first.usedPercent)
        guard observedHours >= 0.5, usedDelta >= 1 else { return nil }

        let percentPerHour = usedDelta / observedHours
        guard percentPerHour > 0 else { return nil }
        let pointHours = Double(window.remainingPercent) / percentPerHour
        let lower = max(0, pointHours * 0.67)
        let upper = max(lower, pointHours * 1.5)

        let hoursUntilReset = window.resetAt.map {
            max(0, $0.timeIntervalSince(now) / 3600)
        }
        let effectiveLower = hoursUntilReset.map { min(lower, $0) } ?? lower
        let effectiveUpper = hoursUntilReset.map { min(upper, $0) } ?? upper

        let risk: UsageEstimate.Risk
        if effectiveUpper < 6 {
            risk = .critical
        } else if effectiveLower < 24 {
            risk = .watch
        } else {
            risk = .ample
        }

        return UsageEstimate(
            lowerHours: effectiveLower,
            upperHours: effectiveUpper,
            risk: risk,
            sampleCount: relevant.count
        )
    }

    private static func sameReset(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): abs(lhs.timeIntervalSince(rhs)) < 1
        default: false
        }
    }
}
