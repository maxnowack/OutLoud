# The user cleans up text from the keyboard's dictation, in the app or with a shortcut

- Covers: the "Type or dictate" sheet, "Clean Up and Copy", the "Clean Up Text with Outloud" App Intent.
- Build: Debug.

## Preconditions

Setup completed with cleanup on.

## Steps

1. On the Dictate tab, tap "Type text instead": a sheet "Type or dictate" opens with the
   keyboard. Dictate with the keyboard's microphone: "also ähm das ist halt ein test". Tap
   "Clean Up and Copy": the sheet closes and "Copied" appears.
2. With cleanup off (Settings), the sheet's button reads "Copy" and copies the text unchanged.
3. Shortcuts app: new shortcut "Dictate Text" → "Clean Up Text with Outloud" (Text: Dictated
   Text) → "Copy to Clipboard". Run it from another app: the cleaned text is on the clipboard,
   and Outloud did not open.
4. With Apple Intelligence off, the shortcut fails with "Cleaning up text needs Apple
   Intelligence, switched on."

## Assertions

- The history entry of step 1 has no audio (speaker icon missing).

## Screen reader pass

The text field is read as "Text to clean up"; the button's label changes with the cleanup
setting.
