# Pause what plays while a dictation records, and let it play on afterwards, on the Mac and the iPhone

## Status

Phases 1 and 3 built (2026-10-26, 2026-10-28), and the user confirmed phase 3 on the Mac on
2026-10-28: music in the browser pauses and plays on; phase 2, the run with the user on the
iPhone, is open. The user asked for it on
2026-10-26 and chose the approach of ADR 0024, with the iPhone included. `./scripts/precommit`
passes in all three units; the setting's default has its test. The user confirmed the Mac on
2026-10-26 in a local Developer ID build: music and a video pause and play on, nothing starts
when nothing plays, and the setting switches it. The iPhone run is open. It ships together with the hotkey
crash fix as macOS 0.2.3.

Addendum 2026-10-28: the user saw the media key start Music with nothing playing. A running
output device turned out to say only that a process uses it — the system sounds and the browser
hold it without a player playing —, and the user chose Ghost Pepper's way of pausing, MediaRemote's
pause command, with the media key to play on only after a player stopped (ADR 0025, phase 3).
The browser then paused but did not play on: it kept its output running, silent. The user chose
to listen to the apps' sound through a Core Audio tap, and a hint in the pill when something
still sounds.

## Problem

Music, a podcast or a video keeps playing while the user dictates: the microphone picks it up,
and the user has to pause and resume it by hand. macOS offers no public way to pause another app's
playback (ADR 0024 §"Context"); on iOS the background recording must mix with other audio
(ADR 0022).

## Goal

1. Mac: with "Pause playback while dictating" on (the default) and Accessibility allowed, a
   dictation pauses what plays and resumes it when the recording ends; with nothing playing,
   nothing starts.
2. iPhone, in the app: other audio pauses while recording and may resume afterwards, as today.
3. iPhone, from the shortcut in the background: music is turned down and spoken audio paused
   while recording, as far as iOS allows; both come back afterwards.
4. One setting on each platform switches it.

## Approach

ADR 0024. On the Mac, `PlaybackPauser` in the app checks the default output device with Core
Audio before the recording starts, posts the play/pause media key as a system-defined event when
it runs, and posts it again when the recording ends or is cancelled, only after pausing. On iOS
the recorder's mixing session adds `.duckOthers` and `.interruptSpokenAudioAndMixWithOthers` when
the setting is on. The setting is `pausesPlayback` in `OutloudSettings`.

## Phases

### 1. Build

DoD: the Mac pauser and the iOS session options built; the setting on both platforms with German
strings; `docs/SPEC.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and the e2e plans updated;
`./scripts/precommit` passes in all three units.

### 2. Run

DoD: the user checks on the Mac — music in Music, a video in a browser, nothing playing — and on
the iPhone — in the app and from the shortcut with music and with a podcast.

### 3. Pause with MediaRemote

DoD: `PlaybackPauser` listens to the apps that put out sound, sends MediaRemote's pause command
when they sound, and presses the media key after the recording only when they fell silent
(`PauseCheck`, with tests); when they still sound, the pill shows "Something is playing in the
background"; without the permission to record system audio, it pauses without playing on and
Settings offer "Allow…"; German strings, the usage description included; nothing starts with
nothing playing; ADR 0025 written, ADR 0024 marked superseded for macOS; `docs/SPEC.md`,
`docs/DESIGN.md` and the e2e plan updated; `./scripts/precommit` passes in `OutloudKit` and
`apps/macos`; the user checks it on the Mac.

## Risks

- A notification that ends within the second after the pause command, with nothing playing, can
  still make the media key start the last player (ADR 0025 §"Consequences").
- iOS may refuse the ducking options in the background; then the session falls back to plain
  mixing, as today, and the recording still starts.

## Open questions

None.
