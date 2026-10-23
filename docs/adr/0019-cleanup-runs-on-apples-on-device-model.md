# 0019 – Outloud cleans up with Apple's on-device model (Foundation Models) on iOS and macOS; Qwen and llama.cpp are removed

- Status: accepted
- Date: 2026-10-23

## Context

The cleanup ran Qwen 3.5 0.8B or 4B with LLM.swift and its bundled llama.cpp on the GPU (ADR 0006,
ADR 0015). Measured on the user's iPhone 15 Pro and Mac on 2026-10-23
(`plans/BACKGROUND_DICTATION.md` §"Status"):

- An iOS app in the background may not use the GPU, so a dictation from another app (ADR 0018)
  could not be cleaned up; llama.cpp's backend stays failed after a refused run.
- On the CPU, Qwen 3.5 0.8B took 30–48 s for a ten-second dictation on the Mac and gave no result
  within four minutes on the iPhone — past the 20 s limit.

Apple's on-device model runs in a system process; an app may use it in the background within a
budget that Apple sets, tighter on battery. It needs no download. On the user's Mac it cleaned up
German and English test inputs in 1.5–4 s, applied a spoken correction and repeated an injected
instruction instead of following it (`plans/APPLE_CLEANUP.md`).

Rejected alternatives:

- Qwen as a further choice next to Apple's model: the user decided against it; it keeps a
  download of 0.5–2.7 GB, a dependency with a bundled llama.cpp, and the gap in the background.
- Qwen on the CPU in the background: too slow (above).

## Decision

We clean up with Apple's on-device model through the Foundation Models framework, on iOS and
macOS, also while the iOS app is in the background. The prompt keeps its rules, the worked
examples and the `<USER-INPUT>` framing; the hesitation filter, the timeout and the fallbacks to
the transcript stay. Cleanup is available where `SystemLanguageModel.default` is available;
otherwise, and when the model refuses — budget, language, guardrail — the transcript is the
result, and the app says so.

We remove Qwen from the catalogue, LLM.swift and llama.cpp from the package, the cleanup model
choice and download from the first launch and the settings, and the increased-memory-limit
entitlement that ADR 0015 added for the 4B model.

## Consequences

- Supersedes ADR 0015 and the cleanup part of ADR 0006; ADR 0005's models chosen and downloaded
  at first launch are now only the transcription model.
- Cleanup needs Apple Intelligence, switched on, on a device that supports it, and a language it
  supports; elsewhere Outloud delivers the transcript.
- The cleanup's quality and speed follow Apple's model and change with system updates; the
  prompt's test inputs are kept in `plans/APPLE_CLEANUP.md` to be run again.
- Qwen files already downloaded stay where they are: the macOS cache is shared with other tools
  (ADR 0010).
- The package has no macro dependency any more, and llama.cpp no longer has to be shut down at
  exit.
