# Verifying a change

This document owns how a change is verified before it is reported done.
`AGENTS.md` §"Verifying a change" says when it is read; the area files say
how a run is driven for their stack, and the end-to-end test plans are
shaped in `docs/ARCHITECTURE_PRINCIPLES.md` §"End-to-end test plans".

- **(MUST)** A new feature, or a change to how the product behaves, is
  verified by running it — the real binary, against real dependencies, in
  an environment equivalent to the one it ships to: a simulator or
  emulator, a local or staging deployment, a container built from the same
  image. Never production. Tests and a clean type check say the code does
  what it was written to do; they do not say the product works. Defects that
  live below the level a unit test can see (an operation order the store
  rejects, a build serving a stale configuration) are found only this way.
- **(MUST)** A user-visible change is one that alters what a user of the
  product can observe — a screen, a route, a command's output, an API's
  response. For such a change, that run follows the end-to-end test plan
  the change ships with where the unit has a user interface
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"End-to-end test plans"), and the
  feature's acceptance criteria in `docs/SPEC.md` where it has not: the
  agent executes the steps against the running product and reports each
  expected outcome as met or not. "It launched" is not a result; the
  assertions are.
- **(MUST)** Ask the user for approval before taking over something that is
  theirs — their screen, their simulator or emulator, their device, their
  interactive terminal session (not the shell the agent runs its own
  commands in) — and wait for it. The approval is not implied by having been
  asked to build the feature. One approval covers that one piece of
  verification — the whole test plan, or the whole loop, however many rounds
  and relaunches it takes. Do not ask again per round; ask again when
  starting a different piece of verification.
- **(SHOULD)** Where a scripted verification loop exists — one that sets up
  the environment, drives a session and judges the result — use it rather
  than looking at a screen, so "it launched" is not mistaken for "it
  worked". A plain look is fine when that is genuinely all the change needs.
- **(MUST)** Verify in the build mode that matches the question. Where the
  product has feature gates, a build that takes them from an account or an
  environment silently shows less than a development build, and a gate
  being closed looks exactly like the code being wrong.
- **(MUST)** A run on a developer machine, simulator or emulator proves
  behaviour, never performance. It runs on a workstation's CPU against a
  workstation's disk, so no figure from it is a measurement, and no
  threshold it trips is a finding. Performance is measured on the hardware
  the product ships to.
- **(MUST)** When a result contradicts an edit that is definitely on disk,
  check what was actually served, built or installed before believing the
  result. A stale bundle, a cached build or a watcher that silently stopped
  makes every negative result look like a real finding about the code.
- **(SHOULD)** Reach for a sampling profiler before adding another probe.
  In-product instruments can only time work someone already decided to
  instrument, so a cost nobody suspects is invisible to all of them; a
  profiler sees whatever is actually running.
- **(MUST NOT)** Run a scripted, state-mutating harness against real user
  data, a real user device or a production system without the user asking
  for it in that same conversation.
