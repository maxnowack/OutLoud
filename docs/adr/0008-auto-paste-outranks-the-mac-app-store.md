# 0008 – Auto-paste outranks the Mac App Store: if App Review rejects it, Outloud for macOS is downloaded from GitHub instead

- Status: superseded by [0009](0009-macos-github-download-outside-the-sandbox.md)
- Date: 2026-10-22

## Context

ADR 0004 makes auto-paste part of the macOS app; ADR 0007 builds the
app for the App Sandbox to go into the Mac App Store. Posting ⌘V with
`CGEvent.post` works inside the sandbox, but App Review rejected a
sandboxed clipboard manager for it under Guideline 2.4.5, with further
reports up to September 2026
(https://developer.apple.com/forums/thread/820594).

Asked on 2026-10-22 what Outloud on the Mac should be if the Mac App
Store does not let auto-paste through, the user decided to leave the
Mac App Store and let the app be downloaded from GitHub.

Rejected alternative: a Mac App Store version without auto-paste.

## Decision

If App Review rejects auto-paste, we do not distribute the macOS app
through the Mac App Store; it is downloaded from GitHub, with
auto-paste.

## Consequences

- Auto-paste stays in the macOS app on every distribution channel.
- Outside the Mac App Store the app is not bound to the sandbox; the
  shared Hugging Face cache becomes reachable for the models
  (`docs/SPEC.md` §"Models", ADR 0007).
- Whether the Mac App Store is tried first, and how a GitHub download is
  signed and updated, are open (`plans/done/CONCEPT.md` §"Open questions").
