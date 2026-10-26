# Pause what plays while a dictation records, and let it play on afterwards, on the Mac and the iPhone

## Status

Phase 1 built (2026-10-26); phase 2, the run with the user, is open. The user asked for it on
2026-10-26 and chose the approach of ADR 0024, with the iPhone included. `./scripts/precommit`
passes in all three units; the setting's default has its test. The user confirmed the Mac on
2026-10-26 in a local Developer ID build: music and a video pause and play on, nothing starts
when nothing plays, and the setting switches it. The iPhone run is open. It ships together with the hotkey
crash fix as macOS 0.2.3.

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

## Risks

- Audio that is not a player can make the media key start the last player (ADR 0024
  §"Consequences").
- iOS may refuse the ducking options in the background; then the session falls back to plain
  mixing, as today, and the recording still starts.

## Open questions

None.
