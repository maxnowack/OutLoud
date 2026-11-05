# The user dictates into Claude and the message is sent without pressing Return

- Covers: Settings › General › Send with Return (ADR 0036) — adding and removing an app, the
  Return after a paste into a listed app, none in an unlisted app, none after a copy, the Return
  after a paste on return, no Return into a field the user left in the wait.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  The app is started with `open`, so that macOS checks Outloud's own Accessibility access.

## Preconditions

Setup completed (`first-launch.md`); microphone allowed; Outloud allowed under System
Settings › Privacy & Security › Accessibility; auto-paste on; the shortcut is ⌥ ⌘. Claude is
open with two sessions, A and B, that may receive test messages; TextEdit is open with an empty
document.

## Steps

1. Open Settings › General. Below auto-paste, "Send with Return" shows "No apps".
2. Click "Add App…": the file dialog opens on the applications folder. Choose Claude. The list
   shows Claude with its icon and a "Remove" button; "No apps" is gone. Add Claude a second time:
   it is listed once.
3. In Claude session A, click into the prompt field, hold ⌥ ⌘, say "Das ist ein Test" and
   release without leaving the field. The text appears in the field and is sent at once, whole —
   not an empty or cut-off message.
4. In TextEdit, dictate "Zweiter Test": the text is pasted, no line break follows it.
5. In Claude session A, dictate and switch to session B at once after the release. Nothing is
   typed or sent in B. Switch back to A: the text is pasted there and sent.
6. In Claude session A, dictate, and click into session B's field within a moment of the paste.
   Nothing is sent into B.
7. Turn auto-paste off and dictate in Claude: the result is copied, nothing is pasted or sent.
   Turn auto-paste on again.
8. Click "Remove" next to Claude: the list shows "No apps". Dictate in Claude: the text is pasted
   and not sent.
9. Quit Outloud and open it again: the list is as it was left.

## Assertions

- A Return follows a paste only in a listed app, and only into the field the text was pasted in.
- The message that is sent holds the whole dictation.
- A copied result is never sent.
- The list survives a relaunch.

## Screen reader pass

With VoiceOver on, in Settings › General: "Send with Return" is read as the section's heading,
each listed app by its name followed by its "Remove" button — the icon is not read —, and the
footer after "Add App…". The section is reached with Tab like the rest of the form.
