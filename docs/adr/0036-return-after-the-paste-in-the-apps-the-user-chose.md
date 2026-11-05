# 0036 – On macOS, a dictation pasted into an app the user listed is followed by one Return

- Status: accepted
- Date: 2026-11-05
- Extends: ADR 0004, ADR 0026, ADR 0027 (the one key besides ⌘V)

## Context

ADR 0026 and ADR 0027 let Outloud post no key but ⌘V: a Return sends a
message, and one sent into the wrong field cannot be taken back. On
2026-11-05 the user asked for the apps where every dictation is a message
to be sent — Claude first — to send it without the extra key press.

## Decision

The user lists apps in the settings, by bundle identifier; the list is
empty by default. When Outloud pastes a dictation with ⌘V into a text field
of a listed app — at once, or on the return to its field under ADR 0027 —
it posts one plain Return afterwards, and only when, right before that
Return:

- the same field — element and identity, as for the paste on return — has
  the focus and its app is in front,
- no recording has started since the paste.

The Return waits until the target has handled the ⌘V, as the clipboard's
restore already does. Where a check fails, no Return is posted and the text
stays in the field. A result that is only copied gets no Return. No other
key is posted, and no app is activated for it.

## Consequences

- In a listed app a dictation is sent as soon as it is pasted; the user
  cannot read it first. Who wants to read first leaves the app off the
  list.
- A dictation pasted on the return to its field is sent the moment the user
  comes back, by the user's choice of listing the app.
- The property given up is narrow: Outloud may now post Return, only into
  the field it just pasted into and only in an app the user listed. The
  exposure is a Return into that field when its content changed in the
  wait in a way the identity check does not see.
- The wait is a guess until it is measured in Claude
  (`plans/RETURN_AFTER_PASTE.md` phase 4); the measurement and its date are
  added here.
