# 0010 – On macOS, Outloud stores its models in the Hugging Face hub cache, in the hub's own layout

- Status: accepted
- Date: 2026-10-22

## Context

Downloaded models go into a directory that other apps needing the same
models can reuse (`docs/SPEC.md` §"Models"). Since ADR 0009 the macOS app
runs outside the App Sandbox and can reach any such directory.

The one cross-tool convention in use is the Hugging Face hub cache:
`$HF_HUB_CACHE`, else `$HF_HOME/hub`, else `~/.cache/huggingface/hub`.
One folder per repository holds the files by hash in `blobs/` and per
revision as symlinks in `snapshots/<commit>/`; writers lock per file
under `.locks/`. huggingface_hub, transformers, mlx-lm, llama.cpp and the
Swift libraries swift-huggingface, mlx-swift-lm and mlx-audio-swift use
it. A model there is reused only by a tool that looks it up under the
same repository and revision (`plans/done/CONCEPT.md` §"Shared model storage:
what exists").

FluidAudio and LLM.swift, which run Outloud's two models (ADR 0006),
download into flat folders of their own by default; both take a
configurable path. Whether they load from a snapshot folder whose files
are symlinks is not verified.

The user confirmed the hub cache as the shared directory on 2026-10-22.

Rejected alternative: an app-private folder, as ghost-pepper keeps for
its Whisper and GGUF models — no other app finds the models there.

## Decision

On macOS, Outloud stores its models in the Hugging Face hub cache at the
path the hub's own tools resolve — `$HF_HUB_CACHE`, else `$HF_HOME/hub`,
else `~/.cache/huggingface/hub` — and in the hub's own layout, including
its per-file locks.

## Consequences

- A model another tool already downloaded under the same repository and
  revision does not have to be downloaded again, and other tools reuse
  Outloud's downloads.
- Outloud downloads in the hub's layout itself and hands the snapshot
  folder to FluidAudio and LLM.swift. That they load from it has to be
  shown before code builds on it (`plans/done/CONCEPT.md` §"Risks").
- Every process of the user can write to the cache; how Outloud verifies
  a model file before loading it is open (`docs/ARCHITECTURE.md`
  §"Model downloads").
- Deleting a model in Outloud's settings touches a cache other tools use
  (`plans/done/CONCEPT.md` §"Open questions").
- On iOS, models stay in the app's own container (ADR 0009).
