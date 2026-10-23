# 0015 – The catalogue also offers Qwen 3.5 4B as a second, optional cleanup model

- Status: superseded by [0019](0019-cleanup-runs-on-apples-on-device-model.md)
- Date: 2026-10-23

## Context

ADR 0006 gave the first version one cleanup model of about 0.8B parameters. Measured on
2026-10-22 on an M1 Pro (`plans/FIRST_VERSION.md` §"Status", phase 1), Qwen 3.5 0.8B removes
fillers and punctuates in about 1.2 s but applies neither "scratch that" nor "streich das";
Qwen 3.5 4B handled both samples correctly, including the corrections, in about 4 s, at
2.7 GB. On 2026-10-23 the user decided to offer the 4B model for download too.

Rejected alternative: replacing 0.8B with 4B — four times the wait and five times the
download for every user, also for those who only need punctuation.

## Decision

The catalogue holds two cleanup models: Qwen 3.5 0.8B, the default, and Qwen 3.5 4B
(`unsloth/Qwen3.5-4B-GGUF`, Q4_K_M, pinned revision and hash), both run by LLM.swift. The
user chooses one at first launch and can change it in the settings; only the chosen one
must be downloaded.

## Consequences

- The model selection in setup and settings shows a choice between the two.
- Whether 4B fits an iPhone's memory together with Parakeet is not verified; the iOS app
  requests the increased memory limit.
- Attribution: Apache License 2.0, like 0.8B.
