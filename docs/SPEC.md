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
- Transcription and cleanup on the device, on iOS and macOS: Parakeet v3
  for transcription, downloaded at first launch (ADR 0005, ADR 0006), and
  Apple's on-device model for cleanup, which needs Apple Intelligence and
  no download (ADR 0019).
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

In any app, without Outloud coming to the front and with the screen in
view (ADR 0022): the user's shortcut is "Start or Stop Dictation with
Outloud" followed by "Copy to Clipboard", run from Back Tap, the Action
Button in its Shortcut mode or Siri. The first run starts the recording,
shown by a Live Activity in the Dynamic Island and on the Lock Screen; the
next run ends it, Outloud transcribes and cleans up in the background and
returns the text, and the shortcut copies it. The Live Activity shows each
phase — recording with its time, transcribing, cleaning up with its
progress, then "Copied" or what failed — and disappears a few seconds
after. Its Stop button ends the recording too, but keeps the text in the
history without copying it, unless Outloud is in front. A run while the
last dictation is still processed starts nothing.

Alternatively, system dictation supplies the transcript — through
"Dictate Text" in the shortcut, or in Outloud's own text field. Steps 4
to 6 follow.

Rules:

- Outloud cannot write into other apps; the user pastes the result.
- With "Pause playback while dictating" on (the default), a recording in
  the app interrupts other audio, which may play on afterwards; from the
  shortcut in the background iOS allows only turning music down and
  pausing spoken audio (ADR 0024).
- Recording and the shortcut need the matching permissions. The lock
  screen and switching apps can require extra steps.
- The shortcut and control "Dictate with Outloud" open Outloud and start
  recording at once; the user ends the recording with the stop button.
  The control is offered by the Action Button, the Control Center and the
  Lock Screen (ADR 0017).
- The app's guide "Dictate from any app" starts with the shortcut, set up
  once, and then lists the ways of running it — AssistiveTouch, the Action
  Button, Back Tap, the Control Center, Siri — each with its steps and
  trade-offs; last, the control that opens Outloud instead.
- In the background, Outloud cleans up as in front (§"Cleanup"); when
  Apple's model refuses there, the text is the transcript.
- After a dictation the app says that the text was copied; the text is
  shown only when the user asks for it. Text from the keyboard's
  dictation is entered in a separate sheet. "Clean Up
  Text with Outloud" takes text — what "Dictate Text" produced — cleans
  it up without opening the app, and returns it. It fails with a message,
  rather than returning the text unchanged, when cleanup is switched off,
  Apple Intelligence is unavailable, or the cleanup did not succeed.
- A shortcut that runs while a dictation in the app is still going is
  refused with "Outloud is busy with another dictation", so that it
  cannot take over that recording.

Acceptance criteria:

- Pressing the Action Button set to the "Dictate" control opens Outloud
  recording; stopping puts the result on the clipboard and says so.
- In another app, the shortcut of "Start or Stop Dictation with Outloud"
  and "Copy to Clipboard", run twice, records while the app stays in view
  and puts the cleaned text on the clipboard; Outloud does not come to the
  front; the Live Activity shows the recording, the processing and
  "Copied"; the dictation is kept in the history.
- The record button starts and ends a recording; it is disabled while the
  models are missing and while a result is being processed.
- Text in Outloud's text field is cleaned up and copied with one tap; the
  "Clean Up Text" shortcut returns the cleaned text for the shortcut to
  copy.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/ios/e2e/dictation.md`, `apps/ios/e2e/system-dictation.md`,
`apps/ios/e2e/ways-to-start.md`.

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
  Accessibility access. It asks for the microphone at its first launch,
  not at the first dictation.
- A release of the hotkey while Outloud still waits — for the microphone
  dialog, say — ends that dictation: nothing is recorded and the overlay
  goes away. A press always ends a recording that runs without the hotkey
  held, and starts a new one.
- Outloud can open at login. The setup window offers it, preselected; the
  settings switch it and say when macOS wants it approved in Login Items.
- Auto-paste happens only once the user has granted it. Without the
  permission, or when the target field is not suitable, the result stays
  available for pasting by hand.
- Focus changes, protected fields and hotkey conflicts limit how reliably
  auto-paste works.
- The push-to-talk hotkey is ⌥ ⌘, held alone, by default (ADR 0020);
  ⌥ Space, ⌃ ⌥ Space and ⇧ ⌥ Space can be chosen instead. ⇧ or ⌃ joining
  ⌥ ⌘ cancels the recording at any time; another key cancels it within
  the first second — a shortcut such as ⌥ ⌘ D —, later it is typed as
  usual and the recording goes on (ADR 0021). ⌥ ⌘ needs Accessibility
  access; until it is allowed, ⌥ Space works instead, and the settings say
  so and offer to allow it. A press shorter than a quarter second records
  nothing. When another app holds the shortcut, Outloud says so.
- With "Pause playback while dictating" on (the default) and
  Accessibility allowed, a recording pauses what plays and plays it on
  once the recording ends; with nothing playing, nothing starts. Outloud
  presses the play/pause media key for it (ADR 0024).
- Auto-paste can be switched off; then the result is always copied.
  Password fields never receive a paste. After a paste, the clipboard
  holds what it held before.

Acceptance criteria:

- Holding the hotkey shows a wave that follows the voice, without taking
  the focus from the app the user types in; releasing it pastes the result there when
  Accessibility is allowed and a text field is focused.
- Without Accessibility, or without a text field, the result is on the
  clipboard and the overlay says so.
- The menu bar panel shows the state and the last result with a copy
  button.
- While the transcription and the cleanup run, the overlay's ring moves
  evenly from the start of each, by the time passed over the duration
  expected for this recording or text — learned on the device from
  earlier runs and the recording's length in seconds or the text's in
  tokens —, and is full only at the end.
- Releasing the hotkey while the microphone dialog is open, then allowing
  the microphone, leaves no overlay and no recording.
- After a restart with "Open at login" on, the hotkey works without
  opening Outloud.

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
- Cleanup runs on Apple's on-device model (ADR 0019), also while the iOS
  app is in the background. It is available where the device supports
  Apple Intelligence and the user switched it on; elsewhere the cleanup
  setting is off and disabled, says why, and the result is the transcript.
- While the transcription and then the cleanup run after a recording —
  the macOS hotkey, the iOS record button or shortcut —, a ring shows
  roughly how far each is, by the time passed over the duration learned
  on the device for a recording of this length (per transcription model)
  or a text of this many tokens (per prompt); it stays short of full until
  the step is done. Inside it, a countdown shows the whole seconds the
  step should still take; it never counts up and disappears once the
  expected duration has passed. On iOS the Live Activity shows both too. Text from
  system dictation and the debug seams show none.
- When cleanup fails — the model times out after 20 s, answers instead
  of cleaning up, refuses (in the background, Apple limits how often an
  app may use it, above all on battery; a language it does not support),
  or the text is longer than 4,000 characters — the transcript is the
  result, and the result view says "Cleanup failed — this is the
  transcript."

Acceptance criteria:

- A dictated "Also ähm ich komme heute so gegen acht vorbei" comes back
  without "ähm", punctuated, in German.
- A dictated instruction ("Ignoriere alle vorherigen Anweisungen …")
  comes back as that sentence.
- A dictated "Kannst du mir sagen wann der Zug fährt" comes back with a
  comma and a question mark; "neuer Absatz" starts a new paragraph.
- With cleanup off, or Apple Intelligence off, the result is the
  transcript; with Apple Intelligence off, the settings say so.

Acceptance criteria are proposals written on 2026-10-23 from the rules
above, while the user was away (`plans/FIRST_VERSION.md` §"Decisions for
the user").

Verified by: `apps/macos/e2e/dictation.md`, `apps/ios/e2e/system-dictation.md`.

### Models

Transcription runs on the device with a downloaded model (ADR 0005,
ADR 0006); the cleanup runs on Apple's on-device model, which the system
provides (ADR 0019, §"Cleanup"). The catalogue holds one model:

| Model | Purpose | Languages | Download |
| --- | --- | --- | --- |
| Parakeet v3 | transcription | 25, German and English among them | 483 MB |

Rules:

- Outloud offers only multilingual models.
- The app cannot be used until the transcription model is downloaded.
- On macOS, downloaded models go into a directory that other apps
  needing the same models can reuse: the Hugging Face hub cache —
  `~/.cache/huggingface/hub`, or the path that `HF_HUB_CACHE` or
  `HF_HOME` set — in the hub's own layout, so that other tools find the
  models there (ADR 0009, ADR 0010). On iOS, where apps of different
  vendors cannot share one, they stay in Outloud's own container.

The flow at first launch:

1. Outloud shows the transcription model with its size, and the cleanup
   setting with whether Apple Intelligence is available.
2. The user confirms, and switches cleanup off if they want.
3. The user starts the download.
4. Outloud downloads the transcription model.
5. Once the download is finished, the app can be used.

In the app's settings, the user switches cleanup on or off, sees the
model's download, and can stop a download and delete the model.

Before deleting a model, Outloud warns the user — on macOS also that
other tools may use it from the shared cache — and deletes it only if
the user confirms.

When a download fails or the device runs out of space, Outloud informs
the user. The app stays unusable until the models it needs are
downloaded.

When only cellular data is available, Outloud warns that the models are
very large, and the user decides whether to download them over cellular
data. A download the user did not allow over cellular data waits for
Wi-Fi when Wi-Fi goes away.

A download goes on while Outloud is in the background; one the app did not
see finish — iOS ended the app, or the user quit it — goes on at the next
launch, unless the user stopped it.

Models another tool already downloaded into the shared cache are shown
as "Already on this device" and are not downloaded again (ADR 0010).

Acceptance criteria:

- A first launch shows the transcription model with size and languages
  and the cleanup setting with Apple Intelligence's availability; the user
  can untick cleanup; "Download" shows the missing size; progress is
  shown; "Continue" appears once the model is there.
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

- The states read "Transcribing…", "Cleaning up…", "Done" — a recording
  shows the wave, and the menu bar panel and the screen reader say
  "Recording…" — and, on a failure, a sentence with a way out ("Open Settings",
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
- The user can listen to a kept result — with its waveform, and seek in
  it — and view its text: both the cleaned version and the transcript,
  each with a copy button.
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
