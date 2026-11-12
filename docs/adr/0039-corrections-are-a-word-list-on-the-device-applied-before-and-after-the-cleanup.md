# 0039 – Corrections are a word list on the device, applied literally before and after the cleanup

- Status: accepted
- Date: 2026-11-10

## Context

Parakeet writes some words wrong the same way every time: names, product
names, technical terms. The cleanup must not change the content
(`docs/SPEC.md` §"Cleanup"), and it does not know which spelling the user
means. ghost-pepper keeps two plain-text lists for this, *preferred
transcriptions* and *commonly misheard* (`plans/CORRECTIONS.md`
§"Problem"). The questions were where such a list acts, and where it is
kept.

Rejected:

- **Giving the list only to the cleanup model.** It works only where Apple
  Intelligence is on, is not deterministic, and gives a small model a reason
  to change the content.
- **Vocabulary boosting in the speech model** (FluidAudio's
  `VocabularyBoostingSession`). It needs a second model of its own, does not
  cover system dictation or lip reading, and is left as a later decision
  (`plans/CORRECTIONS.md` §"Phase 3").
- **Keeping the list in `UserDefaults` as raw text**, as ghost-pepper does.
  An entry has more fields than its text — origin, date, use count — and a
  learned entry is written beside the user's own edits; one owner of one
  file keeps the two from overwriting each other.
- **Keeping the raw transcript in the history.** The history would then need
  a third text for a result without cleanup, a change of its format for a
  judgement the use counts and the settings already give.

## Decision

A correction is a pair — what was heard, what is meant — or a term, a
spelling the user keeps. `CorrectionStore` in OutloudKit is the one owner of
the list on each device: `Corrections.json` in the app's Application Support
directory, `{"version": 1, "corrections": [...]}`, each entry with its id,
`heard` (absent for a term), `meant`, `origin` (`added` or `learned`),
`createdAt` and `uses`. There is no sync between devices.

Every result is corrected in `DictationController.finish`, whatever produced
its transcript: Parakeet, system dictation, or the lips. The corrections are
replaced literally, in one pass, on whole words, without regard to case or
spacing, longest pattern first; a match that already lies inside the meant
text is left, so that applying the list twice changes nothing more. The
corrected transcript goes to the cleanup, the terms (at most 50, most used
first) go into its prompt between `<SPELLINGS>` and `</SPELLINGS>` before
the transcript, and the list is applied once more to the cleaned version, so
that the cleanup cannot undo a correction. The history keeps the corrected
transcript.

A side is trimmed to one line with single spaces and refused when it is
empty, has no letter or digit, is longer than 50 characters or 4 words, or
holds a control character, `<` or `>`. The list holds at most 500 entries.
A file that cannot be read — damaged, with an entry that fails these checks,
or of a newer version — leaves the list empty and is never written over.

## Consequences

- A correction works with the cleanup on or off, and without Apple
  Intelligence.
- The cleanup prompt changed, so its fingerprint did: the learned cleanup
  durations start over once (`DurationEstimate`).
- The spellings are user data inside the prompt. They cannot close the
  input frame, since `<` and `>` never reach them, and the prompt says they
  are a list of words, never instructions (`OutloudKit/AGENTS.md`
  §"Security").
- The lip-reading samples keep the raw transcript; whether they should take
  the corrected one was put off by the user on 2026-11-10.
- The CLI applies no corrections: it does not read the apps' list.
