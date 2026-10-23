# 0017 – The iOS app ships a widget extension with a "Dictate" control, so that the Action Button, the Control Center and the Lock Screen start a dictation without the Shortcuts app

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0003 starts a dictation on iOS from a shortcut, which the Action Button can run. Testing on
the user's iPhone 15 Pro on 2026-10-23, the user did not find Outloud in the Action Button's
settings: a shortcut is offered there only under "Shortcut", after iOS has indexed the app's
App Shortcuts, while "Controls" — the Action Button's other list, also used by the Control
Center and the Lock Screen — only lists controls that a widget extension provides.

Rejected alternative: only the App Shortcut and an explanation — it works, but each way of
starting needs the Shortcuts app, and the Action Button's Controls list stays empty.

## Decision

The iOS app embeds a widget extension, `OutloudWidgets` (`dev.nowack.outloud.widgets`), with
one control, "Dictate with Outloud", a `ControlWidgetButton` that runs `StartDictationIntent`.
The intent is compiled into the app and the extension (`apps/ios/Shared/`); the system runs it
in the app, which installs what it does at launch. The app explains every way of starting a
dictation — Action Button, Control Center, Lock Screen, Back Tap, Siri, Home Screen — with
steps and trade-offs.

## Consequences

- A second target in `apps/ios/project.yml`, signed automatically with the same team.
- The intent's behaviour lives in the app (`StartDictationIntent.start`), not in the extension.
- The exact settings paths in the explanation are written for iOS 27 and are checked on the
  user's iPhone.
