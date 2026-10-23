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
| `accent` | `#1F7A70` | `#4CC2B2` | Primary buttons, selection, the idle icon |
| `recording` | system red | system red | Recording icon, record button while recording |
| `success` | system green | system green | Installed models, a copied result |
| `warning` | system orange | system orange | Cleanup fell back to the transcript, cellular data |
| `failure` | system red | system red | Failure icons |
| `textPrimary` | primary label | primary label | Body text, results |
| `textSecondary` | secondary label | secondary label | Captions, sizes, explanations |
| `surface` | secondary system background | secondary system background | Cards |

Contrast pairs, computed with the WCAG formula: `#1F7A70` on white 5.1:1
and white on `#1F7A70` 5.1:1 (light); `#4CC2B2` on black 9.7:1 and on
`#1E1E1E` 7.7:1 (dark). All meet WCAG AA for text. System colours carry
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
button is a circle of `recordButtonSize` 88 points.

### Elevation

None in the windows. The macOS recording overlay floats on a regular
material with `overlayShadow` (radius 12, 20 % black).

### Motion

`standard`: 0.2 s ease-in-out for state changes. `pulse`: 1 s repeating
scale of the recording icon. With Reduce Motion on, nothing pulses and
state changes cross-fade.

## Components

### StatusIndicator

The dictation state as icon and label: idle (waveform, `accent`),
recording (record circle, `recording`, pulsing), transcribing and
cleaning (progress spinner, "Transcribing…", "Cleaning up…"), finished
(checkmark, `success`), failed (exclamation, `failure`). Reads `heading`,
`motion`. Accessibility: one combined element, its label is the state's
words; a state change is announced.

### LevelMeter

The input level while recording, as five bars filled from `textSecondary`
to `recording`. Hidden from accessibility (the StatusIndicator says
"Recording").

### RecordButton

iOS only: starts and ends a recording. Idle: `accent` circle with a
microphone; recording: `recording` circle with a stop square; disabled
(models missing) at 40 % opacity. `recordButtonSize`, at least the 44 pt
hit target. Accessibility: button, label "Start dictation" / "Stop
dictation".

### ResultCard

The result on `surface` with `radiusMedium`: the text, selectable, in
`body`; a `warning` notice "Cleanup failed — this is the transcript" when
cleanup fell back; a Copy button that turns into "Copied" with `success`
for two seconds. Empty state: not shown. Accessibility: the text is read
as is; the copy button has its own label.

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

The first launch: what the models are for and that they run on the
device, a selectable row per model — transcription required, cleanup
optional — the total download size, and Download; then the progress of
each model and Continue once the needed ones are installed. On cellular
data the download asks first, naming the size. Reads `title`, `body`,
`spacing.xl`.

### Checkbox

A toggle drawn as a square check box on both platforms (`CheckboxStyle`),
so that an optional model in ModelSetup looks like the required one's
mark: `accent` filled check when on, an empty `textSecondary` square when
off. Accessibility: read as its label with the value "On"/"Off".

### HistoryList

The kept results, newest first: date in `caption`, the first line of the
result, a speaker icon when there is audio. Empty state: "No results
kept", with the current retention period. Swipe or context menu deletes
an entry.

### HistoryEntryDetail

One kept result: Play/Stop for the audio, the cleaned version and the
transcript, each selectable with a Copy button.

### RetentionPicker

A picker over the periods of `docs/SPEC.md` §"History": Nothing, 1 day,
3 days, 10 days, 30 days, 3 months, Unlimited.

### PrivacyNotice

How Outloud processes: transcription and cleanup on the device, nothing
sent; the only transfer is downloading models from Hugging Face; how long
results are kept. Reads `body`, `detail`.

### Acknowledgements

The licences and attributions of the models and libraries Outloud
includes or downloads.

## Screens

- **macOS menu bar panel** — StatusIndicator, ResultCard, FailureNotice,
  buttons for History, Settings and Quit.
- **macOS recording overlay** — StatusIndicator, LevelMeter.
- **macOS setup window** — ModelSetup, PrivacyNotice.
- **macOS settings window** — General (cleanup, hotkey, auto-paste),
  Models (ModelRow), History (RetentionPicker), Privacy (PrivacyNotice,
  Acknowledgements).
- **macOS history window** — HistoryList, HistoryEntryDetail.
- **iOS setup** — ModelSetup, PrivacyNotice.
- **iOS dictate tab** — RecordButton, StatusIndicator, LevelMeter,
  ResultCard, FailureNotice, and a text field for system dictation with a
  Clean up button.
- **iOS history tab** — HistoryList, HistoryEntryDetail.
- **iOS settings tab** — cleanup toggle, ModelRow, RetentionPicker,
  PrivacyNotice, Acknowledgements.
