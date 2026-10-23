# The user cleans up text from the keyboard's dictation, in the app or with a shortcut

- Covers: the text field on the Dictate tab, "Clean Up and Copy", the "Clean Up Text with Outloud" App Intent.
- Build: Debug.

## Preconditions

Setup completed with cleanup on.

## Steps

1. On the Dictate tab, tap the text field and dictate with the keyboard's microphone:
   "also ähm das ist halt ein test". Tap "Clean Up and Copy". The keyboard closes; "Done",
   "Copied to the clipboard" and the cleaned text appear; the field is empty.
2. With cleanup off (Settings), the button reads "Copy" and copies the text unchanged.
3. Shortcuts app: new shortcut "Dictate Text" → "Clean Up Text with Outloud" (Text: Dictated
   Text). Run it: the dialog says "Copied to the clipboard." and returns the cleaned text,
   without opening Outloud.
4. Run the shortcut before the models are downloaded: it fails with "Open Outloud once to
   download its models."

## Assertions

- The history entry of step 1 has no audio (speaker icon missing).

## Screen reader pass

The text field is read as "Text to clean up"; the button's label changes with the cleanup
setting.
