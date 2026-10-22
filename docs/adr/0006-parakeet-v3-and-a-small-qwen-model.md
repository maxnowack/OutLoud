# 0006 – The first version transcribes with Parakeet v3 and cleans up with a Qwen model of about 0.8B parameters

- Status: accepted
- Date: 2026-10-22

## Context

ADR 0005 starts Outloud's model catalogue from ghost-pepper's: eight
speech models on four runtimes and three Qwen cleanup models
(`plans/done/CONCEPT.md` §"Prior art"). Three of the speech models are English
only, while the first version supports German and English; the Nemotron
models carry the NVIDIA Open Model License with its termination clauses
(`plans/done/CONCEPT.md` §"Model licences").

On 2026-10-22 the user decided that Parakeet v3 and a Qwen model of
about 0.8B are enough for Outloud.

Parakeet TDT 0.6B v3 lists 25 languages on its model card, German and
English among them, under CC-BY-4.0
(https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3, read 2026-10-22).
ghost-pepper runs it with FluidAudio (~1.4 GB). Its smallest Qwen cleanup
model is Qwen 3.5 0.8B in a Q4_K_M GGUF (~535 MB), Apache-2.0.

Rejected alternative: ghost-pepper's full catalogue — more runtimes,
English-only models and a stricter licence, for no need the first
version has.

## Decision

The first version's catalogue holds one speech-to-text model, Parakeet
v3, and one cleanup model, a Qwen model of about 0.8B parameters.

## Consequences

- One model covers transcription in German and English.
- The other runtimes of ghost-pepper — WhisperKit and MLX Audio — are not
  needed, and neither are the Nemotron licences.
- Parakeet v3 requires crediting its source (CC-BY-4.0); the Qwen model
  carries Apache-2.0's licence and NOTICE duties.
- The download at first launch is about 2 GB if both models are
  chosen. Whether both run on an iPhone within its memory is not
  verified (`plans/done/CONCEPT.md` §"Risks").
- The exact cleanup model file and the runtimes are not decided
  (`plans/done/CONCEPT.md`, assumption A-6).
