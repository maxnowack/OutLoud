# Architecture Decision Records (ADR)

Architecture decisions are recorded here. The binding rule for when an ADR
must be written is in `AGENTS.md` §"Plan and ADR rules".

## Format

One file per decision, numbered consecutively:
`NNNN-short-kebab-case-title.md`. Language is English. Every ADR contains
exactly these sections:

```markdown
# NNNN – Title of the decision

- Status: accepted | superseded by [NNNN](NNNN-….md) | open
- Date: YYYY-MM-DD

## Context

What problem was at hand, which forces/alternatives existed. Name rejected
alternatives with the reason for rejection.

## Decision

What was decided, in full sentences and active voice ("We use …").

## Consequences

What follows — positives, negatives, new duties, affected modules.
```

The title is a sentence that states the decision, not a topic: "The socket
is the app's transport", not "Transport". A reader of the index should be
able to tell what was decided without opening the file.

## Rules

- An accepted ADR is not rewritten. A revised decision gets a new ADR; the
  old one gets the status "superseded by" with a link.
- The status `open` is reserved for the decisions this template ships to be
  made at project start (0001). An open ADR is closed — one variant kept,
  the other deleted, the title rewritten to state the decision, the index
  entry with it, status `accepted`, date set, and this rule deleted —
  before the first feature is built. No other ADR is ever created open.
- ADRs record the decision and its rationale, not the implementation —
  implementation detail belongs in the corresponding plan under `plans/`.
- Where a decision was set by a *measurement* — a limit, a floor, a threshold
  — the ADR records the measurement and its date, so a later reader can tell
  whether the reason still holds.
- A number collision after a rebase is resolved in the commit that created
  the file, with every reference rewritten repo-wide (`docs/COMMITS.md`).

## Index

- [0001 – The project does / does not maintain a technical dossier](0001-technical-dossier.md) *(open — decided at project start)*
