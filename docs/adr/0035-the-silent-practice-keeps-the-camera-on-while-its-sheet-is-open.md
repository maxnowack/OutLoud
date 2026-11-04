# 0035 – The silent practice keeps the camera on while its sheet is open

- Status: accepted
- Date: 2026-11-04

## Context

ADR 0034 let the camera run only while the hotkey is held and, in the
settings' silent practice, between the user's Start and Done. The Mac's
FaceTime HD camera takes 1.25 to 1.45 s from cold to its first frame,
whatever the capture format, and 0.15 s only when it ran less than about
3 s before (measured on 2026-11-04 with a probe app). Started for each
sentence, the practice made the user wait over a second before every one,
and what they mouthed in that second was not seen, while the sample was
labelled with the whole sentence.

## Decision

We keep the camera on while the practice sheet is open, from its opening
to its closing however it closes. Start and Done only mark which frames
are a sentence's: the frames between them are cropped and kept, those
before Start and after Done are dropped as they arrive. Start shows "The
camera is starting…" until the camera delivers frames, which on an open
sheet is at once. Everything else ADR 0034 decided about the camera
stands: with a dictation, it runs only while the hotkey is held.

## Consequences

- The camera light is on for as long as the practice sheet is open, also
  between sentences. The user opened the sheet to be filmed; its light
  says so.
- A dictation while the sheet is open turns the camera off at its end, and
  the next Start turns it on again from cold.
- ADR 0034's rule for the practice is superseded by this one.
