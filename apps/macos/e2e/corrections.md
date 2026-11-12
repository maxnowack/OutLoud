# The user's corrections are applied to every dictation, and the Mac learns one from an edit

- Covers: Settings › Corrections (`docs/SPEC.md` §"Corrections", ADR 0039) — adding a pair and a
  term, the refusals, removing; a dictation corrected with cleanup on and off; learning a pair
  from an edit after a paste, its pill and its undo in the menu bar panel (ADR 0040); nothing
  learned from a password field, an edit of three words, or text written after the result.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  The app is started with `open`, so that macOS checks Outloud's own Accessibility access. Steps
  1–6 can run without the microphone: `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` with a
  recording that says "ich teste out loud" (`say -v Anna -o test.wav --data-format=LEI16@16000`).

## Preconditions

Setup completed (`first-launch.md`); Outloud allowed under System Settings › Privacy & Security ›
Accessibility; auto-paste on; the history keeps results; TextEdit open with an empty document; a
page with a password field open in Safari. The list of corrections is empty, or
`~/Library/Application Support/Outloud/Corrections.json` was moved aside.

## Steps

1. Open Settings › Corrections. "No corrections yet" is shown; "Add" is disabled.
2. Type "out loud" in "Heard as", press Return: the focus moves to "Write as". Type "Outloud" and
   press Return. The row "out loud → Outloud" appears with "Not used yet"; both fields are empty.
3. Add "Out  Loud" → "OutLoud": "This is already corrected." is shown and nothing is added. Add
   "x" → "<b>": "Use up to four words, without < or >." is shown.
4. Add the term "iPhone" with "Heard as" empty: the row shows "iPhone" alone.
5. With cleanup off, in TextEdit, dictate "ich teste out loud mit dem iphone". The text pasted
   is "ich teste Outloud mit dem iPhone"; in Settings both rows read "Corrected once"; the history
   shows "Outloud" in the transcript.
6. Turn cleanup on and dictate the same: the cleaned result holds "Outloud" and "iPhone"; the rows
   read "Corrected 2 times".
7. In TextEdit, dictate "Ich teste Outlout heute". After the paste, select "Outlout", type
   "Outloud" and wait. Within a few seconds the pill shows "Learned: “Outlout” → “Outloud”. Undo
   it in the menu bar.". Settings › Corrections lists "Outlout → Outloud" with "Learned · Not
   used yet".
8. Open the menu bar panel: "Learned: “Outlout” → “Outloud”" and "Undo" are shown. Click "Undo":
   the line goes, and the entry is gone from Settings.
9. Dictate "Ich teste Outlout heute" again, then replace the three words "teste Outlout heute"
   with "mag das nicht": nothing is learned. Dictate it once more and type " Und noch ein Satz."
   after it: nothing is learned.
10. In Safari, focus the password field and dictate: nothing is pasted (ADR 0004), nothing is
    learned.
11. Click "Remove" next to "iPhone": the row goes. Quit Outloud and open it again: the list is as
    it was left.

## Assertions

- Every dictation comes back with the corrections, with cleanup on and off.
- A refused entry says why and is not added.
- An edit of one word within 15 s is learned, shown in the pill and undone from the panel.
- Nothing is learned from a password field, an edit of three words, or text written after the
  result.
- The list and its use counts survive a relaunch.

## Screen reader pass

With VoiceOver on, in Settings › Corrections: the fields are read as "Heard as" and "Write as",
"Add" as a button that is dimmed while "Write as" is empty; adding announces "Correction added";
each row is read as one element — "out loud → Outloud, Corrected once" — followed by its
"Remove" button. In the menu bar panel, the learned line is read before its "Undo" button.
