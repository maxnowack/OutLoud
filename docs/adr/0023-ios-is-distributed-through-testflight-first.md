# 0023 – The iOS app is distributed through TestFlight first; the App Store is decided later

- Status: accepted
- Date: 2026-10-23

## Context

The iOS app ran only as a development build installed on the user's iPhone by cable; its
distribution channel was open (`plans/FIRST_VERSION.md` §"Decisions for the user" item 15). The
user asked how to get it into TestFlight and created the app record `dev.nowack.outloud` in App
Store Connect on 2026-10-23.

Rejected alternatives:

- The App Store right away: it needs the App Store listing, screenshots, the privacy
  questionnaire and App Review, before the app has had testers beyond its author.
- Ad hoc builds: limited to registered devices and expiring with their profile.

## Decision

We distribute the iOS app through TestFlight, internal testing first. `apps/ios/scripts/release`
archives the Release build, signs it for App Store distribution with automatic signing of team
95ZC649QPM and uploads it with the account signed in to Xcode. The app declares that it uses no
non-exempt encryption (it only uses HTTPS) and ships a privacy manifest that declares no
tracking, no collected data and the reasons for the required-reason APIs it uses. The App Store
is a later decision.

## Consequences

- Every upload needs a build number higher than the last one of its version; it is raised by
  hand in `apps/ios/project.yml`.
- External testers would need Beta App Review, with a description and a contact.
- A new use of a required-reason API needs its reason in `apps/ios/Resources/PrivacyInfo.xcprivacy`
  in the same change set, or App Store Connect refuses the upload.
