# 0013 – OutloudKit also holds the audio capture, the shared interface components and a command-line tool

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0002 gives the shared package the transcription, the cleanup, the settings and the error
handling, and the platform modules recording, the shortcut and the clipboard on iOS and the
hotkey, the menu bar and auto-paste on macOS. It also says that behaviour both platforms share
is written once, in the package.

Building the first version showed three things both apps need identically: capturing the
microphone as 16 kHz mono samples with `AVAudioEngine`, the components of `docs/DESIGN.md`
(both apps compose their screens from one library), and a way to run the model pipeline
without an app, for the model spike and for checks without a microphone
(`plans/FIRST_VERSION.md` §"Status").

Rejected alternative: a capture implementation in each app — the same `AVAudioEngine` code
twice, differing only in the audio session, which `#if os(iOS)` covers in one place.

The user was asleep when this was decided (2026-10-23) and asked for such decisions to be made
and collected (`plans/FIRST_VERSION.md` §"Decisions for the user").

## Decision

The package `OutloudKit/` has three targets:

- `OutloudKit` — the core of ADR 0002 plus the audio capture (`AudioRecorder`); the apps own
  when a recording starts and ends and the microphone permission prompt.
- `OutloudUI` — the tokens and components of `docs/DESIGN.md`, used by both apps.
- `OutloudCLI` (`outloud`) — a macOS command-line tool that lists, downloads and deletes the
  models in the cache and runs dictation on an audio file.

## Consequences

- The platform modules keep only what is theirs: the hotkey, the overlay and auto-paste on
  macOS; the App Intents and the screens on iOS.
- The CLI is a developer tool and is not distributed.
