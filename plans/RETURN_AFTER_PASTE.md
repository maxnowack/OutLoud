# Pressing Return after a paste in the apps the user chose

## Status

In progress: approved on 2026-11-05 (ADR 0036); setting, Return, settings
section and documents built; the end-to-end run in Claude open.

## Problem

In a chat app such as Claude the user dictates a message and then always
presses Return to send it. Outloud pastes the text but must not post any
key but ⌘V (ADR 0026, ADR 0027), so the last step is always the user's.

## Goal

The user lists apps in the settings. A dictation that Outloud pastes into a
text field of a listed app is followed by one Return, so the message is
sent; in every other app, and whenever the result is only copied, nothing
changes.

## Approach

Decided with the user on 2026-11-05:

- One plain Return, no per-app key (⌘Return and the like are not offered
  until an app needs them).
- The same for a dictation pasted on the return to its field (ADR 0027):
  the paste and the Return follow each other there too.
- No key to skip the Return for a single dictation.

The list is the apps' bundle identifiers in `OutloudSettings`
(`submitAfterPasteApps`), empty by default. The app reads the focused field
before the paste, and after a `.pasted` delivery into a listed app it waits
until the target has handled the ⌘V, checks that the same field — element
and identity — still has the focus while its app is in front and no
recording has started, and only then posts Return
(`AutoPaster.postReturn`). Where any check fails, nothing is posted.

Alternatives considered:

- Posting Return right after ⌘V without a wait: the target reads the
  clipboard asynchronously (the restore waits 600 ms for that reason), so
  the Return could send the message before the text is in it.
- Choosing apps from the running ones: misses an app that is not open
  while the user sets it up; the file dialog on the applications folder
  covers every app.

## Phases

### 1. Decision and setting

DoD: ADR 0036 accepted and the security rule in `apps/macos/AGENTS.md`
matches it; `OutloudSettings.submitAfterPasteApps` survives a new instance, and
a test says so and that an unlisted app is not submitted.

### 2. Return after the paste

DoD: in a listed app the pasted dictation is sent; in an unlisted app it is
only pasted; a copied result gets no Return.

### 3. Settings section, German strings, documents

DoD: apps can be added and removed in the settings, shown with name and
icon; every new string has its German translation; `docs/SPEC.md`,
`docs/DESIGN.md` and `apps/macos/e2e/return-after-paste.md` describe it;
`./scripts/precommit` passes in `OutloudKit/` and `apps/macos/`.

### 4. End-to-end run

DoD: `apps/macos/e2e/return-after-paste.md` executed with the user in
Claude, and the wait before the Return recorded in ADR 0036 with the date.

## Risks

- The Return lands in another field than the paste: excluded by the second
  focus check right before it is posted.
- An app handles ⌘V slower than the wait: the message would go out before
  the text is in it. The wait is measured in phase 4.

## Open questions

None.
