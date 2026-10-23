# Polish what the user's tests on 2026-10-23 asked for: the ⌥ ⌘ rules, cleanup progress, the pill, the icon, a subtler shortcut

## Status

Built (2026-10-23) except the icon and the shortcut link: the ⌥ ⌘ rules
(ADR 0021), the cleanup progress, the Liquid Glass pill and the Dictate Text
variant are in; `./scripts/precommit` passes in all three units; the Mac
app dictated the German sample correctly through the debug seam in 2.7–4.3 s
with the progress streamed (no slowdown measured), and the build is on the
user's iPhone. Not checked: the chord rules and the pill by eye (they need
the user), the progress bar on the iPhone.

The icon: the user first chose to keep the dark appearance dark and match
its hue; they then clarified that the light appearance differs from the
record button. Both are `#1F7A70` — the button's fill, and the rendered
icon's background, measured with `ictool` — so the difference arises on
the Home Screen; the dark change was reverted. The user's screenshots
showed it: the Home Screen icon in its light appearance (#1E7A70) beside
the app in its dark appearance, where the record button took the dark
accent (#4EC0B1). Filled surfaces with white content now take
`accentFill`, #1F7A70 in both appearances — the icon's colour, and white
on it keeps 5.1:1 where white on #4CC2B2 gave about 2:1.

## Problem

- macOS: any key pressed while ⌥ ⌘ is held cancels the recording, so typing
  during a dictation loses it; another modifier added to ⌥ ⌘ (⇧, ⌃) ends the
  chord like a release and dictates (`apps/macos/Sources/Hotkey.swift`).
- The cleanup takes 2–4 s with no sign of how long is left.
- The macOS recording overlay is a fixed 320 × 64 pt panel, wider than its
  text, on a plain material.
- The iOS icon's dark appearance is almost black (#0E1C1A), not the app's
  colour.
- The "Record Audio" shortcut shows the Shortcuts app's full-screen
  recording view; Outloud cannot change it, and cannot record in the
  background itself (ADR 0018).
- The shortcut has to be built by hand.

## Goal

1. Another modifier added to ⌥ ⌘ cancels the recording at any time; another
   key cancels it within the first second (a shortcut such as ⌥ ⌘ D); after
   that a key is typed as usual and the recording goes on.
2. While the cleanup runs after a dictation in the app (macOS hotkey, iOS
   record button), a progress bar shows roughly how far it is.
3. The overlay is a capsule as wide as its content, in Liquid Glass.
4. The icon looks like the app's colour on the Home Screen.
5. A dictation from another app leaves the screen in view — solved by the
   background dictation of ADR 0022; the "Dictate Text" variant was built
   and then removed, since the user rejected Apple's speech recognition.
6. Offering the shortcut from the app: an iCloud link the user shares.

## Approach

- **Progress**: the cleaned text is about as long as the transcript, so the
  share of it streamed so far — capped below 100 % — estimates the
  progress. Streaming is used only where the progress is shown: Apple's
  model budget in the background runs out sooner when an app streams.
  `Cleaning` gets a variant with a progress callback; the controller
  publishes `cleanupProgress` on the recording path.
- **Pill**: the panel takes its content's size (`NSHostingController` with
  `sizingOptions`), recentres when it changes, and draws `glassEffect` in a
  capsule.
- **Icon**: to be found from a screenshot (see Status).

Rejected: a time-based progress from past cleanups — the length of the
answer is a direct measure, the clock only a guess.

## Phases

### 1. Build

DoD: the five changes built; `./scripts/precommit` passes in all three
units; `docs/SPEC.md`, `docs/DESIGN.md`, ADR 0020's plan and the e2e plans
updated; German strings in the catalogs.

### 2. Run

DoD: on the Mac, a dictation through the debug seam shows the pill with the
progress bar; the chord rules are checked by the user; on the iPhone the
user sees the icon and the progress bar.

## Risks

- The estimate can stall near the cap when the model writes a shorter text;
  it never claims 100 % before the end.

## Open questions

- The iCloud link of the shortcut, from the user.
