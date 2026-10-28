# Design

This document owns the visual appearance of the product: the tokens, the
component vocabulary built on them, and the states every component renders.
It is fixed before the first screen and extended in the same change set
that adds a token or a component (`docs/ARCHITECTURE_PRINCIPLES.md`
§"Design system"). What the product *does* lives in `docs/SPEC.md`; how it
is built lives in `docs/ARCHITECTURE.md`.

The tokens and components live in the `OutloudUI` library of the package
(`OutloudKit/Sources/OutloudUI/`), which both apps compose their screens
from.

## Principles

- **Calm.** Outloud is a quiet writing tool for short everyday texts
  (`docs/SPEC.md`). One accent colour, system typography, no decoration;
  the text is the largest thing on screen.
- **Native.** Each app looks like its platform: SwiftUI's standard
  controls, system colours and materials, the system's text sizes. The
  apps override the platform only for the record button and the
  recording overlay, which have no system equivalent.
- **The state is always visible.** Recording, processing, the result and
  every failure are shown with an icon *and* words, never by colour alone
  (`docs/SPEC.md` §"Result view and states").
- **Nothing happens unseen.** What leaves the device — model downloads —
  and how much space a model takes are stated before it happens.

## Tokens

Every value below is a member of `Tokens` in `OutloudUI`; a literal in a
screen or a component is a defect.

### Colour

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `accent` | `#1F7A70` | `#4CC2B2` | Text, links, selection, the idle icon |
| `accentFill` | `#1F7A70` | `#1F7A70` | Filled surfaces with white content: the record button, the play button, prominent buttons, numbered steps — the app icon's colour in both appearances |
| `recording` | system red | system red | Recording icon, record button while recording |
| `success` | system green | system green | Installed models, a copied result |
| `warning` | system orange | system orange | Cleanup fell back to the transcript, cellular data |
| `failure` | system red | system red | Failure icons |
| `textPrimary` | primary label | primary label | Body text, results |
| `textSecondary` | secondary label | secondary label | Captions, sizes, explanations |
| `surface` | secondary system background | secondary system background | Cards |

Contrast pairs, computed with the WCAG formula: `#1F7A70` on white 5.1:1
and white on `#1F7A70` 5.1:1 (light); `#4CC2B2` on black 9.7:1 and on
`#1E1E1E` 7.7:1 (dark). All meet WCAG AA for text. `accentFill` keeps white
content at 5.1:1 in both appearances and stands at 4.1:1 against black,
above the 3:1 that a control needs; `#4CC2B2` under white would give only
about 2:1. System colours carry
the platform's own contrast guarantees.

### Typography

System font, Dynamic Type everywhere; no fixed point sizes.

| Token | Style | Use |
| --- | --- | --- |
| `title` | `.title2`, semibold | Screen titles in setup |
| `heading` | `.headline` | Card and section headings |
| `body` | `.body` | Results, explanations |
| `detail` | `.callout` | Model details, notices |
| `caption` | `.caption` | Sizes, dates, footnotes |

### Spacing

`xs` 4, `s` 8, `m` 12, `l` 16, `xl` 24, `xxl` 32 points.

### Shape

`radiusSmall` 6, `radiusMedium` 10, `radiusLarge` 16 points. The record
button is a circle of `recordButtonSize` 104 points, the play button one
of `playButtonSize` 56; a waveform is `waveformHeight` 36 points high; the
copied confirmation's check mark is `confirmationIconSize` 64 points. The
LevelWave is `levelWaveSize` 96 × 24 points on macOS and 180 × 44 on iOS;
the overlay's text wraps at `overlayTextWidth` 320 points.

### Elevation

None in the windows. The macOS recording overlay is a Liquid Glass capsule,
which brings its own depth and shadow.

### Motion

`standard`: 0.2 s ease-in-out for state changes. `pulse`: 1 s repeating
scale of the recording icon. `overlayAppear`: 0.4 s smooth, without a
bounce, for the macOS overlay growing and fading in and fading out.
`overlayContentFade`: 0.12 s ease-in-out, for the overlay's content fading
out before the capsule changes size and in after; in between, the capsule
takes the next content's size with a smooth curve of 0.15 s for a few points
up to 0.3 s for the width of a label (`overlayResizeSeconds`). `overlaySwap`:
0.08 s out and 0.08 s in, for a content about as wide as the one before
(within `overlaySwapWidth`, 12 pt). `overlayStepHold`: 0.25 s, how long a
step of the pipeline must last before the overlay shows it. With
Reduce Motion on, nothing pulses or grows, and state changes and the overlay
only cross-fade.

## Components

### Buttons

Buttons follow Apple's Human Interface Guidelines
(https://developer.apple.com/design/human-interface-guidelines/buttons),
as the user decided on 2026-10-25 after text-only buttons had been tried
and rejected: they lacked a button's spacing, hit area and states.

- **System styles only.** On macOS an action is a push button in the
  system style, which brings its spacing, its hit area, its pressed and
  focus states and its tooltip; no text-only or link-style buttons stand
  in for actions. One prominent button (`accentFill`) for a view's most
  likely action, such as "Continue" in the setup window and "Set Up
  Outloud…" in the menu bar panel; a destructive action has the
  destructive role and is never the prominent one.
- **A trailing ellipsis** marks a button that opens another window, a
  confirmation or another app: "Allow…", "Open Login Items…", "History…",
  "Delete All Results…". In German it follows a space, as in Apple's own
  German texts: "Erlauben …".

### StatusIndicator

The dictation state as icon and label: idle (waveform, `accent`),
recording (record circle, `recording`, pulsing — or, where the input level
is given, "Recording…" above the LevelWave, without the icon: the
overlay and the dictate tab), transcribing and cleaning ("Transcribing…", "Cleaning up…"
beside a ring of 24 points (`progressRingSize`; the other icons take
`statusIconSize`, 20) that fills clockwise in `accent` over a
`textSecondary` track where the progress is known, and a spinner where it
is not; the ring moves evenly from the step's start, by the time passed
over the duration learned for a recording of this length in seconds or a
text of this length in tokens, fills only at the end, and starts anew for
the cleanup — the same ring as the Live Activity's; inside it, the whole
seconds left until the learned duration, rounded up, in 10-point
semibold digits — they never count up when the expectation grows, vanish
once it has passed, and are left out above 99), finished (checkmark,
`success`), failed (exclamation, `failure`). Reads `heading`, `motion`.
Accessibility: one combined element, its label is the state's words, its value "About N seconds left" while
the seconds count down, else the ring's percentage; a state
change is announced.

### LevelWave

The voice while recording, as one smooth line in `recording`, tapered to
the ends: the shape of the input's last 30 ms, redrawn about once a frame,
starting where the signal rises through zero so that a held vowel stands
still, as on an oscilloscope. Its height is the level — mapped from -55 dB
to -15 dB, the range of speech at the microphone, rising at once and
falling back within about a tenth of a second. So a vowel shows as a
steady wave, a hiss as a fine tremble, and silence as a flat line: the
user sees that the microphone hears them and that the line is their voice,
not an animation. With Reduce Motion it shows a calm sine of three periods
that only grows and shrinks with the level. Hidden from accessibility (the
StatusIndicator says "Recording").

### RecordButton

iOS only: starts and ends a recording; it sits at the bottom of the screen,
within the thumb's reach. Idle: `accent` circle with a microphone;
recording: `recording` circle with a stop square; disabled (models missing,
processing) at 40 % opacity. `recordButtonSize`, at least the 44 pt hit
target. Accessibility: button, label "Start dictation" / "Stop
dictation".

### ResultCard

The result on `surface` with `radiusMedium`: the text, selectable, in
`body`; a `warning` notice "Cleanup failed — this is the transcript" when
cleanup fell back; a Copy button that turns into "Copied" with `success`
for two seconds. Empty state: not shown. Accessibility: the text is read
as is; the copy button has its own label.

### DictationLiveActivity

iOS: a dictation started from another app (ADR 0022), in the Dynamic Island
and on the Lock Screen, one phase at a time: recording (red record circle,
"Recording" and its running time, a Stop button), transcribing (waveform
and "Transcribing…"), cleaning up (sparkles, "Cleaning up…"), each with a
progress bar and the seconds left beside it ("2s"), and a progress ring
with the seconds inside in the compact island, then copied (green
check mark, "Copied", "Paste it anywhere."), saved (ended from its Stop
button: "Saved in Outloud", not copied), nothing recognised or failed
(warning sign and what to do), and gone after four seconds. Progress moves
in steps of 5 %, since iOS limits how often an activity may change.
Accessibility: the Stop button is "Stop dictation".

### DeliveryConfirmation

iOS: the result as "Copied" with a `success` check mark of
`confirmationIconSize`, one sentence on pasting, the cleanup-failed notice
where it applies, and a "Show text" button that reveals the ResultCard.
The text is not shown until asked for. Accessibility: "Copied" is
announced.

### FailureNotice

A failure as icon, sentence and, where one exists, a recovery button:
microphone denied → "Open Settings"; models missing → "Download models";
nothing recognised → none. Reads `failure`, `detail`.

### ModelRow

One model: name, purpose, size and languages in `detail`/`caption`, and
its state — not installed (Download button), downloading (progress bar
with bytes, Stop button), installed (checkmark in `success`, Delete
button), failed (message in `failure`, Retry button). Delete asks first
(`docs/SPEC.md` §"Models"). Accessibility: the state is part of the row's
label; the progress bar has a value.

### ModelSetup

The first launch, short enough to need no scrolling on an iPhone: a title
and one sentence; a card for speech recognition (required, name and size)
with its download state — a failed download with its own Retry button —,
and a card for cleanup with a Checkbox and the CleanupAvailabilityNote; the
Checkbox is off and disabled where cleanup is unavailable; "What happens
with my data?" opens the PrivacyNotice in a sheet; a full-width "Download …"
button with "Preferably on Wi-Fi." under it, "Stop" while downloading,
"Continue" once the model is installed. On cellular data the download asks first, naming
the size.

### CleanupAvailabilityNote

Whether the cleanup can run, in `caption` with an icon (ADR 0019):
available — "Uses Apple Intelligence on this device. No download.", in
`textSecondary` with the Apple Intelligence symbol; otherwise, in `warning`
with an exclamation mark, why not and what to do — the device does not
support Apple Intelligence, Apple Intelligence is switched off, or it is
still getting ready. Shown in ModelSetup and under the cleanup toggle of
both settings screens. Accessibility: read as its text.

### Checkbox

A toggle drawn as a square check box on both platforms (`CheckboxStyle`),
so that the optional cleanup in ModelSetup looks like the required model's
mark, with its label beside it: `accent` filled check when on, an empty
`textSecondary` square when off. Accessibility: read as its label with the value "On"/"Off".

### HistoryList

The kept results, newest first: date in `caption`, the first line of the
result, a speaker icon when there is audio. Empty state: "No results
kept", with the current retention period. Swipe or context menu deletes
an entry.

### HistoryEntryDetail

One kept result: the AudioPlayer when it has audio, the cleaned version
and the transcript, each selectable with a Copy button.

### AudioPlayer

A kept recording on `surface` with `radiusLarge`: a play/pause button of
`playButtonSize` in `accent`, the recording's waveform — its loudness in 48
bars, the played part in `accent`, the rest in `textSecondary` at 35 % —
which seeks where it is tapped, and the position and length in
`caption`. Accessibility: the button is "Play"/"Pause"; the waveform is
hidden.

### RetentionPicker

A picker over the periods of `docs/SPEC.md` §"History": Nothing, 1 day,
3 days, 10 days, 30 days, 3 months, Unlimited.

### PrivacyNotice

How Outloud processes: transcription on the device and the cleanup with
Apple Intelligence's model on the device, nothing sent; the only transfer
is downloading the transcription model from Hugging Face; how long results
are kept. Reads `body`, `detail`.

### Acknowledgements

The licences and attributions of the models and libraries Outloud
includes or downloads.

## App icon

An "O" with two sound arcs to its right: the name, said out loud. One
Icon Composer document, `apps/shared/AppIcon.icon`, serves both apps;
the system renders the glass, the dark and the tinted appearance from
it. On macOS the icon shows in Finder, Spotlight and the system's
windows, not in the Dock (`LSUIElement`); the menu bar keeps the
StatusIndicator.

| Layer | Geometry (100 × 100 canvas) | Light | Dark |
| --- | --- | --- | --- |
| Background | the system's icon shape | `accent` light, `#1F7A70` | `#0E1C1A` |
| `ring` | circle at (40, 50), radius 16, stroke 9 | white | `accent` dark, `#4CC2B2` |
| `echo-near` | arc of radius 29 around the ring's centre, ±40°, 5 wide with round caps, 75 % opacity | white | `accent` dark |
| `echo-far` | arc of radius 39, ±40°, 5 wide with round caps, 40 % opacity | white | `accent` dark |

The layers are SVGs in the document's `Assets/`; change them there or in
Icon Composer, never as exported PNGs. An open shape is drawn as a closed,
filled outline, never as a stroked open path: App Store Connect fills an
open path as if it were closed, so a stroked arc showed a filled segment
there (2026-10-23), while Xcode and Icon Composer drew it correctly.
The README shows `docs/images/app-icon.png`, rendered from the document
in its default appearance at 256 × 256 px; render it again whenever a
layer changes:
`"$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool" apps/shared/AppIcon.icon --export-image --output-file docs/images/app-icon.png --platform iOS --rendition Default --width 128 --height 128 --scale 2`. The rejected directions —
waveform-to-text, a speech bubble, a microphone — were compared in a
design canvas outside the repository on 2026-10-23.

## Screens

- **macOS menu bar panel** — a popover under the menu bar icon, opened by
  a click: StatusIndicator, ResultCard, FailureNotice and one push button,
  "History…". A right-click (or ⌃-click) on the icon opens a menu instead:
  "Settings…" (⌘,), "Check for Updates…", "Quit Outloud" (⌘Q); the settings
  open in a window of their own.
- **macOS recording overlay** — a Liquid Glass capsule (AppKit's
  `NSGlassEffectView` in its clear style, which lets what lies behind show
  through and shines at the edge; the regular style turns into an even fill
  over a calm background and looked like a plain pill)
  as wide as its content: the LevelWave and "Recording…" while recording —
  below them, in `caption` and `warning` with a speaker icon, "Something is
  playing in the background" when an app still sounds after the pause
  command (ADR 0025) —, the
  StatusIndicator with its ring while processing, or the delivery message,
  which wraps at
  `overlayTextWidth`. It grows out of a smaller capsule while fading in, and
  fades out. A change of content goes in three steps — the old content fades
  out, the capsule takes the new one's size, the new content fades in — and
  the content is clipped to the capsule, so that it never reaches past the
  edge and the capsule never shows space its content does not fill. A
  content about as wide as the one before swaps in a quick dip instead, the
  capsule following as it fades in, so that it is not empty for a change
  that cannot be seen. A narrower content, which already fits, fades in
  after the old one's quick fade while the capsule shrinks around it, so
  that "Pasted" comes with the pasted text. Transcribing and cleaning up appear only once they
  lasted a quarter second; one that ends sooner — a transcription on the Mac
  often does — is skipped, and the line stays until the next one. "Done" is
  never shown: the delivery message follows it as soon as the result is
  pasted or copied, and the step before stays until then, its ring full.
  Centred
  at the bottom of the screen, inside a fixed transparent area of
  `overlayAreaSize`, it grows and shrinks about its middle.
- **macOS setup window** — ModelSetup, PrivacyNotice, and the switch
  "Open Outloud at login", preselected.
- **macOS settings window** — General ("Open at login", with a `warning`
  note and "Open Login Items…" while macOS waits for the user's approval;
  cleanup with its
  CleanupAvailabilityNote; the shortcut, with a `warning` note and "Allow…"
  while ⌥ ⌘ waits for Accessibility access; "Pause playback while
  dictating", with "Recording system audio" and "Allow…" while that
  permission is declined; auto-paste), Models (ModelRow of the
  transcription model), History (RetentionPicker), Privacy (PrivacyNotice,
  Acknowledgements).
- **macOS history window** — HistoryList, HistoryEntryDetail.
- **iOS setup** — ModelSetup.
- **iOS dictate tab** — a dismissible card pointing to dictating from any
  app, with even margins around its icon, text and ×; the LevelWave and
  "Recording…" while recording, the StatusIndicator otherwise, in the middle, DeliveryConfirmation or FailureNotice after a dictation, RecordButton
  and "Type text instead" (a sheet with a text field for system
  dictation) at the bottom.
- **iOS dictate from any app** — a sheet in three parts: "1. Set up the
  shortcut, once" with numbered steps and a link to the Shortcuts app; "2.
  Choose how to run it" listing AssistiveTouch, Action Button, Back Tap,
  Control Center and Siri, each opening its steps, advantages and
  drawbacks; and "Or open Outloud and record" for the Dictate control.
- **iOS history tab** — HistoryList, HistoryEntryDetail.
- **iOS settings tab** — cleanup toggle with its CleanupAvailabilityNote,
  "Pause playback while dictating" with what iOS allows from the shortcut,
  ModelRow of the transcription model, RetentionPicker, the
  ways to start Outloud, PrivacyNotice, Acknowledgements.
