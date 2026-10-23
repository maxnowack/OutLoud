# 0016 – The macOS app is signed with Developer ID of team 95ZC649QPM, notarised, and updated by Sparkle from GitHub releases

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0009 distributes the macOS app as a download from GitHub, outside the App Sandbox, and
left signing, notarisation and updates open. Gatekeeper warns about an app that is not signed
with a Developer ID and notarised by Apple. The user has an Apple Developer account and chose the team "Max Nowack"
(95ZC649QPM) and Sparkle on 2026-10-23.

Rejected alternatives: an update notice that only links to the GitHub release (less code,
but the user installs by hand), and no update mechanism at all.

## Decision

- Debug builds are signed with "Apple Development" of team 95ZC649QPM, Release builds with
  "Developer ID Application" of the same team, with the hardened runtime and a secure
  timestamp.
- Each release is notarised with `notarytool` and stapled.
- The app updates through Sparkle 2.10.0. Each GitHub release carries the zip and an
  `appcast.xml`; the app reads
  `https://github.com/maxnowack/OutLoud/releases/latest/download/appcast.xml`. Updates are
  signed with Sparkle's EdDSA key, whose public half is `SUPublicEDKey` in `Info.plist`.
- `apps/macos/scripts/release` performs the build; `docs/RELEASE.md` owns the procedure.

## Consequences

- A Developer ID Application certificate, a notarytool profile and Sparkle's key pair must
  exist on the releasing Mac (`docs/RELEASE.md`); none existed on 2026-10-23.
- Until `SUPublicEDKey` is set, the app does not start the updater.
- The stable development signature keeps the microphone and Accessibility permissions across
  rebuilds.
- Losing the EdDSA private key means existing installs can no longer verify updates.
