# 0024 – Other audio pauses while dictating: the media key on macOS when audio plays, the audio session on iOS

- Status: accepted; its decision for macOS superseded by [0025](0025-macos-pauses-with-mediaremote-and-plays-on-with-the-media-key.md)
- Date: 2026-10-26

## Context

The user asked that whatever plays — music, a podcast, a video — pause while a dictation records
and play on once the recording ends, on the Mac and on the iPhone.

macOS gives third-party apps no way to pause another app's playback or to ask whether one plays:
the MediaRemote framework that does is private, and since macOS 15.4 it serves only entitled
processes. What macOS offers is the system's play/pause media key, which goes to the app that
plays now, and Core Audio's `kAudioDevicePropertyDeviceIsRunningSomewhere`, which says whether
any process uses the output device.

On iOS, the in-app recording already opens an exclusive session (`.record`), which interrupts
other audio, and ends it with `notifyOthersOnDeactivation`, which tells them they may resume. The
background recording of ADR 0022 must mix with other audio: iOS refuses an exclusive session in
the background.

Rejected alternatives:

- MediaRemote: a private framework, closed to unentitled apps since macOS 15.4.
- AppleScript to Music and Spotify: covers two apps, not a video in a browser, and asks for
  Automation access per app.
- Pressing the media key whatever plays: with nothing playing it starts the last player.

## Decision

On macOS, when a recording starts and the default output device is running, Outloud posts the
play/pause media key once, and posts it again when the recording ends — only when it paused
something itself. It needs Accessibility access, which the ⌥ ⌘ shortcut needs anyway, and a
setting switches it, on by default. The device is checked before Outloud's own recording starts,
so that a headset whose microphone it uses does not count as playing.

On iOS, the in-app recording keeps its exclusive session. The background recording mixes as
before but asks others to duck and spoken audio to pause (`.duckOthers`,
`.interruptSpokenAudioAndMixWithOthers`), as far as iOS allows that in the background; its
deactivation tells them they may resume. The same setting switches both.

## Consequences

- Audio that is not a player — a call, a game — can make the media key start the last player
  instead. Pausing by hand during a dictation lets the second key press start it again.
- Whether a paused app resumes on iOS is up to that app; most players do.
- In the background on iOS, music is only made quieter, not paused: iOS does not let a mixing
  session pause others.
