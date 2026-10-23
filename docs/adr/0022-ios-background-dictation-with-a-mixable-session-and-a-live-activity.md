# 0022 – On iOS, a shortcut starts and stops a recording in the background, with an audio session that mixes with other audio and a Live Activity, and copies the text Outloud returns

- Status: accepted
- Date: 2026-10-23

## Context

ADR 0018 recorded that iOS refuses to open the microphone for an app in the background, and
chose a shortcut that records with the Shortcuts app's "Record Audio". That action covers the
screen while it records; the user needs to see what they are writing about. They ruled out
Apple's "Dictate Text" (not Outloud's model), a custom keyboard (the app has to be opened and
left again) and a microphone kept open between dictations.

The refusal in ADR 0018 came from the kind of session, not from the background as such: the
recording opened an exclusive session (`.record`), which iOS does not let a background app
activate ("Session activation failed"). A second spike on the user's iPhone 15 Pro on 2026-10-23
opened a session that mixes with other audio (`.playAndRecord` with `.mixWithOthers`) from an
`AudioRecordingIntent` that is also a `LiveActivityIntent`: the Live Activity started, the
session activated, the recording ran, a second run of the intent ended it, and Parakeet and
Apple's model processed it in the background in 3–7 s (about 20 s when the app had just been
launched). The text reached the clipboard once the shortcut's "Copy to Clipboard" took the
intent's result (`plans/BACKGROUND_DICTATION.md` §"Status").

## Decision

We offer "Start or Stop Dictation with Outloud", an App Intent that runs in the background: the
first run starts a Live Activity and a recording with a mixable session; the next run ends it,
transcribes and cleans up, and returns the text. The user's shortcut is that action followed by
"Copy to Clipboard", run from Back Tap, the Action Button in its Shortcut mode or Siri. The Live
Activity shows each phase — recording, transcribing, cleaning up with its progress, copied or
what failed — and has a Stop button, which keeps the text in the history without copying it
unless Outloud is in front. The microphone is open only while recording.

We remove "Transcribe Audio with Outloud" and the guide's "Record Audio" and "Dictate Text"
shortcuts, which this replaces.

## Consequences

- Supersedes ADR 0018's decision and its claim that iOS refuses the microphone in the
  background; its findings on the clipboard (refused) and the GPU stand.
- Other audio plays on while recording, and can be heard in the recording through the speaker.
- The cleanup streams for the Live Activity's progress, which uses Apple's background budget a
  little sooner (ADR 0019).
- Ending a dictation from the Live Activity cannot copy: only the shortcut writes the clipboard.
- The control and "Dictate with Outloud" keep opening Outloud (ADR 0017).
