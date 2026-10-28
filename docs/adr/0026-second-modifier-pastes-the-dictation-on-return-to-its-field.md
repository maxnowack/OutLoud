# 0026 – On macOS, the second ⌘ or ⌥ held with ⌥ ⌘ lets the dictation finish in the background and pastes it when the user returns to the field it was recorded in; Outloud never brings an app to the front, and writing into an app in the background is rejected

- Status: accepted
- Date: 2026-10-28

## Context

A dictation on macOS is pasted with ⌘V into whatever is frontmost when it
is done (ADR 0004), so the user waits for the cleanup in the field they
dictated into. On 2026-10-28 the user asked for a mode that lets them work
on while the dictation is processed.

ADR 0021 gives ⇧ and ⌃ joining ⌥ ⌘ the meaning "a shortcut, cancel". The
second ⌘ or ⌥ on the other side of the keyboard has no meaning yet: the
device-independent modifier flags do not change when it joins, and macOS
reports which side was pressed.

macOS hands keystrokes to the active app only. An app in the background
can be written to through Accessibility alone. Measured with a prototype
on 2026-10-28 (`plans/done/PASTE_ON_RETURN.md` §"Status"): TextEdit took the
text; Messages reported success and kept the field empty; Mail's web
editor did not take it; Claude (Electron) ignored it even in front; key
events posted to an app in the background reached no field.

Rejected alternatives:

- Writing into the field, with or without Enter, while its app stays in
  the background — fails in the apps that matter, per the measurement.
- Activating the target app for ⌘V and giving the focus back, also with
  the user's keys buffered meanwhile — rejected by the user: no focus
  change under any circumstances.
- Pressing Enter after the paste on return — rejected by the user.
- ⇧ as the mode key — the user chose the second ⌘ or ⌥.

## Decision

While ⌥ ⌘ is held for a recording, pressing the second ⌘ or ⌥ marks the
dictation as "paste on return". Outloud remembers the focused text field
when the recording starts, and after the release transcribes and cleans
up while the user works on.

The result is pasted with the normal auto-paste (⌘V) when the field's app
is active and its focused element is the remembered field — at once if the
user never left, otherwise when the user switches back to that app. With
another field focused, the result goes to the clipboard and Outloud says
so. Outloud never activates an app and presses no Enter. A later
dictation in this mode replaces a result that still waits.

This extends ADR 0004: the paste of such a dictation comes when the user
returns, not right after the release; it still goes only into a field that
takes text and is not a password field. ADR 0021's chord gains a meaning
for the second key; the rest of both stands.

## Consequences

- The user can dictate and move on; the text is there when they come back.
- The comparison of the focused element with the remembered one is what
  keeps the paste in the field the user dictated into; a change to it is
  reviewed against this ADR, and its refusal cases are tested.
- Apps that rebuild their input field may no longer match on return; the
  result then stays on the clipboard.
- Keyboards without a second ⌘ or ⌥ have no such mode.
- The dictation controller has to accept a recording while an earlier one
  is still processed.
