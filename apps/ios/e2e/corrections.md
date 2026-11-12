# The user's corrections are applied to every dictation on the iPhone

- Covers: Settings › Corrections (`docs/SPEC.md` §"Corrections", ADR 0039) — adding a pair and a
  term, the refusals, deleting with a swipe; a dictation and a text from system dictation
  corrected.
- Build: Debug, from `apps/ios/` (`./scripts/precommit` builds it into `.build/DerivedData`). In
  the simulator, launch with `-cleanupEnabled NO` (it offers no Apple Intelligence) and dictate a
  file with `-OutloudSampleAudio <wav> -OutloudAutoDictate YES`, a recording that says "ich teste
  out loud" in the app's `tmp/`; read the result from the history's `index.json`.

## Preconditions

Setup completed (`first-launch.md`); the history keeps results; the list of corrections is
empty.

## Steps

1. Open the Settings tab: "Corrections" is listed below the transcription model with the footer
   "Words Outloud writes the way you write them.". Tap it: "No corrections yet" is shown; "Add"
   is disabled.
2. Type "out loud" in "Heard as", tap Return, type "Outloud" in "Write as", tap Return: the row
   "out loud → Outloud" appears with "Not used yet". The keyboard capitalised nothing and
   corrected nothing.
3. Add "x" → "<b>": "Use up to four words, without < or >." is shown. Add "OUT LOUD" → "x":
   "This is already corrected." is shown.
4. Dictate "ich teste out loud": the result on the clipboard and in the history is "ich teste
   Outloud"; the row reads "Corrected once".
5. On the Dictate tab, use "Type text instead" with "ich teste out loud": the result is "ich teste
   Outloud".
6. Swipe the row to the left and delete it: "No corrections yet" is shown. Quit the app and open
   it again: the list is still empty.

## Assertions

- Every result comes back with the corrections, from a recording and from typed or system
  dictation text.
- A refused entry says why and is not added.
- A deleted entry stays deleted after a relaunch.

## Screen reader pass

With VoiceOver on: "Corrections" is read as a button leading to the list; the fields are read as
"Heard as" and "Write as"; adding announces "Correction added"; each row is read as one element
with its use count, and the rotor offers "Delete" on it.
