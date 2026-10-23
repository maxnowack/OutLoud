# Start a dictation on macOS by holding ⌥ ⌘ alone

## Status

Phase 1 built (2026-10-23), phase 2 open — the run on the Mac needs the
user's keyboard. Asked for by the user on 2026-10-23 ("Option
Command gleichzeitig drücken … wie Ghost Pepper"), noted in
`plans/FIRST_VERSION.md` §"Decisions for the user" item 5, started on the
user's "Mach alles". The fallback below was decided by the agent, since
the user did not answer the question; it is named in the summary to them.

## Problem

The push-to-talk shortcut is ⌥ Space (or ⌃ ⌥ Space, ⇧ ⌥ Space), a Carbon
hot key, which reports press and release without the Accessibility
permission but needs a key besides the modifiers (ADR 0004,
`apps/macos/Sources/Hotkey.swift`). The user wants to hold ⌥ and ⌘
together, alone, as ghost-pepper does with a modifier.

## Goal

1. "⌥ ⌘" is a shortcut choice and the default: holding both, alone,
   records; releasing either ends the recording.
2. Pressing another key while ⌥ ⌘ is held — a shortcut such as ⌥ ⌘ D —
   cancels the recording instead of dictating it.
3. Without Accessibility access, macOS does not report the modifier keys of
   other apps; then ⌥ Space works instead, and the settings say so and offer
   to allow access. Once access is granted, ⌥ ⌘ works without a relaunch.

## Approach

`HotkeyMonitor` gets a second kind of shortcut: a modifier chord, watched
with global and local `NSEvent` monitors for `flagsChanged` and `keyDown`.
The chord counts as pressed when exactly ⌥ and ⌘ are down (no ⇧, ⌃), and
as released when that ends; a key pressed meanwhile cancels. The existing
rule that a press shorter than 250 ms is no dictation stays, so a quick
⌥ ⌘ tap does nothing. Without Accessibility access, registering the chord
registers ⌥ Space as a Carbon hot key and reports the fallback; the app
registers again when the access changes.

Rejected:

- A `CGEventTap`: it needs Input Monitoring or Accessibility as well, and
  more code for the same events.
- A delay before the recording starts, to avoid a flash of the overlay
  when ⌥ ⌘ starts another shortcut: it would cut the start of every
  dictation; the cancel on the next key is enough.

This changes what a dictation needs on macOS (ADR 0004: the hotkey works
without Accessibility) and is recorded as ADR 0020.

## Phases

### 1. The chord

DoD: the chord preset, the monitor, the fallback and the cancel are built;
the settings show "⌥ ⌘" and the fallback note; `./scripts/precommit`
passes; ADR 0020, `docs/SPEC.md` §"Dictation on macOS", `docs/DESIGN.md`
and `apps/macos/e2e/settings.md` are updated; the German strings are in
the catalog.

### 2. Run on the Mac

DoD: the user holds ⌥ ⌘ in another app and a dictation is pasted; ⌥ ⌘ D
does not dictate; without Accessibility, ⌥ Space works. These checks need
the user's keyboard and are theirs (`apps/macos/AGENTS.md`).

## Risks

- ⌥ ⌘ is part of other shortcuts: the cancel on the next key and the
  250 ms rule keep them from dictating; the overlay may flash briefly.
- An app that reads ⌥ ⌘ alone (rare) would see it too; the monitor only
  listens, it does not swallow events.

## Open questions

None.
