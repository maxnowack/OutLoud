# The iOS shortcut starts a recording every time, and a cleanup that times out does not get Outloud ended

## Status

In progress (2026-10-31): phases 1–3 built, `./scripts/precommit` passes
in `OutloudKit` (130 tests) and `apps/ios`; the Debug build is on the
user's iPhone (installed 2026-10-31); phase 4, reading out the log after
some days of use, is open. Deviation from phase 3: the check in the iOS Simulator could not
run — under Xcode 27.1's CoreSimulator the iOS 27 runtimes are
unavailable, and Xcode 27.2's tools wait for an administrator's
component install — so the first entries are read from the iPhone after
the user's next dictations instead. Confirmed by the user on
2026-10-30 ("1 ok", the plan with this file; "2 ok", test builds on their
iPhone); revised on 2026-10-31 ("Okay, alles umsetzen bitte") after the
user ruled out a test session of their own on the iPhone ("nein, keine
spike version"; "nur mit simulator im zweifel"): the fixes are measured in
daily use instead, by a log on the device read out later.

Descoped by that decision: the spike of input-only capture on the iPhone
(the former phase 1), and the goal's 20 starts in a row as a test session.

The user added that the podcast in Overcast was paused at 15:42; its
session was active all the same and was interrupted.

The spike of ending a cleanup past its deadline (the former phase 2), on
the Mac (macOS 27, scratch programs with the real `AppleCleaner`, a 2 s
deadline, a 2,800-character transcript): cancelling the request leaves
Foundation Models' assertion "Finish Task Uninterruptable" held in 2 of 5
runs with `respond` and 4 of 5 with `streamResponse`, with or without
prewarming, also after the session is released; it is a defect of the
framework, not of the cleaner's race. Not cancelling — the deadline still
returns the transcript, the request runs to its end and its answer is
dropped — gave the assertion back in 3 of 3 runs, 5–7 s after the start.
The user chose not cancelling ("Zu Ende laufen lassen", 2026-10-30).

Xcode 27.2's `devicectl` expects CoreDevice 651.32 and wants an
administrator to install it; the device tools of Xcode 27.1, installed
beside it, match the installed 651.13.5 and are used instead
(`DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer`).

## Problem

The user runs "Start or Stop Dictation with Outloud" from AssistiveTouch.
Some starts end at once: the Live Activity shows "failed" for four seconds
and nothing is recorded; a second try works. Once, a dictation seemed to
hang. The iPhone's log of 2026-10-30 (`idevicesyslog archive`, 15:00–16:13)
shows three causes:

1. **The start misses a window of about 0.1 s** (16:10:34). The recording
   uses a `.playAndRecord` session with `AVAudioEngine`, whose I/O plays as
   well as records. `audiomxd` checks the right to start mixable playback
   (`CMSUtility_IsAllowedToStartPlaying`) and refused it: "does not have
   assertions to start mixable playback", "insufficient privileges"
   (`AUIOClient_StartIO failed (2003329396)`). The right to record was
   granted for the intent (`appAllowedToInitiateRecordingTemporarily`).
   SpringBoard's assertion "FBWorkspace (BG-Active)", taken when the intent
   is delivered, ended 106 ms later, 46 ms before the I/O started; the
   activation had taken 92 ms, 62 ms of them a route change from the
   speaker to receiver and microphone. In the four successful starts, the
   I/O started before that assertion ended or within 7 ms of it.
2. **Another app's audio session is interrupted** (15:42:46). Overcast's
   session — the podcast paused, its session still active — was interrupted
   by the activation; the input route was not configured when
   `setActive(true)` returned, the input node reported 0 Hz
   (`AURemoteIO … failed: -10851`), and `AudioRecorder.start` threw
   `noInput`. The retry 11 s later, with Overcast's session already
   interrupted, worked.
3. **iOS ends Outloud after a cleanup that timed out** (15:46:50). A
   three-minute dictation's cleanup passed the 20 s deadline; the cleaner
   stopped waiting, but Foundation Models kept its in-process assertion
   "Finish Task Uninterruptable" (acquired 15:46:00, never relinquished).
   RunningBoard ended the app 30 s after the background task
   (`0x2182BAAD`, "Timed-out waiting for process … to invalidate assertion …
   'Finish Task Uninterruptable'"). The next dictation started the app anew:
   its transcription took 28 s while Parakeet loaded (16:09:35–16:10:03),
   40 s from the stop to the text.

No crash or memory report of Outloud exists on the device.

## Goal

1. Starts from another app through the shortcut record — also starts more
   than 0.11 s after the shortcut ran, and starts with another app's audio
   session active (a paused podcast).
2. A dictation whose cleanup times out in the background is not followed by
   RunningBoard ending Outloud; the next dictation takes the usual time.
3. The microphone is still open only while recording (ADR 0022).
4. Goals 1 and 2 can be read off the device after some days of daily use,
   without a test session of the user's.

## Approach

**Cause 1.** The start holds an assertion of its own — a background task,
from the moment the intent runs until the recording runs or failed — so
that the right to start audio no longer depends on the system's assertion
of about 0.1 s. Whether `audiomxd` counts a background task as an
assertion "to start mixable playback" only the device shows; the log
(below) shows it from the starts' durations.

**Cause 2.** When the input reports no format right after the activation,
`AudioRecorder` waits up to one second for it, trying a new engine every
0.1 s (an engine keeps the format it saw first), instead of failing; the
background task holds the right to start meanwhile.

**Cause 3.** The cleaner still returns the transcript at the deadline, but
no longer cancels the request: it runs to its end and its answer is
dropped, so that Foundation Models gives its assertion back (ADR 0030).

**Measuring in daily use.** Outloud on iOS keeps a log of its starts and
ends on the device (ADR 0031): one line per first use of a process, per
start (the trigger, the milliseconds from the trigger to the recording,
the outcome) and per end (the milliseconds from the stop to the text, what
became of the cleanup). No dictated text; the last 500 entries; read out
with `devicectl`. Goal 1 holds when no start from the shortcut failed,
among them starts over 110 ms; goal 2, when no first use of a process
follows within a minute of an end whose cleanup failed after more than
20 s.

Rejected:

- Input-only capture (an input `AudioQueue`, or `AVAudioEngine` with its
  output not started), so that `audiomxd` checks only the right to record:
  a rewrite of the iOS capture whose effect could not be checked without
  a test session on the device, which the user ruled out. It is the next
  step if the log shows starts still refused.
- Shortening the path to the I/O start (activating before the Live
  Activity, the asynchronous activation of iOS 27): the activation alone
  took 92 ms of a 106 ms window; it narrows the race without removing it.
- Retrying a refused start inside the same run: the window has closed by
  then; a retry would fail the same way.
- Keeping the session active between dictations: the user ruled out a
  microphone kept open between dictations (ADR 0022).
- Cancelling the cleanup's request at the deadline, as before: Foundation
  Models then keeps its assertion in a share of the runs, and RunningBoard
  ends the app.
- Keeping the app alive with a background task until the cleanup's request
  is done: it hides the cause and still ends the app when the model takes
  longer than the background time.
- The log in the unified system log: iOS drops it after a few days, and
  reading it out moves hundreds of megabytes. A screen for it in the app:
  interface, translations and a test plan for something only the
  developer reads.

## Phases

### 1. The fixes

`BackgroundDictation` holds a background task through the start;
`AudioRecorder` waits for the input's format on iOS; `AppleCleaner` lets
a request past its deadline run to its end.

DoD: a test in `OutloudKit` shows the deadline's operation not cancelled;
the macOS capture behaves as before.

### 2. The log

`DiagnosticsLog` in `OutloudKit`; the iOS app records the first use of a
process, the starts and the ends, from the shortcut and in the app.

DoD: tests in `OutloudKit` for the entries, their outcomes and the limit;
`./scripts/precommit` passes in `OutloudKit` and `apps/ios`.

### 3. Documents and the check

ADRs 0030 and 0031, `docs/ARCHITECTURE.md`, the e2e plan
`apps/ios/e2e/ways-to-start.md` with reading out the log.

DoD: in the iOS Simulator, a dictation in the app and one through the
shortcut record and leave their lines in the log; the build is on the
user's iPhone.

### 4. Reading out

After some days of use, the log is read out and judged against goals 1
and 2.

DoD: the result is recorded here; if starts still fail, input-only capture
gets a plan of its own.

## Risks

- `audiomxd` may not count a background task: the log shows it as refused
  starts over 110 ms, and input-only capture is the next step.
- The window's rule is not documented by Apple and may change with an iOS
  update: the log keeps recording.
- A request left to run may outlast the app's remaining background time
  and still get it ended: the log shows it as a first use of a process
  right after a timed-out cleanup.
- The next dictation's cleanup may wait behind a request that is still
  running: the log shows it in the ends' durations.

## Open questions

None.
