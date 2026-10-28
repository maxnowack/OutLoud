# The user dictates, works on elsewhere while the dictation is processed, and finds the text in its field on the return

- Covers: paste on return (ADR 0026, ADR 0027) — leaving the field sends the dictation out of
  sight, the overlay's notice, the paste into the remembered field only, the next dictation while
  one is processed, a dictation in a field that already has one going to the next field.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  The app is started with `open`, so that macOS checks Outloud's own Accessibility access.

## Preconditions

Setup completed (`first-launch.md`); microphone allowed; Outloud allowed under System
Settings › Privacy & Security › Accessibility; auto-paste on; the shortcut is ⌥ ⌘. Messages is
open with a conversation with the user themself; Claude is open with two sessions, A and B;
TextEdit is open with an empty document.

## Steps

1. In Messages, click into the message field, hold ⌥ ⌘, say "Das ist ein Test" and release
   without leaving the field. The overlay shows the progress ring, the text appears in the field
   and the overlay shows "Pasted". No Enter is pressed — the message is not sent.
2. Dictate again in Messages and switch to TextEdit at once after the release. The overlay shows
   "Pastes into Messages when you are back in the text field." for about three seconds and goes.
   Nothing is typed into TextEdit.
3. While that dictation is still processed, hold ⌥ ⌘ in TextEdit, say "Zweiter Test" and
   release: the recording starts at once, and its text is pasted into TextEdit after the first
   dictation is done.
4. Switch back to Messages, into the message field: within half a second the text of step 2
   appears there and the overlay shows "Pasted".
5. In Claude, session A, click into the input, dictate, and switch to session B at once. Nothing
   is pasted into session B, also after waiting.
6. Switch back to session A: the text appears in its input and the overlay shows "Pasted".
7. In TextEdit, dictate a long sentence and, while its ring still runs, hold ⌥ ⌘ again in
   TextEdit, say "Für das nächste Feld" and release. The first ring goes at the second press.
   Stay in TextEdit: the first text is pasted into TextEdit; once the second is done, the
   overlay says "Copied — press ⌘V where you want the text." and the clipboard holds it.
8. Repeat step 7, but switch to Messages' message field right after the second release: the
   second text is pasted into Messages, the first into TextEdit on the return to it.
9. Dictate in Messages, switch to TextEdit, dictate there, then switch back to Messages: the
   Messages text appears; back in TextEdit, its text appears. Neither replaced the other. Every
   result is in the history.
10. Hold ⌥ ⌘ in a password field (Safari's sign-in page, say): the result is copied — "Copied —
    press ⌘V where you want the text." — and pasted nowhere.
11. Hold the second ⌘ or ⌥ while recording: nothing changes, and no line appears below the wave.

## Expected end state

Outloud brought no app to the front during the run; no message was sent; every dictated text is
in the history; the clipboard holds what it held before the run, except after steps 7 and 10.
