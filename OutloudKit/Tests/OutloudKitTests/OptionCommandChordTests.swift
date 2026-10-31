import Testing

@testable import OutloudKit

struct OptionCommandChordTests {
    private let start = ContinuousClock.now
    private let leftCommand: UInt = OptionCommandChord.command | 0x08
    private let rightCommand: UInt = OptionCommandChord.command | 0x10
    private let leftOption: UInt = OptionCommandChord.option | 0x20
    private let rightOption: UInt = OptionCommandChord.option | 0x40

    private func at(_ ms: Int) -> ContinuousClock.Instant { start + .milliseconds(ms) }

    @Test func optionCommandHeldAloneRecordsUntilReleased() {
        var chord = OptionCommandChord()
        #expect(chord.modifiersChanged(leftOption, at: at(0)) == nil)
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(10)) == .pressed)
        #expect(chord.modifiersChanged(leftCommand, at: at(900)) == .released)
    }

    @Test(arguments: [0x10 as UInt, 0x40])
    func theSecondKeyOfAKindChangesNothing(second: UInt) {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(chord.modifiersChanged(leftOption | leftCommand | second, at: at(300)) == nil)
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(400)) == nil)
        #expect(chord.isPressed)
        #expect(chord.modifiersChanged(0, at: at(600)) == .released)
    }

    @Test func bothSidesFromTheStartPress() {
        var chord = OptionCommandChord()
        #expect(
            chord.modifiersChanged(rightOption | leftCommand | rightCommand, at: at(0)) == .pressed)
    }

    @Test func releasingOneOfTwoCommandKeysKeepsRecording() {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand | rightCommand, at: at(0))
        #expect(chord.modifiersChanged(leftOption | rightCommand, at: at(300)) == nil)
        #expect(chord.isPressed)
    }

    @Test(arguments: [0, 5000])
    func controlCancelsAtAnyTime(ms: Int) {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        let control = OptionCommandChord.control
        #expect(
            chord.modifiersChanged(leftOption | leftCommand | control, at: at(ms)) == .cancelled)
        // Spoiled until ⌥ or ⌘ is released.
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(ms + 100)) == nil)
        #expect(chord.modifiersChanged(leftOption, at: at(ms + 200)) == nil)
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(ms + 300)) == .pressed)
    }

    @Test func shiftCancelsOnlyWithinTheShortcutWindow() {
        let shift = OptionCommandChord.shift
        var early = OptionCommandChord()
        _ = early.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(early.modifiersChanged(leftOption | leftCommand | shift, at: at(999)) == .cancelled)

        var late = OptionCommandChord()
        _ = late.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(late.modifiersChanged(leftOption | leftCommand | shift, at: at(1000)) == nil)
        #expect(late.modifiersChanged(leftOption | leftCommand, at: at(1100)) == nil)
        #expect(late.isPressed)
        #expect(late.modifiersChanged(leftOption | leftCommand | shift, at: at(1200)) == nil)
        #expect(late.modifiersChanged(leftOption | shift, at: at(1300)) == .released)
    }

    @Test func shiftAndControlTogetherCancelLate() {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        let both = OptionCommandChord.shift | OptionCommandChord.control
        #expect(chord.modifiersChanged(leftOption | leftCommand | both, at: at(5000)) == .cancelled)
    }

    @Test func keysAreTypedFromTheEndOfTheShortcutWindowWhileHeld() {
        var chord = OptionCommandChord()
        #expect(chord.typingStarts == nil)
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(chord.typingStarts == at(1000))
        _ = chord.modifiersChanged(leftCommand, at: at(2000))
        #expect(chord.typingStarts == nil)

        var cancelled = OptionCommandChord()
        _ = cancelled.modifiersChanged(leftOption | leftCommand, at: at(0))
        _ = cancelled.keyPressed(at: at(500))
        #expect(cancelled.typingStarts == nil)
    }

    @Test func aKeyCancelsOnlyWithinTheShortcutWindow() {
        var early = OptionCommandChord()
        _ = early.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(early.keyPressed(at: at(999)) == .cancelled)

        var late = OptionCommandChord()
        _ = late.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(late.keyPressed(at: at(1000)) == nil)
        #expect(late.isPressed)
    }

    @Test func aResetEndsAHeldChordAsReleased() {
        var chord = OptionCommandChord()
        #expect(chord.reset() == nil)
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(chord.reset() == .released)
    }
}
