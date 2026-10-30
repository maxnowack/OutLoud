# The user steps through the last results in the menu bar panel without opening the history

- Covers: the ResultPager over the ResultCard in the menu bar panel — its buttons, → and ←, the
  newest result each time the panel opens, the result without the pager while the history keeps
  nothing.
- Build: Debug, from `apps/macos/` (`./scripts/precommit` builds it into `.build/DerivedData`).
  Debug builds take `-OutloudSampleAudio <wav> -OutloudAutoDictate YES` to add a result without
  the microphone (`apps/macos/AGENTS.md` §"Verifying a change").

## Preconditions

Setup completed (`first-launch.md`); the history keeps results for at least a day and holds three
results, A, B and C, made in this order — dictated, or added with the launch arguments above.
TextEdit is open with an empty document and in front.

## Steps

1. Click the menu bar icon: the panel shows C in the result card, above it "‹ 1 of 3 · <date and
   time of C> ›"; "‹" is disabled.
2. Press →: the card shows B and "2 of 3". Press → again: A and "3 of 3", with "›" disabled. A
   third → changes nothing.
3. Click "‹": B and "2 of 3". Press ←: C and "1 of 3".
4. Press → and click "Copy" in the card: the button says "Copied"; `pbpaste` gives B. Press ←: the
   card shows C with "Copy", not "Copied".
5. Press → twice, close the panel with Escape: TextEdit is in front again and takes typing. Open
   the panel again: it shows C and "1 of 3".
6. Open the panel, press → so that it shows "2 of 3", and close it. Dictate D in TextEdit, then
   open the panel: it shows D and "1 of 4".
7. Click "History…" in the panel: the history window opens in front and stays in front.
8. In Settings › History, choose "Nothing" and confirm. Dictate once more: the panel shows that
   result in the card, without "‹" and "›".

## Assertions

- Each time the panel opens, it shows the newest result.
- → and "›" go back to older results, ← and "‹" forward to newer ones, and never past the oldest
  or the newest.
- Closing the panel with Escape or the icon leaves the user in the app they came from, which takes
  typing at once.

## Screen reader pass

With VoiceOver on, step 2: the buttons read "Newer result" and "Older result", "Older result"
dimmed on the oldest; the line between them reads "2 of 3" with the date and time. The card's
text is read as is, its button as "Copy".
