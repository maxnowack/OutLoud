# The iOS app gets its App Store listing: copy, screenshots and the submission sheet

## Status

Done on 2026-11-02. The submission sheet and both listings are written
and pass `check-listing.mjs`; the 12 captures and the 16 rendered images
exist, and the user approved the images on 2026-11-02. Price, countries
and the age rating remain the user's answers in App Store Connect
(`marketing/STORE_SUBMISSION.md`).

Deviation, 2026-11-02, at the user's request: the iOS 27 simulator offers
no Apple Intelligence, so the cleanup's text comes from a Debug-only
stand-in cleaner (`-OutloudCleanupStandIn`, ADR 0032). Everything else on
the screens is the app's own output.

Blocked on 2026-11-01: no iOS 27 simulator runtime works on this Mac.
Installed iOS 27.0, 27.1 and 27.2 runtimes show as "Ready" in
`simctl runtime list`, but CoreSimulator never registers them
("runtime profile not found"; the signature state stays "Unknown"). A
reboot, restarting the service and downloading 27.2 again did not help,
and the same problem is reported elsewhere for Xcode 27. Ways tried and
ruled out:

- iOS 26.5: the app does not build, because `LanguageModelError` needs
  iOS 27, and ADR 0012 rules out availability checks.
- "Designed for iPhone" on the Mac: the build signs once this Mac is
  registered in the team (done 2026-11-01), but outside Xcode the app
  does not launch (LaunchServices -10670, lldb), and UI tests are not
  supported there.
- The user's iPhone: declined by the user.

Unblocked on 2026-11-02. CoreSimulator only registers runtimes mounted
as plain disk images; it never looks at the cryptex mounts Xcode 27.2
installs. Installing iOS 27.2 as a disk image works with no Xcode update;
the steps are in `marketing/store-screenshots/README.md`.

## Problem

Outloud for iPhone is in TestFlight (0.1.0 (6), `docs/RELEASE.md` §"iOS")
and has nothing for an App Store submission: no listing copy, no
screenshots, no record of the answers App Store Connect asks for. The
review simulation of 2026-11-01
(`docs/app-review/2026-11-01-app-store-review.md`) adds review notes that
have to go somewhere they are kept.

## Goal

- `marketing/STORE_SUBMISSION.md` holds everything about the submission
  that does not depend on the listing language: field limits, category,
  price, age rating, privacy labels, the review notes, the keyword method,
  and the decisions still owed to App Store Connect.
- `marketing/STORE_LISTING_EN.md` and `marketing/STORE_LISTING_DE.md` hold
  the field copy for en-US and de-DE, within every limit, each claim
  covered by `docs/SPEC.md`.
- `marketing/store-screenshots/` produces, from captures of the real app
  and with one command each, the 6.9" iPhone screenshots (1290 × 2796),
  the product page header (3840 × 1646) and the search results image
  (3840 × 2560) for both locales, and the user has approved them.

## Approach

The structure follows CatchFlights (`~/code/CatchFlights/marketing/`),
which has been through App Store review: one language-independent
submission document, one listing per locale, and a screenshot pipeline
that captures the real app in a fresh simulator and frames the captures
with HTML rendered by Puppeteer.

- **Captures.** A Debug build in a new simulator per locale, set up by
  `capture.mjs`: language and region, appearance, status bar
  (`simctl status_bar override`), `-hasCompletedSetup`, the models copied
  in rather than downloaded, and real dictations from sample recordings
  through `-OutloudSampleAudio`, so that the history and the result are
  real output of the app, not retouched. Nothing on a screenshot claims
  what the app does not do.
- **Renderer.** Node with Puppeteer, its versions pinned exactly in
  `marketing/package.json` (ADR 0032). Rejected: rendering with SwiftUI's
  `ImageRenderer` and the OutloudUI tokens, which needs no new toolchain
  but leaves the device frame and the type setting to be built from
  nothing, while CatchFlights' renderer is proven and can be adapted.
- **Look.** Colours and type from `docs/DESIGN.md` §"Tokens"; the copy
  per screen lives in `copy.json`.
- **Scope.** iOS only: the Mac app ships through GitHub and Sparkle. No
  6.5" and no iPhone Duo set, since both are optional; the Live Activity
  is not captured, because the simulator cannot show it reliably.

## Phases

### 1. Submission sheet

DoD: `marketing/STORE_SUBMISSION.md` names every field App Store Connect
asks for on a first submission, with its value or marked as a decision
for the user; the review notes from the review simulation are in it.

### 2. Listing copy

DoD: both listings have name, subtitle, promotional text, description,
keywords and "What's New", each with its character count under the
limit; every claim traces to `docs/SPEC.md`.

### 3. Captures

DoD: `node marketing/store-screenshots/capture.mjs` creates the
simulators, captures every screen in both locales at 1320 × 2868 or the
6.9" device's native size, and deletes the simulators; the raw captures are
in `marketing/store-screenshots/source/<locale>/`.

### 4. Renderer

DoD: `node marketing/store-screenshots/generate.mjs` writes
`out/<format>/<locale>/` deterministically; the sizes are checked by the
script; the user approved the images.

### 5. Documentation

DoD: ADR 0032 for the Node toolchain; `marketing/store-screenshots/README.md`
describes formats, capture and regeneration; `README.md` points at
`marketing/`; `docs/RELEASE.md` §"iOS" names the listing and the
screenshots as steps of a first App Store release.

## Risks

- The simulator may lack Apple Intelligence, so the cleaned results could
  not be produced there. Mitigation: capture on a host that has it, or
  show results whose cleanup is visible in the history detail produced
  on the device; the screenshot never shows a cleaned text the app did not
  produce.
- Apple's required screenshot sizes change; verify against App Store
  Connect before uploading.

## Open questions

- Price (assumed free), countries, and the age rating questionnaire —
  answered in App Store Connect by the user.
