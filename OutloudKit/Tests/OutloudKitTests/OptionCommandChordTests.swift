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
        #expect(chord.modifiersChanged(leftOption, at: at(0)) == [])
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(10)) == [.pressed])
        #expect(chord.modifiersChanged(leftCommand, at: at(900)) == [.released])
    }

    @Test(arguments: [0x10 as UInt, 0x40])
    func theSecondKeyOfAKindPastesOnReturn(second: UInt) {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(
            chord.modifiersChanged(leftOption | leftCommand | second, at: at(300)) == [
                .pasteOnReturn
            ])
        // Reported once, also when the key goes up and down again.
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(400)) == [])
        #expect(chord.modifiersChanged(leftOption | leftCommand | second, at: at(500)) == [])
        #expect(chord.modifiersChanged(0, at: at(600)) == [.released])
    }

    @Test func bothSidesFromTheStartPressAndPasteOnReturn() {
        var chord = OptionCommandChord()
        #expect(
            chord.modifiersChanged(rightOption | leftCommand | rightCommand, at: at(0)) == [
                .pressed, .pasteOnReturn,
            ])
    }

    @Test func aNewPressStartsWithoutPasteOnReturn() {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand | rightCommand, at: at(0))
        _ = chord.modifiersChanged(0, at: at(500))
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(900)) == [.pressed])
    }

    @Test func releasingOneOfTwoCommandKeysKeepsRecording() {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand | rightCommand, at: at(0))
        #expect(chord.modifiersChanged(leftOption | rightCommand, at: at(300)) == [])
        #expect(chord.isPressed)
    }

    @Test(arguments: [OptionCommandChord.shift, OptionCommandChord.control])
    func shiftOrControlCancelsAtAnyTime(modifier: UInt) {
        var chord = OptionCommandChord()
        _ = chord.modifiersChanged(leftOption | leftCommand, at: at(0))
        #expect(
            chord.modifiersChanged(leftOption | leftCommand | modifier, at: at(5000)) == [
                .cancelled
            ])
        // Spoiled until ⌥ or ⌘ is released.
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(5100)) == [])
        #expect(chord.modifiersChanged(leftOption, at: at(5200)) == [])
        #expect(chord.modifiersChanged(leftOption | leftCommand, at: at(5300)) == [.pressed])
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
