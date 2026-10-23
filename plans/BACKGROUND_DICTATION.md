# Dictate on iOS without leaving the app in front, and keep model downloads running in the background

## Status

Phases 1–3 built and checked on the user's iPhone (2026-10-23), phase 3
as a shortcut that records instead of a recording in the background
(ADR 0018); one item is open: offering the shortcut from the app; the
cleanup of a dictation from another app moved to `plans/APPLE_CLEANUP.md`.
The plan was confirmed by the user on 2026-10-23.

*Addendum 2026-10-23, later:* a second spike found that the refusal of the
microphone came from the exclusive session: with a session that mixes with
other audio, an `AudioRecordingIntent` that is also a `LiveActivityIntent`
started the recording from the background on the user's iPhone, a second
run ended it, and the shortcut copied the returned text once its "Copy to
Clipboard" took the intent's result (probe log 17:33–18:30 UTC). Built as
"Start or Stop Dictation with Outloud" with a Live Activity that shows each
phase (ADR 0022, superseding ADR 0018); the "Record Audio" path and
"Transcribe Audio with Outloud" were removed.

*Addendum 2026-10-23:* an independent review found, and this plan's
changes now fix: a shortcut run during an in-app dictation took over its
recording and left the microphone unusable (the controller now refuses
while busy); the Action Button at launch could see the models as missing
(start is awaited by every caller); after iOS ended the app only the file
in flight went on (pending downloads are kept and resumed, a model's
files start at once); a download not allowed over cellular data could
switch to it; the destination path could go stale when the container
moves; the background session's completion could be dropped; an HTTP
error of a finished, reattached task was lost. Not yet run on the
iPhone.

Phase 1, on the user's iPhone 15 Pro: a download went on with Outloud in
the background and finished.

Phase 2, on the same iPhone, started by Back Tap from another app (probe
log, 2026-10-23 06:48–06:54):

- Live Activity: refused from the background (`ActivityAuthorizationError`
  "visibility") while the intent was only an `AudioRecordingIntent`;
  started once it also adopted `LiveActivityIntent`.
- Recording: refused from the background — `AVAudioSession.setActive`
  failed with "Session activation failed" even with the Live Activity
  running and the `audio` background mode. This matches the report in
  Apple Developer Forums thread 815725. The intent fell back to the
  foreground as designed.
- The failed activation exposed a defect: the fallback's recording then
  failed with `noInput`, because the failed start had created the audio
  engine's input node while the session was inactive, and the node kept a
  format of 0 Hz. Fixed by replacing the engine after a failed start
  (`OutloudKit/Sources/OutloudKit/Audio/AudioRecorder.swift`).
- Background GPU access: not supported on the device
  (`BGTaskScheduler.supportedResources` lacks `.gpu`), so the cleanup
  cannot run in the background on the GPU.
- Transcription and clipboard in the background: not measured, since no
  recording started there. In the foreground fallback, a dictation took
  3.9 s with cleanup, and the clipboard changed.

Further attempts on the same day, each tested by the user:

- "Keep microphone ready": after a dictation in the app the microphone
  stayed open, and later dictations recorded and transcribed in the
  background (0.1–0.8 s) — but writing the clipboard from the background
  had no effect (the change count stayed), so the text never arrived.
- Returning the text from "Dictate with Outloud" for the shortcut to
  copy, ending with a second Back Tap: the second run never reached the
  app; ending with the Live Activity's Stop button had to open Outloud to
  copy.
- A shortcut of "Record Audio", "Transcribe Audio with Outloud" and "Copy
  to Clipboard", from Back Tap in Notes: worked; Outloud stayed in the
  background; 0.08 s per dictation, 19.7 s for the first after iOS started
  the app. Built as phase 3 (ADR 0018); the Live Activity, the standby
  and the probe log were removed again.

Phase 3 deviates from the plan: no `AudioRecordingIntent`, no Live
Activity, no `audio` background mode. Found on the way and fixed: the
recorder failed after one refused start (above), and "Clean Up Text with
Outloud" ran its cleanup in the background, where it cannot use the GPU —
it now refuses there, and the cleanup model is no longer loaded while the
app is in the background.

Cleanup on the CPU, measured 2026-10-23 with a local copy of LLM.swift
that keeps llama.cpp off the GPU (`n_gpu_layers = 0` and no GPU device),
the German sample `OutloudKit/Samples/de.wav` (10 s) and Qwen 3.5 0.8B:

- iPhone 15 Pro, GPU, in front: 2.6–2.9 s per dictation, transcription
  included (load 1.1 s, warm-up 0.9 s).
- iPhone 15 Pro, CPU: no result within 4 minutes.
- Mac, GPU: 1.0 s. Mac, CPU: 30 s with 8 threads, 48 s with 4, 36 s with
  10 — past the 20 s limit, so the transcript is kept.

The CPU is about 30 times slower; the qwen35 architecture's CPU path in
this llama.cpp is not usable for a dictation. No fork was published.

Open:

- Cleanup in the background: not on the CPU (above). Moved to
  `plans/APPLE_CLEANUP.md` on 2026-10-23: the cleanup runs on Apple's
  on-device model, also in the background, and Qwen is removed (ADR 0019).
- Offering the shortcut from the app: an iCloud link to the shortcut,
  which the user shares from their iPhone, opened by a button in the
  guide.

## Problem

Testing on the user's iPhone 15 Pro on 2026-10-23:

- A model download broke when the user put Outloud in the background to
  delete another app, while the second download went on. The broken one
  could not be restarted until the other had finished. Two causes: the
  downloads run in an ordinary `URLSession`, which iOS suspends and drops
  in the background (`OutloudKit/Sources/OutloudKit/Models/FileFetching.swift`),
  and the setup screen shows a failed model's message without a way to
  retry it, offering only "Stop" while another model downloads
  (`OutloudKit/Sources/OutloudUI/ModelSetup.swift`).
- "Dictate with Outloud" opens Outloud (`supportedModes =
  .foreground(.immediate)`, ADR 0003, ADR 0017). The user asked for a
  dictation that leaves them in the app they are in, or a return to it
  after the transcription. iOS gives apps no way to switch back to the
  previous app; only the system's "◀ App" breadcrumb does.

## Goal

1. A model whose download failed can be restarted at once, also while
   another one downloads.
2. A model download goes on while Outloud is in the background or was
   ended by the system, and the app picks it up when it runs again.
3. Pressing the Action Button (or the control, Siri, a shortcut) in
   another app starts a recording without bringing Outloud to the front;
   pressing it again — or Stop in the Live Activity — ends it, and the
   result lands on the clipboard while the user stays in their app. Where
   iOS does not allow a step in the background, the dictation still works
   the way it does today, and the user is told what changed.

## Approach

**Retry.** The setup screen's model state offers "Try Again" for a failed
model, independent of the other model's download; the settings' model row
has it already (`docs/DESIGN.md` §"ModelRow").

**Background downloads.** On iOS the store's fetcher uses one background
`URLSession` (`URLSessionConfiguration.background`), shared by every
download of the process and identified by a fixed identifier; iOS goes on
downloading while the app is suspended or ended and hands the finished
file to the app when it runs again. Each task carries its destination in
its description, so that a download that finished while the app was not
running is moved to its `.incomplete` file and checked against its hash
like any other (ADR 0014). The app reattaches to running tasks at launch.
macOS keeps the default session: the app is not suspended there.
Rejected: resuming with resume data when the app comes back — less change,
but nothing downloads while the app is in the background, which is
exactly when the user leaves a 0.5–2.7 GB download alone.

**Dictation in the background.** `StartDictationIntent` adopts
`AudioRecordingIntent` (iOS 18+), which lets an intent record without the
app in front, on the condition that a Live Activity runs for as long as it
records. The intent declares `[.background, .foreground(.dynamic)]`: it
starts in the background and continues in the foreground — today's
behaviour — when iOS refuses the recording or the Live Activity there.
The Live Activity shows the recording in the Dynamic Island and on the
Lock Screen with a Stop button (a `LiveActivityIntent`), then the
processing and "Copied". The app gets the `audio` background mode for
the recording. Three things are not known and are measured on the
user's iPhone first (phase 2):

- whether iOS lets the intent start the Live Activity and the recording
  from the background at all — one developer report says "Target is not
  foreground" (Apple Developer Forums thread 815725);
- whether Parakeet (Core ML, CPU and Neural Engine) runs in the
  background;
- whether the cleanup runs in the background: llama.cpp computes on the
  GPU, and iOS revokes GPU access from apps in the background; the
  llama.cpp build in LLM.swift marks the backend as failed instead of
  aborting, after which it has to be recreated;
- whether writing the clipboard from the background works.

The decision is recorded as ADR 0018 once phase 2 has measured it.
Rejected: switching back to the previous app after the dictation — no
public API exists for it.

## Phases

### 1. Downloads

- Setup shows "Try Again" for a failed model while the other model
  downloads; the cellular question applies to it as to "Download".
- iOS downloads run in a background session; a download survives the app
  being in the background for minutes and the app being ended by the
  system, and the app reattaches to it at launch.
- Tests in `OutloudKit/Tests/OutloudKitTests` cover the reattachment and
  a file that finished while the app was not running.

DoD: on the user's iPhone, a download goes on with Outloud in the
background and finishes; a failed model can be restarted while the other
downloads; `apps/ios/e2e/first-launch.md` covers both.

### 2. Feasibility spike on the user's iPhone

A debug build in which "Dictate with Outloud" tries the background path
and writes a probe log — the app state, whether the Live Activity and the
recording started, the durations of transcription and cleanup, the
cleanup's outcome, whether the clipboard changed, whether background GPU
access is supported; never the dictated text. The user runs it from
another app with the Action Button; the log is read from the app's
container.

DoD: for each of the four unknowns the plan states what the iPhone did.

### 3. Background dictation

Built on what phase 2 measured: the intent, the Live Activity in the
widget extension, the Stop intent, the fallback for whatever iOS refuses
in the background, the probe removed. ADR 0018; `docs/SPEC.md`
§"Dictation on iOS", `docs/ARCHITECTURE.md`, `docs/DESIGN.md` (the Live
Activity), the guide's texts, and the e2e plans updated.

DoD: in another app, the Action Button starts and ends a dictation and
the result is on the clipboard without Outloud coming to the front — or,
where phase 2 showed that iOS forbids it, the plan records what was
built instead and the user agreed.

## Risks

- iOS refuses to start a recording from the background: the intent falls
  back to the foreground, as today; the user keeps today's flow.
- The cleanup cannot use the GPU in the background: the options are the
  transcript without cleanup, or the cleanup on the CPU, which LLM.swift
  does not offer without a change (it sets `n_gpu_layers` only in the
  simulator). Decided with the user after phase 2.
- A GPU failure leaves llama.cpp's backend unusable until it is
  recreated; the cleaner must unload the model after a failed run.
- A background session delivers progress only while the app runs; the
  progress bar jumps after a return. Accepted.

## Open questions

- The iCloud link of the shortcut, shared by the user.
