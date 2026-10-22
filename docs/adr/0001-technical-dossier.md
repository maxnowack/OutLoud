# 0001 – The project does / does not maintain a technical dossier

- Status: open — decided at project start, before the first feature
- Date: —

## Context

A technical due diligence, a certification audit or a security review asks
the same set of questions of every software project: what the system is,
why it is that way, what it depends on and under which licences, how data
is classified and protected, how the system is operated and restored, how
quality is established, what is known to be fragile, who knows what. Most
of the answers exist somewhere in a well-kept repository; what an assessor
needs is that they are findable, current, and backed by evidence.

Answering those questions once, at the moment they are asked, costs weeks
and produces a document set that is wrong the day after. Keeping them
current as a side effect of ordinary work costs a section update per change
and a verification pass per release — small, but only if it starts on day
one: the sections that are hardest to reconstruct later (the decision
history, the restore drills, the access reviews) are exactly the ones that
cannot be back-filled.

`docs/DOSSIER.md` is the concept: an index over the living documents plus
the few sections that have no other owner, each with a `Last verified`
line and a rule that evidence lives in the repository.

The alternative is to not maintain it and accept that a future due
diligence or certification starts from scratch. That is the right choice
for a project that will never face one — an internal tool, an experiment, a
library without an operational footprint.

## Decision

*Pick one, delete the other, set the status to `accepted` and the date.*

**Variant A — maintained.** We maintain `docs/DOSSIER.md` from the first
feature. Every section has an owner and a `Last verified` line; the release
checklist includes the verification pass; a change that alters something a
section covers updates the section in the same change set. The dossier is
listed in the ownership map in `AGENTS.md`.

**Variant B — not maintained.** We do not maintain a technical dossier.
`docs/DOSSIER.md` is deleted and its row removed from the ownership map in
`AGENTS.md`. The living documents, the ADRs and the plans remain the only
technical documentation. Should a due diligence or certification become
likely, adopting the dossier is a new ADR, and the cost of reconstructing
the sections that were not kept is accepted as the price of this decision.

## Consequences

*Variant A:* one more living document with the same discipline as the
others; a verification pass per release; generated inventories for
dependencies and licences with their tests; restore drills and access
reviews actually performed and logged. In exchange, a due diligence or
audit is a walk through an index rather than a project.

*Variant B:* nothing to maintain. The decision history, the architecture
and the specification are still kept, because the other rules require them;
what is lost is the evidence trail — the drills, the reviews, the verified
dates — which cannot be reconstructed later.
