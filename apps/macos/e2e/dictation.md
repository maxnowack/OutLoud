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
   above a red line that takes the shape of the voice — a steady wave on a held vowel, a tremble on an "s" — and lies flat in silence; the background shows through the capsule; the menu bar icon turns into a record circle. TextEdit keeps the focus.
2. Say "Also ähm ich komme heute so gegen acht vorbei" and release.
   The line lies flat; the overlay shows "Transcribing…" — skipped when it takes less than a
   quarter second, as for a short sentence on most Macs —, then "Cleaning up…", each with a
   ring that fills from the start and only at the end, without standing at zero and jumping,
   with the seconds left inside it counting down — never up, and gone once the step takes
   longer than expected —,
   then "Pasted" (paste branch), as the text appears in TextEdit, or "Copied — press ⌘V. Allow Accessibility to paste
   automatically." (fallback branch). Each change fades the content out, resizes the capsule
   about its middle and fades the new content in, with nothing reaching past the edge; between two
   contents about as wide — within 12 pt — it swaps them in a quick dip without an empty
   capsule, and a narrower content — "Pasted" after "Cleaning up…" — fades in while the
   capsule shrinks, without an empty capsule. Every capsule has its middle on the same line,
   whatever its height: the taller "Recording…" capsule reaches as far below "Pasted" as above
   it, and does not share its bottom edge.
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
   the song pauses when the overlay appears and plays on after release; the first time, macOS
   asks to allow recording system audio. Play a video in Helium or Safari and dictate: the
   same. With nothing playing, dictate: nothing starts — also with a browser tab open that
   played a sound shortly before. With a call or a video that does not pause, dictate: it keeps
   sounding, the overlay says "Something is playing in the background", and nothing starts
   after release. With recording system audio declined, the song pauses and stays paused, and
   Settings show "Recording system audio" with "Allow…". Turn the setting off:
   the song keeps playing through a dictation.
11. Another microphone: dictate once, then connect AirPods (or choose another input under
   System Settings › Sound › Input) and dictate again; disconnect them and dictate once more.
   Each dictation records and is transcribed, the log of `dev.nowack.outloud` holds no
   "Format mismatch" from AVFAudio, and clicking the menu bar icon afterwards opens the panel —
   the app does not crash.
12. Two sentences in a row starting with "also": dictate "Wichtig ist, dass diese Aufgabe
   getauscht werden kann und dann muss die Aufgabe, die gerade getauscht wurde, abgeschlossen
   sein. Also das ist dann quasi so eine. Also da kommt dann keine neue Aufgabe, sondern die
   Aufgabe ist einfach abgeschlossen." The result holds every sentence once, the last one
   included, and neither starts with "Also"; no sentence is repeated.
13. Softening words: dictate "Ich hab das halt quasi schon gemacht" and "It is sort of done and
   kind of works". The results keep "quasi schon", "sort of" and "kind of".
14. Typing while ⌥ ⌘ is held (ADR 0029): hold ⌥ ⌘ in TextEdit, wait a second, and type
   "Hallo Welt" with Space and ⇧ while saying a sentence, then release. "Hallo Welt" appears as
   typed, no Finder search window opens, the overlay keeps recording while typing, and the
   dictation is pasted after release. Repeat in Helium and in Claude: the same. Hold ⌥ ⌘ and
   press ⇧ or D at once: the recording is cancelled and ⌥ ⌘ D reaches the app. Hold ⌥ ⌘, wait a
   second and press ⌃: the recording is cancelled. After release, Space and ⌘ shortcuts work as
   usual.

## Assertions

- The result contains no "ähm"; the transcript in the history (`history.md`) still does.
- The process exits with status 0 on Quit.
- Do not assert the exact wording of the cleanup; the model may phrase punctuation differently.

## Screen reader pass

The overlay is not focusable and is not announced; the state change ("Recording…", "Done") is
announced through the StatusIndicator's announcement while the menu bar panel is open.
