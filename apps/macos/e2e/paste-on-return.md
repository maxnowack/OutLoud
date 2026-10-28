# The user marks a dictation with the second ⌘ or ⌥, works on elsewhere, and finds the text in its field on the return

- Covers: paste on return (ADR 0026) — the second ⌘ or ⌥, the overlay's notices, the paste into
  the remembered field only, the next dictation while one is processed.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  The app is started with `open`, so that macOS checks Outloud's own Accessibility access.

## Preconditions

Setup completed (`first-launch.md`); microphone allowed; Outloud allowed under System
Settings › Privacy & Security › Accessibility; auto-paste on; the shortcut is ⌥ ⌘. Messages is
open with a conversation with the user themself; Claude is open with two sessions, A and B;
TextEdit is open. The keyboard has ⌘ and ⌥ on both sides.

## Steps

1. In Messages, click into the message field. Hold left ⌥ ⌘, then press right ⌘ while holding:
   below the wave the overlay shows, with a clock icon, "Pastes when you are back". Say "Das ist
   ein Test" and release. The overlay goes away at once.
2. Without leaving the field, wait: within a few seconds the text appears in the field and the
   overlay shows "Pasted". No Enter is pressed — the message is not sent.
3. Repeat step 1 with right ⌥ instead of right ⌘, then switch to TextEdit at once. The overlay
   shows "Pastes into Messages when you are back in the text field." for about three seconds and
   goes. Nothing is typed into TextEdit.
4. While that dictation is still processed, hold ⌥ ⌘ in TextEdit, say "Zweiter Test" and
   release: the recording starts at once, and its text is pasted into TextEdit after the first
   dictation is done.
5. Switch back to Messages, into the message field: within half a second the text of step 3
   appears there and the overlay shows "Pasted".
6. In Claude, session A, click into the input, dictate with the second ⌘ as in step 1, and
   switch to session B at once. Nothing is pasted into session B, also after waiting.
7. Switch back to session A: the text appears in its input and the overlay shows "Pasted".
8. In Messages, dictate with the second ⌘, switch to TextEdit, and dictate with the second ⌘
   there, then switch back to Messages: nothing is pasted — the newer dictation replaced it.
   Back in TextEdit, its text appears. Both results are in the history.
9. Hold ⌥ ⌘ with the second ⌘ in a password field (Safari's sign-in page, say): the result is
   copied — "Copied — press ⌘V." — and pasted nowhere.
10. Without the second key, ⌥ ⌘ behaves as in `dictation.md`: the overlay stays through
    "Transcribing…" and "Cleaning up…" and pastes where the focus is.

## Expected end state

Outloud brought no app to the front during the run; no message was sent; every dictated text is
in the history; the clipboard holds what it held before the run.
