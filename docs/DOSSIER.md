# Technical dossier

This document owns the technical due-diligence and certification view of
the project: what an assessor — an acquirer's technical due diligence, a
certification auditor, a security review — asks for, where in this
repository the answer lives, what counts as evidence, and when each answer
was last verified. Whether the project maintains it is decided at project
start and recorded in `docs/adr/0001-technical-dossier.md`; a project that
decided against it deletes this file.

## How it works

The dossier is an **index, not a second documentation set**. Each section
below names the living document that owns the concern (`AGENTS.md`
§"Living documents and their owners") and points at it; the dossier never
restates what an owner holds, because two copies drift and an assessor who
finds them disagreeing stops trusting both. Where a concern has no owner
elsewhere — dependency and licence policy, data classification, security
posture, operations, the risk register — the dossier owns it, either inline
in the section or as a living document of its own listed in the ownership
map.

Three rules keep it current:

- **(MUST)** A change that alters something a section covers updates the
  section — its pointer, its own content, or its evidence — in the same
  change set, exactly as for every living document.
- **(MUST)** Every section carries a `Last verified` line: the date, who
  verified, and what was checked. A section is verified at every release
  that reaches users (`docs/RELEASE.md` §"Release checklist") — under
  continuous deployment, at least weekly rather than per deploy — and at
  least every six months regardless. A line older than that is a finding,
  not a formality: it is what an auditor reads first.
- **(MUST)** Evidence lives in the repository or is reproducible from it — a
  CI run, a generated inventory, a test that asserts the property, a
  restore drill with its log committed. A screenshot in a wiki or a
  statement in a slide deck is not evidence.

## Sections

Each section: what is asked, who owns the answer, what the evidence is, and
the `Last verified` line.

### 1. System overview

*Asked:* what the system is, its components, how they communicate, where
the boundaries are.
*Owner:* `docs/ARCHITECTURE.md`; `README.md` for the map.
*Evidence:* the document, and that it matches the deployment manifests.
*Last verified:* —

### 2. Product scope and requirements

*Asked:* what the product does, and how a requirement is traced to its
verification.
*Owner:* `docs/SPEC.md` for the behaviour and, per feature, the
`Verified by:` line naming its end-to-end test plans; `e2e/README.md` for
the coverage of every screen and route
(`docs/ARCHITECTURE_PRINCIPLES.md` §"End-to-end test plans").
*Evidence:* the coverage-index check green on the release commit, and every
plan a feature names executed in the release (`docs/RELEASE.md`
§"Release checklist").
*Last verified:* —

### 3. Decision history

*Asked:* why the system is the way it is, and which alternatives were
rejected.
*Owner:* `docs/adr/`.
*Evidence:* the index; every ADR dated and either accepted or superseded.
*Last verified:* —

### 4. Source, build and release

*Asked:* how the source is organised, that a build is reproducible, how a
change reaches production, how it is rolled back, how versions are named.
*Owner:* `AGENTS.md` for the working discipline; the CI workflows for the
checks; `docs/RELEASE.md` for versioning, the release and the rollback
procedure.
*Evidence:* the full local check and, where CI exists, a clean CI run per
unit on the release commit; a rollback performed and logged at least once.
*Last verified:* —

### 5. Dependencies and licences

*Asked:* every third-party component, its version, its licence, its
compatibility with the product's licence, and how vulnerabilities in it are
found and handled.
*Owner:* this section. The inventory is *generated* from the lockfiles
(never hand-maintained, `docs/ARCHITECTURE_PRINCIPLES.md` §"Generated
artifacts"); the policy — allowed licences, update cadence, how a
vulnerability report is triaged and within what time — is written here.
*Evidence:* the generated inventory checked in and matching the lockfiles
(a test fails when it does not); the vulnerability scan in CI.
*Last verified:* —

### 6. Data

*Asked:* the data model, which data is personal or otherwise classified,
how it flows between components and to third parties, how long it is kept,
how it is deleted and exported on request.
*Owner:* `docs/ARCHITECTURE.md` for the model and formats; this section for
the classification, retention, deletion and export procedures, and — where
personal data is processed — the record of processing activities.
*Evidence:* the deletion and export paths exercised by a test; retention
enforced by a job whose run is recorded.
*Last verified:* —

### 7. Security

*Asked:* who authenticates to what and how, where secrets live and how they
rotate, what the threat model is, who can reach production, how an incident
is detected, handled and reported.
*Owner:* `docs/ARCHITECTURE.md` for the auth model and the threat model
per boundary; `docs/ARCHITECTURE_PRINCIPLES.md` §"Security" for the rules
every boundary keeps; this section for secrets management, access control
to production, and the incident-response procedure.
*Evidence:* no secret in the repository (a scan in CI); the refusal tests
per boundary green on the release commit; the access list reviewed and
dated; an incident drill or a real incident with its post-mortem.
*Last verified:* —

### 8. Operations

*Asked:* the environments, how the system is deployed and monitored, what
alerts exist and who receives them, how backups are taken and — the part
that is actually asked — how a restore was *tested*, with the measured
recovery time and data loss.
*Owner:* this section, or an operations document under `docs/` it points
at and that is listed in the ownership map; the
horizontal-scaling register `docs/HORIZONTAL_SCALING.md` for what keeps a
service single-instance.
*Evidence:* a restore drill with its log committed and its RPO/RTO
recorded; the alert rules in the repository.
*Last verified:* —

### 9. Quality

*Asked:* how correctness is established at each level, what gates a change
must pass, how code is reviewed, what static analysis runs.
*Owner:* `docs/VERIFICATION.md` and the area files for the
standard; the CI workflows for the gates; `docs/RELEASE.md` §"Review" for
who reviews a change before it merges.
*Evidence:* the gates green on the release commit; the verification record
of the release.
*Last verified:* —

### 10. Risk and technical debt

*Asked:* what is known to be fragile, single points of failure, deliberate
shortcuts and what they would cost to remove, open plans that carry risk.
*Owner:* this section: a register with one row per item — what it is, what
happens if it fails, the mitigation in place, the plan that would remove it.
*Evidence:* the register itself, and that every risk a plan under `plans/`
names in its Risks section is listed.
*Last verified:* —

### 11. Team and knowledge

*Asked:* who owns which area, where the knowledge is concentrated, how a
new engineer becomes productive.
*Owner:* this section for ownership; `README.md` and the area files for the
onboarding path.
*Evidence:* this section's table — one row per area of the area table in
`AGENTS.md`, with the person who owns it and the person who could take
over.
*Last verified:* —

### 12. Standard-specific requirements

*Asked:* whatever the target standard or regulation asks for beyond the
sections above — accessibility, a medical or financial regime, a
sector-specific certification.
*Owner:* this section, one subsection per standard, each mapping the
standard's own checklist onto the sections above and naming what is not
covered by them.
*Evidence:* per the standard.
*Last verified:* —
