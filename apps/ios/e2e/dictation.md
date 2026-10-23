# The user dictates with the record button or the Action Button and pastes the text in another app

- Covers: Dictate tab (RecordButton, StatusIndicator, LevelMeter, ResultCard, FailureNotice), the "Dictate with Outloud" App Intent.
- Build: Debug. The microphone-free branch uses
  `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` (`apps/ios/Sources/AppModel.swift`); the
  WAV file has to be inside the app's container (e.g. its `tmp/`).

## Preconditions

Setup completed; microphone allowed (simulator: `xcrun simctl privacy booted grant microphone io.github.maxnowack.outloud`).

## Steps

1. On the Dictate tab, tap the record button ("Start dictation"). It turns red with a stop
   square; the status reads "Recording…" with a level meter.
2. Say "Also ähm ich komme heute so gegen acht vorbei" and tap the button ("Stop dictation").
   The status reads "Transcribing…", then "Cleaning up…", then "Done".
3. "Copied to the clipboard" and the result card appear. Switch to Notes and paste: the cleaned
   text appears.
4. Settings › Action Button › Shortcut › Outloud › "Dictate" (device). Press the Action Button
   in another app: Outloud opens and records at once; stop it as in step 2.
5. Shortcuts app › "Dictate with Outloud": same as step 4.
6. Deny the microphone in Settings › Outloud and tap the record button: "Outloud may not use the
   microphone…" with "Open Settings", which opens Outloud's settings.
7. Microphone-free check:
   `xcrun simctl launch booted io.github.maxnowack.outloud -OutloudSampleAudio <container>/tmp/de.wav -OutloudAutoDictate YES -hasCompletedSetup YES`.
   The result card shows the German sample's text; the history (`history.md`) has a new entry
   with audio.

## Assertions

- The record button is disabled while transcribing or cleaning up.
- In the simulator, cleanup times out (llama.cpp generates far too slowly there); the result is
  then the transcript with "Cleanup failed — this is the transcript." Run the cleanup branch on a
  device.
- Do not assert the exact cleanup wording.

## Screen reader pass

The record button is read as "Start dictation" / "Stop dictation"; state changes ("Recording…",
"Done") are announced; the result text is read in full.
