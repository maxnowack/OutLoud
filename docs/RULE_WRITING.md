# Writing rules

This document owns how a working rule is phrased, where it lives, and what an
area file looks like. The rules themselves live in `AGENTS.md`, the area
files, `docs/ARCHITECTURE_PRINCIPLES.md`, and the three situational
documents `docs/PROCESSES.md`, `docs/VERIFICATION.md` and
`docs/COMMITS.md`.

## Where a rule goes

| The rule is about | It goes in |
| --- | --- |
| How to plan, verify, commit, report — regardless of stack | `AGENTS.md` |
| The shape of the system, regardless of stack | `docs/ARCHITECTURE_PRINCIPLES.md` |
| One area's stack, tooling, data-access gate or generated artifacts | `<area>/AGENTS.md` |
| A convention every unit of one stack shares | `AGENTS.md` §"Conventions shared by every unit of one stack", once |
| A repeatable multi-step procedure an agent runs (a batch pass, a measurement loop) | a skill file under the harness's skill directory, with the plan that explains why under `plans/` |
| A group that applies everywhere but only in a situation — starting something, verifying, committing | its own document under `docs/` (`docs/PROCESSES.md`, `docs/VERIFICATION.md`, `docs/COMMITS.md`), with one `(MUST)` in `AGENTS.md` that names when it is read and what it prevents |

A rule is stated once. An area file that needs a repository-wide rule points
at `AGENTS.md`; it does not restate it. The one allowed second appearance
is a duty the root `AGENTS.md` imposes on every change set whose rule a
principle owns: the root names the duty in one sentence and points at the
owner, and the why and the cost stay with the owner. Anything longer is a
second copy, and a second copy drifts — the review of 2026-09-17 found
eleven of them, two with different modalities for the same rule.

## How a rule is phrased

Every rule has four parts, and the last two are what make it hold:

1. **A modality.** `(MUST)`, `(MUST NOT)`, `(SHOULD)` or `(SHOULD NOT)`, in
   bold, at the start. A MUST is a condition for the work counting as done.
   A SHOULD is the default and may be deviated from when the deviation is
   named and reasoned.
2. **The rule**, in one sentence, imperative, concrete enough to check.
3. **Why**, in a sentence or two: the mechanism that makes the rule
   necessary. "Because it is cleaner" is not a why. "Because the decoder
   refuses unknown symbols, so an unknown key fails on live input" is.
4. **What it cost**, where there is a case: the incident, the measurement,
   the day. A rule without a stated cost gets waived the first time it is
   inconvenient; a rule that says "this cost an hour of experiments against
   a stale bundle on <date>" does not. Cite the plan or ADR that holds the
   detail rather than reproducing it.

Where a rule has a *worked example* — the one place in the code that shows
the rule done right — name it. A reader who can look at one correct instance
needs less explanation than one who has to reconstruct it.

Where a rule is *checked* rather than remembered — a test that fails the
suite, a lint that rejects the identifier, a CI step that exits non-zero —
say so and name the check. A checked rule can be shorter; the check carries
the enforcement and the rule carries the why.

Rules that state the same thing from two sides (the context budget and the
machine budget) say so and say which wins when they disagree.

## What is not a rule

- A preference that costs nothing when ignored. Fold it into the code style
  section as a SHOULD, or leave it out.
- A description of how something currently works. That is documentation and
  belongs in the living document that owns the concern.
- A decision and its rationale. That is an ADR.
- A step-by-step procedure. That is a skill or a README.

## When a rule changes

A rule whose mechanism changed but whose conclusion did not says so in
place: "the mechanism changed with ADR NNNN and the rule did not". A rule
that no longer holds is deleted, not softened. A rule that moved between
files leaves no forwarding note; the table above says where it is.

A plan written before a rule that now contradicts it keeps its body
(`AGENTS.md` §"Plan and ADR rules"); the rule says "plans written before
this rule still say the opposite; the rule here is the one that holds".

## The shape of an area file

An area file is `<area>/AGENTS.md` in a monorepo — with a `<area>/CLAUDE.md`
beside it containing `@AGENTS.md`, so that Claude Code loads it — or the
*Area rules* section of the root `AGENTS.md` in a single-unit repository.
It opens by scoping itself and pointing back, then lists its rules grouped
by concern. The groups every area file has, in this order — delete a group
only when the area genuinely has nothing under it:

```markdown
# <Area> working rules (`<area>/`)

These rules cover <the stack>. Repository-wide rules — how to work, plan and
ADR duties, commit and staging discipline — live in the root `AGENTS.md`;
the architectural rules they specialise live in
`docs/ARCHITECTURE_PRINCIPLES.md`; the root file says when each is read.
<The living document or plan that describes this area's architecture> — read
it before making changes here.

## Toolchain

What version of what to read before writing code; what not to start
(the user's interactive server); how the agent's own instance runs; the
build mode to verify in and why.

## Verifying a change

How a behaviour change is proven in this area, what a run proves and does
not prove, and which runs need the user's approval.

## Tests

The runner, what is real and what is mocked, the rules the runner's
mechanics impose (hoisting, workers, snapshots), and the worked examples.

## End-to-end test plans

How the plans under `e2e/` are executed for this unit — the simulator,
emulator or browser and the tools that drive it — the coverage index,
identifier conventions, and what may not be asserted on.

## Persistence

The data-access gate and its closed exception list. The generated
artifacts, each with its generator, its source, and the test that fails
when they part ways. The bounded-read rule and where it is checked.

## Security

For an area with a trust boundary: the concrete validation layer, the one
place authentication and authorisation are enforced, the secret store,
the scan and the refusal-test conventions — specialising
`docs/ARCHITECTURE_PRINCIPLES.md` §"Security", never restating it.

## <The area's own hazards>

One group per mechanism whose breach is silent and expensive — a single
lane, an exclusive resource, a wire format, a cache. Each rule with its
why and its cost.

## Coding rules

The area's style: naming, imports, quoting, what to extract and what to
leave inline. Short, because most of it is enforced by the formatter and
the linter.
```

The order matters: what an agent must know before it can *run* anything
comes first, what it must know before it can *write* anything comes last.
