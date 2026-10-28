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
- [0004 – On macOS, Outloud is a menu bar app with a held push-to-talk hotkey that pastes into the active field when permitted and otherwise leaves the result on the clipboard](0004-macos-menu-bar-push-to-talk-with-auto-paste.md) *(extended by 0026, 0027)*
- [0005 – Outloud transcribes and cleans up on the device, on iOS and macOS, with open models the user chooses and downloads at first launch](0005-on-device-models-chosen-at-first-launch.md) *(catalogue narrowed by 0006, shared storage settled by 0009, cleanup model dropped by 0019)*
- [0006 – The first version transcribes with Parakeet v3 and cleans up with a Qwen model of about 0.8B parameters](0006-parakeet-v3-and-a-small-qwen-model.md) *(cleanup model superseded by 0019)*
- [0007 – Outloud for macOS is built for the App Sandbox to go into the Mac App Store; its models stay in its own container where no shared location is open to it](0007-mac-app-store-and-models-in-the-sandbox.md) *(superseded by 0009)*
- [0008 – Auto-paste outranks the Mac App Store: if App Review rejects it, Outloud for macOS is downloaded from GitHub instead](0008-auto-paste-outranks-the-mac-app-store.md) *(superseded by 0009)*
- [0009 – Outloud for macOS is downloaded from GitHub and runs outside the App Sandbox; the Mac App Store is not pursued](0009-macos-github-download-outside-the-sandbox.md)
- [0010 – On macOS, Outloud stores its models in the Hugging Face hub cache, in the hub's own layout](0010-models-in-the-hugging-face-hub-cache-on-macos.md)
- [0011 – The repository holds three units — the OutloudKit package, the macOS app and the iOS app — and XcodeGen generates the apps' Xcode projects](0011-monorepo-of-three-units-with-xcodegen.md)
- [0012 – iOS 27 and macOS 27 are the oldest versions Outloud supports](0012-ios-27-and-macos-27-are-the-oldest-supported.md)
- [0013 – OutloudKit also holds the audio capture, the shared interface components and a command-line tool](0013-outloudkit-holds-capture-interface-and-cli.md)
- [0014 – Every model file is checked against the hash the catalogue pins, after the download and before it is loaded when it changed](0014-model-files-are-checked-against-pinned-hashes.md)
- [0015 – The catalogue also offers Qwen 3.5 4B as a second, optional cleanup model](0015-qwen-4b-as-an-optional-cleanup-model.md) *(superseded by 0019)*
- [0016 – The macOS app is signed with Developer ID of team 95ZC649QPM, notarised, and updated by Sparkle from GitHub releases](0016-macos-release-developer-id-notarised-sparkle.md)
- [0017 – The iOS app ships a widget extension with a "Dictate" control, so that the Action Button, the Control Center and the Lock Screen start a dictation without the Shortcuts app](0017-ios-control-for-the-action-button.md)
- [0018 – On iOS, a dictation that leaves the user in their app is a shortcut that records with "Record Audio", has Outloud transcribe the file in the background, and copies the text itself](0018-ios-dictation-in-any-app-through-a-shortcut-that-records.md) *(superseded by 0022)*
- [0019 – Outloud cleans up with Apple's on-device model (Foundation Models) on iOS and macOS; Qwen and llama.cpp are removed](0019-cleanup-runs-on-apples-on-device-model.md)
- [0020 – On macOS, the default push-to-talk shortcut is ⌥ ⌘ held alone, watched with event monitors that need Accessibility access; ⌥ Space stands in until it is granted](0020-macos-push-to-talk-is-option-command-held-alone.md)
- [0021 – Holding ⌥ ⌘ is cancelled by another modifier at any time and by another key only within its first second; later keys are typed and the recording goes on](0021-option-command-cancels-on-modifiers-and-early-keys-only.md) *(extended by 0026)*
- [0022 – On iOS, a shortcut starts and stops a recording in the background, with an audio session that mixes with other audio and a Live Activity, and copies the text Outloud returns](0022-ios-background-dictation-with-a-mixable-session-and-a-live-activity.md)
- [0023 – The iOS app is distributed through TestFlight first; the App Store is decided later](0023-ios-is-distributed-through-testflight-first.md)
- [0024 – Other audio pauses while dictating: the media key on macOS when audio plays, the audio session on iOS](0024-other-audio-pauses-while-dictating.md) *(macOS superseded by 0025)*
- [0025 – macOS pauses with MediaRemote's pause command and plays on with the media key only after the apps it heard fell silent](0025-macos-pauses-with-mediaremote-and-plays-on-with-the-media-key.md)
- [0026 – On macOS, the second ⌘ or ⌥ held with ⌥ ⌘ lets the dictation finish in the background and pastes it when the user returns to the field it was recorded in; Outloud never brings an app to the front, and writing into an app in the background is rejected](0026-second-modifier-pastes-the-dictation-on-return-to-its-field.md) *(trigger superseded by 0027)*
- [0027 – On macOS, every dictation follows the field it was recorded in: leaving the field sends it to the background and its text is pasted on the return; the second ⌘ or ⌥ loses its meaning](0027-every-dictation-follows-its-field-and-pastes-on-return.md)
