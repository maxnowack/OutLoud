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
- The app runs outside the App Sandbox (ADR 0009) and is signed ad hoc
  for local builds; the signing of the GitHub download is open
  (`plans/FIRST_VERSION.md` §"Open questions").

## Verifying a change

- **(MUST)** Ask before launching the app to verify a change. It sits in
  the user's menu bar, registers a global hotkey, records from the
  microphone and, with Accessibility access, types into the user's other
  apps (`docs/VERIFICATION.md`).
- **(MUST)** Quit every instance you launched when you are done, also
  after a failure. Two instances both register the hotkey, and a
  leftover one keeps the microphone permission in use.

## Tests

- Logic belongs in `OutloudKit`, where it is tested; the app wires it to
  the system. The app has no unit-test target until it holds logic that
  cannot move into the package.

## End-to-end test plans

- **(MUST)** Every user-visible flow has a plan under `e2e/`, one file per
  flow, with `e2e/README.md` as the coverage index; the first screen
  ships with the first plan (`docs/ARCHITECTURE_PRINCIPLES.md`
  §"End-to-end test plans").

## Security

- **(MUST)** Record only while the hotkey is held, and post keystrokes
  only to paste a result after the hotkey was released (ADR 0004). The
  app holds the microphone and Accessibility access outside a sandbox;
  any other use of them acts in the user's name without their action.

## Coding rules

- SwiftUI; the menu bar is a `MenuBarExtra`, and the app has no Dock icon
  (`LSUIElement`).
