# The user listens to a kept result and reads its texts

- Covers: History tab, HistoryList, HistoryEntryDetail.
- Build: Debug; `-OutloudTab history` opens the tab directly.

## Preconditions

At least one dictation with audio was kept (`dictation.md`).

## Steps

1. Open the History tab. Results are listed newest first with date, time, a speaker icon and two
   lines of the result.
2. Tap the newest. The detail shows "Play", "Cleaned up" (if cleanup ran) and "Transcript".
3. Tap "Play": the recording plays; the button reads "Stop".
4. Go back and swipe the result left › "Delete": it disappears.
5. Settings › "Keep results for" › "Nothing": the History tab shows "No results kept".

## Assertions

- `<data container>/Library/Application Support/Outloud/History/index.json` lists exactly the
  shown entries; deleted entries have no WAV file left.

## Screen reader pass

Each row is read as one element; "Play"/"Stop" and the copy buttons have labels.
