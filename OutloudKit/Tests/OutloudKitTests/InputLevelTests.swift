import Foundation
import Testing

@testable import OutloudKit

struct InputLevelTests {
    /// The mean square of a sine of `amplitude`: half its square.
    private func tone(_ amplitude: Float) -> Float {
        amplitude * amplitude / 2
    }

    @Test func letsNormalSpeakingFillMostOfTheDisplay() {
        #expect(InputLevel.of(meanSquare: 0) == 0)
        #expect(InputLevel.of(meanSquare: tone(0.0001)) == 0)
        // About -25 dB, as normal speaking at the microphone.
        #expect(abs(InputLevel.of(meanSquare: tone(0.0796)) - 0.75) < 0.01)
        #expect(InputLevel.of(meanSquare: tone(0.9)) == 1)
    }

    @Test func risesAtOnceAndFallsBackWithinATenthOfASecond() {
        #expect(InputLevel.following(0.2, 0.8) == 0.8)
        var level: Float = 0.8
        // A tenth of a second: mostly gone, but not cut off.
        for _ in 0..<6 { level = InputLevel.following(level, 0) }
        #expect(level > 0.1 && level < 0.2)
        // A quarter of a second: as good as gone.
        for _ in 0..<10 { level = InputLevel.following(level, 0) }
        #expect(level < 0.02)
    }
}
