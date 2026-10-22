# 0001 – The project does not maintain a technical dossier

- Status: accepted
- Date: 2026-10-22

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

The template shipped `DOSSIER.md` as the concept: an index over the
living documents plus the few sections that have no other owner, each
with a `Last verified` line and a rule that evidence lives in the
repository.

Not maintaining it is the right choice for a project that will never face
a due diligence or a certification. Outloud is an open-source app without
monetisation (`docs/SPEC.md`), with no server to operate.

Rejected alternative: maintaining the dossier from the first feature —
one more living document and a verification pass per release, for an
assessment nobody expects.

## Decision

We do not maintain a technical dossier. `DOSSIER.md` is deleted and
its row removed from the ownership map in `AGENTS.md`. The living
documents, the ADRs and the plans remain the only technical
documentation. Should a due diligence or certification become likely,
adopting the dossier is a new ADR, and the cost of reconstructing the
sections that were not kept is accepted as the price of this decision.

## Consequences

Nothing to maintain. The decision history, the architecture and the
specification are still kept, because the other rules require them; what
is lost is the evidence trail — the drills, the reviews, the verified
dates — which cannot be reconstructed later.
