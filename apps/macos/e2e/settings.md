# The user changes the shortcut, cleanup, auto-paste and the retention period

- Covers: Settings › General, History, Privacy.
- Build: Debug.

## Preconditions

Setup completed.

## Steps

1. With Accessibility access allowed, the shortcut is "⌥ ⌘". In another app, hold ⌥ ⌘ and speak,
   release: the result is pasted. Hold ⌥ ⌘ and press D at once: no dictation (the overlay may
   flash). Hold ⌥ ⌘, speak, add ⇧ after a few seconds: the recording is cancelled. Hold ⌥ ⌘,
   speak for two seconds, press a letter, speak on, release: the letter reaches the app and the
   whole dictation is pasted (ADR 0021).
2. Remove Outloud from System Settings › Privacy & Security › Accessibility and reopen Settings:
   a note says ⌥ ⌘ needs Accessibility access and to hold ⌥ Space until then; ⌥ Space dictates,
   ⌥ ⌘ does nothing. Click "Allow…" and allow it: the note disappears and ⌥ ⌘ works again,
   without a relaunch.
3. Settings › General › "Push-to-talk shortcut" › "⌃ ⌥ Space". Hold ⌃ ⌥ Space: a recording
   starts; ⌥ Space alone does nothing.
4. Under "Clean up the transcript", the note reads "Uses Apple Intelligence on this device. No
   download." Turn the toggle off and dictate: the result equals the transcript (fillers stay).
   With Apple Intelligence switched off in System Settings, the toggle is off and disabled, and
   the note says to switch it on.
5. Turn off "Paste into the active text field" and dictate: the overlay reads "Copied — press ⌘V."
6. With auto-paste on and Accessibility not allowed, "Accessibility access" shows "Allow…";
   clicking it opens the system prompt. After allowing, it shows "Allowed".
7. Settings › History: choose "3 days"; the Privacy tab reads "… kept on this device for 3 days,
   then deleted."
8. Settings › Privacy shows the three points and the acknowledgements with the model licences.

## Assertions

- `defaults read dev.nowack.outloud` shows `hotkey`, `cleanupEnabled`, `autoPaste` and
  `retentionPeriod` with the chosen values.

## Screen reader pass

Every control has a label; the warning when a shortcut is taken is read with the picker.
