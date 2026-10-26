# The user holds the shortcut, speaks, releases, and the text lands in the active text field or on the clipboard

- Covers: push-to-talk hotkey, recording overlay, menu bar icon states, auto-paste, clipboard fallback, ResultCard in the menu bar panel.
- Build: Debug. The microphone-free branch uses the debug seam
  `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` (`apps/macos/Sources/AppModel.swift`).

## Preconditions

Setup completed (`first-launch.md`); microphone allowed. For the paste branch, Outloud is
allowed under System Settings › Privacy & Security › Accessibility; for the fallback branch, it
is not. TextEdit is open with an empty document focused.

## Steps

1. Hold the shortcut (⌥ ⌘; ⌥ Space without Accessibility access). The overlay — a glass
   capsule just as wide as its content — appears at the bottom of the screen with "Recording…"
   and a level meter; the menu bar icon turns into a record circle. TextEdit keeps the focus.
2. Say "Also ähm ich komme heute so gegen acht vorbei" and release.
   The overlay shows "Transcribing…", then "Cleaning up…" with a progress bar that moves from
   the start and fills only at the end, without standing at zero and jumping, then
   "Pasted" (paste branch) or "Copied — press ⌘V. Allow Accessibility to paste automatically."
   (fallback branch).
3. Paste branch: the cleaned text appears in TextEdit at the cursor; the clipboard holds what it
   held before step 1. Fallback branch: press ⌘V in TextEdit; the cleaned text appears.
4. Tap ⌥ Space for less than a quarter second. Nothing is recorded; the overlay disappears.
5. Focus a password field (e.g. the Keychain Access password prompt) and dictate. The result is
   not pasted: the overlay says "Copied — press ⌘V where you want the text."
6. Open the menu bar panel. It shows "Done" and the last result with a "Copy" button.
7. Without the microphone permission, hold the shortcut: the panel and overlay show "Outloud may
   not use the microphone…" with "Open Settings".
8. Hanging overlay: quit Outloud, run `tccutil reset Microphone dev.nowack.outloud`, launch it and
   leave its microphone dialog open. Hold the shortcut, release it, then click "Allow": no
   overlay stays, and the menu bar icon is the waveform, not the record circle. Hold the shortcut
   again: a recording starts and ends as usual.
9. Microphone-free check: quit Outloud, run
   `Outloud.app/Contents/MacOS/Outloud -OutloudSampleAudio OutloudKit/Samples/de.wav -OutloudAutoDictate YES -OutloudQuitAfterAutoDictate YES`.
   The process prints "OutloudAutoDictate: …", exits with status 0, and the clipboard holds the
   German sample's text.
10. Pausing playback: with "Pause playback while dictating" on, play a song in Music and dictate:
   the song pauses when the overlay appears and plays on after release. Play a video in Safari
   and dictate: the same. With nothing playing, dictate: nothing starts. Turn the setting off:
   the song keeps playing through a dictation.

## Assertions

- The result contains no "ähm"; the transcript in the history (`history.md`) still does.
- The process exits with status 0 on Quit.
- Do not assert the exact wording of the cleanup; the model may phrase punctuation differently.

## Screen reader pass

The overlay is not focusable and is not announced; the state change ("Recording…", "Done") is
announced through the StatusIndicator's announcement while the menu bar panel is open.
