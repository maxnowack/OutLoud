# The user listens to a kept result and reads its texts

- Covers: History window, HistoryList, HistoryEntryDetail, retention.
- Build: Debug.

## Preconditions

At least one dictation was made with retention "1 day" (`dictation.md`).

## Steps

1. Menu bar panel › "History…". The window lists results newest first: date, time, a speaker
   icon, two lines of the result.
2. Select the newest result. The detail shows "Play", "Cleaned up" with the cleaned text and
   "Transcript" with the uncleaned transcript, each with a copy button.
3. Click "Play": the recording plays and the button reads "Stop"; it returns to "Play" at the end.
4. Right-click the result › "Delete": it disappears; its WAV file is gone from
   `~/Library/Application Support/Outloud/History/`.
5. Settings › History › "Keep results for" › "Nothing". The history window shows "No results
   kept" and "Outloud keeps no results…"; the History folder holds only `index.json`.

## Assertions

- `index.json` lists exactly the entries the window shows.
- Do not assert dates.

## Screen reader pass

Each row is read as one element (date, "With audio", the text); the copy buttons are read as
"Copy Cleaned up" and "Copy Transcript".
