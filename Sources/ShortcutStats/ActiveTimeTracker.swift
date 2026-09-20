import Foundation

/// Samples foreground activity without retaining input contents or event sequences.
/// Call immediately before changing foreground identity, then again with the new
/// identity to establish its baseline. reset() drops any interval across a gap.
final class ActiveTimeTracker {
    private struct Sample {
        let date: Date
        let uptime: TimeInterval
        let appID: String
        let appName: String
        let eligible: Bool
        let idleSeconds: Double
    }

    private var previous: Sample?
    private let idleThreshold: TimeInterval = 60
    private let maximumInterval: TimeInterval = 5

    func reset() {
        previous = nil
    }

    func sample(at date: Date, uptime: TimeInterval, appID: String, appName: String,
                enabled: Bool, eligible: Bool, idleSeconds: Double) -> [ActivitySlice] {
        guard date.timeIntervalSinceReferenceDate.isFinite, uptime.isFinite,
              idleSeconds.isFinite, idleSeconds >= 0 else {
            reset()
            return []
        }
        let current = Sample(date: date, uptime: uptime, appID: appID, appName: appName,
                             eligible: enabled && eligible && !appID.isEmpty,
                             idleSeconds: idleSeconds)
        defer { previous = current }
        guard let prior = previous, prior.eligible, current.eligible else { return [] }
        let elapsed = uptime - prior.uptime
        let wallElapsed = date.timeIntervalSince(prior.date)
        // Never bridge sleep, suspended timers, clock jumps or time corrections.
        guard elapsed > 0, elapsed <= maximumInterval, wallElapsed > 0,
              abs(wallElapsed - elapsed) <= 0.5 else { return [] }
        // Resuming from idle establishes a fresh baseline. We conservatively omit
        // this short interval because its exact input/resume time is unknown.
        guard prior.idleSeconds < idleThreshold else { return [] }
        let idleExcess = max(0, idleSeconds - idleThreshold)
        let end = date.addingTimeInterval(-idleExcess)
        guard end > prior.date else { return [] }
        return [ActivitySlice(start: prior.date, end: end,
                              appID: prior.appID, appName: prior.appName)]
    }
}
