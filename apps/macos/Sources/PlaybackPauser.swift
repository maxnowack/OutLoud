import AppKit
import CoreAudio

/// Pauses what plays while a dictation records, and lets it play on afterwards (ADR 0024).
///
/// macOS offers no public way to pause another app's playback, so this presses the play/pause
/// media key, which goes to the app that plays now — but only when the default output device is
/// in use, so that with nothing playing it does not start the last player.
@MainActor
final class PlaybackPauser {
    /// Whether this pauser pressed the key, and so owes the second press.
    private var paused = false

    /// Before a recording starts: pauses what plays. Needs Accessibility access to post the key.
    func pauseIfPlaying() {
        guard !paused, AXIsProcessTrusted(), Self.outputIsRunning() else { return }
        Self.pressPlayPause()
        paused = true
    }

    /// Once the recording has ended: plays on what this pauser paused.
    func resume() {
        guard paused else { return }
        paused = false
        Self.pressPlayPause()
    }

    /// Whether any process uses the default output device.
    private static func outputIsRunning() -> Bool {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
            device != kAudioObjectUnknown
        else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    /// The play/pause media key, as the keyboard sends it: a system-defined event of subtype 8
    /// with the key in the high half of `data1` and down (0xA) or up (0xB) beneath it.
    private static func pressPlayPause() {
        // NX_KEYTYPE_PLAY in <IOKit/hidsystem/ev_keymap.h>.
        let playKey = 16
        for state in [0xA, 0xB] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)), timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: (playKey << 16) | (state << 8),
                data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
