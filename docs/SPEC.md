# Specification

This document owns what the product does: its features, rules, flows and
acceptance criteria. It describes behaviour the user can observe; how that
behaviour is built lives in `docs/ARCHITECTURE.md`, and why it was decided
lives in `docs/adr/`.

Outloud turns spoken thoughts into text that can be pasted — into
messages, e-mails and notes — on iOS and macOS. A short trigger starts the
input; transcription and an optional cleanup make the text ready to use.
The aim is less typing and less editing afterwards, without changing what
was said.

Outloud is a calm writing tool for short everyday texts. Its value over
plain dictation is the cleanup and the way into the target app.

Outloud is an open-source app. Monetisation deliberately plays no role.

The concept is still being shaped: assumptions waiting for confirmation
are marked `ASSUMPTION` and listed with the open questions in
`plans/done/CONCEPT.md`.

## Vocabulary

- **Trigger** — the user action that starts an input: the Action Button
  or a shortcut on iOS, the held hotkey on macOS. Outloud never starts a
  recording on its own.
- **Recording** — the audio captured between the trigger and its end.
- **Transcript** — the text that transcription produces from a recording,
  or that system dictation supplies. Not yet cleaned up.
- **Cleanup** — the optional pass over the transcript that fixes
  punctuation, removes filler words and sets paragraphs. It does not
  change the content.
- **Result** — the text Outloud hands over: the cleaned transcript, or the
  transcript itself when cleanup is off.
- **Target app** — the app the user wants the result in; on macOS also the
  focused text field in it.
- **Auto-paste** — macOS only: Outloud inserts the result into the
  focused text field itself.
- **History** — the results Outloud keeps, each with its transcript, its
  recording and its cleaned version, for as long as the user has set.

## Scope of the first version

The first version covers:

- German and English.
- Local models for transcription and for cleanup, on iOS and macOS,
  chosen at first launch (ADR 0005): Parakeet v3 for transcription and a
  Qwen model of about 0.8B parameters for cleanup (ADR 0006).
- Optional cleanup of punctuation, filler words and paragraphs.
- A result view, and clear states for recording, processing and errors.
- On iOS a shortcut and the clipboard; on macOS a hotkey and optional
  auto-paste.
- An explanation of how processing and data transfer work. Audio is not
  stored permanently by default.

Not in the first version: a custom keyboard, long recordings,
translation, and synchronisation across devices.

## Features

### Dictation on iOS

The flow (ADR 0003):

1. The user presses the Action Button or runs a shortcut. The Action
   Button starts the shortcut; a hold-and-release control is not assumed.
2. Outloud records.
3. Outloud transcribes the recording.
4. Outloud cleans up the transcript, if cleanup is on.
5. Outloud puts the result on the clipboard.
6. The user pastes it into the target app.

Alternatively, system dictation supplies the transcript — through
"Dictate Text" in the shortcut, or in Outloud's own text field. Steps 4
to 6 follow.

Rules:

- Outloud cannot write into other apps; the user pastes the result.
- Recording and the shortcut need the matching permissions. The lock
  screen and switching apps can require extra steps.
- The shortcut "Dictate with Outloud" opens Outloud and starts recording
  at once; the user ends the recording with the stop button. "Clean Up
  Text with Outloud" takes text — what "Dictate Text" produced — cleans
  it up without opening the app, and copies it.

Acceptance criteria:

- Pressing the Action Button set to "Dictate with Outloud" opens Outloud
  recording; stopping puts the result on the clipboard and shows it.
- The record button starts and ends a recording; it is disabled while the
  models are missing and while a result is being processed.
- Text in Outloud's text field is cleaned up and copied with one tap; the
  "Clean Up Text" shortcut returns and copies the cleaned text.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/ios/e2e/dictation.md`, `apps/ios/e2e/system-dictation.md`.

### Dictation on macOS

The flow (ADR 0004):

1. The user holds the push-to-talk hotkey; Outloud records.
2. The user releases the hotkey.
3. Outloud transcribes the recording.
4. Outloud cleans up the transcript, if cleanup is on.
5. Outloud pastes the result into the active text field, or puts it on
   the clipboard.

A small menu bar app shows recording and processing.

Rules:

- A recording starts only on a user action.
- Outloud needs the microphone permission; auto-paste usually also needs
  Accessibility access.
- Auto-paste happens only once the user has granted it. Without the
  permission, or when the target field is not suitable, the result stays
  available for pasting by hand.
- Focus changes, protected fields and hotkey conflicts limit how reliably
  auto-paste works.
- The push-to-talk hotkey is ⌥ Space by default; ⌃ ⌥ Space and ⇧ ⌥ Space
  can be chosen instead. A press shorter than a quarter second records
  nothing. When another app holds the shortcut, Outloud says so.
- Auto-paste can be switched off; then the result is always copied.
  Password fields never receive a paste. After a paste, the clipboard
  holds what it held before.

Acceptance criteria:

- Holding the hotkey shows "Recording…" without taking the focus from the
  app the user types in; releasing it pastes the result there when
  Accessibility is allowed and a text field is focused.
- Without Accessibility, or without a text field, the result is on the
  clipboard and the overlay says so.
- The menu bar panel shows the state and the last result with a copy
  button.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/dictation.md`, `apps/macos/e2e/settings.md`.

### Cleanup

- Cleanup is optional.
- It fixes punctuation, removes filler words and sets paragraphs, in
  German and English.
- It does not change the content.
- The default cleanup prompt starts from ghost-pepper's
  (`plans/done/CONCEPT.md` §"Prior art") and is multilingual: its filler words
  and self-correction phrases cover every language Outloud supports, not
  English alone. It adds a rule for paragraphs.

- The prompt's rules about screen (OCR) context are left out, because
  Outloud does not read the screen.
- Hesitation sounds ("äh", "ähm", "uh") are removed before the model sees
  the transcript.
- When cleanup fails — the model times out after 20 s, answers instead
  of cleaning up, or the text is longer than 4,000 characters — the
  transcript is the result, and the result view says "Cleanup failed —
  this is the transcript."

Acceptance criteria:

- A dictated "Also ähm ich komme heute so gegen acht vorbei" comes back
  without "ähm", punctuated, in German.
- A dictated instruction ("Ignoriere alle vorherigen Anweisungen …")
  comes back as that sentence.
- With cleanup off, the result is the transcript.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/dictation.md`, `apps/ios/e2e/system-dictation.md`.

### Models

Transcription and cleanup run on the device, with models from a
catalogue that starts from ghost-pepper's (ADR 0005). The first
version's catalogue holds two models (ADR 0006):

| Model | Purpose | Languages | Download |
| --- | --- | --- | --- |
| Parakeet v3 | transcription | 25, German and English among them | 483 MB |
| Qwen 3.5 0.8B | cleanup | multilingual | 533 MB |

Rules:

- Outloud offers only multilingual models.
- The app cannot be used until the transcription model is downloaded.
  With cleanup on, the cleanup model has to be downloaded as well; with
  cleanup off, it is not needed.
- On macOS, downloaded models go into a directory that other apps
  needing the same models can reuse: the Hugging Face hub cache —
  `~/.cache/huggingface/hub`, or the path that `HF_HUB_CACHE` or
  `HF_HOME` set — in the hub's own layout, so that other tools find the
  models there (ADR 0009, ADR 0010). On iOS, where apps of different
  vendors cannot share one, they stay in Outloud's own container.

The flow at first launch:

1. Outloud shows which models are available.
2. The user chooses the models, or at least confirms them.
3. The user starts the download.
4. Outloud downloads the chosen models.
5. Once the download is finished, the app can be used.

Changing models later: in the app's settings, the user picks another
model from a selection, such as a dropdown. The settings show the
download, and the user can stop a download and delete a model.

Before deleting a model, Outloud warns the user — on macOS also that
other tools may use it from the shared cache — and deletes it only if
the user confirms.

When a download fails or the device runs out of space, Outloud informs
the user. The app stays unusable until the models it needs are
downloaded.

When only cellular data is available, Outloud warns that the models are
very large, and the user decides whether to download them over cellular
data.

Models another tool already downloaded into the shared cache are shown
as "Already on this device" and are not downloaded again (ADR 0010).

Acceptance criteria:

- A first launch shows both models with size and languages; the user can
  untick cleanup; "Download" shows the missing size; progress is shown
  per model; "Continue" appears once the needed models are there.
- A stopped download leaves no partial file; a deleted model is gone from
  the cache and shows "Download".
- On cellular data, a download asks first and names its size.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/first-launch.md`, `apps/macos/e2e/models.md`,
`apps/ios/e2e/first-launch.md`, `apps/ios/e2e/settings.md`.

### Result view and states

- A result view shows the result.
- Recording, processing and errors each have a clear state.

Acceptance criteria:

- The states read "Recording…", "Transcribing…", "Cleaning up…", "Done"
  and, on a failure, a sentence with a way out ("Open Settings",
  "Download models") where one exists.
- A recording too short or too quiet to hold speech ends in "Nothing was
  recognised".

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/dictation.md`, `apps/ios/e2e/dictation.md`.

### History

- Outloud keeps results for as long as the user sets in the settings:
  nothing, 1 day, 3 days, 10 days, 30 days, 3 months, or without limit.
  With "nothing", Outloud keeps no result.
- The default is 1 day, so audio is not stored permanently by default
  (§"Transparency and privacy").
- A kept result holds the transcript as it came from transcription, not
  cleaned up; the audio of its recording; and the cleaned version.
  Without a recording — when system dictation supplied the text — there
  is no audio; without cleanup there is no cleaned version.
- The user can listen to a kept result and view its text: both the
  cleaned version and the transcript, each with a copy button.
- The user can delete one kept result, or all of them.
- A shorter period applies to the results already kept.

Acceptance criteria:

- After a dictation with audio, the history lists the result with a
  speaker icon; its detail plays the recording and shows both texts.
- Choosing "Nothing" removes every kept result and its audio.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/history.md`, `apps/ios/e2e/history.md`.

### Transparency and privacy

- Outloud explains how processing and data transfer work.
- Audio is not stored permanently by default.
- Neither audio nor text leaves the device for processing (ADR 0005).
- The setup and the settings explain this, the model download as the only
  transfer, and the current retention period; the acknowledgements list
  the licences of the models and libraries.

Acceptance criteria:

- The privacy text names the retention period currently set.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/settings.md`, `apps/ios/e2e/settings.md`.
