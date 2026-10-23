# The user manages cleanup, models and the retention period

- Covers: Settings tab.
- Build: Debug; `-OutloudTab settings` opens the tab directly.

## Preconditions

Setup completed.

## Steps

1. The Settings tab shows "Clean up the transcript", the transcription and cleanup models with
   their state, "Keep results for 1 day", "Delete All Results", "Privacy" and
   "Acknowledgements".
2. Tap "Delete" on the cleanup model; the dialog warns that it has to be downloaded again;
   confirm. The row shows "Download".
3. Tap "Download" and then "Stop": the row returns to "Download".
4. Tap "Delete All Results" › "Delete All": the History tab is empty.
5. Open "Privacy" and "Acknowledgements": the three points and the licences are shown.

## Assertions

- In German (`-AppleLanguages '(de)'`), every label is German.

## Screen reader pass

Each control has a label; model rows include their state.
