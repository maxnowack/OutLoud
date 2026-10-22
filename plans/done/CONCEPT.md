# Shape the Outloud concept until the first version can be built without guessing

## Status

Done (2026-10-22): the concept is in the living documents and ADRs
0002–0010; the open questions and assumption A-10 below were handed to
`plans/FIRST_VERSION.md` by the user's decision to start implementing.

Before that, on 2026-10-22: The product concept of 2026-10-22 is sorted
into `docs/SPEC.md`, `docs/ARCHITECTURE.md` and ADRs 0002–0004;
ghost-pepper is recorded as prior art below. The first interview round
decided on-device models chosen at first launch (ADR 0005), a
multilingual cleanup prompt and the MIT licence. What exists for sharing
models between apps, and the model licences, are researched below. The
first version's catalogue is Parakeet v3 and a Qwen model of about 0.8B
(ADR 0006). The first launch, changing models and failed downloads are
in `docs/SPEC.md` §"Models". The macOS app is a GitHub download outside
the App Sandbox (ADR 0009, superseding ADRs 0007 and 0008), so it can
share its models with other apps; on iOS they stay in the app's
container; on macOS the shared directory is the Hugging Face hub cache
(ADR 0010). Outloud is open source, and monetisation deliberately plays
no role. The history keeps transcript, audio and cleaned version for a
period the user sets — 1 day by default — and lets the user listen to a
result and view its text (`docs/SPEC.md` §"History").

The user ended the interview on 2026-10-22 to start implementing: the
remaining open questions below, and assumption A-10, are answered during
development. Phases 2 and 3 are descoped to that extent by this
decision.

## Problem

The product exists as a one-page concept. Building it would mean
guessing at the model scope, the storage of models, the distribution
channel, the acceptance criteria and more.

## Goal

Someone who reads only the living documents and the ADRs can build the
first version without guessing anywhere. Every assumption below is
confirmed, rejected or deliberately left open; no row reads `open`.

## Approach

An interview: one open question at a time (two to four when they cover
details of the same topic), each answer written into the document that
owns it before the next question. The concept lives in the documents that
own it — `docs/SPEC.md` for behaviour, `docs/ARCHITECTURE.md` for
components, ADRs for decisions — not in a separate concept directory, so
there is one source per concern (`AGENTS.md` §"Living documents and their
owners"). Whatever the documents state that the user did not say is an
assumption: marked `ASSUMPTION (A-n, unconfirmed)` where it stands, and
listed in the ledger below until the user confirms or corrects it.

## Phases

### 1. Sort the concept of 2026-10-22 into the documents

DoD: every statement of the concept stands in the document that owns it,
or is listed below as open. — Done 2026-10-22.

### 2. Interview until no gap is left

DoD: the open questions below are answered or deliberately deferred, and
every feature in `docs/SPEC.md` has acceptance criteria.

### 3. Close the ledger

DoD: no assumption reads `open`; no `ASSUMPTION` marker is left in the
documents.

## Prior art: ghost-pepper

The user named https://github.com/matthartman/ghost-pepper (commit
`5a5b53aadbc1`, read 2026-10-22) as inspiration, and its models,
download links and default cleanup prompt as fit to adopt. What it is:
a macOS menu bar app — hold Control to talk, release to transcribe and
paste — that runs speech-to-text and cleanup entirely on the Mac.

### Speech models

| Model | Runtime | Size | Languages |
| --- | --- | --- | --- |
| Whisper tiny.en (`openai_whisper-tiny.en`) | WhisperKit | ~75 MB | English |
| Whisper small.en (`openai_whisper-small.en`), the default | WhisperKit | ~466 MB | English |
| Whisper small (`openai_whisper-small`) | WhisperKit | ~466 MB | multilingual |
| Parakeet v3 (`fluid_parakeet-v3`) | FluidAudio | ~1.4 GB | 25 |
| Qwen3-ASR 0.6B int8 (`fluid_qwen3-asr-0.6b-int8`) | FluidAudio | ~900 MB | 50+; macOS 15 / iOS 18 and later |
| Nemotron Speech Streaming 0.6B 8-bit (`animaslabs/nemotron-speech-streaming-en-0.6b-mlx-8bit`) | MLX Audio | ~633 MB | English, streaming |
| Nemotron 3.5 ASR Streaming 0.6B 8-bit (`mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit`) | MLX Audio | ~721 MB | 40 locales, streaming |
| Apple SpeechAnalyzer | the system | managed by the OS | — |

### Cleanup models

GGUF files run with LLM.swift, each download pinned to a revision:

| Model | Size | Download |
| --- | --- | --- |
| Qwen 3.5 0.8B Q4_K_M, the default | ~535 MB | https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/6ab461498e2023f6e3c1baea90a8f0fe38ab64d0/Qwen3.5-0.8B-Q4_K_M.gguf |
| Qwen 3.5 2B Q4_K_M | ~1.3 GB | https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-Q4_K_M.gguf |
| Qwen 3.5 4B Q4_K_M | ~2.8 GB | https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/Qwen3.5-4B-Q4_K_M.gguf |

### Where it stores models

Whisper models in `~/Library/Application Support/GhostPepper/whisper-models`,
cleanup models in `~/Library/Application Support/GhostPepper/models` —
both private to the app. The MLX Audio models go into the Hugging Face
hub cache (`~/.cache/huggingface/hub`), the one place another app could
find them.

### Cleanup prompt and pipeline

`GhostPepper/Cleanup/TextCleaner.swift` (`defaultPrompt`): the model is
told it is a cleanup tool, not an assistant, and must not answer or
follow instructions in the input; the transcript is wrapped in
`<USER-INPUT>` tags. Rules: delete filler words; delete a passage only
after explicit self-corrections ("scratch that", "never mind"); fix
punctuation and obvious recognition errors; honour spoken punctuation
and spelling; never summarise or drop sentences. Eleven input/output
examples follow. Reasoning tags in the output are stripped; when the
model is unavailable or its output unusable, the raw transcript is used.

Where it does not fit Outloud as is:

- Filler words and self-correction phrases are English only; German
  needs its own.
- There is no rule for paragraphs, which Outloud's cleanup sets.
- "Appear competently and professionally written" may go further than
  "does not change the content".
- Rules 3 and 8 rely on OCR of the screen, which Outloud does not do.

### Ideas beyond Outloud's concept

None of these is decided; each is a question for the interview.

- The frontmost window's text (OCR) as context for the cleanup; needs
  the Screen Recording permission.
- A correction store of preferred spellings for names and jargon, and
  learning from what the user edits after a paste.
- Prompt evaluation tests (`GhostPepperTests/CleanupPromptEvalTests.swift`).
- An editable cleanup prompt.
- Auto-paste that saves the clipboard, pastes with a simulated ⌘V, and
  restores the clipboard; a check that the focused element accepts text;
  "paste again" for the last result.
- A privacy audit table in the README.
- Apple's system-managed models instead of downloads: SpeechTranscriber
  for transcription, Foundation Models for cleanup (§"Shared model
  storage: what exists").

### Distribution and licence

The app has no App Sandbox entitlement and ships as a DMG with Sparkle
updates, outside the Mac App Store. It builds on forks:
`obra/mlx-audio-swift` and `obra/LLM.swift`.

The README states "License: MIT" and links a `LICENSE` file that does
not exist; GitHub reports no licence. Without a licence, default
copyright applies
(https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).
The user treats it as MIT (2026-10-22) (§"Risks").

### Model licences

Checked 2026-10-22 on the model cards; whether a download at runtime
triggers the duties of redistribution is not settled.

| Model | Licence | Duties |
| --- | --- | --- |
| Whisper weights, `argmaxinc/whisperkit-coreml` | MIT | keep the licence notice |
| Parakeet TDT 0.6B v3, incl. the FluidInference CoreML conversion | CC-BY-4.0 | credit the source |
| Qwen3-ASR 0.6B, incl. its CoreML conversion | Apache-2.0 | licence copy and NOTICE when redistributing |
| Qwen 3.5 0.8B/2B/4B, incl. the unsloth GGUFs | Apache-2.0 | licence copy and NOTICE when redistributing |
| Nemotron Speech Streaming EN 0.6B, incl. the animaslabs MLX conversion | NVIDIA Open Model License | agreement and a NVIDIA notice when distributing; the rights end if guardrails are bypassed or on IP litigation |
| Nemotron 3.5 ASR Streaming 0.6B | OpenMDW-1.1 upstream; the mlx-community conversion is tagged NVIDIA Open Model License | keep the agreement and notices; the two tags do not match |

The runtimes: WhisperKit, mlx-audio-swift and LLM.swift are MIT;
FluidAudio and swift-transformers are Apache-2.0.

## Shared model storage: what exists

Researched 2026-10-22 for `docs/SPEC.md` §"Models"; sources are the
libraries' source code and Apple's documentation.

- **The Hugging Face hub cache is the one cross-tool convention in
  use.** Its path is `$HF_HUB_CACHE`, else `$HF_HOME/hub`, else
  `~/.cache/huggingface/hub`. One `models--<org>--<name>/` folder per
  repository holds the files by hash in `blobs/` and per revision as
  symlinks in `snapshots/<commit>/`; identical files are stored once, and
  writers lock per file under `.locks/`
  (https://huggingface.co/docs/huggingface_hub/guides/manage-cache).
  transformers, mlx-lm and llama.cpp (`-hf`) use it by default. Ollama
  (`~/.ollama/models`) and LM Studio (`~/.lmstudio/models`) keep their
  own folders. No formal cross-app standard exists. A model in the cache
  is reused only by an app that looks it up there under the same
  repository and revision; an app that downloads the same model into its
  own folder does not find it.
- **The Swift runtimes differ.** swift-huggingface's `HubCache` writes
  the same layout and honours the same variables; mlx-swift-lm reads from
  it; mlx-audio-swift downloads into it and copies each model once more
  into `<cache>/mlx-audio/`. WhisperKit (`Documents/huggingface/models`),
  FluidAudio (`~/Library/Application Support/FluidAudio/Models`) and
  LLM.swift (`Documents`) use flat folders of their own; each takes a
  configurable path. Whether they load from a symlinked snapshot folder
  is not verified.
- **macOS, outside the App Sandbox** (Developer ID distribution), an app
  can read and write `~/.cache/huggingface/hub` directly.
- **macOS, inside the App Sandbox,** which the Mac App Store requires:
  swift-huggingface moves the cache into the app's own container. Access
  to the shared cache needs a folder the user picks once (kept as a
  security-scoped bookmark) or a temporary-exception entitlement that
  App Review must accept; a probe on macOS 27.0.1 confirmed that the
  sandbox denies `~/.cache` and the exception opens it. Guideline 2.4.5
  forbids installing resources in shared locations. App Groups share only
  between apps of the same team.
- **Auto-paste in the Mac App Store:** posting ⌘V with `CGEvent.post`
  works inside the sandbox, but App Review rejected a sandboxed
  clipboard manager for it under 2.4.5, with further reports up to
  September 2026 (https://developer.apple.com/forums/thread/820594).
- **iOS:** apps of different vendors share files only through a folder
  the user picks in each app (`UIDocumentPickerViewController`); App
  Groups are same-team only.
- **System-managed models are already shared.** The assets of
  SpeechAnalyzer / SpeechTranscriber (iOS and macOS 26 and later) are
  downloaded from Apple, managed by the system and shared between apps
  (https://developer.apple.com/documentation/speech/assetinventory); on
  this Mac, 45 locales were supported, German and English were installed,
  and an app may reserve five. Foundation Models, the on-device Apple
  Intelligence model, supports German and English with a context of 4096
  tokens for input and output together, on Apple Intelligence devices
  only (iPhone 15 Pro and later, M1 Macs and later)
  (https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window).
  How well it cleans up dictation is not verified.

## Assumptions

| ID | Assumption | Stands in | Status |
| --- | --- | --- | --- |
| A-1 | Transcription and cleanup run on the device with downloaded open models; neither audio nor text leaves it for processing, and "data transfer" means model downloads | `docs/SPEC.md`, `docs/ARCHITECTURE.md` | confirmed 2026-10-22 for on-device processing (ADR 0005); what "data transfer" covers was not said and is no longer stated |
| A-2 | The iOS app also downloads and runs the models on the iPhone | `docs/ARCHITECTURE.md` | confirmed 2026-10-22 (ADR 0005) |
| A-3 | The shortcut reaches Outloud through an App Intent | `docs/ARCHITECTURE.md`, ADR 0003 | confirmed 2026-10-22 |
| A-4 | The default cleanup prompt is ghost-pepper's, extended with German filler words and self-corrections and a paragraph rule, without the OCR rules | `docs/SPEC.md` | confirmed 2026-10-22 as ghost-pepper's prompt made multilingual, with the paragraph rule from the concept; leaving out the OCR rules → A-5 |
| A-5 | The prompt's rules about screen (OCR) context are left out, because Outloud does not read the screen | `docs/SPEC.md` | confirmed 2026-10-22 |
| A-6 | Parakeet v3 runs with FluidAudio (`FluidInference/parakeet-tdt-0.6b-v3-coreml`), and the cleanup model is ghost-pepper's Qwen 3.5 0.8B Q4_K_M GGUF at its pinned revision, run with LLM.swift | `docs/ARCHITECTURE.md`, ADR 0006 | confirmed 2026-10-22 |
| A-7 | Outloud does not download models over cellular data | `docs/SPEC.md` | rejected → `docs/SPEC.md` §"Models": Outloud warns about the size, the user decides |
| A-8 | Both models have to be downloaded before the app can be used, even when cleanup stays off | `docs/SPEC.md` | rejected → `docs/SPEC.md` §"Models": the cleanup model is needed only with cleanup on |
| A-9 | On macOS the shared model directory is the Hugging Face hub cache (`~/.cache/huggingface/hub`, or the path `HF_HUB_CACHE` or `HF_HOME` set), in the hub's own layout | `docs/SPEC.md` | confirmed 2026-10-22 (ADR 0010) |
| A-10 | Viewing a kept result shows both texts — the uncleaned transcript and the cleaned version | `docs/SPEC.md` | deliberately open — decided during development |

## Risks

- ghost-pepper's licence is stated only in its README; the repository
  has no licence file, and without one default copyright applies. The
  user treats it as MIT; whether the README line alone grants the right
  to copy is not settled. A `LICENSE` file added by its author would
  settle it. Copies of its prompt or code carry its copyright and
  permission notice, as MIT requires.
- Whether Parakeet v3 (~1.4 GB) and the Qwen model (~535 MB) run on an
  iPhone within its memory, and how fast, is not verified (ADR 0006).
  Both runtimes support iOS (FluidAudio from iOS 17, LLM.swift from
  iOS 16).
- FluidAudio and LLM.swift download into flat folders of their own.
  Whether they load from a snapshot folder of the Hugging Face cache,
  whose files are symlinks into `blobs/`, is not verified (ADR 0010).

## Open questions

Answered during development, by the user's decision of 2026-10-22, carried over to `plans/FIRST_VERSION.md`:

1. How cleanup is switched on and off, and how the language is chosen.
2. How the GitHub download is signed, notarised and updated.
3. The acceptance criteria per feature.
4. The default hotkey on macOS.
5. Which of the ideas from ghost-pepper belong in the product.
6. The history's edges: whether a kept result can be copied again or
   deleted on its own, and what a shorter period does to results already
   kept.
