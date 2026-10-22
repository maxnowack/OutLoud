# Architecture Decision Records (ADR)

Architecture decisions are recorded here. The binding rule for when an ADR
must be written is in `AGENTS.md` §"Plan and ADR rules".

## Format

One file per decision, numbered consecutively:
`NNNN-short-kebab-case-title.md`. Language is English. Every ADR contains
exactly these sections:

```markdown
# NNNN – Title of the decision

- Status: accepted | superseded by [NNNN](NNNN-….md)
- Date: YYYY-MM-DD

## Context

What problem was at hand, which forces/alternatives existed. Name rejected
alternatives with the reason for rejection.

## Decision

What was decided, in full sentences and active voice ("We use …").

## Consequences

What follows — positives, negatives, new duties, affected modules.
```

The title is a sentence that states the decision, not a topic: "The socket
is the app's transport", not "Transport". A reader of the index should be
able to tell what was decided without opening the file.

## Rules

- An accepted ADR is not rewritten. A revised decision gets a new ADR; the
  old one gets the status "superseded by" with a link.
- ADRs record the decision and its rationale, not the implementation —
  implementation detail belongs in the corresponding plan under `plans/`.
- Where a decision was set by a *measurement* — a limit, a floor, a threshold
  — the ADR records the measurement and its date, so a later reader can tell
  whether the reason still holds.
- A number collision after a rebase is resolved in the commit that created
  the file, with every reference rewritten repo-wide (`docs/COMMITS.md`).

## Index

- [0001 – The project does not maintain a technical dossier](0001-technical-dossier.md)
- [0002 – Outloud is a native Swift and SwiftUI app for iOS and macOS, with one shared Swift package and one module per platform](0002-native-swift-and-swiftui-with-one-shared-package.md)
- [0003 – On iOS, a shortcut starts the input and the result reaches the target app through the clipboard; the first version ships no custom keyboard](0003-ios-hands-over-through-the-clipboard-without-a-keyboard.md)
- [0004 – On macOS, Outloud is a menu bar app with a held push-to-talk hotkey that pastes into the active field when permitted and otherwise leaves the result on the clipboard](0004-macos-menu-bar-push-to-talk-with-auto-paste.md)
- [0005 – Outloud transcribes and cleans up on the device, on iOS and macOS, with open models the user chooses and downloads at first launch](0005-on-device-models-chosen-at-first-launch.md) *(catalogue narrowed by 0006, shared storage settled by 0009)*
- [0006 – The first version transcribes with Parakeet v3 and cleans up with a Qwen model of about 0.8B parameters](0006-parakeet-v3-and-a-small-qwen-model.md)
- [0007 – Outloud for macOS is built for the App Sandbox to go into the Mac App Store; its models stay in its own container where no shared location is open to it](0007-mac-app-store-and-models-in-the-sandbox.md) *(superseded by 0009)*
- [0008 – Auto-paste outranks the Mac App Store: if App Review rejects it, Outloud for macOS is downloaded from GitHub instead](0008-auto-paste-outranks-the-mac-app-store.md) *(superseded by 0009)*
- [0009 – Outloud for macOS is downloaded from GitHub and runs outside the App Sandbox; the Mac App Store is not pursued](0009-macos-github-download-outside-the-sandbox.md)
- [0010 – On macOS, Outloud stores its models in the Hugging Face hub cache, in the hub's own layout](0010-models-in-the-hugging-face-hub-cache-on-macos.md)
- [0011 – The repository holds three units — the OutloudKit package, the macOS app and the iOS app — and XcodeGen generates the apps' Xcode projects](0011-monorepo-of-three-units-with-xcodegen.md)
- [0012 – iOS 27 and macOS 27 are the oldest versions Outloud supports](0012-ios-27-and-macos-27-are-the-oldest-supported.md)
