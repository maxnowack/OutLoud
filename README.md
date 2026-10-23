# Outloud

Outloud turns spoken thoughts into text that can be pasted — into
messages, e-mails and notes — on iOS and macOS:

- **iOS** — the Action Button or a shortcut starts a recording; Outloud
  transcribes it, optionally cleans it up, and puts the result on the
  clipboard for pasting into the target app.
- **macOS** — a menu bar app: hold a hotkey to talk, release it, and
  Outloud pastes the transcribed and optionally cleaned-up text into the
  active text field, or leaves it on the clipboard.

Transcription and cleanup run on the device. Outloud is open source,
without monetisation.

## Status

The first version is built for macOS and iOS but not yet released
(`plans/FIRST_VERSION.md` §"Status"): transcription and cleanup run on
the device, the apps cover the setup, dictation, the history and the
settings, in English and German. Signing, a run on a real iPhone and the
user's checks of the end-to-end plans are open
(`plans/FIRST_VERSION.md` §"Decisions for the user").

## Where to start

1. `AGENTS.md` — the working rules.
2. `docs/SPEC.md` — what the product does.
3. `docs/adr/README.md` — the decisions.
4. `plans/FIRST_VERSION.md` — the plan of the first version.
5. The area files of the units: `OutloudKit/AGENTS.md`,
   `apps/macos/AGENTS.md`, `apps/ios/AGENTS.md`.

## What is here

| Path | What it is |
| --- | --- |
| `AGENTS.md` | The repository-wide working rules, the map of rule files and the map of living documents. |
| `CLAUDE.md` | A pointer to `AGENTS.md`, for harnesses that read that name. |
| `LICENSE` | MIT. |
| `OutloudKit/` | The shared Swift package: models, downloads, transcription, cleanup, settings, history, the interface components, and the `outloud` developer CLI. |
| `apps/macos/` | The macOS menu bar app, with its end-to-end plans in `e2e/`; its Xcode project is generated from `project.yml`. |
| `apps/ios/` | The iOS app, with its end-to-end plans in `e2e/`; its Xcode project is generated from `project.yml`. |
| `docs/SPEC.md` | What the product does. |
| `docs/ARCHITECTURE.md` | Components, trust boundaries and data. |
| `docs/DESIGN.md` | The visual style: tokens, components, screens. |
| `docs/RELEASE.md` | Versioning, release and rollback (skeleton). |
| `docs/HORIZONTAL_SCALING.md` | The register of single-instance assumptions. |
| `docs/ARCHITECTURE_PRINCIPLES.md` | The technology-independent architectural rules. |
| `docs/RULE_WRITING.md` | How a rule is phrased and where it goes. |
| `docs/PROCESSES.md`, `docs/VERIFICATION.md`, `docs/COMMITS.md` | Situational working rules, read when `AGENTS.md` says so. |
| `docs/adr/` | Decision records with format and index. |
| `plans/` | Open plans and their index; `plans/done/` for finished ones. |

Each unit's full check is `./scripts/precommit`, run from the unit's
directory; the apps need XcodeGen (`brew install xcodegen`).

The structure and the rule documents come from the `agents-template`
repository (commit `3bdf7b1`), adopted on 2026-10-22.
