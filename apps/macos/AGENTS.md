# macOS app working rules (`apps/macos/`)

These rules cover the macOS menu bar app: the push-to-talk hotkey,
recording, auto-paste, the first launch, the settings and the history
(ADR 0004, ADR 0009). Repository-wide rules — how to work, plan and ADR
duties, commit and staging discipline, the Swift conventions — live in
the root `AGENTS.md`; the architectural rules they specialise live in
`docs/ARCHITECTURE_PRINCIPLES.md`; the root file says when each is read.
`docs/SPEC.md` §"Dictation on macOS" and `plans/FIRST_VERSION.md`
describe this area — read them before making changes here.

## Toolchain

- **(MUST)** Generate the project with `xcodegen generate` from
  `apps/macos/` before building or opening it; `project.yml` is its only
  source (ADR 0011).
- **(MUST)** Build into `.build/DerivedData` (`-derivedDataPath`), as
  `./scripts/precommit` does. The shared DerivedData folder is used by
  the user's Xcode and by other sessions.
- The app runs outside the App Sandbox (ADR 0009). Debug builds are
  signed with "Apple Development" of team 95ZC649QPM, so the microphone
  and Accessibility permissions survive rebuilds; `./scripts/release`
  builds the Developer ID, notarised download with its Sparkle appcast
  (ADR 0016, `docs/RELEASE.md`).

## Verifying a change

- **(MUST)** Ask before launching the app to verify a change. It sits in
  the user's menu bar, registers a global hotkey, records from the
  microphone and, with Accessibility access, types into the user's other
  apps (`docs/VERIFICATION.md`).
- **(MUST)** Quit every instance you launched when you are done, also
  after a failure. Two instances both register the hotkey, and a
  leftover one keeps the microphone permission in use.
- Debug builds take `-OutloudSampleAudio <wav> -OutloudAutoDictate YES`
  to dictate a file once at launch instead of the microphone, and
  `-OutloudQuitAfterAutoDictate YES` to quit afterwards; the result lands
  on the clipboard (`pbpaste`) and in the history. This runs the whole
  pipeline without the microphone and Accessibility permissions, which an
  agent cannot grant. It writes the user's clipboard and history, so save
  and restore the clipboard and delete the test entries afterwards.
- The first launch of a newly built app takes up to a minute before the
  first dictation: CoreML prepares the transcription model for it. Later
  launches load it in about a second (`plans/FIRST_VERSION.md`
  §"Status").

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
  translation in `Resources/Localizable.xcstrings` (and
  `InfoPlist.xcstrings` for `Info.plist` texts) in the same change set;
  see `OutloudKit/AGENTS.md` §"Localisation" for finding the keys.

## Security

- **(MUST)** Record only while the hotkey is held, and post keystrokes
  only to paste a result after the hotkey was released, into an element
  that takes text and is not a password field (ADR 0004). The app holds
  the microphone and Accessibility access outside a sandbox; any other
  use of them acts in the user's name without their action.
- **(MUST)** Paste a dictation that follows its field only into the field
  it was recorded in — or, for one started in a field that already had
  one, the next other field focused —, while its app is in front and that
  field — element and identity — has the focus; never activate an app and
  post no key but ⌘V (ADR 0026, ADR 0027). A paste on a looser match lands
  the user's words in another conversation.

## Coding rules

- SwiftUI; the app has no Dock icon (`LSUIElement`). The menu bar icon is
  an AppKit status item (`Sources/StatusItem.swift`) with the SwiftUI panel
  in a popover: `MenuBarExtra` cannot tell a click from a right-click, and
  the right-click opens the menu (`docs/DESIGN.md` §"Screens").
