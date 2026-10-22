# Build the first version of Outloud for macOS and iOS

## Status

In progress (2026-10-22). Phase 0 is done: ADRs 0001, 0011 and 0012,
the maps and Swift conventions in `AGENTS.md`, the three area files, and
the units scaffolded; the `precommit` command of every unit passes on
this Mac. OutloudKit's first type is the history's `RetentionPeriod`,
because a test target needs a test and the periods are specified. The
bundle identifier is `io.github.maxnowack.outloud` on both platforms,
after the GitHub account the macOS app is downloaded from. Phase 1 is
next.

The user confirmed the plan on 2026-10-22, with iOS 27 and macOS 27 as
the oldest supported versions instead of the proposed iOS 17 and
macOS 14.

## Problem

The concept is written down (`docs/SPEC.md`, `docs/ARCHITECTURE.md`,
ADRs 0002–0010, `plans/done/CONCEPT.md`), but no code exists. Two of its
foundations are unproven: that FluidAudio and LLM.swift load the models
from the Hugging Face cache (ADR 0010), and that Parakeet v3 and the Qwen
model fit an iPhone (ADR 0006).

## Goal

Outloud runs on macOS and iOS as `docs/SPEC.md` describes it: dictation
with the platform flows of ADRs 0003 and 0004, local transcription and
optional cleanup, model selection at first launch, model management in
the settings, and the history. Every feature has acceptance criteria and
an end-to-end test plan that was executed.

## Approach

Foundations first, then the shared core, then the two apps, so that each
app is composed from a tested core and a decided style.

- Repository layout (ADR 0011): a monorepo of three units — the Swift
  package `OutloudKit/` and the apps `apps/macos/` and `apps/ios/` — each
  with its own area file and `precommit` command. XcodeGen generates the
  Xcode projects from a `project.yml` per app. Rejected: one hand-kept
  Xcode project with both targets — a faster start, but its project file
  conflicts under parallel edits and the units would share one
  directory, against `AGENTS.md` §"Repository layout".
- The feasibility of the model foundations is shown in a spike before
  the core builds on it.
- The technical dossier is not kept (ADR 0001).
- The oldest supported versions are iOS 27 and macOS 27 (ADR 0012).

## Phases

### 0. Foundations

ADR 0001 closed; ADRs 0011 and 0012 written; the maps and the Swift
conventions in `AGENTS.md`; an area file per unit; the three units
scaffolded without features; the concept plan moved to `plans/done/`.

DoD: the `precommit` command of every unit passes on this Mac.

### 1. Model spike

A command-line tool in `OutloudKit/` downloads Parakeet v3
(`FluidInference/parakeet-tdt-0.6b-v3-coreml`) and ghost-pepper's Qwen
3.5 0.8B Q4_K_M GGUF into the Hugging Face cache in the hub's layout;
FluidAudio and LLM.swift load them from the snapshot folders; a German
and an English sample are transcribed and cleaned up with the
multilingual prompt.

DoD: both samples come out correctly on this Mac, and the load and run
times are recorded in this plan. If a runtime cannot load from the cache,
the work stops and the user decides (ADR 0010). Cost: about 2 GB of
downloads.

### 2. OutloudKit core

The model catalogue; the downloader with progress, stop, delete with
warning, the cellular check on iOS, the hub layout on macOS and the app
container on iOS; transcription; cleanup with the prompt and the fallback
to the raw transcript; the settings; the history with its retention
periods.

DoD: `swift test` passes, including tests for retention expiry, stopping
a download and deleting a model.

### 3. Design

`docs/DESIGN.md` — tokens, component vocabulary, accessibility contract —
and the components, before the first screen.

DoD: `docs/DESIGN.md` is filled and approved by the user.

### 4. macOS app

Menu bar app, push-to-talk hotkey, recording, auto-paste with the
clipboard fallback, first launch, settings, history; the end-to-end test
plans under `apps/macos/e2e/`.

DoD: the plans were executed on this Mac, with the user's approval for
their screen.

### 5. iOS app

App Intent for the shortcut, recording, clipboard, first launch with the
cellular warning, settings, history; the end-to-end test plans under
`apps/ios/e2e/`.

DoD: the plans were executed in the simulator. The memory on a real
iPhone stays unverified until the user provides a device.

### 6. Release

Signing, notarisation and updates of the GitHub download for macOS.

DoD: `docs/RELEASE.md` and the ADR for the macOS release path are
written.

## Risks

- FluidAudio or LLM.swift may not load from a snapshot folder whose files
  are symlinks (ADR 0010) — shown or refuted in phase 1.
- Parakeet v3 (~1.4 GB) and the Qwen model (~535 MB) may not fit an
  iPhone's memory, or run too slowly there (ADR 0006).
- ghost-pepper's licence is stated only in its README
  (`plans/done/CONCEPT.md` §"Risks"); its prompt is adapted with its
  copyright and permission notice.

## Open questions

Carried over from the concept, answered as the work reaches them
(`plans/done/CONCEPT.md` §"Open questions"):

- How cleanup is switched on and off, and how the language is chosen.
- How the GitHub download is signed, notarised and updated.
- The acceptance criteria per feature.
- The default hotkey on macOS.
- Which of the ideas from ghost-pepper belong in the product.
- The history's edges: copying a kept result again, deleting one on its
  own, and what a shorter period does to results already kept.
- Whether viewing a kept result shows both texts (A-10).
