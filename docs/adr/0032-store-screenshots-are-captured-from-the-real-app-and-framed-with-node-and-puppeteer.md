# 0032 – The App Store screenshots are captured from the real app in a fresh simulator and framed by a Node script with Puppeteer, kept in `marketing/` with its own pinned dependencies

- Status: accepted
- Date: 2026-11-01

## Context

The iOS app needs App Store screenshots and creative assets in English and
German (`plans/done/APP_STORE_LISTING.md`). Screenshots go stale with every
change to a screen, so they have to be reproducible: the same command
after an app change gives the same frames with the new UI. Guideline 2.3
asks that they show the app as it is.

Until now the repository held only Swift units (ADR 0002, ADR 0011).
Framing captures — a device shell, headlines, a backdrop, the cropped
creative assets — is layout and type setting.

Alternatives considered:

- **SwiftUI's `ImageRenderer` with the OutloudUI tokens.** No new
  toolchain, and the colours come from the code. Rejected: the device
  frame, the text layout across locales and the creative-asset crops
  would all be built from nothing, while HTML and CSS do them directly.
- **A third-party screenshot service or a design tool.** Rejected: not
  reproducible from the repository, and a manual step after every UI
  change.
- **Retouched or mocked screens.** Rejected: a screenshot that shows
  what the app does not produce is a Guideline 2.3 risk and drifts from
  the app. The one exception is the cleanup's text, below.
- **Showing the transcripts without cleanup.** Rejected: the simulator
  offers no Apple Intelligence (the app reports the model as not ready,
  with it switched on on the Mac), so every screen would show filler
  words and a warning in place of the app's main feature.

CatchFlights (`~/code/CatchFlights/marketing/store-screenshots/`), by the
same author, has taken this approach through App Review.

## Decision

We keep the store material in `marketing/` at the repository root, beside
the units and not inside one: it describes the product, not a unit's
code.

We capture the screenshots from a Debug build of the real app in a new
simulator per locale (`marketing/store-screenshots/capture.mjs`). The
dictations shown are the app's own output from recordings spoken by
macOS's `say`, fed in through the existing debug seam
`-OutloudSampleAudio`; the model is copied from the local Hugging Face
cache instead of downloaded.

The cleanup's text is the exception: the simulator has no Apple
Intelligence, so a Debug-only stand-in cleaner
(`-OutloudCleanupStandIn <text>`, `StandInCleaner.swift`) answers with
a cleaned text written in `capture.mjs`. It is written as the cleanup
produces it on a device (`docs/SPEC.md` §"Cleanup"): the transcript's
filler words removed, punctuation and paragraphs set, nothing else
changed. The transcription, the history and every screen remain the
app's own.

We frame them with a Node script that renders HTML in Puppeteer
(`marketing/store-screenshots/generate.mjs`). Its dependencies are pinned
to exact versions in `marketing/package.json` with a committed
`package-lock.json`; `node_modules/` is ignored.

## Consequences

- The repository has a second toolchain: Node and npm, used only under
  `marketing/` and only on a maintainer's Mac. No app or package build
  depends on it, and `precommit` does not run it.
- The type in the frames is the system font as Chrome resolves it on
  macOS; a render on another platform would differ.
- A change to a screen that appears in the screenshots is followed by a
  new capture and render before the next store submission
  (`docs/RELEASE.md` §"iOS").
- The capture depends on the debug seams `-OutloudSampleAudio`,
  `-OutloudAutoDictate`, `-OutloudTab`, `-OutloudCleanupStandIn` and
  `-hasCompletedSetup`; removing one breaks it.
- A change to the cleanup's behaviour is followed by a check that the
  cleaned texts in `capture.mjs` still match what it produces. Once a
  simulator offers Apple's model, the stand-in goes.
