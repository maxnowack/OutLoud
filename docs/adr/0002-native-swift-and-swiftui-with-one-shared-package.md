# 0002 – Outloud is a native Swift and SwiftUI app for iOS and macOS, with one shared Swift package and one module per platform

- Status: accepted
- Date: 2026-10-22

## Context

The product concept of 2026-10-22 describes Outloud for iOS and macOS.
Both platforms share the same core — transcription, an optional cleanup,
settings, error handling — and differ in how an input starts and how the
result reaches the target app: a shortcut and the clipboard on iOS, a
held hotkey, a menu bar app and auto-paste on macOS.

The concept names Swift with SwiftUI and one shared Swift package as the
intended code base. It names no alternative.

## Decision

We build Outloud in Swift with SwiftUI for iOS and macOS. One shared
Swift package owns the connection to transcription, the cleanup, the
settings and the error handling. One platform module per platform owns
the rest: recording, the shortcut integration and the clipboard on iOS;
the hotkey, the menu bar app and auto-paste on macOS.

## Consequences

- Outloud runs on Apple platforms only.
- Behaviour that both platforms share is written once, in the package;
  a platform module does not reimplement it.
- How the package and the two apps are laid out in the repository, and
  the oldest supported iOS and macOS versions, are open
  (`plans/TEMPLATE_ADOPTION.md` §"Open questions").
