# 0027 – On macOS, every dictation follows the field it was recorded in: leaving the field sends it to the background and its text is pasted on the return; the second ⌘ or ⌥ loses its meaning

- Status: accepted
- Date: 2026-10-28
- Supersedes: the trigger of ADR 0026 (the second ⌘ or ⌥)

## Context

ADR 0026 lets a dictation finish in the background and pastes it when the
user returns to its field, but only when the user pressed the second ⌘ or ⌥
while holding ⌥ ⌘. On 2026-10-28 the user asked to drop the key: Outloud
already watches the focused field, so it can tell by itself that the user
left.

## Decision

Every dictation that starts in a text field, with Accessibility access and
auto-paste on, belongs to that field:

- While the user stays in it, the pill shows the progress and the result is
  pasted, as before.
- When the user leaves it while the dictation is processed — another field,
  the same field showing another conversation, another app —, the pill says
  once that the text waits and goes, the processing goes on out of sight,
  and the next dictation can start at once. The result is pasted with ⌘V
  when the field has the focus again, under ADR 0026's rules: element and
  identity match, its app is in front, no app is activated, no Enter.
- A new dictation started in a field for which an earlier one is still
  processed or waits belongs to the next other text field the user focuses.
  When it is done before the user focused one, it is copied. Dictations of
  different fields wait side by side; none replaces another.
- A press of the hotkey while a dictation is processed in sight sends that
  one to the background and starts the new recording.

A dictation started without a text field, or with auto-paste off, is
delivered as ADR 0004 says: at its end, into the text field in front, else
the clipboard. Sent to the background by a new press, it is copied, so that
nothing is pasted while the user records.

The second ⌘ or ⌥ has no meaning; ADR 0021's chord stands otherwise.

## Consequences

- No key to learn; the user dictates and works on.
- The strict match of ADR 0026 now governs every dictation with a field. An
  app whose field changes its identity while the user stays makes the
  result wait instead of being pasted at once; the identity is
  `AutoPaster.identity(of:)`, and a change to it is reviewed against this
  ADR and ADR 0026.
- A dictation made in a field that is already taken lands in another field,
  possibly another conversation, by the user's choice.
- Several results can wait at the same time, each for its own field.
