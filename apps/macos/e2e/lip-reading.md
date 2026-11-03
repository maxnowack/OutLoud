# The user dictates without sound by reading the lips, and Outloud learns from their dictations

- Covers: Settings › Lip Reading, the silent practice sheet, dictation with the camera
  (`docs/SPEC.md` §"Lip reading on macOS", ADR 0034).
- Build: Debug, or the release download.

## Preconditions

Setup completed; a camera in front of the user, in good light; TextEdit open with an empty
document. Samples deleted before the run (Settings › Lip Reading › "Delete Samples…").

## Steps

0. Delete the model if it is installed (`swift run outloud delete outloud-lipreading` from
   `OutloudKit/`). Settings › Lip Reading: the first section is headed "Experimental" with its
   note, and shows "Auto-AVSR", "Lip reading · 610 MB · German, English" with Download. Click
   it: the progress grows to 610 MB, Stop cancels it, Download again finishes with a checkmark;
   "Next learning" no longer says "When the model is installed".
1. Settings › Lip Reading: "Read the lips" is "Off" and "Learn from my dictations" is off.
   Dictate a sentence aloud in TextEdit: the result is pasted, and the camera's green light and
   the menu bar's camera indicator never come on. "Accuracy" says "Not measured yet", "Last learned" "Not yet",
   and "Next learning" how many more samples it waits for.
2. Turn "Learn from my dictations" on, keep "Off", language "English". The first time, macOS
   asks for the camera, with the text that only a small picture of the mouth is kept. Allow it.
   Dictate a sentence aloud: the camera light is on only while the shortcut is held, the
   sentence is pasted as Parakeet hears it, and "Samples kept" grows by one.
   Dictate "Bitte schick mir den Bericht bis Freitag" aloud: "Language" changes to "German",
   and the sample counts are German ones. Dictate "Okay." aloud: "Language" stays, and no
   sample is kept. Dictate an English sentence aloud: "Language" is "English" again.
   Choose "When there is no sound".
3. Hold the shortcut and say "Please send me the report by Friday" aloud: the camera light is on
   only while the shortcut is held; the sentence is pasted as Parakeet hears it. "Samples kept"
   grows by one, none of them silent, by about 1 MB.
4. Hold the shortcut and mouth "Thank you very much" without sound: the overlay shows the
   transcription, and a text is pasted — read from the lips, not empty.
5. Choose "Always, without sound" and mouth "I will call you back after lunch": a text is
   pasted; dictating aloud also pastes the lips' reading, not Parakeet's.
6. Cover the camera and mouth a sentence: the overlay says nothing was recognised.
7. "Practise Silently…": the sheet shows "Sentence 1 of 40" and an English sentence. The camera
   light is off. Click Start: it comes on; mouth the sentence, click Done: it goes off, and the
   sheet shows sentence 2. Click Start, then Close: the camera light goes off. Settings shows
   one silent sample more.
8. Choose language "German": the sentences of the practice are German; without the German model,
   the footer says it is not installed.
9. With at least 10 English samples, "Learn Now": "Learning from your samples…" with a spinner,
   then either "Learned: words misread fell from … to …" or "Nothing learned this time: …".
   With fewer samples: "More samples are needed to learn from."
10. "Delete Samples…", confirm "Delete All": the count is 0 and the size zero bytes.
11. Choose "Off" and dictate aloud: the camera light comes on while the shortcut is held
    (learning is on). Turn "Learn from my dictations" off and dictate again: it stays off.
12. With at least 10 new samples since the last learning, the Mac on its power adapter: leave
    mouse and keyboard alone for 10 minutes, then open the settings without touching anything
    else first — "Learning from your samples…" shows, or its result. Start another such run and
    move the mouse: the spinner goes away within a few seconds, and the earlier result stays.
13. After a learning, "Accuracy" shows its share with "good enough from 70 %", or "good enough
    to use"; "Last learned" says when and from how many samples, and "Next learning" waits for
    10 more. The first time the accuracy passes 70 %, one notification "Lip reading is ready"
    comes; later learnings bring none.
14. With 10 new German samples while "Language" is "English", leave the Mac idle as in step 12:
    the German samples are learned from, and "Language" "German" shows "Last learned" from then.

## Assertions

- `defaults read dev.nowack.outloud lipReadingAnnounced.en` is 1 after step 13's notification,
  and no key `lipReadingError.*` is left after step 10.
- `defaults read dev.nowack.outloud lipReading` is the chosen mode;
  `lipReadingLanguage` the chosen language.
- `~/Library/Application Support/Outloud/LipReading/Samples/` holds one `.lips` and one `.json`
  per sample, and is empty after step 10; `Adapters/` is empty after step 10.
- `log show --predicate 'subsystem == "dev.nowack.outloud" AND category == "lipreading"' --last
  10m` holds frame counts and durations, never a dictated word.

## Screen reader pass

Every control of the tab and the sheet has a label; the learning's result is read as text.
