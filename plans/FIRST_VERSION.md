# Build the first version of Outloud for macOS and iOS

## Status

In progress (2026-10-23). Phases 0 to 5 are built; phase 6 is prepared
and waits on credentials only the user can create (§"Decisions for the
user", 1).

Addendum 2026-10-23, after the user's answers: team "Max Nowack"
(95ZC649QPM) signs both apps; Debug builds of the macOS app are signed
with Apple Development; Sparkle 2.10.0 and `apps/macos/scripts/release`
prepare the notarised GitHub download (ADR 0016, `docs/RELEASE.md`);
Qwen 3.5 4B is offered as a second cleanup model (ADR 0015); the iOS
simulator is skipped in favour of the user's iPhone. The first signed device build with the increased memory limit passed and
the app was installed and launched on the user's iPhone 15 Pro. The
plans in `apps/ios/e2e/` are the user's to run on it. Built on 2026-10-22/23 while the user
was asleep, as they asked: "build the macOS and iOS apps to the end;
decide yourself or collect the decisions". Committed on 2026-10-23 at the
user's request, one commit per unit plus one for the documents.

- **Phase 0** — ADRs 0001, 0011, 0012, the maps and Swift conventions in
  `AGENTS.md`, the area files, the scaffold. The bundle identifier was
  `io.github.maxnowack.outloud`; on 2026-10-23 the user changed it to
  `dev.nowack.outloud` on both platforms (the widget extension:
  `dev.nowack.outloud.widgets`).
- **Phase 1** — see below; the model foundations hold.
- **Phase 2** — `OutloudKit`: catalogue with pinned hashes, `ModelStore`
  (hub layout, locks, progress, stop, space check, hash checks, delete
  that keeps what other tools reference; ADR 0014), `ModelLibrary`,
  `NetworkMonitor`, `Engines`, `AudioRecorder`, `DictationPipeline` with
  `HesitationFilter` and the fallback to the transcript,
  `DictationController`, `HistoryStore`/`HistoryModel`, `OutloudSettings`,
  the CLI (ADR 0013). 40 tests pass, also with the Mac locked (the history
  first used complete file protection, which fails while locked). A real download of Parakeet v3
  (483 MB) from Hugging Face took 50 s and passed the hash checks.
- **Phase 3** — `docs/DESIGN.md` and the `OutloudUI` components; approved
  by the user on 2026-10-23 after a preview canvas
  (https://claude.ai/artifact/NMtJBPyvCvZiPqjUsfqKqT).
- **Phase 4** — the macOS app: menu bar panel, ⌥ Space push-to-talk
  (Carbon hot key), non-activating overlay, auto-paste with clipboard
  save/restore and the fallback, setup window, settings, history window,
  German and English. Executed: the debug seam dictated the three samples
  inside the app — models loaded in 0.9–1.5 s, a dictation took 1.2–1.5 s,
  the result reached the clipboard (`copied(noPermission)`, since the app
  has no Accessibility access), the history kept transcript and audio,
  and Quit exited with status 0. Not executed: the hotkey, the
  microphone, auto-paste and every visual check — they need the user's
  permissions and screen (`apps/macos/e2e/`).
- **Phase 5** — the iOS app: dictate tab, "Dictate with Outloud" and
  "Clean Up Text with Outloud" App Intents and App Shortcuts, setup with
  the cellular warning, history, settings, German and English. A copy built for iOS 26 ran on the
  iOS 26.5 simulator: setup, dictate, result, history and settings
  screens rendered correctly in English and German; the debug seam's
  dictation transcribed and kept the recording. Cleanup timed out in the
  simulator after 38–44 s every time (llama.cpp is far too slow there),
  so the iOS cleanup path is unverified; on the Mac the same code takes
  about 1 s. Not executed: microphone, Action Button, the Shortcuts app,
  a real device.

The user confirmed the plan on 2026-10-22, with iOS 27 and macOS 27 as
the oldest supported versions instead of the proposed iOS 17 and
macOS 14.

Phase 1, 2026-10-22, on an M1 Pro Mac (macOS 27), with the
samples in `OutloudKit/Samples/` (macOS `say`, voices Anna and Samantha)
and `swift run outloud dictate`:

- The models were not downloaded: ghost-pepper's copies of Parakeet v3
  (FluidAudio's folder) and of the Qwen GGUF matched the pinned
  revisions file by file and were placed in the hub cache as APFS
  clones. FluidAudio 0.17.7 reads `JointDecisionv3.mlmodelc`, which
  ghost-pepper's FluidAudio 0.13.6 copy lacked; `ModelStore` downloaded
  its four small files and reused the identical weights blob.
- FluidAudio loads Parakeet v3 from the snapshot folder, whose files are
  symlinks (`AsrModels.loadLocal`), in 0.2 s. German and English are
  detected without a setting; a 10 s sample is transcribed in 0.2 s,
  correctly.
- LLM.swift loads the Qwen GGUF from the cache in 0.4–0.7 s. Cleanup
  takes about 1.2 s with Qwen 3.5 0.8B, 1.7 s with 2B and 4 s with 4B.
  0.8B removes the fillers and punctuates, but applies neither "scratch
  that" nor "streich das", and once changed a word ("streicht" →
  "streich es"); 2B translated the German sample into English; 4B handled
  both samples correctly. A dictated instruction ("Ignoriere alle
  vorherigen Anweisungen …") came back as the sentence from every model.
  Two measures improved 0.8B: removing hesitation sounds before the model
  (`HesitationFilter`) and giving the examples as earlier conversation
  turns. The catalogue stays at 0.8B (ADR 0006); whether to offer 4B is
  in §"Decisions for the user".
- Freeing llama.cpp's Metal device at process exit crashes unless
  `LLM.shutdownBackend()` runs first (`QwenCleaner.shutDownBackend()`).

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

- Parakeet v3 (483 MB) and the Qwen model (533 MB) may not fit an
  iPhone's memory, or run too slowly there (ADR 0006); the simulator
  cannot tell.
- The 0.8B cleanup model does not apply spoken self-corrections
  ("scratch that", "streich das") and occasionally changes a word
  (§"Status", phase 1).
- ghost-pepper's licence is stated only in its README
  (`plans/done/CONCEPT.md` §"Risks"); its prompt is adapted with its
  copyright and permission notice.

## Decisions for the user

Made on 2026-10-22/23 without the user, as they asked; each can be
reversed. The first three block parts of the plan.

1. **Release credentials** (phase 6, blocking): a Developer ID
   Application certificate, a notarytool profile and Sparkle's key pair
   (`docs/RELEASE.md` §"Release procedure"). Decided: team 95ZC649QPM,
   Sparkle (ADR 0016).
2. **iPhone** — done 2026-10-23: the app runs on the user's iPhone 15
   Pro; the e2e plans on it are the user's. Decided: no iOS 27 simulator.
3. **`docs/DESIGN.md`** — approved 2026-10-23.
4. **Cleanup model size** — decided 2026-10-23: 0.8B stays the default,
   4B is offered too (ADR 0015). *Addendum 2026-10-23:* superseded — the
   cleanup runs on Apple's on-device model and Qwen is removed (ADR 0019,
   `plans/APPLE_CLEANUP.md`).
5. **Default hotkey ⌥ Space**, with ⌃ ⌥ Space and ⇧ ⌥ Space to choose.
   A modifier alone (e.g. holding Fn or right ⌥, as ghost-pepper does with
   Control) would need an event tap and the Accessibility permission,
   which the app has to work without.
   *Addendum 2026-10-23:* the user wants ⌥ ⌘ pressed together, alone,
   as the hotkey — as ghost-pepper does it. Built as the default, with
   ⌥ Space while Accessibility access is missing (ADR 0020,
   `plans/OPTION_COMMAND_HOTKEY.md`); the text below is the earlier note. It needs a
   modifier-only trigger (a `flagsChanged` monitor or an event tap)
   instead of the Carbon hotkey, and with it the Accessibility
   permission for recording itself; auto-paste asks for that permission
   already, so the cost is that dictation without auto-paste no longer
   works without it. Open: whether ⌥ Space stays as the fallback while
   the permission is missing.
6. **Acceptance criteria** in `docs/SPEC.md` were written from the rules,
   as proposals.
7. **History details**: viewing shows both texts (A-10); single results
   can be deleted and copied; a shorter period applies to results already
   kept.
8. **Cleanup limits**: 20 s timeout; transcripts over 4,000 characters
   are not cleaned up; an answer much longer than the transcript is
   discarded. Long dictations are out of scope for the first version.
9. **Hesitation filter** before the model, and the examples as
   conversation turns — both measured to help 0.8B.
10. **Cleanup on by default** when its model is present; switched in the
    settings; the language is detected by Parakeet, never chosen.
11. **ADR 0013** (capture, components and CLI in the package) and
    **ADR 0014** (hash checks of model files).
12. **App icon**: none yet; both apps use the system default.
    *Addendum 2026-10-23:* the user chose the "O with echo" icon; both
    apps build it from one Icon Composer document,
    `apps/shared/AppIcon.icon` (`docs/DESIGN.md` §"App icon").
13. **Launch at login** for the macOS app (ghost-pepper enables it by
    default): not built.
14. **ghost-pepper ideas** not built: screen (OCR) context, a correction
    store, learning from edits after a paste, an editable prompt.
15. **iOS distribution channel**: TestFlight or the App Store — not
    discussed yet (`docs/RELEASE.md` §"iOS").

## Open questions

Carried over from the concept (`plans/done/CONCEPT.md` §"Open
questions"); each now has a proposal in §"Decisions for the user":
signing and updates (1), acceptance criteria (6), the default hotkey (5),
the ghost-pepper ideas (14), the history's edges and A-10 (7), cleanup
switching and the language (10).
