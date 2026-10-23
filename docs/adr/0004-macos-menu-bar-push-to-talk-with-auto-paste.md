# 0004 – On macOS, Outloud is a menu bar app with a held push-to-talk hotkey that pastes into the active field when permitted and otherwise leaves the result on the clipboard

- Status: accepted; its default shortcut extended by [0020](0020-macos-push-to-talk-is-option-command-held-alone.md)
- Date: 2026-10-22

## Context

The product concept of 2026-10-22 sets the macOS flow: the user holds a
push-to-talk hotkey, Outloud records, the user releases it, Outloud
transcribes, optionally cleans up, and pastes the result into the active
text field or puts it on the clipboard. A small menu bar app shows
recording and processing.

macOS sets the limits. Recording needs the microphone permission; auto-
paste usually also needs Accessibility access
(https://support.apple.com/en-ie/guide/mac-help/mh43185/mac). Focus
changes, protected fields and hotkey conflicts limit how reliably
auto-paste works.

## Decision

On macOS, Outloud is a menu bar app. A recording starts only while the
user holds the push-to-talk hotkey, and ends when they release it.
Outloud pastes the result into the active text field once the user has
granted it; without the permission, or when the field is not suitable,
the result stays available for pasting by hand.

## Consequences

- Auto-paste depends on a permission the user grants in System Settings;
  the app explains it and works without it.
- Whether auto-paste fits the App Sandbox — and with it whether Outloud
  can be distributed through the Mac App Store — is open
  (`plans/done/CONCEPT.md` §"Open questions").
- The default hotkey, and how a hotkey conflict is handled, are open.
