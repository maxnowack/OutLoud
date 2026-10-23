# Release

This document owns how each unit is versioned, released and rolled back,
and the release checklist. It describes the procedure; the rules it
satisfies are in `docs/ARCHITECTURE_PRINCIPLES.md` §"Release and
versioning". A release is performed by following this document, and a step
it lacks is added in the release that needed it.

## Versioning

- **The apps** expose no API; a version is what users install. Both apps
  carry `MARKETING_VERSION` (semantic version, e.g. `0.1.0`) and
  `CURRENT_PROJECT_VERSION` (a build number, raised with every build that
  is handed out) in their `project.yml`, bumped by hand in a commit of its
  own. A macOS release is tagged `v<MARKETING_VERSION>`.
- **OutloudKit** is internal to this repository and is not versioned
  separately. Its persistence formats (`docs/ARCHITECTURE.md` §"Contracts")
  change additively; a change that existing history or caches cannot read
  is a breaking change for both apps.

## Review

A single-person project: the person releasing reviews the diff since the
last tag against the plan's Definitions of Done, the living documents and
the ADRs before tagging. The checks of `AGENTS.md` §"Before reporting done"
stand in for a second reviewer.

## Release procedure

### macOS — the GitHub download (ADR 0009, ADR 0016)

Once per Mac:

1. In Xcode › Settings › Accounts › team "Max Nowack" › Manage
   Certificates, add a **Developer ID Application** certificate.
2. Store notarisation credentials:
   `xcrun notarytool store-credentials outloud-notary --apple-id <Apple ID> --team-id 95ZC649QPM`
   (asks for an app-specific password from appleid.apple.com).
3. Create Sparkle's key pair, after one build of the app (so that the
   package is resolved):
   `apps/macos/.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys`.
   It keeps the private key in the login keychain and prints the public
   key; put that into `apps/macos/project.yml` as `SUPublicEDKey` under
   `info.properties`. Back up the private key
   (`generate_keys -x <file>`) somewhere safe: without it, no installed
   app accepts another update.

Each release:

1. Bump the versions in `apps/macos/project.yml`, commit.
2. From `apps/macos/`: `./scripts/precommit`, then `./scripts/release`.
   It archives, signs with Developer ID, notarises, staples, zips and
   writes `appcast.xml` into `apps/macos/.build/release/updates/`.
3. Verify: `spctl --assess --type execute -v .build/release/export/Outloud.app`
   reports "accepted, source=Notarized Developer ID"; the app launches.
4. Tag `v<version>`, push the tag, create the GitHub release and attach
   `Outloud-<version>.zip` and `appcast.xml`.
5. Check: the previous version finds the update via "Check for Updates…".

### iOS — TestFlight (ADR 0023)

Once:

1. The app record `dev.nowack.outloud` in App Store Connect — created on
   2026-10-23 — and an internal testing group with the testers.
2. The team's account signed in to Xcode (Settings › Accounts); automatic
   signing creates the distribution certificate and profiles on the first
   upload.
   Without an account signed in to Xcode, an App Store Connect API key does
   the same: create one under Users and Access ›
   Integrations with the role Admin, keep the `.p8` file outside the
   repository, and set `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` for
   `./scripts/release` — or, with the key in a keychain item instead of a
   file, `ASC_KEY_KEYCHAIN_ITEM` (its name) in place of `ASC_KEY_PATH`. For example:
   `ASC_KEY_ID=<key id> ASC_ISSUER_ID=<issuer id> ASC_KEY_KEYCHAIN_ITEM=<item name> ./scripts/release`.
   The role matters: signing for distribution uses cloud-managed
   certificates and profiles, which only an Admin key may use. A key with
   a lesser role (App Manager, tried 2026-10-23) is refused access to
   certificates (403) and the export fails with "Cloud signing permission
   error", even with an Apple Distribution certificate in the keychain. Without an Admin key, the upload goes through Xcode:
   Product › Archive, then Distribute App › App Store Connect › Upload.

Each build:

1. Raise `CURRENT_PROJECT_VERSION` in `apps/ios/project.yml` (and
   `MARKETING_VERSION` for a new version), commit.
2. From `apps/ios/`: `./scripts/precommit`, then `./scripts/release`. It
   archives the Release build and uploads it to App Store Connect;
   `./scripts/release --export` writes the `.ipa` to
   `.build/release/export/` instead.
3. Once App Store Connect has processed the build, add it to the testing
   group in TestFlight.

The app declares `ITSAppUsesNonExemptEncryption = NO` and ships
`Resources/PrivacyInfo.xcprivacy`; a new use of a required-reason API
adds its reason there.

Builds for the user's iPhone by cable: from `apps/ios/`,
`xcodebuild -project Outloud.xcodeproj -scheme Outloud -destination 'id=<device id>' -derivedDataPath .build/DeviceData -allowProvisioningUpdates build`,
then `xcrun devicectl device install app --device <device id> .build/DeviceData/Build/Products/Debug-iphoneos/Outloud.app`.

## Rollback procedure

### macOS

1. Delete the faulty GitHub release, or edit the latest release's
   `appcast.xml` to list the previous version only; Sparkle never
   downgrades, so users who installed the faulty version get a fixed
   version as a new, higher one.
2. Users can install any earlier zip from the releases page by hand.

Not performed yet.

## Release checklist

1. Every end-to-end test plan in every unit's `e2e/` executed, outcomes
   recorded.
2. The changelog written or generated, and read.
3. The version bumped per the rules above; a breaking change coordinated
   with every caller.
4. The rollback procedure confirmed to apply to this release.
5. macOS: the download is notarised (`spctl` above) and its appcast
   entry is signed.
