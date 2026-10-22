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

## Implemented (`plans/done/`)

| Plan | Topic | Done |
| --- | --- | --- |

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
mitigates it. Where the dossier is maintained, each row this plan adds to
or removes from its risk register (`docs/DOSSIER.md` §10).>

## Open questions

<What has to be decided by the user before or during the work.>
```
