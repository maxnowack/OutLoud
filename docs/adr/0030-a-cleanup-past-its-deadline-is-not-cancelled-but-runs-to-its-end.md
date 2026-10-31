# 0030 – A cleanup that passes its deadline is not cancelled: its request to Apple's model runs to its end and its answer is dropped

- Status: accepted
- Date: 2026-10-31

## Context

The cleanup gives up after 20 s and hands over the transcript
(`docs/ARCHITECTURE.md` §"Models"). Until now it also cancelled the
request to Foundation Models. On 2026-10-30, a three-minute dictation from
the iOS shortcut passed the deadline in the background; Foundation Models
kept its in-process assertion "Finish Task Uninterruptable", and
RunningBoard ended Outloud 30 s after the background task
(`0x2182BAAD`). The next dictation started the app anew and took 40 s
from the stop to the text (`plans/IOS_SHORTCUT_START.md` §"Problem",
cause 3).

Measured on 2026-10-30 on the Mac (macOS 27, the real `AppleCleaner`, a
2 s deadline, a 2,800-character transcript): cancelling `respond` kept the
assertion in 2 of 5 runs, cancelling `streamResponse` in 4 of 5, with or
without prewarming, also after the session was released — a defect of the
framework. Not cancelling gave the assertion back in 3 of 3 runs, 5–7 s
after the start.

Rejected alternatives:

- Cancelling the request, through `respond` or a dropped
  `streamResponse`: it leaks the assertion, as measured.
- Keeping the app alive with a background task until the request is done:
  it hides the cause and still ends the app when the model takes longer
  than the background time.
- Leaving it as it was and only reporting the defect to Apple: offered to
  the user, who chose to let the request run ("Zu Ende laufen lassen").

## Decision

`AppleCleaner.withDeadline` still returns `CleanerError.timedOut` at the
deadline, and the transcript becomes the result, but it no longer cancels
the operation: the request runs to its end in an unstructured task, and
its answer is dropped. A cancellation of the caller is treated the same
way.

## Consequences

- Foundation Models gives its assertion back, and iOS no longer ends
  Outloud for it.
- The model keeps working for some seconds after the deadline; a cleanup
  started meanwhile may wait behind it. ADR 0031's log shows it in the
  ends' durations.
- A request that runs longer than the app's remaining background time can
  still get the app ended; ADR 0031's log shows it.
- Applies on macOS too, where nothing ends the app for it; the request's
  work there is the same as on iOS.
- When Apple fixes the leak, cancelling can return; the test
  `CleanupDeadlineTests.letsTheOperationRunToItsEndPastTheDeadline` names
  the decision.
