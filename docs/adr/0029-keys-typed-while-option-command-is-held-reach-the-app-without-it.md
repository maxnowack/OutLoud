# 0029 – On macOS, keys typed while ⌥ ⌘ has been held for more than a second reach the app without ⌥ and ⌘, and ⇧ then types capitals instead of cancelling

- Status: accepted
- Date: 2026-10-30

## Context

ADR 0021 lets a key pressed later than one second after ⌥ ⌘ reach the app
and keeps the recording, but the key still arrives with ⌥ ⌘ held, so the
app sees a ⌥ ⌘ shortcut: Space opens Finder's search, a letter triggers a
menu item. ⇧ joining ⌥ ⌘ cancels at any time, so no capital can be typed
either. On 2026-10-30 the user reported that they cannot type during a
recording and need to, and chose to type while ⌥ ⌘ is held, with the
recording still bound to the held keys.

Rejected alternatives:

- A recording that runs on after a tap of ⌥ ⌘, ended by the next press —
  offered to the user, who chose to keep holding. It would also have
  broken the rule that Outloud records only while the hotkey is held
  (ADR 0004).
- A tap that is enabled whenever ⌥ ⌘ is watched and decides per key: an
  active tap holds every keystroke of the user until Outloud's main thread
  answers, so a busy main thread would delay typing in every app.
- A tap at the session level: a key that the window server matches as a
  system shortcut (⌥ ⌘ Space) could be taken before it; the HID level is
  where the key enters, before any of that.

## Decision

While the ⌥ ⌘ chord is held and its first second has passed, Outloud takes
⌥ and ⌘ off every key-down and key-up event at the HID event tap, so that
the key reaches the app the user types in as if only the other modifiers
were held. The tap is enabled only for that time and disabled when the
chord is released or cancelled. ⇧ joining ⌥ ⌘ after the first second no
longer cancels; ⇧ within the first second and ⌃ at any time still do, and
another key within the first second still cancels as a shortcut. The
Carbon shortcuts (⌥ Space and its variants) are unchanged. This refines
ADR 0021; the rest of it stands.

## Consequences

- Text can be typed during a ⌥ ⌘ recording, with spaces and capitals; a ⌥ ⌘
  shortcut pressed after the first second types its key instead.
- A character that needs ⌥ (@ or € on a German layout) cannot be typed
  while ⌥ ⌘ is held.
- Outloud alters the user's keystrokes in other apps. It does so only while
  the user holds ⌥ ⌘ for a dictation, only on key events, and only by
  removing ⌥ and ⌘; it posts no key and reads no character. The area
  security rule of `apps/macos/AGENTS.md` names this as the one alteration.
- An app that reads the held modifiers from the system instead of from the
  key event may still see ⌥ ⌘; the end-to-end plan checks the common apps.
- The tap needs Accessibility access, which ⌥ ⌘ needs already (ADR 0020).
