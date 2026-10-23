# The user starts a dictation from the Action Button or another way without opening Outloud first

- Covers: the "Dictate" control (ADR 0017), the shortcut that records and leaves the user in their app (ADR 0018), the "Ways to start Outloud" sheet, the hint card on the dictate tab.
- Build: Debug on the user's iPhone (`docs/RELEASE.md` §"iOS").

## Preconditions

Setup completed; microphone allowed; Outloud launched once since it was installed (so that iOS
knows its control and shortcuts).

## Steps

1. On the dictate tab, the card "Dictate with the Action Button" is shown. Tap it: the sheet
   "Start Outloud" lists In any app, Action Button, Control Center, Lock Screen, Back Tap, Siri
   and Home Screen, each with a one-line summary, and a Shortcuts button at the end.
2. Open "Action Button": three numbered steps, then "Good" and "Keep in mind". Follow the
   steps in Settings: under Action Button › Controls, Outloud › "Dictate" is offered; choose it.
3. Lock the iPhone and press the Action Button: Outloud opens on the dictate tab and records
   ("Recording…", level meter). Tap stop: "Copied" appears.
4. Add the control to the Control Center (way "Control Center"); tap it from another app:
   same as step 3.
5. Say "Hey Siri, dictate with Outloud": same as step 3.
6. Open "In any app" and build the shortcut it describes: "Record Audio" (start immediately,
   finish on tap), "Transcribe Audio with Outloud", "Copy to Clipboard". Put it on Back Tap ›
   Double Tap (way "Back Tap"). Copy a word, open Notes, double-tap the back: the recording
   shows over Notes; speak, tap to finish. Paste: the spoken text appears, cleaned up, not the
   copied word; Outloud did not come to the front. In Outloud, the history holds the dictation with
   its recording; the dictate tab does not say "Copied".
7. Repeat step 6 on battery several times in a row: when Apple limits the cleanup in the
   background, the text arrives uncleaned, and the history keeps only the transcript.
8. Dismiss the card with its ×: it does not come back after relaunching; the sheet stays
   reachable from the bolt in the navigation bar and from Settings › "Ways to start Outloud".

## Assertions

- Every settings path the sheet names exists on iOS 27 with these names; a wrong one is a
  defect in `apps/ios/Sources/Views/ShortcutGuide.swift`.
- Do not assert how long iOS takes to offer the control after installation.
- In step 6 the text is cleaned up by Apple's model (ADR 0019); the first run after iOS started
  Outloud takes up to about 20 s, later runs a few seconds.

## Screen reader pass

The card is one button ("Dictate with the Action Button …") plus "Hide"; the bolt reads "Ways
to start Outloud"; each way's steps are read in order.
