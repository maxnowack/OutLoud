# 0005 – Outloud transcribes and cleans up on the device, on iOS and macOS, with open models the user chooses and downloads at first launch

- Status: accepted; the first version's catalogue is narrowed by [0006](0006-parakeet-v3-and-a-small-qwen-model.md); the shared storage of models is settled by [0009](0009-macos-github-download-outside-the-sandbox.md); the cleanup model is no longer downloaded since [0019](0019-cleanup-runs-on-apples-on-device-model.md)
- Date: 2026-10-22

## Context

The product concept of 2026-10-22 named one transcription provider for
the first version. The same day, the user named ghost-pepper
(https://github.com/matthartman/ghost-pepper) as the model for Outloud's
models: a catalogue of open speech-to-text models and small language
models for cleanup, all running on the Mac, downloaded from Hugging Face
(`plans/done/CONCEPT.md` §"Prior art"). The user decided that the first
version needs local models for both transcription and cleanup, on iOS as
well as macOS, and that the models are chosen as in ghost-pepper.

Rejected alternative: one transcription provider, as the concept had it.
The user replaced it with local models chosen from a catalogue.

## Decision

Outloud transcribes and cleans up on the device, on iOS and on macOS,
with open models; neither audio nor text leaves the device for
processing. The catalogue starts from ghost-pepper's speech and cleanup
models and their download sources.

At first launch, the user sees which models are available, chooses
models, and starts the download. Once the download is finished, the app
can be used.

## Consequences

- The catalogue brings ghost-pepper's model runtimes as dependencies —
  WhisperKit, FluidAudio, MLX Audio and LLM.swift — each of which has to
  be checked for iOS support and for its licence.
- Whether every model in the catalogue runs on an iPhone — memory, size,
  runtime support — is not verified (`plans/done/CONCEPT.md` §"Risks").
- Several of ghost-pepper's speech models are English only, while the
  first version supports German and English.
- The app cannot be used before a download has finished.
- The models are stored where other apps can reuse them
  (`docs/SPEC.md` §"Models"); the directory is not decided.
