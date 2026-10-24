<p align="center">
  <img src="docs/images/app-icon.png" width="128" height="128" alt="Outloud, the open-source dictation app for iPhone and Mac">
</p>

<h1 align="center">Outloud — free, open-source dictation for iPhone and Mac</h1>

<p align="center">
  <strong>Speak, and paste what you said. Speech to text that runs entirely on your device.</strong><br>
  No account, no cloud, no subscription — a private, offline alternative to Wispr Flow and Superwhisper.
</p>

<!-- When the iPhone app is in the App Store, replace "App Store: coming soon"
     below and in §"iPhone" with its link (docs/RELEASE.md §"iOS"). -->
<p align="center">
  <a href="#iphone-speech-to-text-in-any-app"><strong>iPhone</strong></a> — App Store: coming soon
  ·
  <a href="https://github.com/maxnowack/OutLoud/releases/latest"><strong>Download for Mac</strong></a>
  ·
  <a href="#build-it-yourself">Build it yourself</a>
</p>

---

Outloud is a dictation app for iPhone and Mac: voice to text for messages,
e-mails and notes, in any app. It turns your voice into text with
[Parakeet v3](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml),
a fast speech-to-text model that runs offline on your iPhone or Mac. If you
like, Apple's on-device model then tidies the text up: punctuation, filler
words, paragraphs — never a rewrite, never a translation.

- **Speech to text on iPhone** — run a shortcut from any app, speak, run it
  again. The text is on your clipboard, ready to paste, and you never leave
  the app you are in. The Dynamic Island shows what Outloud is doing.
- **Dictation on Mac** — hold <kbd>⌥</kbd> <kbd>⌘</kbd>, speak, let go. The
  text appears in the app you are typing in.

## Private, offline speech to text

- **Nothing leaves your device.** The speech model is downloaded once
  (483 MB) and runs locally; the cleanup uses Apple's on-device model.
- **No account, no tracking, no analytics.** Outloud never sends your voice
  or your text anywhere.
- **Your history stays yours.** Recordings are kept only as long as you set
  — one day by default — and you can delete them at any time.
- **Open source**, MIT licensed, without monetisation.

## iPhone: speech to text in any app

**Requirements:** iOS 27. The cleanup needs Apple Intelligence.

**App Store: coming soon.** Until then, the iPhone app is in a closed beta
on TestFlight. Once it is installed:

1. Open Outloud once and download the speech model.
2. In the Shortcuts app, create a shortcut with the action **Start or Stop
   Dictation with Outloud**, followed by **Copy to Clipboard**. The app's
   guide walks you through it.
3. Put the shortcut where your thumb is: AssistiveTouch, the Action Button,
   Back Tap, Control Center or Siri.
4. In any app, run the shortcut, speak, and run it again. The Dynamic Island
   shows what is happening, and the text is on your clipboard.

You can also open Outloud and tap the big record button.

## Mac: download and set up

**Requirements:** macOS 27 on a Mac with Apple silicon. The cleanup needs
Apple Intelligence; without it, Outloud gives you the plain transcript.

1. Download `Outloud-<version>.zip` from the
   [latest release](https://github.com/maxnowack/OutLoud/releases/latest),
   unzip it and move **Outloud** to your Applications folder. The app is
   signed and notarised by Apple.
2. Open it. Outloud lives in the menu bar, not in the Dock. The first
   launch offers the speech model for download and asks for the
   microphone.
3. Grant **Accessibility** access when asked (System Settings › Privacy &
   Security › Accessibility). Outloud needs it to notice <kbd>⌥</kbd>
   <kbd>⌘</kbd> and to paste for you; until then, hold <kbd>⌥</kbd>
   <kbd>Space</kbd> instead, and the text lands on the clipboard.
4. Hold <kbd>⌥</kbd> <kbd>⌘</kbd>, speak, release. A small glass pill at the
   bottom of the screen shows that Outloud is listening, then working.

Pressing another key in the first second — a shortcut like <kbd>⌥</kbd>
<kbd>⌘</kbd> <kbd>D</kbd> — cancels the dictation, so your other shortcuts
keep working. Outloud updates itself through
[Sparkle](https://sparkle-project.org).

## FAQ

**Is Outloud free?**
Yes. Outloud is open source under the MIT license, with no subscription and
no paid tier.

**Does it work offline?**
Yes. After the one-time model download, dictation and cleanup run without an
internet connection. Your voice and your text never leave the device.

**How is it different from the iPhone's built-in dictation?**
The keyboard's dictation types while you speak. Outloud listens first, then
hands you finished text: filler words removed, punctuation and paragraphs
set. You start it from any app without switching to the keyboard, and a
history keeps your recent dictations.

**How is it different from Wispr Flow or Superwhisper?**
Outloud does the same job — on the iPhone and on the Mac, speak and get text
where you type — but runs only on your device, needs no account and is open
source. It does fewer things on purpose: dictation and cleanup, nothing in
the cloud.

**Which languages does it understand?**
Parakeet v3 recognises 25 European languages. Outloud is built and tested
for **English** and **German**, and its interface speaks both.

**Do I need Apple Intelligence?**
Only for the cleanup. Without it, Outloud gives you the plain transcript.

**Why does it need Accessibility access on the Mac?**
To notice <kbd>⌥</kbd> <kbd>⌘</kbd> while another app is in front, and to
paste the text into it. Outloud records only while you hold the keys.

## Build it yourself

You need Xcode 27.1 and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
cd apps/macos            # or apps/ios
xcodegen generate
open Outloud.xcodeproj
```

Each unit — `OutloudKit/`, `apps/macos/`, `apps/ios/` — has a full check
in `./scripts/precommit`, run from its directory: build with warnings as
errors, format lint, tests. `docs/RELEASE.md` describes how a release is
signed and published.

## Status

Version 0.1.0 is out: the macOS app as a
[GitHub release](https://github.com/maxnowack/OutLoud/releases/tag/v0.1.0),
the iOS app as a TestFlight beta. What the first version covers, and what
is still open, is in `plans/FIRST_VERSION.md` §"Status".

## For contributors

The repository is worked on by people and coding agents under the same
rules. Where to start:

1. `AGENTS.md` — the working rules.
2. `docs/SPEC.md` — what the product does.
3. `docs/adr/README.md` — the decisions.
4. `plans/FIRST_VERSION.md` — the plan of the first version.
5. The area files of the units: `OutloudKit/AGENTS.md`,
   `apps/macos/AGENTS.md`, `apps/ios/AGENTS.md`.

### What is here

| Path | What it is |
| --- | --- |
| `AGENTS.md` | The repository-wide working rules, the map of rule files and the map of living documents. |
| `CLAUDE.md` | A pointer to `AGENTS.md`, for harnesses that read that name. |
| `LICENSE` | MIT. |
| `OutloudKit/` | The shared Swift package: models, downloads, transcription, cleanup, settings, history, the interface components, and the `outloud` developer CLI. |
| `apps/macos/` | The macOS menu bar app, with its end-to-end plans in `e2e/`; its Xcode project is generated from `project.yml`. |
| `apps/ios/` | The iOS app, with its end-to-end plans in `e2e/`; its Xcode project is generated from `project.yml`. |
| `apps/shared/` | What both apps build from: the app icon (`AppIcon.icon`, `docs/DESIGN.md` §"App icon") and the release scripts' shared parts. |
| `docs/SPEC.md` | What the product does. |
| `docs/ARCHITECTURE.md` | Components, trust boundaries and data. |
| `docs/DESIGN.md` | The visual style: tokens, components, screens, the app icon. |
| `docs/RELEASE.md` | Versioning, release and rollback, per app. |
| `docs/HORIZONTAL_SCALING.md` | The register of single-instance assumptions. |
| `docs/ARCHITECTURE_PRINCIPLES.md` | The technology-independent architectural rules. |
| `docs/RULE_WRITING.md` | How a rule is phrased and where it goes. |
| `docs/PROCESSES.md`, `docs/VERIFICATION.md`, `docs/COMMITS.md` | Situational working rules, read when `AGENTS.md` says so. |
| `docs/adr/` | Decision records with format and index. |
| `docs/images/` | Images for this README; `app-icon.png` is rendered from `AppIcon.icon` and is re-rendered when the icon changes (`docs/DESIGN.md` §"App icon"). |
| `plans/` | Open plans and their index; `plans/done/` for finished ones. |

The structure and the rule documents come from the `agents-template`
repository (commit `3bdf7b1`), adopted on 2026-10-22.

## License

[MIT](LICENSE) © 2026 Max Nowack
