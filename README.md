# outloud

*`outloud` is the repository's working title.* What the product is has not
been written down yet; `docs/SPEC.md` will own it.

## Status

The repository holds the working rules and the document skeletons of the
template, nothing else (`plans/TEMPLATE_ADOPTION.md` §"Status"). No product
decision, no stack and no code exist yet.

## Where to start

1. `AGENTS.md` — the working rules.
2. `plans/TEMPLATE_ADOPTION.md` — which setup steps of the template are
   done, and the questions the open ones wait on.
3. `docs/adr/README.md` — the decisions.
4. `docs/SPEC.md` — what the product does, once it is written.

## What is here

| Path | What it is |
| --- | --- |
| `AGENTS.md` | The repository-wide working rules, the map of rule files and the map of living documents. |
| `CLAUDE.md` | A pointer to `AGENTS.md`, for harnesses that read that name. |
| `docs/SPEC.md` | What the product does (skeleton). |
| `docs/ARCHITECTURE.md` | Components and communication paths (skeleton). |
| `docs/DESIGN.md` | The visual style (skeleton). |
| `docs/RELEASE.md` | Versioning, release and rollback (skeleton). |
| `docs/DOSSIER.md` | The technical due-diligence index — kept or deleted by ADR 0001, which is open. |
| `docs/HORIZONTAL_SCALING.md` | The register of single-instance assumptions. |
| `docs/ARCHITECTURE_PRINCIPLES.md` | The technology-independent architectural rules. |
| `docs/RULE_WRITING.md` | How a rule is phrased and where it goes. |
| `docs/PROCESSES.md`, `docs/VERIFICATION.md`, `docs/COMMITS.md` | Situational working rules, read when `AGENTS.md` says so. |
| `docs/adr/` | Decision records with format and index. |
| `plans/` | Open plans and their index; `plans/done/` for finished ones. |

The structure and the rule documents come from the `agents-template`
repository (commit `3bdf7b1`), adopted on 2026-10-22.
