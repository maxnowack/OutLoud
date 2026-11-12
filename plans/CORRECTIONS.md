# Words Outloud keeps getting wrong are corrected, from a list the user keeps and the Mac learns

## Status

In progress (2026-11-10): phases 1 and 2 are built (ADR 0039, ADR 0040) and pass the unit tests
and `./scripts/precommit` in all three units. Descoped by the user on 2026-11-10: the runs of
`apps/macos/e2e/corrections.md` and `apps/ios/e2e/corrections.md` against the apps ("keine e2e
tests"); the plans stay for a later run, and the behaviour is proven by the unit tests only.
Phase 3 is a decision after two weeks of use and
cannot be taken earlier.

Deviations from the approach below, decided while building on 2026-11-10:

- The history keeps the *corrected* transcript, not the raw one. Keeping the raw one would have
  needed a third text in the history's format for results without cleanup; the use counts and the
  settings already show what an entry does (ADR 0039).
- An entry is not edited in place: the user removes it and adds it anew.
- The pill cannot take a click (it ignores the mouse so as not to block the app beneath), so it
  only says what was learned; the undo is in the menu bar panel, until the next dictation.
- The CLI applies no corrections: it does not read the apps' list.

Decided by the user on 2026-11-10:

- Lip-reading training samples keep the raw transcript for now. The question is not closed, only
  put off.
- The interface calls the feature "Corrections" / "Korrekturen".
- Learned pairs apply at once, with a notice and an undo.

## Problem

Parakeet writes some words wrong the same way every time: names, product names, technical terms,
words the user spells their own way. Cleanup cannot fix them. It must not change the content
(`docs/SPEC.md` §"Cleanup"), and it does not know which spelling the user means. Today the user
fixes the same word by hand after every dictation, and the history keeps the wrong word.

Prior art: ghost-pepper (`plans/done/CONCEPT.md` §"Prior art"), checked on 2026-11-10 in
`GhostPepper/Cleanup/CorrectionStore.swift` and `PostPasteLearningCoordinator.swift` on
github.com/matthartman/ghost-pepper:

- Two plain-text lists in its settings: *preferred transcriptions* (one term per line) and
  *commonly misheard* (`wrong -> right` per line). Both are stored as raw text in `UserDefaults`.
- After a paste it polls the focused field through Accessibility, once a second for up to 15 s.
  Once the text has been unchanged for 2 s, it compares the text with what was pasted, by the
  common words before and after the change. A change of at most 2 words on each side, not only
  punctuation, whose wrong side appears word for word in the pasted text, is appended to
  *commonly misheard* without asking.
- Not checked: whether it replaces literally, gives the list to the language model, or both.

## Goal

- The user keeps a list of corrections on each device, in the settings of both apps. Each entry
  is either a pair (*heard* → *meant*) or a single term (*how a word is written*).
- Every result is written with the corrections, whatever produced its transcript: Parakeet,
  system dictation on iOS, or lip reading on the Mac. This holds with cleanup on or off, and with
  Apple Intelligence missing.
- On the Mac, when the user changes a word or two of a pasted result in its field within a few
  seconds, Outloud learns that pair, says so, and the user can take it back.
- Each entry shows how often it has corrected a result. That is the user's sign that an entry
  works, and the measurement for this plan (§"Phases").
- Nothing in the list, and no text read from a field, is logged or leaves the device.

## Approach

### Where the corrections apply

A new step in `DictationPipeline` runs after transcription and before `HesitationFilter` and the
cleanup. Pairs are replaced literally, case-insensitively, on word boundaries, longest *heard*
first, and *meant* is written exactly as entered. The cleanup model then sees the right word. The
single terms and the *meant* sides of the pairs go into the cleanup prompt as a list of
spellings to keep. They are marked as data, like the transcript (`OutloudKit/AGENTS.md`
§"Security"). After the cleanup the pairs run once more, so that the model cannot undo a
correction (for example, writing a term the user keeps as one word as two).

- The history keeps the transcript as it came from transcription, as it does today, and the
  corrected result. A correction can then be judged, and a wrong entry undone, against the raw
  text.
- `DictationPipeline.isUsable` compares the cleanup with the corrected transcript. A correction
  must never count as a dropped passage.

Rejected:

- **The list only in the cleanup prompt**, as the model's job. This works only with Apple
  Intelligence on, is not deterministic, and gives a small model a reason to change content.
- **Vocabulary boosting in the speech model only** (phase 3). It needs a second model, and it
  does not cover system dictation.

### Storage

One type in `OutloudKit` owns the list (`Corrections`). No other code reads or writes it
(`OutloudKit/AGENTS.md` §"Persistence"). The list is a versioned JSON file in the app's support
directory, one per device, with no sync. Each entry has its kind, its text, its origin (*added*
or *learned*), its creation date and its use count. A file and not `UserDefaults` because the
entries carry fields beyond the raw text, and because a learned entry has to be written beside
user edits without one overwriting the other. This is a new persistence format: **ADR 0039**.

### Learning on the Mac

After an auto-paste, `AutoPaster` already knows the field and its identity
(`apps/macos/Sources/AutoPaster.swift:193`) and holds the Accessibility permission. A new
`PasteObserver` reads that field's value once a second for up to 15 s, only while the same field
of the same app has focus. Once the text has been unchanged for 2 s, it diffs it against the
value after the paste. It learns at most one pair per dictation, under ghost-pepper's limits
(≤ 2 words each side, not only punctuation or case, the heard side present in the pasted
result) plus these:

- Never from a secure text field (`AXSecureTextField`) or a field whose value cannot be read.
- Never when the change lies outside the pasted range: that is the user writing on, not
  correcting.
- Never a pair that a list entry already covers, and never one that would undo an entry.

The learned pair applies at once. The pill or the panel says "Learned: *heard* → *meant*" with an
undo. In the settings, learned entries carry a mark. Reading the text of another app's field is a
new trust boundary: **ADR 0040**. Its review covers what is read, how long it is kept (memory
only, until the diff), and that it is never logged.

Rejected:

- **Learning without saying so**, as ghost-pepper does. A wrong pair would then silently change
  every later result.
- **Asking before every learned pair.** This interrupts the writing it is meant to spare.
- **Learning on iOS.** Outloud hands over through the clipboard and cannot see the target field
  (ADR 0003).

### Vocabulary boosting (phase 3, not decided)

FluidAudio 0.17.7, the pinned version, has `VocabularyBoostingSession`: CTC keyword spotting with
a second model (parakeet-ctc-110m) over the audio, then rescoring of the transcript. It could
catch the words that Parakeet writes differently each time, where a literal pair cannot help. It
costs a model download with pinned hashes (ADR 0014), an ADR, and extra time per dictation. It
is worth deciding only if phases 1 and 2 leave measurable misses (§"Phase 3").

## Phases

### Phase 1 — The list, applied to every result (macOS and iOS)

- `Corrections` in `OutloudKit`: load, save, add, delete, apply and count uses. Unit tests for:
  word boundaries ("Outloud" is not touched inside "Outloudness"), case, multi-word pairs,
  longest first, no chained replacement, a corrupt or newer file version (read nothing, overwrite
  nothing), and use counts.
- The step in `DictationPipeline`, before and after cleanup, and the terms in `CleanupPrompt`.
  Tests: a pair applies with cleanup off; a cleanup that undoes a pair is corrected again; a term
  list that reads like an instruction does not change the prompt's rules; `isUsable` passes after
  a correction.
- The settings section in both apps (`OutloudUI`), in German and English, with the states that
  `docs/DESIGN.md` requires: add a pair or a term, edit, delete, see origin and use count, and an
  empty state that explains the feature.
- `docs/SPEC.md` gets a §"Corrections" with acceptance criteria and a *Corrections* entry in
  §"Vocabulary". `docs/ARCHITECTURE.md` describes the step and the file. ADR 0039 is written.
  New e2e plans are added: `apps/macos/e2e/corrections.md` and `apps/ios/e2e/corrections.md`.

DoD: with the pair *out loud* → *Outloud*, a dictated "ich teste out loud" comes back as
"ich teste Outloud", with cleanup on and off, on the Mac and the iPhone. The entry's use count
then reads 1. Both e2e plans have been run against the apps. `./scripts/precommit` passes in all
three units.

### Phase 2 — Learning from the user's edits on the Mac

- `PasteObserver` in the macOS app, with the diff as a pure function in `OutloudKit` that the unit
  tests cover. Tests: a one-word fix learns; a fix of three words, a punctuation-only change,
  writing on after the result, a fix in a secure field, and an edit after 15 s learn nothing; an
  undo removes the pair.
- The notice with its undo, in the pill or the panel.
- ADR 0040 with the trust-boundary review, class by class. `docs/SPEC.md`,
  `docs/ARCHITECTURE.md` and `apps/macos/e2e/corrections.md` are extended.

DoD: pasting a dictation into TextEdit and changing one wrong word within 15 s adds the learned
pair, and the notice shows it. The next dictation of that word comes back corrected. Undo removes
the pair. In a password field nothing is learned. `./scripts/precommit` passes in `OutloudKit`
and `apps/macos`.

### Phase 3 — Decision on vocabulary boosting

After two weeks of use with phases 1 and 2: the user names the words that the list still does
not fix. If they are words Parakeet writes differently each time, boosting gets its own plan,
with the model's size and the time it adds measured. Otherwise this phase is closed with that
finding.

## Risks

- **A wrong pair changes every later result.** Mitigation: the learning limits, the notice with
  undo, origin and use count in the settings, and the raw transcript in the history.
- **A pair that is also an ordinary word** ("Max" → "max" in some other sentence). Mitigation:
  word boundaries and case as entered, and pairs are added on purpose. The e2e plan covers a term
  that is also a common word.
- **Reading another app's field.** Mitigation: only the field Outloud just pasted into, for 15 s,
  never a secure field, held in memory only, never logged (`OutloudKit/AGENTS.md` §"Logging"),
  and ADR 0040.
- **Apps whose fields Accessibility cannot read** (some Electron and web fields). Then nothing is
  learned. The list still works, and the e2e plan names the apps that were tried.

## Open questions

None. The three questions of 2026-11-10 are answered in §"Status".
