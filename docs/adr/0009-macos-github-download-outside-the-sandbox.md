# 0009 – Outloud for macOS is downloaded from GitHub and runs outside the App Sandbox; the Mac App Store is not pursued

- Status: accepted
- Date: 2026-10-22

## Context

ADR 0007 built the macOS app for the App Sandbox to go into the Mac App
Store, with the models in the app's own container where no shared
location is open. ADR 0008 made a GitHub download the fallback if App
Review rejects auto-paste, which it has done for a comparable app under
Guideline 2.4.5 (https://developer.apple.com/forums/thread/820594).

The sandbox decides at build time where the models live: inside it, the
shared Hugging Face cache (`~/.cache/huggingface/hub`) is denied, and
models land in the app's container. Outside it, the cache is directly
usable (`plans/done/CONCEPT.md` §"Shared model storage: what exists").

Asked on 2026-10-22 whether the macOS app is first submitted to the Mac
App Store or goes straight to the GitHub download, the user chose the
GitHub download without the sandbox.

Rejected alternative: the Mac App Store with the sandbox (ADR 0007),
which costs the shared model directory and puts auto-paste under App
Review.

## Decision

We distribute Outloud for macOS as a download from GitHub. The app runs
outside the App Sandbox. We do not submit it to the Mac App Store.

## Consequences

- Auto-paste is not subject to App Review.
- The macOS app can keep its models in a directory that other apps
  reuse (`docs/SPEC.md` §"Models").
- Without the sandbox, the app runs with all of the user's file access;
  Accessibility access for auto-paste comes on top of it.
- How the download is signed, notarised and updated is open
  (`plans/done/CONCEPT.md` §"Open questions").
- iOS is unaffected: there, apps run sandboxed and apps of different
  vendors share files only through a folder the user picks, so the
  models stay in the app's own container, as the user set on 2026-10-22
  for the case that no shared location exists.
