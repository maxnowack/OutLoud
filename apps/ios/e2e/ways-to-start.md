# The user starts a dictation from the Action Button or another way without opening Outloud first

- Covers: the "Dictate" control (ADR 0017), the shortcut that starts and stops a dictation in the background with its Live Activity (ADR 0022), the "Ways to start Outloud" sheet, the hint card on the dictate tab.
- Build: Debug on the user's iPhone (`docs/RELEASE.md` §"iOS").

## Preconditions

Setup completed; microphone allowed; Outloud launched once since it was installed (so that iOS
knows its control and shortcuts).

## Steps

1. On the dictate tab, the card "Dictate from any app" is shown, with even margins around its
   icon, text and ×. Tap it: the sheet "Dictate from Any App" shows "1. Set up the shortcut,
   once" with four numbered steps and a Shortcuts button, "2. Choose how to run it" with
   AssistiveTouch, Action Button, Back Tap, Control Center and Siri, and "Or open Outloud and
   record" with the Dictate control.
2. Open "Outloud's Dictate control" and follow it: under Action Button › Controls, Outloud ›
   "Dictate" is offered; choose it. Lock the iPhone and press the Action Button: Outloud opens on
   the dictate tab and records (the red wave). Tap stop: "Copied" appears.
3. Add the control to the Control Center; tap it from another app: same as step 2.
4. Open "AssistiveTouch" and follow it with the shortcut of step 6; with the Accessibility
   Shortcut, a triple-click on the side button shows and hides the button.
5. Say "Hey Siri" and the shortcut's name: the dictation starts as in step 6.
6. Build the shortcut of part 1: "Start or Stop Dictation with Outloud", "Copy to Clipboard".
   Run it from AssistiveTouch, the Action Button (Shortcut) or Back Tap. Copy a word, open Notes,
   run the shortcut: Outloud does not come to the front, Notes stays in view, and the Dynamic
   Island shows a red dot with a running time. Speak, run it again: the Live Activity shows
   "Transcribing…", then "Cleaning up…", each with a filling bar and the seconds left beside it (a
   filling ring with the seconds inside in the compact island), counting down, then "Copied",
   and disappears. Paste: the cleaned text appears. In Outloud, the history holds the dictation with its recording.
7. Start again from Notes, then tap Stop in the expanded Dynamic Island: it shows "Saved in
   Outloud" and the clipboard is unchanged; the dictation is in the history. Start once more, open
   Outloud and tap the record button to stop: the text is copied and the Live Activity ends.
8. Start from Notes and run the shortcut twice quickly at the end: the second run during the
   processing starts no new recording.
9. Repeat step 6 on battery several times in a row: when Apple limits the cleanup in the
   background, the text arrives uncleaned, and the history keeps only the transcript.
10. Dismiss the card with its ×: it does not come back after relaunching; the sheet stays
   reachable from the bolt in the navigation bar and from Settings › "Ways to start Outloud".

## Assertions

- Every settings path the sheet names exists on iOS 27 with these names; a wrong one is a
  defect in `apps/ios/Sources/Views/ShortcutGuide.swift`.
- Do not assert how long iOS takes to offer the control after installation.
- In step 6 the text is cleaned up by Apple's model (ADR 0019); the first run after iOS started
  Outloud takes up to about 20 s, later runs a few seconds. Music playing meanwhile goes on
  (the recording mixes with other audio, ADR 0022).

## Screen reader pass

The card is one button ("Dictate with the Action Button …") plus "Hide"; the bolt reads "Ways
to start Outloud"; each way's steps are read in order.
