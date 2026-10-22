# 0003 – On iOS, a shortcut starts the input and the result reaches the target app through the clipboard; the first version ships no custom keyboard

- Status: accepted
- Date: 2026-10-22

## Context

The product concept of 2026-10-22 sets the iOS flow: the Action Button or
a shortcut starts the input, Outloud records, transcribes, optionally
cleans up, puts the result on the clipboard, and the user pastes it into
the target app.

iOS sets the limits. Custom keyboards have no microphone access
(https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard),
and Outloud cannot write into arbitrary other apps. The Action Button can
run a shortcut
(https://support.apple.com/en-gb/guide/shortcuts/apdfea15680b/ios); a
hold-and-release control is not assumed.

Not in the first version: a custom keyboard. The concept lists it among
the things that stay outside the first version.

## Decision

On iOS, the input starts from a shortcut, which the Action Button can
run. Outloud records, transcribes, optionally cleans up and puts the
result on the clipboard; the user pastes it. Outloud also accepts text
that system dictation supplies — through "Dictate Text" in the shortcut,
or in Outloud's own text field — and continues with cleanup and the
clipboard.

The first version ships no custom keyboard.

## Consequences

- Every use ends with one paste by hand in the target app.
- Recording and the shortcut need the matching permissions; the lock
  screen and switching apps can require extra steps.
- How the shortcut reaches Outloud is not decided (`plans/done/CONCEPT.md`,
  assumption A-3).
