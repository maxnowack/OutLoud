# 0020 – On macOS, the default push-to-talk shortcut is ⌥ ⌘ held alone, watched with event monitors that need Accessibility access; ⌥ Space stands in until it is granted

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0004 holds a push-to-talk hotkey; the first version registered ⌥ Space as a Carbon hot key,
which reports press and release without the Accessibility permission but needs a key besides the
modifiers (`plans/FIRST_VERSION.md` §"Decisions for the user" item 5). The user asked for ⌥ and ⌘
held together, alone, as ghost-pepper starts a dictation with a modifier.

macOS reports the modifier keys pressed in other apps only to an app with Accessibility access
(global `NSEvent` monitors for key events), or Input Monitoring for an event tap. Outloud asks for
Accessibility already, for auto-paste (ADR 0004), but works without it.

Rejected alternatives:

- A `CGEventTap`: it needs a permission as well, and more code for the same events.
- Waiting a moment before recording, so that ⌥ ⌘ as part of another shortcut (⌥ ⌘ D) never
  starts one: it would cut the start of every dictation. A key pressed while ⌥ ⌘ is held cancels
  the recording instead, and a press under 250 ms records nothing.

## Decision

We offer "⌥ ⌘" as a push-to-talk shortcut and make it the default. It is watched with global and
local `NSEvent` monitors for `flagsChanged` and `keyDown`: exactly ⌥ and ⌘ down starts the
recording, their release ends it, any other key cancels it. The monitors only listen; they do not
consume events. Without Accessibility access, ⌥ Space works instead, as a Carbon hot key; the
settings say so and offer to allow access, and the app switches to ⌥ ⌘ once access is granted.
⌥ Space, ⌃ ⌥ Space and ⇧ ⌥ Space stay as choices.

## Consequences

- Extends ADR 0004: the default shortcut needs Accessibility access; dictation itself still works
  without it, through the fallback.
- Every ⌥ ⌘ shortcut of another app starts and at once cancels a recording; the overlay may flash.
- The decision is implemented by `apps/macos/Sources/Hotkey.swift` (`plans/OPTION_COMMAND_HOTKEY.md`).
