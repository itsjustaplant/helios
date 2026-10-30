import XCTest
@testable import Helios

final class SwitchCountdownTests: XCTestCase {
    func testNormalCountdown() {
        let countdown = SwitchCountdown(duration: 5, startedAt: 100)
        XCTAssertEqual(countdown.progress(at: 102), 0.4, accuracy: 0.000001)
        XCTAssertEqual(countdown.remainingDuration(at: 102), 3, accuracy: 0.000001)
    }

    func testAccelerationPreservesProgressAndQuintuplesSpeedForEveryDelay() {
        for duration in [3.0, 5.0, 10.0] {
            var countdown = SwitchCountdown(duration: duration, startedAt: 100)
            let halfway = 100 + duration / 2
            countdown.accelerate(at: halfway)
            XCTAssertEqual(countdown.progress(at: halfway), 0.5, accuracy: 0.000001)
            XCTAssertEqual(countdown.remainingDuration(at: halfway), duration / 10, accuracy: 0.000001)
            XCTAssertEqual(countdown.progress(at: halfway + duration / 20), 0.75, accuracy: 0.000001)
            XCTAssertEqual(countdown.progress(at: halfway + duration / 10), 1, accuracy: 0.000001)
        }
    }

    func testRepeatedAccelerationDoesNotCompoundOrRestart() {
        var countdown = SwitchCountdown(duration: 10, startedAt: 100)
        countdown.accelerate(at: 101)
        let remaining = countdown.remainingDuration(at: 102)
        let progress = countdown.progress(at: 102)
        countdown.accelerate(at: 102)
        XCTAssertEqual(countdown.speed, 5)
        XCTAssertEqual(countdown.remainingDuration(at: 102), remaining)
        XCTAssertEqual(countdown.progress(at: 102), progress)
        XCTAssertEqual(countdown.progress(at: 104), 1, accuracy: 0.000001)
    }

    func testExpiredCountdownStaysComplete() {
        var countdown = SwitchCountdown(duration: 3, startedAt: 100)
        countdown.accelerate(at: 104)
        XCTAssertEqual(countdown.progress(at: 105), 1)
        XCTAssertEqual(countdown.remainingDuration(at: 105), 0)
    }

    func testNewCountdownStartsAtNormalSpeed() {
        var previous = SwitchCountdown(duration: 5, startedAt: 100)
        previous.accelerate(at: 101)
        let next = SwitchCountdown(duration: 5, startedAt: 102)
        XCTAssertEqual(next.speed, 1)
        XCTAssertEqual(next.progress(at: 102), 0)
        XCTAssertEqual(next.remainingDuration(at: 102), 5)
    }
}
