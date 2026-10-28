# Every dictation on macOS follows its field: leaving it sends the dictation to the background, and the text is pasted on the return

## Status

In progress (2026-10-28): phases 1–3 are built and `./scripts/precommit`
passes in `OutloudKit/` and `apps/macos/`; the run of
`apps/macos/e2e/paste-on-return.md` against the app is open, waiting for
the user to allow the launch. The plan was confirmed by the user on
2026-10-28, with their answers to the three open questions below
(ADR 0027).

Addendum 2026-10-28: released in 0.4.0 at the user's request before the
end-to-end run; the user decided to skip the end-to-end plans for this
release. The run of `apps/macos/e2e/paste-on-return.md` remains open, and
the plan stays in progress until it passed.

Deviation: `ReturnPaste.finish` only stores the result; the paste comes
from the next focus check, which the app runs at once — and not while a
recording is held, since a ⌘V then would cancel the recording as a
shortcut (`OptionCommandChord.keyPressed`).

## Problem

Paste on return (ADR 0026, `plans/done/PASTE_ON_RETURN.md`) has to be asked
for with the second ⌘ or ⌥ while ⌥ ⌘ is held. On 2026-10-28 the user found
the extra key in the way: the app can see by itself that the user left the
field, so the user should just work on.

## Goal

- A dictation whose field the user stays in behaves as before: the pill shows
  the progress, and the result is pasted.
- Leaving that field — another field, the same field showing another
  conversation, another app — while the dictation is processed makes the
  pill say once "Pastes into <app> when you are back in the text field." and
  go; the dictation goes on out of sight, the next one can start at once,
  and the result is pasted when that field has the focus again.
- A dictation started in a field for which an earlier dictation is still
  processed or waits goes into the next other text field the user focuses;
  when it is done before the user focused one, it is copied.
- A dictation started without a text field focused, or with auto-paste off,
  is delivered as before (ADR 0004).
- The second ⌘ or ⌥ has no meaning any more.

## Approach

The pieces of ADR 0026 stay: the field remembered at the press
(`AutoPaster.Target`), the polled focus, the strict match of element and
identity, ⌘V only while the field's app is in front. What changes:

- `ReturnPaste` keeps a list of dictations instead of one, each bound to its
  field or to "the next field after" one; leaving a field is an action of
  its own, so that the app can move the visible dictation to the
  background.
- `DictationController.continueInBackground()` hands the dictation the user
  sees to the background mid-way: `state` returns to idle, the progress goes,
  and the processing runs on without publishing. A press while a dictation
  is processed in sight calls it, so that the new recording starts.
- `OptionCommandChord` loses `pasteOnReturn`; the overlay loses its
  "Pastes when you are back" line during a recording.

Decided by the user on 2026-10-28:

1. The second ⌘ or ⌥ is removed, not kept as a way to send the pill away.
2. Without a text field at the press, the result goes where it went before:
   into the text field in front at the end, else the clipboard. Sent to the
   background by a new press, such a dictation is copied, so that nothing
   is pasted while the user records (decided while planning).
3. A new dictation in a field that already has one processed or waiting
   goes to the next text field focused afterwards; if none was focused when
   it is done, it is copied. Dictations in different fields wait side by
   side; none replaces another.

Considered and dropped while planning: pasting into whatever field is in
front when the user never left (the old rule) and matching strictly only
after the user left. The poll compares the same element and identity in
both cases, so a field that changes its identity looks like a field the
user left either way; the old rule would only add a second path that pastes
into another conversation the user switched to within one poll.

Rejected (ADR 0026, unchanged): writing into an app in the background,
activating an app, pressing Enter.

## Phases

### Phase 1 — the logic in `OutloudKit`

`ReturnPaste` handles several dictations, the "next field" binding and the
leave action; `DictationController.continueInBackground()`; the chord without
the second key.

DoD: `ReturnPasteTests` cover staying (paste at once), leaving and returning,
the refusals (another field, the same element with another identity, no
field / another app), a newer dictation in the same field going to the next
field, its copy when no field came, two dictations in two fields waiting side
by side, a failed dictation; `DictationControllerTests` cover
`continueInBackground()` returning the state to idle while the result still
comes; `OptionCommandChordTests` no longer know the second key.

### Phase 2 — the app

`AppModel` tracks every dictation with a field and auto-paste on, polls the
focus while one is processed or waits, sends the visible one to the
background on leaving or on a new press, and delivers copies and pastes; the
hotkey and the overlay lose the second key.

DoD: `./scripts/precommit` passes in `OutloudKit/` and `apps/macos/`.

### Phase 3 — documents and the end-to-end plan

ADR 0027 (supersedes ADR 0026's trigger), `docs/SPEC.md`,
`docs/ARCHITECTURE.md`, `apps/macos/AGENTS.md` §"Security", the German
strings, `apps/macos/e2e/paste-on-return.md` rewritten for the automatic
flow.

DoD: the documents say what the code does; the e2e plan is executed against
the running app after the user allowed the launch, and the outcome is in
this status section.

## Risks

- An app whose focused field changes its identity while the user stays —
  a window title that counts unread messages, say — looks as if the user
  left: the pill goes and the result waits for a field that no longer
  matches. Before, only dictations marked with the second key had this;
  now every dictation with a field has it. The e2e plan checks Messages,
  Claude and TextEdit; a match found too strict is a change to
  `AutoPaster.identity(of:)`, reviewed against ADR 0027.
- "The next field" can be in another app and another conversation: the
  user asked for exactly that, for a dictation made in a field that was
  already taken.

## Open questions

None.
