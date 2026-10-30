# The menu bar panel lists what waits to be pasted, and steps through the results

## Status

Built (2026-10-30): phases 1–3 are in place and `./scripts/precommit`
passes in `OutloudKit/` and `apps/macos/`. Open: the run of
`apps/macos/e2e/pending-pastes.md` and `apps/macos/e2e/browse-results.md`
with the user. The plan was confirmed by the user on 2026-10-30 with their
answers below.

Deviation: handing the activation back when the panel closes collided with
"never activate an app" of ADR 0026 and ADR 0027; the user accepted it on
2026-10-30 with the principle that no app is ever activated without the
user's interaction. ADR 0028 records it, and `apps/macos/AGENTS.md`
§"Security" now says so.

## Problem

Since every dictation on macOS follows its field (ADR 0027,
`plans/AUTOMATIC_PASTE_ON_RETURN.md`), several dictations can wait to be
pasted at once. The pill says so once and goes; afterwards nothing shows
what waits, where it goes, or what it says, and a dictation the user no
longer wants pasted cannot be taken back. On 2026-10-30 the user asked for
the queue in the menu bar panel: quick to read, each text copyable, each
paste cancellable.

The panel shows only the last result, and only until Outloud quits. To see
an earlier one, the user opens the history window; the user asked to step
back and forth through the results in the panel, with buttons and the
arrow keys.

## Goal

- While dictations wait to be pasted, the panel lists them, oldest first:
  where each goes ("Into Messages", "Into the next text field"), and its
  text — or "Processing…" while it is still transcribed or cleaned up.
- "Copy" puts a waiting text on the clipboard and takes it out of the queue:
  Outloud no longer pastes it. The row says "Copied" for two seconds.
- "Don't Paste" takes a dictation out of the queue, also while it is still
  processed; its processing goes on and its result lands in the history.
- The menu bar icon shows a clock while a dictation waits and nothing is
  recorded, processed in sight or failed.
- The panel's result card steps through the history, newest first: "›" and
  → move back to the older result, "‹" and ← forward to the newer one (the
  user's choice, 2026-10-30), and a line says which one it is ("2 of 12")
  and when it was made. Each time the panel
  opens it shows the newest. With "Keep nothing", it shows the last result
  without stepping.
- Opening the panel makes Outloud the active app, so that the arrow keys
  reach it; closing it hands the activation back to the app that had it.

## Approach

- `ReturnPaste` lists its dictations (`pending`: the field, or none for the
  next field; the text once it is there) and takes one out (`remove`,
  which replaces `fail`): a result that comes for a removed dictation is
  dropped.
- `AppModel` publishes the list only when it changed — the focus check runs
  every 0.3 s while something waits — with the app's name for each field,
  and takes a dictation out on the user's request; one taken out while its
  pill shows goes out of sight first, so that the pill does not stay.
- Two components in `OutloudUI`, designed in `docs/DESIGN.md` first:
  `PasteQueue` (the section with its rows, their states and the "Copied"
  confirmation) and `ResultPager` (the "‹ 2 of 12 ›" line). The result card
  stays `ResultCard`; an entry of the history becomes a `DictationOutcome`
  for it. The history keeps no failed cleanup, so the notice "Cleanup
  failed" shows on the newest entry only when it is the last outcome.
- The panel holds which entry it shows (`nil` for the newest) and handles
  ← and → itself; the status item activates Outloud when it opens the
  panel and, on closing, hands the activation back to the app that had it
  — unless another app took it meanwhile or an Outloud window is open.

Rejected:

- Copy that keeps the dictation in the queue: a text the user pasted by
  hand would be pasted a second time on the return to its field (the
  user's decision, 2026-10-30).
- Cancelling the processing with the paste: the queue that processes in the
  background (`DictationController`) cannot cancel a job, and the result is
  worth keeping in the history (the user's decision, 2026-10-30).
- A non-activating panel instead of the popover, which would take keys
  without activating Outloud: it replaces the popover and its placement
  under the icon for the arrow keys alone.
- No exemption for Outloud's own panel from "the user left the field": a
  dictation processed in sight goes out of sight when the panel opens, as
  for any other app, and is pasted when its field has the focus again.

The activation is ADR 0028; nothing else meets the ADR bar.

## Phases

### Phase 1 — the logic in `OutloudKit`

DoD: `ReturnPasteTests` cover the list (order, field or next field, text
once finished, a "next field" dictation taking the field focused) and the
removal (before and after the result, nothing pasted, copied or reported
as left afterwards).

### Phase 2 — the components and the app

`PasteQueue` and `ResultPager` in `docs/DESIGN.md` and `OutloudUI`, with
their German strings; the panel, the icon and the activation in the app.

DoD: `./scripts/precommit` passes in `OutloudKit/` and `apps/macos/`.

### Phase 3 — documents and the end-to-end plans

`docs/SPEC.md` (rules and acceptance criteria), `docs/DESIGN.md` (the
panel, the icon), `apps/macos/e2e/pending-pastes.md` and
`apps/macos/e2e/browse-results.md` with their rows in the coverage index.

DoD: both plans executed against the running app with the user, the
outcome in this section.

## Risks

- The activation on opening the panel is new: an app that does not take
  the activation back would leave the user typing into nothing. The
  end-to-end plan checks Messages, TextEdit and Claude.
- A row that the queue drops while the user reads it — pasted because the
  field came back — moves the rows under the pointer. Rows only go when
  their field has the focus, which it does not while the panel is open.

## Open questions

None.
