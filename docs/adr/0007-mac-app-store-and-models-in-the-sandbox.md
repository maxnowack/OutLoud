# 0007 – Outloud for macOS is built for the App Sandbox to go into the Mac App Store; its models stay in its own container where no shared location is open to it

- Status: superseded by [0009](0009-macos-github-download-outside-the-sandbox.md)
- Date: 2026-10-22

## Context

The user requires that downloaded models go into a directory that other
apps needing the same models can reuse (`docs/SPEC.md` §"Models"). The
one cross-tool convention for this is the Hugging Face hub cache,
`~/.cache/huggingface/hub` (`plans/done/CONCEPT.md` §"Shared model storage:
what exists").

The Mac App Store requires the App Sandbox. Inside it, `~/.cache` is
denied — a probe on macOS 27.0.1 confirmed it on 2026-10-22 — and the
Swift Hugging Face library moves its cache into the app's own container.
A shared location stays reachable only through a folder the user picks,
or through a temporary-exception entitlement that App Review has to
accept; Guideline 2.4.5 forbids installing resources in shared
locations. Outside the sandbox, with Developer ID distribution as
ghost-pepper does it, the cache is directly usable.

On 2026-10-22 the user decided that the Mac App Store is worth more than
the shared directory: if no shared location is available, the models
land in Outloud's own sandbox container.

Rejected alternative: Developer ID distribution outside the sandbox for
the sake of the shared cache.

## Decision

We build Outloud for macOS for the App Sandbox, so that it can be
distributed through the Mac App Store. Outloud stores its models in a
location shared with other apps only where the sandbox allows it;
otherwise it stores them in its own container.

## Consequences

- The requirement of a shared model directory yields to the sandbox:
  other apps may not find Outloud's models, and Outloud may download
  models another app already has.
- Whether Outloud offers a shared location inside the sandbox — a folder
  the user picks — is open (`plans/done/CONCEPT.md` §"Open questions").
- Auto-paste (ADR 0004) has to pass App Review in the sandbox. App Review
  has rejected a sandboxed app for posting ⌘V under Guideline 2.4.5
  (`plans/done/CONCEPT.md` §"Risks").
- On iOS, models stay in the app's own container as well; apps of
  different vendors share files there only through a folder the user
  picks.
