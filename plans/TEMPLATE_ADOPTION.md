# Adopt the agents-template so that outloud is worked on under one documented discipline

## Status

In progress (2026-10-22). The template tree is copied without `.meta/`;
the rule documents and the ADR format are the template's, except for the
one sentence about `.meta/` removed from `AGENTS.md`. The README carries
the working title. Every other step waits on an open question below.

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
| 2. Name the product, replace the README, add `LICENSE` | README done with the working title; product description and `LICENSE` open |
| 3. Fill the two maps in `AGENTS.md` | open until the first unit exists |
| 4. Conventions per stack | open: no stack chosen |
| 5. Area rules | open: no unit exists |
| 6. Fill ARCHITECTURE, SPEC, RELEASE; the stack ADR before code | open: the product is not described |
| 7. Close ADR 0001 (dossier) | open |
| 8. Decide the style; `e2e/README.md` per UI unit | open: whether the product has a user interface is not known |
| 9. Wire the checks | open: no unit exists |
| 10. Delete what does not apply | open |

## Risks

None recorded.

## Open questions

- What the product is: its purpose, its users, its platforms.
- The final product name, or whether `outloud` is it.
- The licence.
- Whether the project maintains the technical dossier (ADR 0001).
- The stack; whether the repository is one unit or several.
- Whether the product has a user interface, and its visual style
  (`docs/DESIGN.md`).
