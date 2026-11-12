# 0040 – The Mac learns a correction by reading the field it just pasted into

- Status: accepted
- Date: 2026-11-10
- Extends: ADR 0004 (what the Accessibility access is used for), ADR 0039

## Context

A correction list the user has to fill by hand stays short. ghost-pepper
learns from the user's edit after a paste: it reads the focused field
through Accessibility for 15 s and appends a change of up to 2 words to its
list, without saying so (`plans/CORRECTIONS.md` §"Problem"). Outloud holds
the Accessibility access for auto-paste only (ADR 0004); reading the text of
another app's field is a new use of it, and a new trust boundary: the text
read is written by the user, by the app, or by a web page in it.

Rejected:

- **Learning without saying so.** A wrong pair would then silently change
  every later result.
- **Asking before each learned pair.** It interrupts the writing it is meant
  to spare; the user decided on 2026-11-10 that a learned pair applies at
  once.
- **Learning on iOS.** Outloud hands its result over through the clipboard
  and never sees the target field (ADR 0003).

## Decision

After Outloud pasted a result with ⌘V, `PasteObserver` reads the value of
the field it pasted into — 0.7 s after the paste, then once a second for up
to 15 s — and only while that field, element and identity, has the focus
and its app is in front (`AutoPaster.text(of:)`). It never reads a password
field, nor a field longer than 20,000 characters, and stops at the next
press of the hotkey or when the field loses the focus. Once the text has not
changed for 2 s, `CorrectionLearning.pair` compares it with the text right
after the paste, and a pair is learned only when:

- one run of one or two words was replaced by one or two others, not words
  added or removed, and not only case or punctuation changed;
- the replaced words lie inside the pasted result;
- the pair passes the checks of ADR 0039, no entry already corrects the
  heard words, and it would not undo an entry.

The learned pair applies at once. The recording pill says "Learned: “x” →
“y”", the menu bar panel offers "Undo" until the next dictation, and the
settings mark it as learned.

The texts read are held in memory for the comparison only, never logged and
never kept; only the learned pair is written, to the list.

## Consequences

- Reading the field is threat-modelled here: the caller is Outloud itself,
  on its own paste; what it accepts is a string bounded in size; what it
  must never do is read another field, a password field, or keep or log
  what it read. Text a page writes into the field could teach a pair; the
  checks bound it to two words inside the pasted result, it is shown and
  undoable, and it cannot reach the prompt as an instruction (ADR 0039).
- A field whose value Accessibility does not expose — some Electron and web
  editors — teaches nothing; the list still works.
- An app's own autocorrection within the 15 s counts as the user's edit.
- The macOS area rules name this use of the Accessibility access
  (`apps/macos/AGENTS.md` §"Security").
