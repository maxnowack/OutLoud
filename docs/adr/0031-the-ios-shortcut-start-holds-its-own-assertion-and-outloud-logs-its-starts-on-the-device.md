# 0031 – On iOS, the shortcut's start holds a background task until the recording runs, and Outloud keeps a log of its starts and ends on the device to be read out later

- Status: accepted
- Date: 2026-10-31

## Context

Some starts from the shortcut (ADR 0022) failed at once. The iPhone's log
of 2026-10-30 showed two causes (`plans/IOS_SHORTCUT_START.md`
§"Problem"):

- `audiomxd` refused to start the engine's I/O: the app "does not have
  assertions to start mixable playback". The assertion SpringBoard takes
  when it delivers the intent ended 106 ms later; the failed start's I/O
  began 46 ms after that, the four successful ones before it or within
  7 ms.
- Activated while Overcast's session — its podcast paused — was being
  interrupted, the input had no format (0 Hz), and the start threw
  `noInput`; a retry 11 s later worked.

Whether a fix works shows only on the device, and only now and then. The
user ruled out a test session of their own on the iPhone and asked for
the fixes to be measured in daily use, with numbers read out later
(2026-10-31).

Rejected alternatives:

- Input-only capture, so that `audiomxd` checks only the right to record:
  a rewrite of the iOS capture whose effect could not be checked without a
  test session. It is the next step if the log shows starts still refused.
- Shortening the path to the I/O: the activation alone took 92 ms of the
  106 ms; it narrows the race without removing it.
- The log in the unified system log: iOS drops it after a few days, and
  reading it out moves hundreds of megabytes.
- A screen for the log in the app: interface, translations and a test
  plan for something only the developer reads.

## Decision

`BackgroundDictation` begins a background task the moment the shortcut's
intent runs and ends it once the recording runs or failed, so that the
right to start audio does not depend on the system's assertion of about
0.1 s.

On iOS, `AudioRecorder` waits up to one second for the input's format when
it has none right after the activation, with a new engine every 0.1 s,
instead of failing.

The iOS app keeps `DiagnosticsLog` (`OutloudKit`): one line of JSON per
first use of a process, per start — the trigger (the shortcut, or the app
in front), the milliseconds from the trigger to the recording, and
`recording` or why not — and per end — the milliseconds from the stop to
the text and what became of the cleanup. It is
`Application Support/Outloud/diagnostics.jsonl` in the app's container,
the last 500 entries, protected like the history; it is read out with
`xcrun devicectl device copy from --domain-type appDataContainer`
(`apps/ios/e2e/ways-to-start.md`). It holds no dictated text and is never
sent anywhere.

## Consequences

- The fixes are judged from the log: no failed start from the shortcut,
  among them starts over 110 ms, and no first use of a process within a
  minute of an end whose cleanup failed after more than 20 s (ADR 0030).
- If `audiomxd` does not count a background task as an assertion, the log
  shows refused starts over 110 ms, and input-only capture follows.
- The log is a persisted format of its own: `DiagnosticsLog` is its only
  reader and writer; an entry's fields are added, never renamed.
- A write that fails is dropped; the log never stops a dictation.
- The macOS app keeps no such log.
