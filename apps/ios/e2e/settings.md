# The user manages cleanup, models and the retention period

- Covers: Settings tab.
- Build: Debug; `-OutloudTab settings` opens the tab directly.

## Preconditions

Setup completed.

## Steps

1. The Settings tab shows "Clean up the transcript" with the note on Apple Intelligence, the
   transcription model with its state, "Keep results for 1 day", "Delete All Results",
   "Privacy" and "Acknowledgements".
2. Switch Apple Intelligence off in the system settings and return: the cleanup toggle is off
   and disabled, and the note says to switch it on. Switch it on again: the toggle is back.
3. Tap "Delete" on the transcription model; the dialog warns that it has to be downloaded
   again; confirm. The app shows the setup. Tap "Download" and then "Stop": the card returns to
   its download button. Download it again to continue.
4. Tap "Delete All Results" › "Delete All": the History tab is empty.
5. Open "Privacy" and "Acknowledgements": the three points and the licences are shown.

## Assertions

- In German (`-AppleLanguages '(de)'`), every label is German.

## Screen reader pass

Each control has a label; model rows include their state.
