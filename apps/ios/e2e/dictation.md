# The user dictates with the record button or the Action Button and pastes the text in another app

- Covers: Dictate tab (RecordButton, StatusIndicator, LevelMeter, ResultCard, FailureNotice), the "Dictate with Outloud" App Intent.
- Build: Debug. The microphone-free branch uses
  `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` (`apps/ios/Sources/AppModel.swift`); the
  WAV file has to be inside the app's container (e.g. its `tmp/`).

## Preconditions

Setup completed; microphone allowed (simulator: `xcrun simctl privacy booted grant microphone dev.nowack.outloud`).

## Steps

1. On the Dictate tab, tap the record button at the bottom ("Start dictation"). It turns red
   with a stop square; the status in the middle reads "Recording…" with a level meter.
2. Say "Also ähm ich komme heute so gegen acht vorbei" and tap the button ("Stop dictation").
   The status reads "Transcribing…", then "Cleaning up…", then "Done".
3. A large check mark, "Copied" and a sentence on pasting appear; the text is not shown. Tap
   "Show text": the result card with the cleaned text and "Copy" appears. Switch to Notes and
   paste: the cleaned text appears.
4. The Action Button and the other ways of starting: `ways-to-start.md`.
5. Shortcuts app › "Dictate with Outloud": Outloud opens and records at once.
6. Deny the microphone in Settings › Outloud and tap the record button: "Outloud may not use the
   microphone…" with "Open Settings", which opens Outloud's settings.
7. Microphone-free check:
   `xcrun simctl launch booted dev.nowack.outloud -OutloudSampleAudio <container>/tmp/de.wav -OutloudAutoDictate YES -hasCompletedSetup YES`.
   The result card shows the German sample's text; the history (`history.md`) has a new entry
   with audio.

## Assertions

- The record button is disabled while transcribing or cleaning up.
- The simulator may lack Apple Intelligence; then the result is the transcript. Run the
  cleanup branch on a device with Apple Intelligence on.
- Do not assert the exact cleanup wording.

## Screen reader pass

The record button is read as "Start dictation" / "Stop dictation"; state changes ("Recording…",
"Done") are announced; the result text is read in full.
