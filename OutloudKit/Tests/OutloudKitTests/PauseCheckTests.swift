import Testing

@testable import OutloudKit

struct PauseCheckTests {
    /// Feeds a peak every 10 ms, as the output's IO buffers come, from `start` to `end`.
    private func record(
        _ check: inout PauseCheck, _ peak: Float, from start: Int, to end: Int
    ) {
        for ms in stride(from: start + 10, through: end, by: 10) {
            check.record(peak: peak, elapsed: .milliseconds(ms))
        }
    }

    @Test func countsAPlayerThatFadesOutAsPaused() {
        var check = PauseCheck()
        record(&check, 0.3, from: 0, to: 300)
        record(&check, 0.01, from: 300, to: 400)
        #expect(check.verdict(elapsed: .milliseconds(400)) == nil)
        record(&check, 0, from: 400, to: 590)
        #expect(check.verdict(elapsed: .milliseconds(590)) == nil)
        record(&check, 0, from: 590, to: 600)
        #expect(check.verdict(elapsed: .milliseconds(600)) == .paused)
    }

    @Test func countsWhatStillSoundsAfterASecondAsStillPlaying() {
        var check = PauseCheck()
        // A call: loud, with the short gaps of speech.
        for start in stride(from: 0, to: 1000, by: 250) {
            record(&check, 0.2, from: start, to: start + 150)
            record(&check, 0, from: start + 150, to: start + 250)
        }
        #expect(check.verdict(elapsed: .milliseconds(990)) == nil)
        #expect(check.verdict(elapsed: .seconds(1)) == .stillPlaying)
    }

    @Test func doesNotTakeATapThatDeliversNothingForAPause() {
        var check = PauseCheck()
        record(&check, 0.3, from: 0, to: 100)
        #expect(check.verdict(elapsed: .milliseconds(900)) == nil)
        #expect(check.verdict(elapsed: .seconds(1)) == .stillPlaying)
    }

    @Test func takesMinus50DecibelsAsTheEdgeOfSilence() {
        #expect(PauseCheck.isAudible(peak: 0.0032))
        #expect(!PauseCheck.isAudible(peak: 0.0028))
        #expect(!PauseCheck.isAudible(peak: 0))
    }
}
