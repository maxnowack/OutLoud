# Adopt the agents-template so that outloud is worked on under one documented discipline

## Status

In progress (2026-10-22). The template tree is copied without `.meta/`;
the rule documents and the ADR format are the template's, except for the
one sentence about `.meta/` removed from `AGENTS.md` and the dossier
clauses removed with the dossier (ADR 0001). Phase 0 of
`plans/FIRST_VERSION.md` did steps 3, 4, 5, 7 and 9: the maps and the
Swift conventions in `AGENTS.md`, an area file per unit, ADR 0001 closed,
and a `precommit` command per unit. The release document and the visual
style wait on phases 3 and 6 of that plan.

## Problem

The repository was empty. The template (the `agents-template` repository
at commit `3bdf7b1`) supplies the working rules and the document
structure; its `README.md` §"Starting a project from it" lists ten
adoption steps.

## Goal

Every adoption step of the template is done or waits on a named open
question below.

## Approach

Follow the template's ten steps in order. A step that needs a decision the
user has not made stays open.

## Phases

### The template's adoption steps

DoD: every row reads "done".

| Template step | State |
| --- | --- |
| 1. Copy the tree without `.meta/` | done |
| 2. Name the product, replace the README, add `LICENSE` | done; MIT, as the user decided on 2026-10-22 |
| 3. Fill the two maps in `AGENTS.md` | done (ADR 0011) |
| 4. Conventions per stack | done: Swift, in `AGENTS.md` |
| 5. Area rules | done: `OutloudKit/AGENTS.md`, `apps/macos/AGENTS.md`, `apps/ios/AGENTS.md` |
| 6. Fill ARCHITECTURE, SPEC, RELEASE; the stack ADR before code | SPEC and ARCHITECTURE hold the concept, stack ADR 0002 done; RELEASE open |
| 7. Close ADR 0001 (dossier) | done: no dossier; `DOSSIER.md` deleted |
| 8. Decide the style; `e2e/README.md` per UI unit | `docs/DESIGN.md` and both `e2e/README.md` written; the style waits on the user's approval |
| 9. Wire the checks | `precommit` per unit done; no CI is set up |
| 10. Delete what does not apply | dossier deleted; `docs/HORIZONTAL_SCALING.md` kept while it is open whether Outloud ever runs a service |

## Risks

None recorded.

## Open questions

- The visual style (`docs/DESIGN.md`) — phase 3 of
  `plans/FIRST_VERSION.md`.
- The release path of the macOS download (`docs/RELEASE.md`) — phase 6
  of `plans/FIRST_VERSION.md`.
