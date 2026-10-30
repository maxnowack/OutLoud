# The user sees in the menu bar panel what waits to be pasted, copies one text and keeps another from being pasted

- Covers: the PasteQueue in the menu bar panel — its rows while processed and waiting, "Copy",
  "Don't Paste" —, the clock in the menu bar icon, and the activation handed back when the panel
  closes.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  The app is started with `open`, so that macOS checks Outloud's own Accessibility access.

## Preconditions

Setup completed (`first-launch.md`); microphone allowed; Outloud allowed under System
Settings › Privacy & Security › Accessibility; auto-paste on; the shortcut is ⌥ ⌘; the history
keeps results for at least a day. Messages is open with a conversation with the user themself;
TextEdit is open with an empty document.

## Steps

1. With nothing dictated since launch, click the menu bar icon: the icon is a waveform, and the
   panel shows no "Waiting to paste".
2. In Messages, click into the message field, hold ⌥ ⌘, say a long sentence, release, and at
   once click the menu bar icon. The pill says "Pastes into Messages when you are back in the text
   field."; the panel shows "Waiting to paste" with a row "Into Messages" and "Processing…" with a
   spinner, then, once done, the sentence instead of "Processing…", with "Copy" and "Don't Paste".
3. Close the panel with Escape: the Messages window is active again, and the sentence appears in
   its message field. The panel, opened again, shows no "Waiting to paste".
4. Dictate "Erster Text" in Messages and switch to TextEdit at once; dictate "Zweiter Text" in
   TextEdit and click into the Safari address bar — or any other app's field — at once. While both
   wait, the menu bar icon is a clock.
5. Click the menu bar icon: the panel lists "Into Messages" with "Erster Text" above "Into
   TextEdit" with "Zweiter Text".
6. Click "Copy" on "Erster Text": the row shows "Copied" with a check mark for two seconds, then
   goes; `pbpaste` gives "Erster Text".
7. Click "Don't Paste" on "Zweiter Text": the row goes at once, and with it "Waiting to paste".
   The menu bar icon is a waveform again.
8. Close the panel by clicking into Messages' message field: nothing is pasted, also after
   waiting. Click into TextEdit's document: nothing is pasted.
9. Dictate in Messages, switch to TextEdit at once, open the panel, and click "Don't Paste" while
   the row still shows "Processing…". Back in Messages, nothing is pasted.
10. Open the history window: the texts of steps 2, 4 and 9 are all listed.

## Assertions

- No text taken out of the queue — copied or not to be pasted — is pasted on the return to its
  field.
- Closing the panel with Escape or with the icon gives the activation back to the app that was in
  front; closing it by clicking into another app leaves that app in front.
- Every dictated text is in the history.

## Screen reader pass

With VoiceOver on, step 5: the menu bar icon is read as "Outloud", with "Dictations wait to be
pasted" as its value. In the panel, each row's target and text are read as one element ("Into
Messages, Erster Text"), followed by the buttons "Copy" and "Don't Paste"; step 6 announces
"Copied". A row still processed reads "Into Messages, Processing…".
