# Working rules

This file holds what applies everywhere in the repository, independent of
language, framework or runtime. Area-specific rules live next to the code they
govern (see *Working rules by area*), and the technology-independent
architectural rules every area specialises live in
`docs/ARCHITECTURE_PRINCIPLES.md`. Three groups apply everywhere but only in
a situation — starting something, verifying, committing — and live in their
own documents that this file names at the moment they apply, so the turns
that do not need them do not pay for them. How a rule is written, and
where a new one goes, is in `docs/RULE_WRITING.md`.

Rules are marked **(MUST)**, **(MUST NOT)**, **(SHOULD)** and
**(SHOULD NOT)**. A MUST is a condition for the work counting as done. A
SHOULD is the default; deviating from it is fine when the deviation is named
and reasoned.

# Repository layout

**(MUST)** The repository root holds exactly four *documents*: `README.md`,
`AGENTS.md`, `CLAUDE.md`, and `LICENSE`. Every other document lives in the
directory that matches its purpose; a new document never lands in the
root. The root is the first thing a reader and an agent see, and a root
that holds an analysis and two plans beside the README no longer says what
the repository is; a document with no obvious home is a document whose
purpose is unclear, and choosing the directory decides the purpose. Tooling and configuration files that their tool requires at
the root — `.gitignore`, `.editorconfig`, a package manifest, a CI
directory, a lockfile — are not documents and are not what this rule is
about.

**(MUST)** In a monorepo, every deployable unit — an app, a service, a
library — lives in a directory of its own with its own area file, and its
commands run from that directory; a tool run from the wrong directory
answers for the wrong thing. A repository with a single unit keeps that
unit at the root: its source, its manifest and its commands live there, and
this file carries the unit's area rules in a section of its own instead of
a separate `<area>/AGENTS.md`. Nesting begins with the second unit.

**(MUST)** Place a new dataset, module or responsibility with the component
that owns the question it answers, and keep facts apart from the product's
judgement about them (`docs/ARCHITECTURE_PRINCIPLES.md` §"Ownership").

## Working rules by area

This file holds what applies everywhere. In a monorepo, area-specific rules
live next to the code they govern and load when that code is touched — read
the matching file before writing code there, and add a new rule to the file
that owns it. In a single-unit repository the area rules are the section
*Area rules* below, and the table has one row fewer.

| File | Owns |
| --- | --- |
| `AGENTS.md` (this file) | Repository-wide: layout, documentation ownership, plan and ADR duties, how to work, commit and staging discipline |
| `docs/ARCHITECTURE_PRINCIPLES.md` | The technology-independent architectural rules every area file specialises |
| `<area>/AGENTS.md` | *(monorepo only; one row per area — the stack, its data-access gate, its generated artifacts, its verification duty)* |

**(MUST)** Read the area file before writing *or advising on* code in that
area. Loading is lazy, so reasoning about an area without opening a file
under it leaves its rules unloaded — and the rules whose breach is silent and
expensive are exactly the ones that live there.

**(MUST)** Every `<area>/AGENTS.md` has a `<area>/CLAUDE.md` beside it
containing exactly `@AGENTS.md`, created in the same change set. Claude Code
reads only `CLAUDE.md` and loads nested ones lazily; an area file without
the pointer is never loaded, and nothing reports that it was not
(https://code.claude.com/docs/en/memory.md).

**(MUST)** Read the group of `docs/ARCHITECTURE_PRINCIPLES.md` that governs
a change before designing it — persistence for a schema or a query,
contracts for a wire format, security for a trust boundary, user interface
for a screen. The file is not loaded with this one, and it is where the
rules with the silent failures live; a design made without it is reviewed
against it afterwards, which is the expensive order.

## Conventions shared by every unit of one stack

Where several units share a language or runtime, the conventions they share
are stated once, here, and are not repeated in their own files. For each
stack in this repository:

- **(MUST)** Keep the formatter clean and the build free of warnings before
  the work counts as done. Each unit defines one `precommit`-style command
  that runs compile, dependency hygiene, format and tests together; run it
  from that unit's own directory.
- **(MUST)** Develop backwards-compatibly; a breaking change is a joint
  release coordinated with the user, never shipped alone
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"Contracts between components").

# Documentation structure

Markdown documentation is split by status and purpose, so that a reader
can tell from the directory alone whether a document describes the
present, a decision, or work — a status line per file is invisible from
the listing, and a wiki outside the repository is neither versioned with
the code nor visible to the tools that read it. Documentation language is
English: tooling, dependencies and everything quoted from the code are
English regardless, and a repository that mixes languages makes every
reader and every agent switch.

Directories:

- **Repository root** — `README.md` (the entry point and map over everything
  below), `AGENTS.md`, `CLAUDE.md`, `LICENSE`. No other document; tooling
  files that must sit at the root are not documents.
- **`docs/`** — the living reference documents (see the ownership map below).
  They are updated in place, never archived while they apply.
- **`docs/adr/`** — Architecture Decision Records; format and rules in
  `docs/adr/README.md`.
- **`plans/`** — only open or in-progress plans. `plans/README.md` is the
  index over all plans (open and done).
- **`plans/done/`** — implemented plans. They remain unchanged as design
  rationale and are still citable from code comments.
- **`e2e/`** (inside each unit that has a user interface) — the end-to-end
  test plans, one Markdown file per flow, and `e2e/README.md` as the
  coverage index (`docs/ARCHITECTURE_PRINCIPLES.md` §"End-to-end test plans").

There is no archive directory: an `archive/` is a directory nobody reads,
that every search returns hits from, that agents load into context, and
whose contents are indistinguishable from the living documents except by
the path.
**(MUST)** Superseded or one-off documents (finished acceptance protocols,
baselines, outdated analyses) are deleted, not archived — git history is the
archive. When deleting a document that is still cited, rewrite the citations
to the bare filename (e.g. `ANALYSIS.md §6.1`) so they read as historical
references retrievable via git history.

## Living documents and their owners

Each living document owns one concern, and is the single source for it.
**(MUST)** When a change alters something a living document owns, update that
document in the same change set — documentation follows the code it describes,
not a later cleanup pass. **(MUST NOT)** Restate in one living document what
another one owns. Point at the owner instead; two copies of a table drift, and
the reader cannot tell which one is current.

| Document | Owns |
| --- | --- |
| `README.md` | The entry point: what the product is, the repository layout, where to find which document |
| `docs/SPEC.md` | What the product does: features, rules, flows, acceptance criteria |
| `docs/ARCHITECTURE.md` | System components, communication paths, API and channel contracts, data and sync formats, auth model |
| `docs/DESIGN.md` | The visual appearance: tokens, the component vocabulary, the states and accessibility contract of every component — decided before the first screen |
| `docs/RELEASE.md` | How a version is named, released and rolled back, per unit; the release checklist |
| `docs/DOSSIER.md` | The technical due-diligence and certification view: the index of evidence, its owners, and when each section was last verified — *only if `docs/adr/0001-technical-dossier.md` decided for it* |
| `docs/HORIZONTAL_SCALING.md` | The register of everything that keeps a service from running as more than one instance: what it is, what goes wrong at two nodes, what coordinating it would take |
| `docs/ARCHITECTURE_PRINCIPLES.md` | The technology-independent architectural rules |
| `docs/RULE_WRITING.md` | How a rule is phrased, where it lives, and the shape of an area file |
| `docs/PROCESSES.md`, `docs/VERIFICATION.md`, `docs/COMMITS.md` | The situational working rules: what is started or connected to, how a change is verified, how a commit is made — read at the moment this file names |
| `AGENTS.md` and the area files above | Working rules, including both maps |

*(Add one row per living document the project needs — an economy, a domain
model, an operations manual, store material. Delete rows for documents the
project will never have; a project without a user interface deletes
`docs/DESIGN.md`, a project that decided against the dossier deletes
`docs/DOSSIER.md`.)*

**(MUST)** Where the dossier is maintained, it is a living document like
every other: a change that alters something a section covers updates the
section in the same change set, and every release includes its verification
pass (`docs/DOSSIER.md` §"How it works").

**(MUST)** `docs/HORIZONTAL_SCALING.md` is the register of everything that
keeps a service from running as more than one instance. Whoever writes
something that a second node would break, duplicate, or diverge from adds it
there in the same change set — what it is, what goes wrong at two nodes, and
what coordinating it would take. The usual shapes: a singleton process, a
periodic timer, an in-memory cache or counter, node-local pub/sub, a write
to the container's own filesystem, an unclaimed poll of an upstream.
Writing it down costs a paragraph while the reasoning is fresh; finding it
again from the symptoms after the second instance is already running costs
an incident. This holds while every service still runs single-instance —
that is precisely when the register is cheap to keep and impossible to
reconstruct later.

## Plan and ADR rules

- **(MUST)** Every plan starts with a `## Status` section whose first
  sentence states the actual implementation status. Whoever changes the
  status updates this section in the same change set.
- **(MUST)** When a plan is fully implemented: update its status section
  (date, deviations, descoped items with their decision), `git mv` it to
  `plans/done/`, rewrite all `plans/<NAME>.md` references repo-wide
  (including code comments) to `plans/done/<NAME>.md`, and update
  `plans/README.md`.
- **(MUST)** New plans are created in `plans/` and registered in
  `plans/README.md`.
- **(MUST)** A plan the user decided to keep lives in this repository under
  `plans/`, committed alongside the code it describes, and is written there
  *before* the work it plans begins. A plan drafted somewhere else — an
  agent harness's own plan directory, a scratchpad, a temporary file — is
  not a plan yet. A plan that exists only outside the repository is
  invisible to everyone else and is lost with the session that produced it.
  (Which prompts get a plan file is decided under *Before coding* below.)
- **(MUST)** Every architecture decision is recorded as an ADR in
  `docs/adr/` before the related work counts as done. Architecture decision
  means in particular: a new external service, a new framework or platform
  a unit is built on, a library that takes over a boundary (authentication,
  persistence, cryptography, parsing of untrusted input) — not every
  utility library —, a new module/process/system boundary, a new or
  changed wire/persistence/sync
  format, a cache/auth/deployment strategy, and any deliberately rejected
  approach whose rejection should guide future work. Small local
  implementation choices need no ADR; when in doubt, ask the user.
- **(SHOULD NOT)** Rewrite the body of implemented plans — append clearly
  dated addenda to the status section instead.
- **(MUST)** A plan is not done while a duty it introduced is only noted as
  a leftover. Work that the change set makes necessary — a translation, a
  regenerated artifact, a migration, a test for a new invariant — is carried
  out in that change set; a leftover that fails CI is a defect, not a note
  for the user's own schedule. An item the user descoped is not a leftover:
  it is recorded in the status section with the decision that descoped it,
  and it is the one form of open work a done plan may carry.

# How to work

## Before coding

- **(MUST)** Ask when the answer changes the work. If two readings of a prompt
  would lead to materially different work, ask before starting — and put every
  open question into one turn rather than a chain of single-question turns.
  Where a careful colleague would simply decide, decide, state the assumption,
  and continue. Do not re-ask what the conversation already settled.
- **(MUST)** Do not assume the prompt is complete. A missing constraint that
  would invalidate the work if guessed wrong is worth a question; a detail you
  can pick sensibly and name in the summary is not.
- **(MUST)** When a prompt states a new rule — or anything interpretable as a
  durable rule (a preference, convention, or process meant to outlast the
  current task) — ask the user whether it should be written down. If the user
  confirms, add it to the file that owns that area (see the table above),
  phrased as a general rule, in the same change set.
- **(MUST)** Every prompt gets a short plan before any code is written: one
  entry per task with a clear, testable Definition of Done, short enough to
  grasp at a glance, stated in the chat. Where two or more approaches
  exist, the plan lists them with pros and cons. With it, the agent says
  whether the work warrants a plan *file* under `plans/` and recommends one
  way or the other; the user decides. A trivial change — a typo, a rename,
  a one-line fix — never gets a file, and its plan is stated and acted on
  in the same turn: a confirmation round for a one-line fix costs more
  than the fix. Everything else waits for the user's confirmation of the
  plan before implementing. A new feature of any size, work that spans
  more than one change set, or work that contains an architecture
  decision gets a file, written before the work begins (§"Plan and ADR
  rules"). In every case the result is checked against every DoD, and the
  work continues until each is met.
- **(SHOULD)** Size plan phases to be productive but still focused — big
  enough to get somewhere, small enough not to lose the thread.
- **(MUST)** When two rules appear to collide in a concrete case, ask rather
  than pick. The rule files say which rule wins where the authors foresaw
  the collision; where they do not, the user decides, and the answer is
  written into the file that owns the rule (see the rule about durable
  rules above).
- **(MUST)** Converge on the real cause before fixing anything. Name the
  plausible explanations, actively rule out the alternatives to your favourite
  one, and start from the isolated part where the bug appears — ask the user
  to confirm your reading before widening the scope. Do not implement a patch
  while the explanation is still uncertain.
- **(MUST)** Fix the cause, never the symptom. A change that hides, suppresses
  or bypasses the visible behaviour — or that disables, removes or degrades
  intended behaviour to make a bug disappear — is a rejected workaround, not a
  fix, unless that behaviour was explicitly unwanted.
- **(MUST)** Take the right way, never the convenient one. Where the correct
  solution costs more work than a shortcut that would make the same symptom go
  away, the correct solution is the one that ships — no quick-and-dirty, no
  "good enough for now", no reaching for the path that is merely easier to
  write. Reusing something that already exists because it happens to produce
  the right answer is such a shortcut whenever it does far more than the
  problem asks for. If the right way is genuinely out of proportion to the
  problem, say so and let the user decide; never decide that silently by
  writing the cheap one.
- **(MUST)** Optimise for measured impact, never for its own sake. A change
  that removes real work is not thereby an improvement: state beforehand which
  number it should move and by roughly how much, and afterwards whether it
  did. A change whose number did not move is reported as such and reverted
  unless it earns its place another way — it is not quietly counted as
  progress. Two shapes to distrust: a change that removed passes over
  thousands of rows and moved nothing measurable, and a change that was
  plausible, unverified, and made things worse. Both look like optimisation
  while they are being written.
- **(MUST)** Keep it simple. The design that ships is the simplest one that
  meets the stated requirement: the fewest parts, the fewest layers, the
  fewest concepts a reader has to hold. Complexity is earned by a
  requirement that is written down, never by a case that might come — no
  abstraction for a second caller that does not exist, no configuration
  for a variation nobody asked for, no framework where a function does.
  This and "the right way, never the convenient one" are the same rule
  seen from two sides: that one forbids the cheap *incorrect* solution,
  this one forbids the elaborate *correct* one. What ships is correct and
  has the fewest parts. Simple means few parts in the *implementation*,
  never less for the user: what the user gets is decided by the interface
  rules in the principles (`docs/ARCHITECTURE_PRINCIPLES.md` §"User
interface"), and a simpler build is not
  an argument against a better interaction.
- **(MUST)** Do not add speculative or unnecessary code. First identify the
  root cause and only implement changes that directly address it.
- **(MUST)** If an emergency mitigation is explicitly requested, label it as
  temporary, state the root-cause fix that remains, and do not present it as
  complete work. Otherwise, continue investigating until the root cause can
  be fixed directly.
- **(MUST)** When the user corrects your bug analysis, record the correction
  precisely and update your working assumptions immediately.
- **(SHOULD)** When the root cause sits in a dependency that is maintained
  alongside this project, say so and propose the change there — a fix
  upstream is a real option, and a workaround here is one every future caller
  inherits. Ground the proposal in the measurement, name file and line, keep
  the project working meanwhile, and record it in the investigation's plan so
  it survives the session.

## After coding

- **(MUST)** Reflect greenfield before reporting done. Once every
  Definition of Done is met, ask: knowing everything that surfaced during
  the work — the constraint nobody had written down, the module that turned
  out to own the question, the abstraction that was one case too many —
  how would this be built from scratch? Where that answer differs from what
  was built, the difference is named in the summary, and the refactoring
  that closes it is proposed as a plan entry with its cost. It is never
  performed silently in the same change set, and it is never skipped
  because the tests are green: the moment after the work is the one time
  the whole picture is in view, and it is gone with the session.
- **(MUST)** Carry refactorings that the work *needed* inside the work, in
  their own commits ahead of the feature — a rename, an extraction, a moved
  responsibility that the feature would otherwise have to work around.
  A feature commit that also reshapes what it touched cannot be reviewed;
  a refactoring commit that changes behaviour cannot be trusted. Keep the
  two apart, and keep both to what the feature needs.

## Working within the context budget

Everything a tool returns is paid for again after every compaction, so the
work is token-optimised throughout: read *narrowly*, not less — the same
answer for a fraction of the bytes — and let nothing into the conversation
that a search, a filter or a subagent could have kept out of it. None of
this licenses a shortcut on correctness — where these rules and any other
rule conflict, the other rule wins.

- **(MUST)** Search first, read second. Locate with a search tool and a
  narrow glob, then read the lines around the hit; never open a file to find
  out whether it is relevant. Files beyond a few hundred lines are read by
  range, not whole.
- **(SHOULD)** Delegate a broad sweep instead of performing it. A question
  answered by scanning many files or naming conventions ("where is this used",
  "which modules do X") goes to a search subagent, so only the conclusion
  enters this session. Read directly when the file is already known.
- **(MUST NOT)** Open generated or curated data in full — fixtures, seed
  data, catalogues, locale files, lockfiles. They run to thousands of
  rows; query them with a search tool, a JSON processor or a one-off script
  and print only the answer. One such file costs more context than every rule
  file in this repository combined.
- **(MUST)** Filter command output where it is produced. Test, build, lint,
  log and `git` commands print far more than the answer: bound them (`| tail
  -30`, a quiet flag, a failed-only mode, `git diff --stat`, `git log
  --oneline -n 20`) and pull the full output only for the one thing that
  actually failed.
- **(MUST)** Verify narrowly while iterating, fully once at the end. Type
  checks, linters and tests run on the touched paths during the work; the
  full check — the unit's `precommit`-style command, and the full suites of
  every unit the change touches — runs *locally*, once, before the work is
  reported done. This holds whether or not CI exists and whether or not the
  work goes out as a pull request: CI is not always set up, and a summary
  that says "CI will tell" has not verified anything. Ten green full runs
  carry the information of one, so the full run is once, at the end, not
  after every edit.
- **(SHOULD)** Read a plan or an ADR once, and keep the answer rather than the
  document. These run to tens of KB. Note the two lines that mattered and cite
  the path; do not re-open it later in the same session.
- **(MUST)** A fresh worktree carries no dependencies. Installing them comes
  before any check, or its result describes nothing. Confirm which build
  produced a measurement before drawing a conclusion from it: check the
  installed package, not the lockfile and not your memory of what you
  installed.

## Working within the machine's budget

This machine is shared. Other sessions run their own suites in their own
worktrees, the user builds, edits and analyses alongside them, and every
container any of them started competes for the same cores. Time and CPU spent
here are taken from all of them: a run that saturates the machine does not
merely take long itself, it stalls everything else running on it.

- **(MUST)** Do the least that answers the question. Every check needs a
  reason it is being run *now* — a check whose result cannot change what
  happens next is not diligence, it is cost. Do not re-run what already
  passed when nothing since could have broken it, do not verify an edit the
  tool would have failed on, and do not build to find out something a search
  answers.
- **(MUST)** Keep expensive work proportionate to the problem. Before starting
  anything that will occupy the machine for minutes — a full suite, a clean
  rebuild, an image build, a sweep over thousands of rows — name what it is
  for and take the narrowest form that answers it. Where only the expensive
  form can answer it, say what it will cost and let the user decide, rather
  than starting it and reporting the wait afterwards. The one full run
  before reporting done (§"Working within the context budget") is exempt
  from the asking: it is the rule being verified, and it was named when the
  plan was confirmed.
- **(SHOULD)** Bound parallelism instead of claiming the machine. Default job
  and worker counts assume the cores are yours; they are not. Leave headroom,
  and prefer one job that runs a while to a fan-out that owns every core.
  Where a suite configures its own worker count, keep it a *cap*, never a
  fraction: a fraction that suits the large machine starves the small CI
  runner, and vice versa.
- **(MUST)** Leave nothing running that the work no longer needs: background
  tasks, watchers, dev servers, and the containers under them. An idle
  watcher still wakes on every file the other sessions write.

This is the same discipline as *Working within the context budget* seen from
the other side, and the two rarely disagree: the run that costs the fewest
bytes usually costs the fewest cycles too. Where they do, neither licenses a
shortcut on correctness — the rule being verified wins.

## Processes, ports and external state

**(MUST)** Before starting anything that runs, listens or connects — a
server, a container, a datastore, a background task, a wait on any of them
— read `docs/PROCESSES.md` and keep to it. It is where a test run against
a production datastore forwarded to a local port is prevented, and where
an abandoned container that blocks the next session is prevented; both
fail silently and are found by someone else.

## Verifying a change

**(MUST)** Before verifying a change — and before claiming that it works —
read `docs/VERIFICATION.md` and follow it: the real product in an
equivalent environment, the end-to-end plan or the acceptance criteria,
the user's approval for their screen, the build mode that shows the whole
product. A change verified by its tests alone has not been verified; that
is the defect the document exists to catch.

## Security

Security is a correctness property of every component that accepts input
across a trust boundary — every server component above all. The rules are
in `docs/ARCHITECTURE_PRINCIPLES.md` §"Security"; the duties they impose
on a change set are these:

- **(MUST)** A vulnerability in our own code is a defect that blocks the
  work; what cannot be assessed is reported as unassessed, never as secure
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"Assessment").
- **(MUST)** The refusal tests of a new entry point, validator or
  authorisation rule ship in the same change set
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"Tests").
- **(MUST)** A change that touches a trust boundary is reviewed against the
  vulnerability classes before it is reported done, and the summary names
  what was checked, one line per class
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"Assessment").
- **(MUST)** A security property is never traded away on the agent's own
  authority: say what the right implementation costs, let the user decide,
  and record a trade in an ADR (`docs/ARCHITECTURE_PRINCIPLES.md`
  §"Assessment").

## Before reporting done

The duties above are spread over this file and the principles because each
lives with its reason. This is the list, so none is forgotten. Work is
reported done only when every line that applies is true, and the summary
says which lines did not apply and why.

1. Every Definition of Done from the plan is met, and checked, not assumed.
2. The formatter is clean and the build has no warnings; the unit's
   `precommit`-style command and the full suites of every touched unit
   passed locally, once, at the end.
3. Every new function, endpoint or rule that carries a security property
   has its refusal tests, and a change to a trust boundary was reviewed
   class by class (§"Security").
4. Every generated artifact whose source changed was regenerated, and its
   test passes.
5. Every living document that owns something the change altered was updated
   — `docs/ARCHITECTURE.md`, `docs/SPEC.md`, `docs/DESIGN.md`, the dossier
   section, the release document, this file or an area file.
6. Every architecture decision the change contains has its ADR; every new
   single-instance assumption is in `docs/HORIZONTAL_SCALING.md`.
7. The plan's `## Status` section states what is now true; a plan that is
   complete was moved to `plans/done/` with every reference rewritten.
8. A user-visible change ships with its end-to-end test plan where the unit
   has a user interface; the plan — or, without one, the feature's
   acceptance criteria — was executed against the running product, and the
   outcome is in the summary.
9. Nothing the work started is still running; nothing it brought up is
   still listening.
10. The greenfield reflection was done, and the gap between what was built
    and what would be built from scratch is in the summary as a proposed
    refactoring — or the summary says there is none.
11. The summary is a management summary in the user's language: what it
    means, what follows, what was not assessed, cited as `path:line`.

## Reporting and delivery

- **(MUST)** Answer the user in the language they wrote in, and keep
  following them when they switch mid-conversation. This governs the
  conversation only — code, comments, commit messages, and everything under
  `docs/` and `plans/` stay English per the documentation language rule
  above.
- **(MUST)** Report as a management summary: what it means and what follows
  from it, not the path that led there. Leave out technical detail the user
  did not ask for, but never something they need to judge the outcome. Cite
  code as `path:line` rather than pasting it.
- **(MUST)** The delivery mode follows the checkout. A session in a
  worktree (`git worktree list` shows the current directory as one) works on
  that worktree's branch and delivers as a pull request; a session in the
  main checkout works on the current branch and delivers as commits on it.
  A branch created for a task is named after the task. The summary names
  the mode that applied.
- **(MUST NOT)** Commit, push or open a pull request without being asked.
  The work is done when it is verified and reported; committing it is the
  user's call, per task, and an instruction to commit in one task does not
  carry into the next.
- **(MUST)** When asked to commit, rebase or open a pull request, read
  `docs/COMMITS.md` first and keep to it: the message format the changelog
  reads, staging by path so that another session's work is not swept into
  the commit, a rebase that adds no commits. Each of these fails silently
  and is found later, in the history, by a reviewer.

# Area rules

*(Single-unit repositories only. A monorepo deletes this section and gives
each unit its own `<area>/AGENTS.md` in the shape `docs/RULE_WRITING.md`
gives. A single-unit repository fills this section in that same shape —
toolchain, verifying a change, tests, end-to-end test plans, persistence,
security, the unit's own hazards, coding rules — so the rules that are only
this unit's live here, beside the repository-wide ones above, and load with
every turn.)*
