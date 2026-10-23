# iOS app working rules (`apps/ios/`)

These rules cover the iOS app: the App Intent behind the shortcut,
recording, the clipboard, the first launch, the settings and the history
(ADR 0003). Repository-wide rules — how to work, plan and ADR duties,
commit and staging discipline, the Swift conventions — live in the root
`AGENTS.md`; the architectural rules they specialise live in
`docs/ARCHITECTURE_PRINCIPLES.md`; the root file says when each is read.
`docs/SPEC.md` §"Dictation on iOS" and `plans/FIRST_VERSION.md` describe
this area — read them before making changes here.

## Toolchain

- **(MUST)** Generate the project with `xcodegen generate` from
  `apps/ios/` before building or opening it; `project.yml` is its only
  source (ADR 0011).
- **(MUST)** Build into `.build/DerivedData` (`-derivedDataPath`), as
  `./scripts/precommit` does. The shared DerivedData folder is used by
  the user's Xcode and by other sessions.
- `precommit` builds for the generic iOS Simulator without signing. A
  device build signs automatically with team 95ZC649QPM and needs
  `-allowProvisioningUpdates` and the team's account signed in to Xcode
  (`docs/RELEASE.md` §"iOS").
- `./scripts/release` uploads a build to TestFlight (ADR 0023). **(MUST)** A
  new use of a required-reason API — `UserDefaults`, file timestamps, disk
  space, system boot time and the others Apple lists — adds its reason to
  `Resources/PrivacyInfo.xcprivacy` in the same change set; App Store
  Connect refuses an upload without it.
- **(MUST)** Ask before running `./scripts/release` without `--export`: it
  uploads to App Store Connect.

## Verifying a change

- **(MUST)** Ask before booting or driving a simulator, and before
  installing on the user's device (`docs/VERIFICATION.md`).
- **(MUST)** State that a simulator run proves behaviour, not memory or
  speed: whether the models fit an iPhone is only shown on a device
  (ADR 0006). The cleanup needs Apple Intelligence, which a simulator may
  lack; launch with `-cleanupEnabled NO` to check the screens.
- Debug builds take `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` to
  dictate a file once at launch (the file must be inside the app's
  container; a relative path is read from its `tmp/`), and
  `-OutloudTab history|settings` to open a tab first. Settings can be set
  for one launch as arguments, e.g. `-hasCompletedSetup YES`. On the
  iPhone, `xcrun devicectl device copy to --domain-type appDataContainer
  --domain-identifier dev.nowack.outloud --source <wav> --destination
  tmp/<wav>` puts a file there, and `xcrun devicectl device process launch
  --console dev.nowack.outloud -- <arguments>` runs the app, with the device
  unlocked, and shows what it prints. `xcrun simctl io booted screenshot` captures
  the screen; the simulator shares its clipboard with the Mac, so read
  results from the history's `index.json`, not from the clipboard.

## Tests

- Logic belongs in `OutloudKit`, where it is tested; the app wires it to
  the system. The app has no unit-test target until it holds logic that
  cannot move into the package.

## End-to-end test plans

- **(MUST)** Every user-visible flow has a plan under `e2e/`, one file per
  flow, with `e2e/README.md` as the coverage index; the first screen
  ships with the first plan (`docs/ARCHITECTURE_PRINCIPLES.md`
  §"End-to-end test plans").

## Localisation

- **(MUST)** Every user-visible string of the app gets its German
  translation in `Resources/Localizable.xcstrings`, App Shortcut phrases in
  `Resources/AppShortcuts.xcstrings` and `Info.plist` texts in
  `Resources/InfoPlist.xcstrings`, in the same change set; see
  `OutloudKit/AGENTS.md` §"Localisation" for finding the keys.

## Security

- **(MUST)** Record only after the user's trigger — the shortcut or the
  in-app control — and put a result on the clipboard only when the user
  produced it (ADR 0003).

## Coding rules

- SwiftUI; the models live in the app's own container (ADR 0009).
- **(MUST NOT)** Write the clipboard, or open an exclusive audio session, on a path an App
  Intent reaches while the app is in the background. iOS ignores the clipboard there without
  an error (ADR 0018) and refuses an exclusive session; a recording from the background takes
  a session that mixes with other audio and a running Live Activity (ADR 0022). Return the
  text and let the shortcut copy it. Apple's on-device model may be used there; a refusal
  (`CleanerError.refused`, e.g. `rateLimited`) falls back to the transcript (ADR 0019).
