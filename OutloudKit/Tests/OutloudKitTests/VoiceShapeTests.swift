import Foundation
import Testing

@testable import OutloudKit

struct VoiceShapeTests {
    private let rate = 48_000.0

    /// A tenth of a second of a 200 Hz tone, a voice's pitch, shifted by `phase`.
    private func voice(phase: Double, amplitude: Float = 0.1) -> [Float] {
        (0..<4800).map { amplitude * Float(sin(2 * .pi * 200 * Double($0) / rate + phase)) }
    }

    @Test func liesFlatInSilenceAndWithTooLittleInput() {
        let silence = VoiceShape.points(of: Array(repeating: 0, count: 4800), sampleRate: rate)
        #expect(silence == Array(repeating: 0, count: VoiceShape.pointCount))
        let short = VoiceShape.points(of: Array(voice(phase: 0).prefix(100)), sampleRate: rate)
        #expect(short == Array(repeating: 0, count: VoiceShape.pointCount))
    }

    @Test func reachesOneAtItsPeakWhateverTheLoudness() {
        for amplitude: Float in [0.01, 0.5] {
            let points = VoiceShape.points(
                of: voice(phase: 0, amplitude: amplitude), sampleRate: rate)
            #expect(abs((points.map(abs).max() ?? 0) - 1) < 0.001)
        }
    }

    @Test func holdsAHeldSoundStillWhereverItsPeriodStands() {
        let first = VoiceShape.points(of: voice(phase: 0), sampleRate: rate)
        // The shape starts where the voice rises through zero, so it starts low and climbs.
        #expect(abs(first[0]) < 0.3 && first[2] > first[0])
        for phase in [0.7, 2.1, 4.0] {
            let other = VoiceShape.points(of: voice(phase: phase), sampleRate: rate)
            let apart = zip(first, other).map { abs($0 - $1) }.max() ?? 0
            #expect(apart < 0.2, "phase \(phase)")
        }
    }
}

extension VoiceShapeTests {
    @Test func startsWhereItMatchesTheLineShownBefore() {
        // A voice with an overtone, whose zero crossings alone leave the start ambiguous.
        func rich(_ phase: Double) -> [Float] {
            (0..<4800).map {
                let t = 2 * .pi * 150 * Double($0) / rate + phase
                return Float(0.1 * sin(t) + 0.08 * sin(3 * t + 1))
            }
        }
        let shown = VoiceShape.points(of: rich(0), sampleRate: rate)
        for phase in [0.9, 2.5, 5.1] {
            let next = VoiceShape.points(of: rich(phase), sampleRate: rate, after: shown)
            let apart = zip(shown, next).map { abs($0 - $1) }.max() ?? 0
            #expect(apart < 0.15, "phase \(phase)")
        }
    }

    @Test func movesAThirdOfTheWayEachFrame() {
        let moved = VoiceShape.moving([0, 1], towards: [1, 0])
        #expect(abs(moved[0] - VoiceShape.blend) < 0.0001)
        #expect(abs(moved[1] - (1 - VoiceShape.blend)) < 0.0001)
        #expect(VoiceShape.moving([], towards: [0.5, 0.5]) == [0.5, 0.5])
    }
}
