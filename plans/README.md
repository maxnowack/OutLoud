# Plan index

Rules for structure and upkeep: `AGENTS.md` §"Documentation structure" and
§"Plan and ADR rules". In short: `plans/` holds open or in-progress plans,
`plans/done/` the implemented ones. This index is updated with every status
change; the authoritative status description always lives in the plan's own
`## Status` section.

## Open / in progress (`plans/`)

| Plan | Topic | State |
| --- | --- | --- |
| `TEMPLATE_ADOPTION.md` | Adopting the agents-template's structure and rules | In progress: tree copied, product decisions open |
| `FIRST_VERSION.md` | Building the first version for macOS and iOS | In progress: phases 0–5 built, phase 6 and the user's checks open |
| `BACKGROUND_DICTATION.md` | Dictating on iOS without bringing Outloud to the front; model downloads in the background | Phases 1–3 built (ADR 0018); the shortcut link open; background cleanup moved to `APPLE_CLEANUP.md` |
| `APPLE_CLEANUP.md` | Cleaning up with Apple's on-device model instead of Qwen, on iOS and macOS | Built; checked in the Mac app; the run on the iPhone open |
| `OPTION_COMMAND_HOTKEY.md` | Starting a dictation on macOS by holding ⌥ ⌘ alone | Built; the run with the user's keyboard open |
| `POLISH_AFTER_DEVICE_TESTS.md` | The ⌥ ⌘ rules, cleanup progress, the pill, the icon colour, a subtler shortcut | Built; the shortcut link open |
| `PAUSE_PLAYBACK_WHILE_DICTATING.md` | Pausing what plays while a dictation records, on the Mac and the iPhone | Built; the run with the user open |
| `TRANSCRIPTION_PROGRESS.md` | A progress bar while transcribing, in both apps and the Live Activity | Built; the run with the user open |

## Implemented (`plans/done/`)

| Plan | Topic | Done |
| --- | --- | --- |
| `CONCEPT.md` | Shaping the product concept until nothing has to be guessed | 2026-10-22; the remaining questions moved to `FIRST_VERSION.md` |
| `MAC_LOGIN_OVERLAY_PROGRESS.md` | Open the Mac app at login, no hanging pill, the microphone at launch, a truthful cleanup progress | 2026-10-24; the prewarming on the iPhone not checked |

## The shape of a plan

A plan is `plans/<NAME>.md`, `NAME` in upper snake case naming the concern,
not the ticket. It has these sections:

```markdown
# <Title: what the plan delivers, as a sentence>

## Status

<First sentence: the actual implementation status, with a date.
Deviations from the plan, items the user descoped — each with the decision
that descoped it — and dated addenda once the plan is done. A duty the
work made necessary is never listed here as open (`AGENTS.md` §"Plan and
ADR rules").>

## Problem

<What is wrong or missing, with the measurement or the incident that says
so. Cite the report, the log line, the number.>

## Goal

<What is true when the plan is done, stated so that it can be checked.>

## Approach

<The chosen approach and the alternatives that were considered, with the
reason each was rejected. A decision this section makes that meets the ADR
bar gets its ADR; the plan cites it.>

## Phases

<One subsection per phase, each with a Definition of Done that a reader can
verify. Sized to be productive but focused: big enough to get somewhere,
small enough not to lose the thread.>

## Risks

<What could go wrong while this is built or once it ships, and what
mitigates it.>

## Open questions

<What has to be decided by the user before or during the work.>
```
