import Foundation

struct SwitchCountdown {
    let duration: TimeInterval
    private var startedAt: TimeInterval
    private var completedFraction = 0.0
    private(set) var speed = 1.0

    init(duration: TimeInterval, startedAt: TimeInterval) {
        precondition(duration > 0)
        self.duration = duration
        self.startedAt = startedAt
    }

    func progress(at time: TimeInterval) -> Double {
        min(1, completedFraction + max(0, time - startedAt) * speed / duration)
    }

    func remainingDuration(at time: TimeInterval) -> TimeInterval {
        (1 - progress(at: time)) * duration / speed
    }

    mutating func accelerate(at time: TimeInterval) {
        guard speed == 1 else { return }
        completedFraction = progress(at: time)
        startedAt = time
        speed = 5
    }
}
