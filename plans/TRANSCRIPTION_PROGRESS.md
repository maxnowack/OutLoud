# Show how far the transcription is, as the cleanup does, in both apps and the Live Activity

## Status

Phases 1 and 3, the countdown, built (2026-10-26, 2026-10-27), and the user approved the look
on the Mac on 2026-10-27; phase 2, the run with the user on the iPhone, is open. The user asked for it on
2026-10-26 and chose this approach, for the iPhone and the Mac. `./scripts/precommit` passes in
all three units; `DurationEstimateTests` and `DictationControllerTests` cover both steps. The
cleanup keeps its stored samples. The Live Activity's detail line "Turning your words into text"
gave way to the bar.

Addendum 2026-10-27: on the user's request the bar became a ring in the StatusIndicator's icon
slot, as in the Live Activity, on both platforms; a recording shows only the new LevelWave
(`docs/DESIGN.md` §"StatusIndicator", §"LevelWave").

Addendum 2026-10-27, after the user's first look on the Mac: the wave seemed not to move with
the voice. The tap delivers 100 ms buffers whatever size it asks for, and the wave travelled at a
fixed speed; the recorder now measures the level in a sink node at every IO buffer (about 94 a
second, measured), the controller reads it once a frame, and the wave's speed follows the level.
The overlay's capsule became AppKit's `NSGlassEffectView`: in a side-by-side comparison
SwiftUI's `glassEffect` only frosted the background, also with the panel forced into its active
look, and the user chose AppKit's regular glass.

Addendum 2026-10-27, after the second look: the regular glass still read as a plain fill — over
a calm background it is one, as a comparison over the desktop showed —, and a sine that only grew
and sped up still did not read as the voice. The user chose the clear glass and a line that is
the voice's own shape: the recorder keeps the input's last tenth of a second, and `VoiceShape`
turns its last 30 ms into the points the LevelWave draws, triggered on a rising zero crossing.

Addendum 2026-10-27, after the third look: the line trembled. Measured on the German and English
samples, each point moved by 0.218 half-heights from frame to frame; matching each shape to the
line shown before and moving a third of the way to it brought that to 0.067 (-69 %) and kept most
of the height (mean peak 0.87 to 0.71); fewer points did not help. The user left the line there.
The pill's changes did not feel round: a slowed-down test showed the glass following the size,
but the old and the new content overlapping and reaching past the edge. A change of the overlay
now fades the content out, resizes the capsule and fades the new content in, with the content
clipped to the capsule; it opens without a bounce, growing out of a smaller capsule.

Addendum 2026-10-27, after the fourth look: a change took 0.54 s, longer than a transcription on
the Mac often lasts, so "Transcribing…" was rarely seen while the capsule resized twice, empty;
and a change to a content of about the same width left the capsule empty for half a second
without a visible resize. Now a step of the pipeline and the result appear only once they lasted
0.25 s, and are skipped otherwise; two contents within 12 pt of each other swap in a quick dip
(0.16 s); a resize takes 0.15 s to 0.3 s by the distance (`docs/DESIGN.md` §"Motion"). After the fifth
look, "Done" flashed before "Pasted": the paste outlasts the quarter second. The pill no longer
shows the result; the step before stays, its ring full, until the delivery message. Then
"Pasted" came 0.6 s after the text: the app waited for the clipboard's restore before reporting the
paste. It now reports it with the ⌘V and restores the clipboard afterwards in the background.
After the sixth look "Pasted" still came late: the three steps of the change let it appear only
after about 0.3 s. A narrower content now fades in while the capsule shrinks, after 0.08 s; and
on the user's wish a recording shows "Recording…" above the line again, on both platforms.

## Problem

While a dictation is transcribed, the apps and the Live Activity show only a spinner; the
cleanup after it has a bar that moves by the time it usually takes
(`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md`). On the iPhone the transcription takes long enough
to be felt, and a spinner says nothing about how long it will be.

## Goal

1. While transcribing, the StatusIndicator — the iPhone's Dictate tab and the Mac's overlay —
   shows a bar that moves evenly from the start by the time passed over the duration expected for
   a recording of this length, and fills only at the end.
2. The Live Activity shows the same as a bar and, in the compact island, a ring, in steps of 5 %.
3. The expected duration is learned on the device, per transcription model; the cleanup's
   estimate works as before and keeps what it has learned.

## Approach

The transcription model reads the whole recording, so its duration is a start plus a time per
second of audio, as the cleanup's is a start plus a time per token. The cleanup's estimate
(`CleanupTimings`: the last 20 runs, a Theil–Sen line, reset by a fingerprint) is generalised to
`DurationEstimate`, which takes the units of work, its two `UserDefaults` keys, the first guess and
the fingerprint; the cleanup keeps its keys and samples, the transcription's are
`transcriptionSamples` with `[audio seconds, seconds]` and `transcriptionModel`, the model the
samples were measured with. `DictationController.cleanupProgress` becomes `progress`, the share
of the phase that runs now — transcribing or cleaning —, ticked by one routine for both.

The rename and the generalisation go first, without a change in behaviour; the transcription's
estimate and the bars follow.

Rejected: a progress reported by the transcription model itself. Parakeet transcribes the
recording in one call and reports nothing on the way; splitting it into chunks to count them
would change the transcription for a bar.

## Phases

### 1. Build

DoD: `DurationEstimate` with tests for both phases, the cleanup's stored samples still read; the
controller publishes `progress` while transcribing and cleaning, and learns both durations, with
a test; the StatusIndicator and the Live Activity show the bar while transcribing;
`docs/SPEC.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and the e2e plans updated;
`./scripts/precommit` passes in all three units.

### 2. Run

DoD: the user dictates on the iPhone — in the app and from the shortcut with the Live Activity —
and on the Mac, and sees the bar move in both phases without standing and jumping.

### 3. Countdown

Asked for by the user on 2026-10-27: while transcribing and cleaning up, show how long it will
still take, inside the ring, so that the user knows roughly when the text is ready. The user chose
a ring of 24 pt, which holds two digits, the Live Activity too, and this plan as its home.

DoD: the controller publishes `secondsLeft` — whole seconds to the expected duration, rounded
up, never rising, `nil` once it passed — with tests on a fixed expectation; the StatusIndicator
shows it inside the ring, VoiceOver reads it, German included; the Live Activity shows it beside
the bar and inside the compact ring; `docs/SPEC.md`, `docs/DESIGN.md` and the e2e plans updated;
`./scripts/precommit` passes in all three units; the user sees it count down on the Mac.

## Risks

- The first transcription after the app started may load the model and take far longer; the
  robust fit keeps such outliers from pulling the line, as with the cleanup's first run.
- On the Mac a transcription takes a fraction of a second; the bar is barely seen there.

## Open questions

- None. The countdown, asked for on 2026-10-27, became phase 3.
