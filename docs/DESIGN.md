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
copied confirmation's check mark is `confirmationIconSize` 64 points. The cleanup's
progress bar is `progressBarWidth` 64 points wide; the overlay's text wraps
at `overlayTextWidth` 320 points.

### Elevation

None in the windows. The macOS recording overlay is a Liquid Glass capsule,
which brings its own depth and shadow.

### Motion

`standard`: 0.2 s ease-in-out for state changes. `pulse`: 1 s repeating
scale of the recording icon. `overlayAppear`: a 0.4 s spring with a little
bounce, for the macOS overlay rising and fading in and settling and fading
out. `overlayResize`: 0.3 s smooth, for the overlay's capsule following its
content's size. With Reduce Motion on, nothing pulses or rises, and state
changes and the overlay only cross-fade.

## Components

### StatusIndicator

The dictation state as icon and label: idle (waveform, `accent`),
recording (record circle, `recording`, pulsing), transcribing and
cleaning (progress spinner, "Transcribing…", "Cleaning up…" — while
cleaning, with a progress bar of `progressBarWidth` in `accent` where the
progress is known), finished
(checkmark, `success`), failed (exclamation, `failure`). Reads `heading`,
`motion`. Accessibility: one combined element, its label is the state's
words; a state change is announced.

### LevelMeter

The input level while recording, as five bars filled from `textSecondary`
to `recording`. Hidden from accessibility (the StatusIndicator says
"Recording").

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
and spinner, "Transcribing…"), cleaning up (sparkles, "Cleaning up…" with a
progress bar; a progress ring in the compact island), then copied (green
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
| `echo-near` | arc of radius 29 around the ring's centre, ±40°, stroke 5, round caps, 75 % opacity | white | `accent` dark |
| `echo-far` | arc of radius 39, ±40°, stroke 5, round caps, 40 % opacity | white | `accent` dark |

The layers are SVGs in the document's `Assets/`; change them there or in
Icon Composer, never as exported PNGs. The rejected directions —
waveform-to-text, a speech bubble, a microphone — were compared in a
design canvas outside the repository on 2026-10-23.

## Screens

- **macOS menu bar panel** — StatusIndicator, ResultCard, FailureNotice,
  buttons for History, Settings and Quit.
- **macOS recording overlay** — a Liquid Glass capsule (`glassEffect` in a
  `GlassEffectContainer`, drawn in its active look although the panel never
  becomes key) as wide as its content: StatusIndicator (with the cleanup's
  progress), LevelMeter, or the delivery message, which wraps at
  `overlayTextWidth`. It rises and fades in, follows its content's size
  smoothly, and fades out; centred at the bottom of the screen, inside a
  fixed transparent area of `overlayAreaSize`.
- **macOS setup window** — ModelSetup, PrivacyNotice.
- **macOS settings window** — General (cleanup with its
  CleanupAvailabilityNote; the shortcut, with a `warning` note and "Allow…"
  while ⌥ ⌘ waits for Accessibility access; auto-paste), Models (ModelRow of the
  transcription model), History (RetentionPicker), Privacy (PrivacyNotice,
  Acknowledgements).
- **macOS history window** — HistoryList, HistoryEntryDetail.
- **iOS setup** — ModelSetup.
- **iOS dictate tab** — a dismissible card pointing to dictating from any
  app, with even margins around its icon, text and ×; StatusIndicator and
  LevelMeter in the middle, DeliveryConfirmation or FailureNotice after a dictation, RecordButton
  and "Type text instead" (a sheet with a text field for system
  dictation) at the bottom.
- **iOS dictate from any app** — a sheet in three parts: "1. Set up the
  shortcut, once" with numbered steps and a link to the Shortcuts app; "2.
  Choose how to run it" listing AssistiveTouch, Action Button, Back Tap,
  Control Center and Siri, each opening its steps, advantages and
  drawbacks; and "Or open Outloud and record" for the Dictate control.
- **iOS history tab** — HistoryList, HistoryEntryDetail.
- **iOS settings tab** — cleanup toggle with its CleanupAvailabilityNote,
  ModelRow of the transcription model, RetentionPicker, the
  ways to start Outloud, PrivacyNotice, Acknowledgements.
