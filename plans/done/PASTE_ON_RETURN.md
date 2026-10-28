# Holding the second ⌘ or ⌥ lets a dictation finish in the background and pastes it when the user returns to its field

## Status

Done (2026-10-28): phases 1–4 are built; `apps/macos/e2e/paste-on-return.md`
was executed by the user and every step passed; `./scripts/precommit`
passes in `OutloudKit/`, `apps/macos/` and `apps/ios/`. The first
approach — writing into the field and pressing Enter while its app stays
in the background — was built as a prototype and refuted on 2026-10-28
(see §"Approach", "Rejected"); the user then decided on pasting on return,
without Enter.

Deviations from the phases:

- Phase 2: a dictation in this mode leaves the visible state at once
  (`DictationController.stopRecordingInBackground()`); all dictations are
  processed one after another. Its pill goes at the release, so a user who
  stays in the field sees no progress until "Pasted" — decided while
  building, named to the user on 2026-10-28.
- Phase 3: a result whose field is not focused on return keeps waiting
  instead of going to the clipboard — asked for by the user on 2026-10-28
  so that the paste reaches the right session; a newer dictation in this
  mode replaces it, and an older one that finishes late is dropped
  (`ReturnPaste.Ticket`). The secure-field refusal stays in the app's
  `AutoPaster.acceptsText`, which reads Accessibility and has no unit test.

Learned from the prototype, 2026-10-28:

- Claude keeps one input element for all its sessions; the address of the
  web area above it (`…/epitaxy/local_<session>`) tells them apart, so the
  field's identity includes it (`AutoPaster.identity(of:)`).
- Switching back to the right session sends no focus notification, since
  the focused element stays the same; the field is therefore polled every
  0.3 s while a result is processed or waits, not observed.
- When the user leaves the field, the pill says once "Pastes into <app>
  when you are back in the text field." (wording confirmed by the user),
  then hides.

Measured with the prototype on 2026-10-28, writing into a field whose app
is in the background, through Accessibility or posted key events:

| App | Result |
| --- | --- |
| TextEdit | Text arrived (`kAXSelectedTextAttribute`), Return posted to the app arrived |
| Messages | Setting the selected text reports success, the field stays empty; the value cannot be read |
| Mail | The web editor (`AXWebArea`) does not take the text; in the background the app reports another focused element, so typed keys are not posted |
| Claude (Electron) | Setting the selected text reports success and is ignored, also with the app in front |

## Problem

A dictation on macOS holds the user until it is delivered: the result is
pasted with ⌘V into whatever is frontmost when the cleanup ends
(`apps/macos/Sources/AutoPaster.swift`), so the user waits in the field
they dictated into until transcription and cleanup are done.

## Goal

- While ⌥ ⌘ is held for a recording, pressing the *second* ⌘ or ⌥ (the one
  on the other side of the keyboard) marks the dictation as "paste on
  return". ⇧ and ⌃ still cancel (ADR 0021); the overlay shows the mode.
- After the release the user can work in any other app; transcription and
  cleanup run behind.
- When the user switches back to the app the dictation was recorded in,
  and the field it was recorded in is focused there, the result is pasted
  with ⌘V. No Enter is pressed.
- If a different field is focused on return, nothing is pasted; the result
  is put on the clipboard and the overlay says so.
- Outloud never brings an app to the front itself.
- The normal hotkey without the second key behaves as today.

## Approach

**Telling the two keys apart.** The device-dependent bits of
`NSEvent.modifierFlags` tell the left and the right ⌘ and ⌥ apart
(`NX_DEVICELCMDKEYMASK` … in IOKit's `IOLLEvent.h`); the chord watcher
already sees every `flagsChanged` (`apps/macos/Sources/Hotkey.swift`). The
device-independent flags do not change when the second key joins, so the
new meaning collides with nothing in ADR 0021. Only the ⌥ ⌘ chord gets the
mode; the Carbon presets (⌥ Space …) do not.

**Remembering the field.** At the start of a recording the app keeps the
system-wide focused element (`kAXFocusedUIElementAttribute`) and its
process id.

**Pasting on return.** The finished result waits with its field. If the
user never left — the field's app is in front with the field focused — it
is pasted at once. Otherwise an `NSWorkspace.didActivateApplicationNotification`
for the field's process triggers the paste: the app's focused element is
compared (`CFEqual`) with the remembered one, and only on a match the
normal auto-paste (⌘V, clipboard restored) runs. A later dictation in this
mode replaces a result that still waits; the history keeps every result.

Rejected:

- *Writing into the field and pressing Enter while its app stays in the
  background* — prototyped and measured on 2026-10-28 (§"Status"): only
  AppKit text views take text through Accessibility; Messages, Mail's web
  editor and Electron apps ignore it, and key events posted to an app in
  the background reach no field. Inserting without Enter fails the same
  way, since the insertion is what fails.
- *Bringing the target app to the front for ⌘V, then giving the focus
  back* — rejected by the user on 2026-10-28, also with buffered keys: no
  focus change under any circumstances.
- *Sending (Enter) on return* — rejected by the user on 2026-10-28.
- *Writing through Accessibility at once where the app takes it, and on
  return elsewhere* — a second path for a subset of apps, with two
  behaviours to learn; one behaviour has the fewest parts.
- *⇧ as the mode key* — the user chose the second ⌘ or ⌥.

## Phases

### Phase 1 — The second ⌘ or ⌥ sets the mode

**DoD:** the mode decision lives in `OutloudKit` and is unit-tested
(second ⌘, second ⌥, either side first, ⇧ / ⌃ still cancel, releasing one
of the two ⌘ keeps the recording going); `HotkeyMonitor` reports the mode;
the overlay shows it, its text translated in `Localizable.xcstrings`.

### Phase 2 — Dictating while the previous one is processed

**DoD:** a new recording starts while an earlier one in this mode is still
transcribed or cleaned up; each result keeps its own field; the
controller's behaviour is unit-tested in `OutloudKit`; a normal dictation
still waits as today.

### Phase 3 — Pasting on return

**DoD:** a waiting result is pasted with ⌘V when its app becomes active
with the remembered field focused, also when the user never left; with
another field focused it goes to the clipboard and the overlay says so;
Outloud activates no app; a later dictation in this mode replaces a
waiting result; tested in Messages, Mail, Claude and one AppKit app.

### Phase 4 — Documents and the end-to-end plan

**DoD:** `docs/SPEC.md` §"Dictation on macOS", `docs/ARCHITECTURE.md` and
the Security rule of `apps/macos/AGENTS.md` describe the mode; a flow
`apps/macos/e2e/paste-on-return.md` is registered in
`apps/macos/e2e/README.md` and executed with the user; `./scripts/precommit`
passes in `OutloudKit/` and `apps/macos/`.

## Risks

- **Electron apps may rebuild their input** (Claude, Slack), so the
  remembered element no longer equals the focused one on return; the
  result then goes to the clipboard. Measured in phase 3.
- **The paste lands in the middle of the user's typing** when they return
  and type at once; the paste runs right after the activation, before the
  first key in practice.
- **Keyboards without a right ⌥ or ⌘**, or remapping tools such as
  Karabiner, give no second key; the mode is then not available.

## Open questions

None.
