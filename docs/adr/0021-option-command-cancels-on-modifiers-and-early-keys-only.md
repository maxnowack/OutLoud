# 0021 – Holding ⌥ ⌘ is cancelled by another modifier at any time and by another key only within its first second; later keys are typed and the recording goes on

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0020 cancelled the ⌥ ⌘ recording on any key pressed while the chord was held, so that
⌥ ⌘ D and similar shortcuts never dictate. Testing on 2026-10-23, the user typed during a
dictation and lost it; and adding ⇧ or ⌃ to ⌥ ⌘ ended the chord like a release, so a shortcut
such as ⇧ ⌥ ⌘ 4 dictated. The user asked for: another modifier means a shortcut, at any time;
another key means a shortcut only in the first moments; later keys are typed normally.

Rejected alternative: a window of 0.5 s — offered to the user, who chose one second.

## Decision

While ⌥ ⌘ is held, ⇧ or ⌃ joining it cancels the recording, at any time. Another key cancels it
only within one second of the chord being pressed; after that the key reaches the app the user
types in, as before (the monitors only listen), and the recording goes on. Releasing ⌥ or ⌘ ends
the recording and dictates. This refines the cancel rule of ADR 0020; the rest of it stands.

## Consequences

- Typing while dictating keeps the dictation; the keys still arrive with ⌥ ⌘ held, so the app
  sees them as ⌥ ⌘ shortcuts.
- A shortcut pressed later than one second after ⌥ ⌘ dictates; in practice shortcuts follow the
  modifiers within a fraction of a second.
