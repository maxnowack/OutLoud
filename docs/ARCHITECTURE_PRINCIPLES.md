# Architecture principles

These are the architectural rules of this repository that are independent
of any technology, language or domain. Some groups apply to every kind of
software; some — *Exclusive resources*, *User interface* — apply to every
project of that kind. A project without a user interface deletes the group
and says so in the commit. Every area file
(`<area>/AGENTS.md`) specialises them for its own stack and domain — it
names the concrete data-access gate, the concrete generators, the concrete
transport, and adds the rules only that area needs — and does not restate
them. Working rules (how to plan, verify, commit) live in `AGENTS.md`; this
document is about the shape of the system.

Each rule carries the failure it exists to prevent. A rule whose cost is not
stated gets waived the first time it is inconvenient (`docs/RULE_WRITING.md`).

## Ownership

- **(MUST)** Give every piece of state exactly one owner, and let every other
  component reach it through the owner's interface. A second copy that is
  maintained by hand drifts; a second copy that is generated from the owner
  is fine (see *Generated artifacts*).
- **(MUST)** Separate facts from the judgement about them. What was observed,
  measured, imported or configured is one dataset; what the product makes of
  it — a score, a tier, a threshold, a policy — is another, with another
  owner. The two look like one thing and are two: the facts must be able to
  change without a product release, and the policy without re-collecting the
  facts.
- **(MUST)** Place a new module, dataset or responsibility with the component
  that owns the *question it answers*, not with the component that happens
  to need it first. The component that merely needed the answer first
  answers it for itself, and the second consumer then finds two answers.
- **(MUST)** Name modules, types, operations and functions with the domain
  vocabulary of `docs/SPEC.md` §"Vocabulary", not ad-hoc names. A reader
  who knows the specification must be able to find the code, and two names
  for one concept are read as two concepts.

## Persistence

- **(MUST)** All reads and writes of persisted data run through one declared
  data-access layer per unit. Direct access to the underlying store is a
  *closed, written-down* exception list — typically: opening the store and
  its settings, schema and data migrations, physical backup and restore, the
  layer's own adapter, independently justified performance escapes, and one
  named read-only reporting module. Anything not on the list goes through the
  layer, and adding to the list is a recorded decision.
- **(MUST)** Review every generated migration by hand before committing it.
  A generator produces the common case; anything the generator does not
  model is checked and added by hand, never assumed correct.
- **(MUST)** A migration never breaks the version that is running. Schema
  changes are made expand-then-contract: add the new column, table or
  index and deploy code that writes both shapes; deploy code that reads the
  new shape; only then remove the old one, in a later release. A rename is
  an add and a remove with a release between them. A migration that would
  fail the previous release's code against the new schema — a dropped
  column it still selects, a `NOT NULL` it does not yet fill — is a
  coordinated joint release (§"Contracts between components"), never a
  routine one.
- **(MUST)** A migration is reversible, and its reverse is written and
  tested with it — or the migration says in its own text why it cannot be
  and what the rollback of that release therefore is. A data migration
  runs idempotently and in bounded batches, so a crash halfway costs a
  restart, not a corrupted table.
- **(MUST)** Removing a field from a type does not remove it from the store.
  An adapter that maps the whole stored record keeps reading, transferring
  and writing back an undeclared field, and nothing in the type system can
  see it. Dropping a field means a migration, and the migration is what a
  test asserts against — the store's actual schema, not the type.
- **(MUST)** A field whose size grows with history or activity does not
  belong in a record that is read or written for other reasons. A record is
  the unit the store moves: every reader of the small fields beside it pays
  for the big one, in both directions. Give it its own table or collection,
  keyed by the slice its readers actually ask for.
- **(MUST)** A read over data that grows with history carries an
  index-matched predicate or a limit — and this is *checked* by a test that
  names the history-sized tables, not remembered; the area file names the
  mechanism that checks it. Where covering the whole set is genuinely the
  job (a rebuild, a count, a full listing), the read declares that with a
  stated reason beside it, so "this one is fine" is written down rather
  than taken on trust.
- **(MUST)** An index is declared in the one place the area file names for
  it — a migration, a schema file, a registry — and justified by a real
  access path. Verify critical paths with the store's query planner; do not
  add speculative indices.
- **(MUST)** A destructive operation enforces its own restriction: the
  filter that limits what it deletes is applied inside the operation, never
  merely displayed beside it or left to callers who could omit it. An
  operation that reads as restricted and is not deletes everything the
  first time a caller omits the filter — silently, and the tests do not
  notice because they reuse the same operation to clear state.

## Derived state

- **(SHOULD)** Where one piece of state is derivable from another — a
  count, an aggregate, a projection, a cache — the derived one is marked as
  derived and can be rebuilt from its source at any time, so the rule that
  derives it can change without a migration. This asks for one source per
  fact, not for an event-sourced architecture: a normalised schema where
  every fact is stored once already satisfies it, and a domain is free to
  keep an append-only log as its truth where that is the right design.
- **(MUST)** Write a read model *with* the write it describes, not behind it.
  A model that lags the row it derives from is a model no caller who needs
  the value *now* can use, and every one of them quietly goes back to the
  source it replaced — so the model costs a write and saves nothing. Where
  the write genuinely cannot be part of the same unit of work, the value
  belongs on the result the caller already holds, never on a re-read.
- **(MUST)** An import or ingestion job is idempotent and re-runnable: upsert
  on a natural identity, record the run, skip work whose input has not
  changed. A crashed run costs time, never correctness.
- **(MUST)** A long-running job checkpoints what it has already produced.
  A run that only writes its results at the end turns any interruption into
  total loss and makes its progress unobservable from outside. Write
  incrementally and resume from what is on disk.
- **(MUST)** Every stored snapshot records what it covered. Absence is
  evidence inside a known coverage and means nothing outside it; a
  derivation that forgets the difference concludes "gone" about everything
  the first time the source fails.

## Answering "not yet"

- **(MUST)** A query that has not been answered yet is not data. A newly
  issued read publishes a *neutral* result — an empty list, a zero count —
  until its source fulfils it, and that result is indistinguishable from a
  real one, because empty is a legitimate answer. Check the pending state
  and keep the last answered value; never let an unanswered read decide
  anything, and never let it write. The cost of getting it wrong is silent
  and looks like a different bug entirely.
- **(MUST)** No interface presents the neutral value of an unanswered read
  as an answer — not a blank, not a zero, not a placeholder figure. A gate
  (a feature flag, a permission, a configuration read) is a read like any
  other, so "not available" waits for it too. Do not invent a per-caller
  `loaded` flag that a loader sets on its own; it says only that the
  function ran.
- **(SHOULD)** Model "not answered yet" as its own state rather than folding
  it into the empty one, and make the unanswered state the *quiet* one —
  nothing announced, nothing granted, nothing triggered. A caller that
  forgets to handle it then gets silence, not false positives.

## Contracts between components

- **(MUST)** Pick one transport per client↔service pair and keep the
  exception list closed. New traffic goes on the transport; what stays off it
  is listed, and adding to that list is a decision that needs its own ADR.
  Existing exceptions migrate on a written schedule, new-path-first and
  old-path-still-working until a measured minimum client version allows
  removal.
- **(MUST)** Develop backwards-compatibly. An older client keeps working
  against a newer service and each service keeps working against the one
  that calls it. A breaking change is a coordinated joint release, never
  something shipped alone.
- **(MUST)** Keep every wire and persistence format versioned and additive.
  A running consumer is older than the producer as often as not, and the
  version is what lets it *refuse* a message instead of crashing on one. A
  new key is additive; a changed meaning for an existing key is a new
  version.
- **(MUST)** Update the consumer's vocabulary in the same change set that
  produces a new key. A strict decoder — one that refuses unknown symbols by
  design — fails on live input rather than reporting a missing field, and
  "the other side was deployed first" is the normal order, not the
  exception.
- **(MUST)** Where a consumer *persists* a record and its status vocabulary
  cannot tell a provisional value from a final one, deliver the record only
  once that value is final. Delivered early, it is persisted wrong and
  the consumer cannot repair it, because "unknown" and "not yet" read the
  same. This is about records that are stored on arrival; it does not
  forbid streaming partial results or optimistic updates where the
  consumer can tell the difference and will be told the final value.
- **(MUST NOT)** Hand a consumer two separate values that must agree with
  each other — a list and its length, a set of items and a parallel set of
  their positions — across a boundary that reads them one at a time (a
  message pair, two shared variables, two properties read in sequence).
  The reader can pair one moment's first value with the next moment's
  second. Hand over one value that holds the relationship — one structure,
  one message — so it is consistent by construction.

## Generated artifacts

- **(MUST NOT)** Hand-edit a generated artifact. Each has exactly one
  generator, the generator is chained into the script that changes its
  source, and a test fails when the checked-in copy no longer matches what
  its source would produce — so a stale artifact is caught by the suite,
  never noticed in production.
- **(MUST)** Regenerate every artifact in the same change set as the source
  it derives from.
- **(MUST NOT)** Copy into source code data that has a maintained source
  somewhere else — a curated table, a dataset, a configuration another
  component owns. A constant with no other source (a list of supported
  currencies, an enumeration the code defines) is code and lives in the
  code. A list extracted from a maintained dataset is a copy of *data* that
  the next update to the dataset rewrites without touching the copy at all.
  Such data crosses a boundary through a generator and a test, never a
  paste.
- **(MUST)** Where a live owner replaces a shipped artifact at runtime, keep
  shipping the artifact. The process boots from the shipped copy and needs
  nothing from the network for it, so a deployment whose live owner is
  unreachable behaves exactly as the previous one did; an artifact that
  exists only at the live owner makes every boot wait on that owner.

## Exclusive resources and upstreams

- **(MUST)** A resource that exists exactly once — a single-session
  connection, a licence-bound poll, a lock on an external system — is held
  by exactly one service, and that service does nothing else. Every
  additional responsibility is a reason it would have to be redeployed for
  something other than the resource, and its whole purpose is not being
  redeployed. It gets no database and no dependency beyond the format it
  emits.
- **(MUST)** Where a service must run as one instance, the deployment
  manifest enforces it and the register in `docs/HORIZONTAL_SCALING.md`
  says that the manifest is the *only* thing enforcing it. A second
  instance is not a capacity decision, it is an outage.
- **(MUST)** The side that redeploys often is the side that dials and
  reconnects. The holder of an exclusive connection *listens*; as a client
  it would have its own connection to recover, and its only recovery is the
  restart that costs the most. As a server it depends on one connection and
  consumers own their own problems.
- **(MUST NOT)** Make a long-lived upstream connection depend on a consumer
  — not on one being attached, not on one having asked, not on one being
  healthy. The connection must survive a consumer's deploy, crash and
  restart without noticing any of them.
- **(MUST)** Back-off floors and caps derived from an upstream's own
  penalties are documented invariants, not tuning knobs. A retry faster than
  the upstream's hold collides with your own previous attempt, fails
  *because of the retry*, and re-arms the hold — a self-perpetuating lockout
  that reads exactly like being blocked at the other end. Both bounds carry
  the date and the measurement that set them.
- **(MUST)** Only one thing polls a per-address rate-limited or
  licence-bound upstream, and only under a cluster-wide lease. A second
  caller is not a second safety net but a second address where the licence
  expects one; more replicas cannot buy throughput on a licence boundary,
  and rotating identity to get around it is a breach, not an optimisation.
- **(MUST)** Close an exclusive connection deliberately on the way out, and
  make sure the shutdown hook actually runs under the supervisor's
  termination. Otherwise the far end is left believing in a session nobody
  is reading, and that close was the only lever on the hold.
- **(MUST)** Emit a periodic health signal whether or not the upstream is
  up, and put in it a figure that distinguishes "alive and receiving the
  expected volume" from "alive and receiving a trickle". A signal only
  emitted while connected makes silence ambiguous between a dead process
  and a down upstream; raw byte and message counts look healthy for an
  upstream reduced to a fraction of itself.
- **(MUST NOT)** Configure on our side a setting that lives on the
  upstream's side. A copy is a second place that can disagree, and the
  failure when it does looks like health from outside: connected, bytes
  arriving, nothing usable. Detect per session instead.

## Security

Applies to every component that accepts input across a trust boundary — a
service with a network interface, an API, a job that reads what someone
else wrote, a CLI that parses a file it did not produce. On our own code a
vulnerability is a defect that blocks the work, not a risk to be noted:
where a class of vulnerability can be assessed, it is excluded, and where it
cannot, the report says so in those words. Dependencies cannot be
guaranteed the same way, so they are contained rather than trusted.

### Boundaries

- **(MUST)** Every trust boundary is written down when it is created: who
  calls across it and with what level of trust, what it accepts, and what
  it must never do. That is the component's threat model, it lives in
  `docs/ARCHITECTURE.md` (or the ADR that created the boundary), and it is
  what a reviewer and a test author check against. A boundary without one
  is reviewed against nothing.
- **(MUST)** Input is validated once, at the boundary, against an explicit
  schema — type, shape, size, range, encoding — and what passes is typed so
  that nothing downstream can receive *raw* input. Downstream code works
  on the typed value and does not re-parse the raw one; it still enforces
  the invariants it owns — a domain type's constructor, a store
  constraint, our own check in front of a dependency — because those are
  not validation of the input but guarantees of the component. Nothing
  downstream trusts a value that did not come through the boundary.
  Output is encoded at the sink for the sink's own grammar.
- **(MUST)** No query, command, path, template, header or log line is built
  by concatenating input. Parameterised queries, argument arrays instead of
  shell strings, path resolution checked against its root, templating that
  escapes by default. Every injection class has the same shape — input
  reaching an interpreter as code — and the same fix.
- **(MUST)** Authentication and authorisation are enforced in one place per
  boundary, never per handler, and a new entry point is *denied by default*
  until it declares what principal it requires — and "public" is such a
  declaration, made explicitly, never the absence of one. An endpoint that
  forgot to declare must fail closed, not open.
- **(MUST)** Every read and write of a resource checks that the caller may
  reach *that* resource, not merely that the caller is authenticated. An
  identifier in a request is a claim, not a permission.
- **(MUST)** Every unauthenticated entry point is rate-limited, and every
  operation whose cost depends on input is bounded — result size, upload
  size, recursion depth, time.
- **(MUST)** An error response reveals nothing about the inside: no stack
  trace, no query, no path, no version, no hint whether a user exists. The
  detail goes to the log; the caller gets a code and a correlation id.
- **(MUST)** An internal endpoint is reachable only inside the network
  boundary that makes its lack of authentication acceptable; exposing it
  is a decision that adds a credential first, because "internal" is the
  whole reason it has none.

### Secrets, cryptography and logs

- **(MUST)** A secret is never in the repository, never in a log, never in
  an error message, never in a URL. Configuration comes from the
  environment or a secret store, and a scan in CI fails the build on
  anything that looks like a credential.
- **(MUST NOT)** Write cryptography. Use the platform's or an audited
  library's primitives: passwords through a memory-hard hash, tokens from a
  cryptographic random source, comparisons in constant time, transport
  encrypted and verified. A home-grown scheme is a vulnerability with extra
  steps.
- **(MUST)** Operational logs carry no personal data and no secrets.
  Security-relevant events — authentication, a permission change, a
  deletion, an access denied — go to an audit trail that says who, what,
  when and from where; the audit trail is a store of its own, access-
  controlled, with its own retention, and what it carries is classified in
  the data section of the architecture document, because
  "from where" is personal data and is kept there deliberately, not
  leaked into the log by accident.

### Tests

- **(MUST)** A security property has a unit test, written in the same
  change set as the function or endpoint that carries it — never later.
  The tests that matter are the *negative* ones: the wrong principal is
  refused, the foreign resource is refused, the oversized input is refused,
  the injection payload arrives at the interpreter as data, the secret does
  not appear in the log or the error. A positive test says the feature
  works; only a refusal test says the boundary holds.
- **(MUST)** Every boundary is tested with hostile input, not only with
  malformed input: the classic payloads for its injection class, boundary
  sizes, wrong encodings, path traversal, nested depth. The test is of
  *our* boundary's behaviour — the payload is refused, or it reaches the
  sink as data — not of the validation library; a schema library's own
  tests are its author's business. A boundary tested only with "a string
  where a number was expected" has not been tested.
- **(MUST)** Every authorisation rule has a test per role that must be
  refused, and a test that an entry point without a declaration is denied.
  Adding an endpoint without its refusal tests fails the review, and where
  the framework allows it, a test enumerates the entry points and fails on
  one without a declared principal.
- **(SHOULD)** Where a class of attack can be exercised end to end — a
  forged token, a replayed request, a tampered parameter — an acceptance
  test does so against the running component.

### Dependencies

- **(MUST)** A dependency that handles untrusted input sits behind our own
  boundary: our validation runs before it sees the input, and its output is
  treated as input. What we cannot audit we contain.
- **(MUST)** Dependencies are pinned, minimal, and scanned in CI on every
  pull request; a reported vulnerability is triaged within the time the
  dependency policy states — the area file's §"Security" — and the triage is
  recorded even when the answer is "not reachable from our code".
- **(SHOULD)** Prefer the dependency with the smaller surface and the
  active maintainer; a dependency chosen for convenience that brings a
  parser, a network client or an evaluator we do not use brings their
  vulnerabilities too.

### Assessment

- **(MUST)** A change that touches a boundary is reviewed against the
  vulnerability classes above before the work is reported done, and the
  report names what was checked. Where a class could not be assessed — a
  dependency's behaviour, a platform guarantee we cannot verify — the
  report says exactly that, rather than claiming a security that was not
  established.
- **(MUST NOT)** Trade a security property for a feature, a deadline or a
  convenience without an ADR that names the property given up, the
  exposure it creates, and the date by which it is restored.

## Resilience and configuration

Applies to every long-running process — a service, a worker, a daemon — and
to every component that calls one.

- **(MUST)** Every outbound call has a timeout, and the timeout is chosen,
  not defaulted: a call without one holds its thread, its connection and
  its caller's request for as long as the far end stays silent, and a far
  end that stays silent is the normal failure, not the rare one.
- **(MUST)** A retry is only ever of an idempotent operation, is bounded in
  count and total time, and backs off with jitter. A retry of a
  non-idempotent call duplicates its effect; a retry without jitter turns
  one outage into a synchronised stampede the moment the far end recovers.
  Where an operation must be retried and is not naturally idempotent, it
  carries an idempotency key the far end honours.
- **(MUST)** Configuration is read once at startup, validated as a whole,
  and the process refuses to start on anything missing or malformed —
  with a message that names the key. A process that starts with a bad
  configuration fails later, somewhere else, in a way that looks like a
  different bug. Nothing reads the environment after startup.
- **(MUST)** A process shuts down gracefully: on the termination signal it
  stops accepting work, finishes or hands back what it holds, closes what
  it opened, and exits within the deadline the platform gives it. A
  process killed mid-request loses the request and leaves the far end
  believing in a session nobody is serving.
- **(MUST)** A long-running process exposes liveness and readiness
  separately, and readiness reflects the dependencies the process cannot
  serve without. A single health endpoint that answers "ok" while the
  database is unreachable routes traffic into failures.
- **(MUST)** Every request carries a correlation identifier from the edge
  through every component and every log line it produces, so one failure
  can be followed across the system from one id. Logs are structured, not
  prose, so they can be queried.

## Release and versioning

- **(MUST)** Every unit has a version, and the version follows semantic
  versioning: a breaking change to what the unit exposes is a major, an
  addition a minor, a fix a patch. What "exposes" means for the unit — an
  API, a wire format, a library surface, a CLI's arguments and output — is
  written in `docs/RELEASE.md`, so that "is this breaking" has an answer
  before the change is made, not after it has shipped.
- **(MUST)** `docs/RELEASE.md` owns how a version is cut, released and
  rolled back, per unit, and the release checklist — the end-to-end test plans
  executed, the changelog written. A release is performed by following it,
  and a step that the document does not have is added to it in the release
  that needed it.
- **(MUST)** A rollback is a documented, tested procedure, not an idea. The
  release document says how the previous version is restored — including
  the schema, which is why migrations expand before they contract
  (§"Persistence") — and the procedure has been performed at least once
  before it is needed.
- **(SHOULD)** The changelog is generated from the commit history, which is
  why commit messages follow Conventional Commits (`docs/COMMITS.md`): `feat` and `fix` and a `!` for a
  breaking change are what the changelog and the version bump read.

## Data quality

- **(MUST)** Keep absence absent. An empty field is not a zero, a padding
  value is not a measurement, and only an explicitly *set* value is
  believed. Believing padding lets a source contradict a state that was
  derived more carefully elsewhere.
- **(MUST)** A heuristic may only turn *unknown* into a claim, never reverse
  a measurement. It adds certainty in one direction — the direction whose
  cost, when wrong, is a missing answer rather than a wrong one. A bound
  that *refuses* a reading is fine; one that *makes* one is not.
- **(MUST NOT)** Infer a state from a proxy signal that two different real
  states share. Every threshold that removes the one removes the other.
- **(MUST)** Ask a new source how a state *ends* on it before believing it
  about how one begins. A source that can open a state but never close it
  serves stale facts for ever, and a metric says when the answer was wrong.
- **(MUST NOT)** Read a published specification as authoritative over
  measured behaviour. Where the two disagree and the disagreement has been
  measured, the measurement is recorded in an ADR and the code follows it.

## Shared single-lane resources

Applies wherever one thread or loop serialises everything — a UI thread, an
event loop, a single-threaded worker, a serialised job queue.

- **(MUST)** A single-lane resource is shared, and every task is queued on
  it. A task that occupies it for longer than its budget delays
  *everything* — so a stalled task is never diagnosed where the stall
  showed; find what held the lane. The signature: an input that appears to
  do nothing and then, later, takes effect several times over — it was
  queued, not slow, and replayed when the lane came free.
- **(MUST)** Nothing that scales with the size of the data runs on the lane
  on a hot path. Moving work off the lane does not move its serialisation:
  a result crossing back is decoded on the lane, so a query's *result size*
  is a lane cost even when its execution is not. Project at the source
  rather than reading whole records and narrowing afterwards.
- **(MUST)** A consumer that is not active does no work. A read, timer or
  poll it keeps running competes for the lane that has to serve the active
  one. What must keep running regardless (a connection, a scheduler, a
  lifecycle listener) lives above the consumers, in a scope of its own.
- **(MUST)** A global batch or transaction scope is short-lived by design.
  It parks *every* dependent read until it ends; that is right for a handful
  of writes belonging to one event and wrong for anything whose length is
  data-dependent. Never batch a loop whose iteration count comes from the
  network or the store.
- **(MUST)** Keep a reactive or subscribed read as small as the consumer it
  serves. Do not put several unrelated reads and a large derivation into one
  scope: every change to any source it touches re-runs the whole thing, for
  every subscriber. Split per consumer, keep the selector stable, and keep
  the derivation a pure function over the read rather than a step inside it.
- **(MUST)** A callback registered across a runtime or process boundary is
  created once and kept, never re-created per render or per tick:
  registering serialises its whole closure across the boundary each time.
  For the same reason a value is compared before it is written across such
  a boundary — the write crosses whether or not the value changed.
- **(MUST)** An error thrown on a runtime that has no handler above it kills
  the process, and a development build may show it as a log entry instead.
  Prefer a shape that cannot fail over a guard that has to remember to.

## User interface

Applies to any product with a user interface — web, mobile, desktop. The
rules name the mechanisms every UI toolkit shares: a single UI thread, a
navigator that keeps screens mounted, a renderer that decides which nodes
become native views, an animation path that is cheap for some properties
and expensive for others.

### Design system

- **(MUST)** The visual style is decided at project start, before the
  first screen, and written in `docs/DESIGN.md`: the tokens (colour,
  typography, spacing, shape, elevation, motion) and the component
  vocabulary built on them. "Decided" is not "frozen": the style grows by
  tokens and components, and changes by a decision recorded in
  `docs/DESIGN.md` — never by a screen that quietly does it differently. A
  style decided screen by screen is not a style; it is a set of screens
  that happen to be in one app, and every later change touches all of them.
- **(MUST)** The interface is built entirely from the component library. A
  screen composes components and arranges them — its layout props (flex,
  stack, grid, padding and gap from the spacing tokens) are its own — but
  it carries no *visual* decision: no colour, typography, radius, border,
  shadow or motion outside a component. A raw primitive with a visual
  style in a screen is a defect, and a lint rejects a literal colour, size
  or radius where a token belongs.
- **(MUST)** A screen that needs a component the library does not have gets
  the component *first*: its role, its states (loading, empty, error,
  disabled, pressed), its variants and the tokens it uses are designed and
  recorded in `docs/DESIGN.md`, it is added to the library with its tests
  and its example, and only then is the screen built from it. Never inline
  it "for now", and never copy an existing component with a tweak — the
  tweak is a variant, and it belongs on the original.
- **(MUST)** A new visual decision is a token, not a literal, and a token is
  added to `docs/DESIGN.md` in the same change set that introduces it. Two
  components that "look about the same" but read different tokens are two
  designs, and the reader cannot tell which one is current.
- **(SHOULD)** Every component documents and renders its states, and the
  loading rule below holds per component: a component that has not been
  handed its data shows its loading state, not its empty one.

### Accessibility

- **(MUST)** Accessibility is part of a component's contract, not a pass
  over the finished screen. Every component in the library ships with its
  accessible name and role, its focus behaviour, its colour pairs checked
  against the contrast tokens, and its text scaling with the platform's
  text size — and `docs/DESIGN.md` records them beside its states. A
  screen composed from accessible components is accessible; a screen
  patched afterwards is accessible until the next change.
- **(MUST)** Every interactive element is reachable and operable without a
  pointer — by keyboard where there is one, by the platform's assistive
  gestures where there is not — in an order that follows the reading order.
  An element the user can tap but not reach is a wall for a user who
  cannot tap.
- **(MUST)** Meaning is never carried by colour alone, by motion alone, or
  by an image without a text alternative.
- **(MUST)** Every end-to-end test plan includes one pass of the flow with
  the platform's screen reader on (§"End-to-end test plans"), so a screen
  nobody can hear is found before it ships, not by the user who reports
  it. Where the driver cannot hear, the pass reads the accessibility tree,
  and the plan says so.

### Design

- **(MUST)** The user's experience is the deciding constraint, and the
  effort it costs is not an argument against it. Where a better interaction
  exists — direct manipulation instead of a confirmation step, an optimistic
  update instead of a spinner, an undo instead of a dialog, a state that
  explains itself instead of a screen that silently omits what it cannot
  offer — propose it with its cost, and build it when the plan the user
  confirmed includes it: the requested scope stays the deliverable
  (`AGENTS.md` §"Before coding"), and the better design enters it by
  decision, not by the agent widening the work. "That would be a lot of
  work", "the current one already works" and "the platform makes it
  awkward" are reasons to plan the work, never reasons to ship the lesser
  design. Two rules of thumb decide the
  close calls: prefer the design that needs less explaining, and never make
  the user do the product's bookkeeping — confirming what they just did,
  retrying what could retry itself, or guessing what the screen could have
  told them. When the better design is genuinely out of reach in this change
  set, say so explicitly and record what it would take, rather than letting
  the compromise become the design.
- **(MUST)** A screen whose data comes from a read that has not answered
  renders a loading state — never an empty state, a blank area, or
  placeholder figures (§"Answering 'not yet'"). A feature gate is a read
  like any other, so a gated screen's "not available" branch waits for the
  gate too.

### Layout

- **(MUST)** Model each visual relationship in the layout hierarchy that
  owns it. Component structure and layout constraints express the design
  intent directly; do not compensate for an incorrect parent-child
  relationship, sizing rule, or layout flow in a descendant.
- **(MUST NOT)** Ship a quick workaround that changes or bypasses intended
  state, hierarchy, navigation history, or interaction semantics to hide a
  symptom — replacing navigation history to emulate Back, suppressing an
  element that should be positioned correctly, a one-off offset for a
  responsive layout issue.
- **(MUST)** Animate what the renderer animates cheaply — transforms and
  opacity — and let the layout engine own size and position. A view whose
  *presence or size* comes out of an animated value can simply not be there
  until something else moves it. Where a size genuinely has to animate, say
  so and measure it; do not let the animation decide whether the thing
  exists.
- **(MUST NOT)** Let a wrapper above an expensive native surface (a GPU
  canvas, a map, a video) come and go. A renderer creates a native view only
  where one is needed, and a transient property — a press-state opacity, a
  transform while something is happening — makes it needed on interaction
  and unneeded afterwards, so everything under it is re-parented twice per
  interaction. A surface with its own GPU-backed state does not survive
  that. Put the transient property on a view that exists either way, or
  declare the wrapper non-collapsible. A constant property is safe for the
  same reason: it never toggles.

### Navigation and the UI thread

- **(MUST)** A tap or click that navigates navigates *now*. The handler's only job is
  the navigation call — no await, no read, no write, no derivation before it
  — and the destination's first frame is cheap enough to commit within one
  frame: its background, its header, and a loading state if the data is not
  there yet. Everything expensive on that screen mounts *after* the
  transition. "The data usually arrives fast enough" is not a defence: the
  screen must appear before the data is asked for, not after it answers.
- **(MUST)** A navigating press is idempotent for as long as it is pending.
  If the thread is busy, the user will act again — and must not end up
  several screens deep. Guard the push; do not assume the stall away.
- **(MUST)** A screen that is not visible does no work. Backgrounded tabs
  and covered stack screens stay mounted in most navigators;
  a query, timer or poll they keep running competes for the thread that has
  to process the next input. What must keep running regardless (a connection,
  a scheduler, a lifecycle listener) lives above the navigator.
- **(MUST)** A read whose result grows with the user's history is
  focus-gated: dropped while the screen is away, its last answer held so
  nothing flickers on return. A subscribed read is re-delivered on every
  write to its source for as long as it exists, so an unfocused screen with
  such a read makes every write pay for a result nobody is looking at. A
  small, bounded read does not need this.
- **(MUST)** A stalled screen change is never diagnosed at the navigation.
  Navigation is nothing but a state update on the navigator; find what held
  the UI thread (§"Shared single-lane resources").
- **(MUST)** A component that hosts an expensive-to-re-record surface is
  memoised, and memoised over what it *draws*. A re-render of such a host is
  never the cheap thing a re-render usually is: the surface re-records its
  whole scene. Where the props are rebuilt on a clock rather than on a
  change, compare their content — a reference comparison is the wrong
  question for a value that is new every tick. This is checked by a test
  that names the hosts.
- **(MUST)** The UI runtime is a runtime without a handler above it
  (§"Shared single-lane resources"): a release build dies on an unhandled
  error where a development build logs it, so a property access, a helper
  call or an array index there is a hazard the local run will not show.

### Verification

A UI change is verified like any other change (`docs/VERIFICATION.md`): by running it in the simulator, emulator or browser, in the
build mode that shows the whole product, with the user's approval when the
run takes their screen, and along the end-to-end test plan it ships with
(§"End-to-end test plans"). The rules are stated there once; nothing here
adds to them.

### End-to-end test plans

End-to-end coverage is mandatory for every product with a user interface,
and it does not require an automated suite. The unit of coverage is a
**test plan**: a Markdown file under the unit's `e2e/`, one per flow,
written so that an agent — or a person — can execute it against the running
product with the tools it has (a simulator, an emulator, a browser, the
accessibility tree) and report each expected outcome as met or not. An
automated suite, where a project decides to build one, implements the plans;
it does not replace them.

A test plan has exactly these sections:

```markdown
# <Flow: what the user achieves, as a sentence>

- Covers: <the screens and routes this flow proves arrive and work>
- Build: <the build mode and any arming the flow needs, and why>

## Preconditions

<The state the product must be in: account, data, permissions, location.
How to establish it, without assuming a previous flow ran.>

## Steps

1. <One action per step, on one named element, followed by the expected
   observable result, stated so it can be read off the screen or the
   accessibility tree — never "it works".>

## Assertions

<What must be true at the end, on the branch that means the screen
*arrived*. What must NOT be asserted on: random or rotating content,
anything inside a surface the driver cannot inspect.>

## Screen reader pass

<The same flow with the platform's screen reader on: what is announced at
each step — read from the accessibility tree where the driver cannot hear.>
```

`e2e/README.md`, the coverage index, has this shape; how the plans are
executed for the unit is in the area file's §"End-to-end test plans", not
here:

```markdown
# End-to-end coverage (`<unit>`)

Executed as `<area>/AGENTS.md` §"End-to-end test plans" says.

| Screen or route | Plan | Note |
| --- | --- | --- |
| <route> | `<flow>.md` | |
| <route> | — | exempt: <the reason> |
```

- **(MUST)** A new screen, route or user-visible feature ships with its
  test plan in the same change set, and the plan was executed against the
  change before the work is reported done (`docs/VERIFICATION.md`). A feature whose plan is "to be added later" is a feature the
  release gate cannot see.
- **(MUST)** `e2e/README.md` is the coverage index: every screen and route
  of the unit, and the plan that covers it. A route that should genuinely
  have no plan is listed there as exempt with its reason — never left
  silently uncovered. Where a script can check the index against the
  routes (every route has a row, every plan named exists), it runs in CI;
  where not, the index is verified in the release checklist.
- **(MUST)** A plan names elements by their accessible name or a stable
  test identifier, never by position or by text that changes. A test
  identifier a plan uses is part of the plan's contract: renaming or
  removing one means updating the plan in the same change set. Identifiers
  are shaped `area:element` and sit on the element the user actually
  touches, never on a wrapper; where the renderer may collapse a wrapper
  that only lays out its child, the identifier goes with it, so such a
  wrapper is declared non-collapsible.
- **(MUST)** A plan asserts on the branch that means the screen *arrived*
  — the content branch and the empty branch, never the loading one — and
  a gated screen's "not available" branch is a separate assertion with
  its own identifier. Sharing one lets a plan pass on the gate and report
  coverage of a feature it never opened.
- **(MUST NOT)** Assert on content that is random or rotating by
  construction, or on anything inside a surface the driver cannot inspect
  (a canvas, a map). Assert that content exists and that the interaction
  lands.
- **(MUST NOT)** Let a build flag that arms the product for end-to-end
  runs grow behaviours beyond the ones it was introduced for. A flag that
  opens gates and enables a seeder is already two things; one that does
  more becomes a second product, and then the plans are not testing the
  first one.
- **(MUST)** Executing the plans is a release gate, run with the user's
  approval when it takes their screen (`docs/VERIFICATION.md`); one approval covers the whole run. Where an automated
  implementation of the plans exists and runs headless, it runs in CI as
  well; a run that needs the user's screen or a real per-platform build
  never does.

## Testing

- **(MUST)** A test double for an optional dependency reports the dependency
  as *absent* or *present*, never as a stub that answers nothing to
  everything — that is neither branch the caller was written for.
- **(MUST)** Test tooling transforms code the way the product build does.
  Where both configure the same transformation, their options are kept in
  step and checked; a divergence fails silently in both directions.
- **(MUST NOT)** Let a snapshot be the only assertion for the thing a test
  is named after. A serialiser that elides depth records nothing to fail on.
  Assert the content directly and keep the snapshot for the structure around
  it.
- **(MUST)** Read a regenerated snapshot before committing it. An update run
  rewrites the baseline whatever changed; the run being green afterwards
  means nothing, because it is green by construction.
- **(MUST)** State the suite's concurrency model where the tests live, and
  do not rely on tests running concurrently unless the isolation actually
  covers what they share — a transaction isolates what a test sees, not the
  locks it takes.

## Code

- **(SHOULD)** Prefer simple, composable, testable functions; introduce a
  class only where the language or framework makes it the natural unit. A
  function is tested by calling it; a class is tested by constructing its
  world first.
- **(SHOULD NOT)** Extract a new function unless it will be reused
  elsewhere, is the only way to unit-test otherwise untestable logic, or
  drastically improves the readability of an opaque block. Every
  extraction is one more name to hold and one more place to look, and one
  with a single caller explains nothing the block did not.
- **(SHOULD NOT)** Add comments except for critical caveats; rely on
  self-explanatory code. A comment restates the code until the code
  changes and the comment does not.
- **(SHOULD NOT)** Remove comments unless they are clearly outdated or
  incorrect. The one that survived is the caveat the next reader needs.
- **(SHOULD)** Keep the code strictly typed; avoid escape-hatch types. An
  escape hatch turns the checker's refusal into a runtime failure
  somewhere else.
- **(SHOULD)** Use descriptive names; files match their primary export, so
  a search for the export finds the file.
- **(MUST)** A constraint on execution context propagates through call
  chains. A function that may only run inside a particular scope — a
  transaction, a reactive scope, a lock, a specific thread — says so in its
  name and is never reached from code outside that scope, however many
  frames up. Satisfying the rule at the line that does the work while a
  caller two frames up is outside the scope is exactly the failure the rule
  exists to prevent.
- **(SHOULD)** When the same derivation is needed from two execution
  contexts, do not write the read twice and do not duplicate the derivation.
  Read once into a plain value and keep the derivation a pure function over
  it; passing a loaded value into a helper is preferred over the helper
  reaching for the store itself.
