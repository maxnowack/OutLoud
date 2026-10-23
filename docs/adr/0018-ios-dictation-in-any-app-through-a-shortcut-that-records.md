# 0018 – On iOS, a dictation that leaves the user in their app is a shortcut that records with "Record Audio", has Outloud transcribe the file in the background, and copies the text itself

- Status: superseded by [0022](0022-ios-background-dictation-with-a-mixable-session-and-a-live-activity.md); its cleanup rule had been superseded by [0019](0019-cleanup-runs-on-apples-on-device-model.md)
- Date: 2026-10-23

## Context

"Dictate with Outloud" opens Outloud and records there (ADR 0003, ADR 0017). The user asked for a
dictation that leaves them in the app they are writing in. A feasibility spike on the user's
iPhone 15 Pro on 2026-10-23 measured what iOS 27 allows an app in the background
(`plans/BACKGROUND_DICTATION.md` §"Status"):

- Opening the microphone: refused. An intent adopting `AudioRecordingIntent` and
  `LiveActivityIntent`, with a Live Activity running and the `audio` background mode, got
  "Session activation failed" from `AVAudioSession.setActive`.
- Writing the clipboard: ignored without an error; the pasteboard's change count stayed.
- Using the GPU: refused, and the device offers no background GPU access
  (`BGTaskScheduler.supportedResources`). llama.cpp's backend stays failed after a refused run
  until it is recreated.
- Transcribing with Parakeet (Core ML, CPU and Neural Engine): allowed, 0.1–0.8 s for a few
  seconds of speech once the model is loaded, about 20 s when iOS has just started the app.

The Shortcuts app may do what Outloud may not: "Record Audio" records over the current app, and
"Copy to Clipboard" writes the clipboard, both while the user stays in their app. Measured on the
same iPhone: a shortcut of "Record Audio", Outloud's transcription and "Copy to Clipboard",
started by Back Tap from Notes, put the text on the clipboard without Outloud coming to the
front.

Rejected alternatives:

- **Recording in the background with a Live Activity** (`AudioRecordingIntent`): iOS refuses to
  open the microphone; the intent can only fall back to opening the app.
- **Keeping the microphone open after a dictation** ("Keep microphone ready"), so that the next
  one starts in the background: it records in the background, but the text cannot reach the
  clipboard, and the microphone stays open — with iOS's orange dot — while nobody dictates.
- **Returning the text from "Dictate with Outloud"** for a shortcut to copy, ending it with a
  second press: the second run never reached the app, and stopping from the Live Activity cannot
  copy without opening Outloud.
- **Switching back to the previous app** after the dictation: no public API exists.
- **A custom keyboard**, which writes into the field without the clipboard: possible, but a
  larger product decision against ADR 0003; not pursued now.

## Decision

The iOS app offers the App Intent "Transcribe Audio with Outloud": it takes an audio file, runs
in the background, transcribes it with the transcription model, keeps the result in the history
and returns the text, without touching the clipboard. The app's guide explains the shortcut the
user sets up once — "Record Audio" (start immediately, finish on tap), "Transcribe Audio with
Outloud", "Copy to Clipboard" — and how to run it from Back Tap, the Action Button in its
Shortcut mode or Siri.

While the app is in the background, Outloud does not clean up and does not load the cleanup
model; the result says so (`DictationOutcome.cleanupSkipped`). "Clean Up Text with Outloud",
which shortcuts run in the background, refuses there instead of returning the text unchanged.

"Dictate with Outloud" and the control keep opening Outloud (ADR 0003, ADR 0017).

## Consequences

- A dictation from another app is not cleaned up until the cleanup can run in the background —
  on the CPU, which LLM.swift does not offer without a change (it sets `n_gpu_layers` only in the
  simulator). Open in `plans/BACKGROUND_DICTATION.md`.
- The user builds the shortcut in the Shortcuts app; nothing in the app can add actions of other
  apps to it.
- The first transcription after iOS started the app in the background loads the model, about
  20 s on the iPhone 15 Pro.
- The cleanup model is loaded when the app comes to the front, not when an intent starts it in
  the background.
