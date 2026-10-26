# Open the Mac app at login, never leave the pill hanging, ask for the microphone at launch, and show the cleanup's progress truthfully

## Status

Done (2026-10-24): both phases are complete. The
plan was confirmed by the user on 2026-10-24, with "open at login"
preselected in the setup window. `./scripts/precommit` passes in all
three units.

*Correction 2026-10-24, from the user's first run:* the bar first followed
the learned wait before the first word and then the answer's length; it
ran far too long. The user decided that the bar follows the average
duration of the whole cleanup — from its start to the cleaned text, not
the recording or the wait for the first word. The bar now fills by the
time passed over that average; the answer is no longer streamed, as
nothing reads its length. The Approach below states the corrected design. Beyond the
plan: `DictationController.startRecording` checks again after the
microphone dialog that no other start won meanwhile, so two presses during
the dialog cannot start two recordings. The user ran a local Developer ID
build on 2026-10-24 and confirmed: ⌥ ⌘ and the paste work, the bar fits,
no pill hangs after the microphone dialog, and "Open at login" works. Not
checked: the prewarming on the iPhone, which only changes speed there.

*Addendum 2026-10-25, after the user's look at the buttons:* text-only
buttons without an ellipsis were tried and rejected; buttons now follow
Apple's Human Interface Guidelines — system push buttons, the ellipsis
where a button opens more (`docs/DESIGN.md` §"Buttons"). The menu bar
panel's row of four buttons no longer fitted as push buttons, so the menu
bar icon became an AppKit status item (`apps/macos/Sources/StatusItem.swift`):
a click opens the panel as a popover with "History…" only, a right-click a
menu with "Settings…", "Check for Updates…" and "Quit Outloud"; the
settings open in a window of their own. The popover takes its size from
SwiftUI before it opens; it had opened at a guessed height, shrunk, and
left its arrow below the icon. The user confirmed buttons, popover and
menu in a local Developer ID build.

*Addendum 2026-10-26, after the user's use of 0.2.0:* the bar ended at
about half for most cleanups. The log showed 1.17, 1.33 and 2.19 s; the
stored moving average was 1.97 s, pulled up by older and slower runs and
slow to follow with a weight of 0.3. The usual duration is now the median
of the last ten durations, which one slow cleanup barely moves and which
forgets old runs after ten.

## Problem

The user's use of the Mac app on 2026-10-24 showed four things:

- **The pill hangs.** Holding ⌥ ⌘ while the microphone was not yet
  allowed showed the system's dialog; the keys were released while it was
  open, and the release was dropped because no recording ran yet
  (`apps/macos/Sources/AppModel.swift` `hotkeyReleased`, the
  `state == .recording` guard). Once the user allowed the microphone, the
  recording started anyway, with no key held: the pill stays and the
  microphone is open. Every later press is ignored, as the controller is
  busy.
- **The microphone is asked for late.** The setup window asks when its
  "Continue" is pressed; whoever does not pass through it — the model
  already in the shared cache, or a new permission after the bundle ID
  changed — sees the dialog at the first dictation.
- **The cleanup's progress stands at 0, then jumps.** The bar follows the
  length of the streamed answer (`AppleCleaner`), and most of the time
  passes before the first word. Measured on 2026-10-24 on an M1 Pro Mac,
  a 204-character transcript, two runs each:

  | | first word after | total |
  | --- | --- | --- |
  | as built | 2.5–4.8 s | 3.5–5.7 s |
  | session prewarmed 4 s before | 1.5–1.6 s | 2.5 s |

  Without prewarming the model reads the instructions and the worked
  examples first; prewarming the session reads them while the user still
  speaks.
- **Outloud does not start at login**, so after a restart the hotkey does
  nothing until the user opens the app (`plans/FIRST_VERSION.md`
  §"Decisions for the user", item 13).

## Goal

1. A release of the keys while Outloud waits — for the microphone dialog
   or anything else — ends that dictation: no recording starts, the pill
   goes away. A press of the hotkey always ends a recording that runs
   without a key held, and starts a new one.
2. The microphone is asked for at launch while the answer is undetermined.
3. The cleanup session is prewarmed when a recording starts, on macOS and
   iOS. The bar moves steadily from the start of the cleanup, by the time
   passed over the learned average duration of a cleanup; it never claims
   completion before the end.
4. The setup window offers "Open Outloud at login", preselected; the
   settings have the same switch, which shows the system's actual state and
   says when macOS wants the user's approval.

## Approach

- **Hanging pill**: `AppModel` gives every press an identity. After
  `startRecording()` returns, a press whose release already happened
  cancels the recording it started and hides the pill. A press while a
  recording runs without a held key cancels that recording first. Logic
  stays in the app: it is the hotkey's flow, and the permission dialog
  cannot be driven in a unit test.
- **Microphone**: `AppModel.start()` asks when the status is
  undetermined; the setup window no longer asks.
- **Prewarming**: `AppleCleaner` creates its session at initialisation and
  prewarms it; its first text uses that session, any later one a fresh
  session. `DictationController` makes the cleaner when a recording starts
  and keeps it for that recording's cleanup.
- **Progress**: a pure estimate in `OutloudKit` fills the bar evenly by
  the time passed over the usual duration of a cleanup, up to 90 % at that
  duration, and creeps towards 95 % when a cleanup takes longer.
  `CleanupTimings` keeps the moving average of the duration in
  `UserDefaults` — only of cleanups after a recording that produced text —
  with a fingerprint of the prompt and examples: a changed prompt starts
  the average anew. The controller ticks the bar while the cleanup runs,
  with its injected clock.
- **Open at login**: `SMAppService.mainApp`. The switch reads its status
  instead of a stored preference, so it never disagrees with System
  Settings.

Rejected: CPU load as a further input to the estimate — the model runs
mostly on the Neural Engine and the GPU, so the CPU's load predicts little,
and the moving average adapts to a slower device anyway; revisited if the
estimate turns out poor. An indeterminate animation until the first word —
truthful, but the user wants one bar that moves throughout. A launch agent
plist — `SMAppService` is the system's supported way and shows in System
Settings › Login Items.

## Phases

### 1. Build

DoD: the four changes built; tests for the progress estimate and the
timings (`OutloudKit/Tests`); `docs/SPEC.md`, `docs/DESIGN.md`,
`docs/ARCHITECTURE.md` and the macOS end-to-end plans updated; German
strings in the catalogs; `./scripts/precommit` passes in all three units.

### 2. Run

DoD: on the Mac, the Release-like build shows the setup switch preselected
and the settings switch in the system's state; a dictation through the
debug seam shows a bar that moves from the start of the cleanup; the user
checks the microphone dialog and the hanging pill with their keyboard.

## Risks

- The duration depends on the transcript's length, which the average
  ignores: a long dictation after short ones reaches 90 % early and creeps
  from there. The bar still only moves forward.
- A recording shorter than the prewarming leaves part of the wait; the
  average absorbs it.
- Registering a debug build as a login item while testing registers that
  build's path; it is unregistered after the test.

## Open questions

None.
