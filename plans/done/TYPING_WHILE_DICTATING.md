# Type while ⌥ ⌘ is held

## Status

Done (2026-10-30). Steps 1–4 built and checked: `./scripts/precommit`
passes in `OutloudKit/` and `apps/macos/`, and the user ran step 14 of
`apps/macos/e2e/dictation.md` in the debug build and reported every
outcome met. No deviations, nothing descoped. Asked
for by the user on 2026-10-30 ("ich muss
tippen können während der Aufnahme"; asked how, they answered "Einfach
tippen während alt cmd gehalten wird" and that the recording stays on the
held key). Decided in ADR 0029.

## Problem

While ⌥ ⌘ is held, every key reaches the app the user types in as a ⌥ ⌘
shortcut: Space becomes ⌥ ⌘ Space, which opens Finder's search, and a
letter triggers a menu item or nothing (ADR 0021 §"Consequences"). ⇧
joining ⌥ ⌘ cancels the recording at any time, so not even a capital can be
typed. Outloud's monitors only listen; nothing of Outloud's swallows a key
(`apps/macos/Sources/Hotkey.swift`).

## Goal

1. Once ⌥ ⌘ has been held for the first second, the keys typed reach the
   app without ⌥ and ⌘: Space types a space, a letter the letter, ⇧ a
   capital. Within the first second a key or ⇧ is a shortcut and cancels,
   as today; ⌃ still cancels at any time.
2. The recording goes on while the user types, and releasing ⌥ or ⌘ ends
   it as before.
3. ⌥ Space and the other Carbon shortcuts are unchanged.

Decided by the agent, named to the user: ⇧ stops cancelling after the
first second, since capitals are typing; ⌃ keeps cancelling, since it is
not needed to type and the user decided on 2026-10-23 that another
modifier means a shortcut. A character typed with ⌥ (@ or € on a German
layout) cannot be typed while ⌥ ⌘ is held; it was a shortcut before.

## Design

- `OptionCommandChord` (OutloudKit) says from when keys are typed
  (`typingStarts`), and lets ⇧ join after that without cancelling.
- `HotkeyMonitor` keeps an event tap on keyDown and keyUp at the HID level,
  created disabled with the ⌥ ⌘ monitors, enabled from `typingStarts` until
  the chord is released, cancelled or no longer watched. While enabled it
  takes ⌥ and ⌘ — device-independent and per-side bits — off every key
  event. The tap is on only then, so that no keystroke of the user waits
  for Outloud's main thread at any other time.
- The listening monitors stay as they are and still decide the cancel
  within the first second.

## Steps and Definition of Done

1. ADR 0029, this plan, the area security rule, `docs/SPEC.md` and
   `docs/ARCHITECTURE.md`. Done when they state the new rule and nothing
   contradicts it.
2. Chord logic with tests in OutloudKit: ⇧ after the first second keeps
   the recording, ⇧ within it cancels, ⌃ cancels at any time,
   `typingStarts` is the press plus the window while pressed and `nil`
   otherwise. Done when `./scripts/precommit` passes in `OutloudKit/`.
3. The tap in `apps/macos/Sources/Hotkey.swift`. Done when
   `./scripts/precommit` passes in `apps/macos/`.
4. `apps/macos/e2e/dictation.md` gets the case, and it is run with the
   user's keyboard in the debug build: holding ⌥ ⌘, after a second typing
   "Hallo Welt" with Space and ⇧ into TextEdit types it, no Finder search
   opens, and releasing dictates.
