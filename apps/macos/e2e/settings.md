# The user changes the shortcut, cleanup, auto-paste and the retention period

- Covers: Settings › General, History, Privacy.
- Build: Debug.

## Preconditions

Setup completed.

## Steps

1. Settings › General › "Push-to-talk shortcut" › "⌃ ⌥ Space". Hold ⌃ ⌥ Space: a recording
   starts; ⌥ Space alone does nothing.
2. Turn off "Clean up the transcript" and dictate: the result equals the transcript (fillers
   stay).
3. Turn off "Paste into the active text field" and dictate: the overlay reads "Copied — press ⌘V."
4. With auto-paste on and Accessibility not allowed, "Accessibility access" shows "Allow…";
   clicking it opens the system prompt. After allowing, it shows "Allowed".
5. Settings › History: choose "3 days"; the Privacy tab reads "… kept on this device for 3 days,
   then deleted."
6. Settings › Privacy shows the three points and the acknowledgements with the model licences.

## Assertions

- `defaults read io.github.maxnowack.outloud` shows `hotkey`, `cleanupEnabled`, `autoPaste` and
  `retentionPeriod` with the chosen values.

## Screen reader pass

Every control has a label; the warning when a shortcut is taken is read with the picker.
