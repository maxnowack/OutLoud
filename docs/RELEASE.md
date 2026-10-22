# Release

This document owns how each unit is versioned, released and rolled back,
and the release checklist. It describes the procedure; the rules it
satisfies are in `docs/ARCHITECTURE_PRINCIPLES.md` §"Release and
versioning". A release is performed by following this document, and a step
it lacks is added in the release that needed it.

## Versioning

*(Per unit: what the unit exposes — an API, a wire format, a library
surface, a CLI's arguments and output — so that "is this breaking" has an
answer before the change. Where the version lives, and how it is bumped:
by hand, from Conventional Commits, from a tag.)*

## Review

*(Who reviews a change before it reaches the default branch, what the
reviewer checks that the automated gates do not — the plan's Definitions of
Done, the living documents, the ADR — and what a single-person project
does instead and why that is acceptable.)*

## Release procedure

*(Per unit, as a numbered list a reader can follow without asking: the
branch, the checks, the build, the artifact, where it goes, how it is
verified there, who is told.)*

## Rollback procedure

*(Per unit, as a numbered list: how the previous version is restored,
including the schema. When it was last performed and how long it took.)*

## Release checklist

*(The list that is walked for every release. Starts from `AGENTS.md`
§"Before reporting done" and adds what a release needs beyond a change:)*

1. Every end-to-end test plan in every unit's `e2e/` executed, outcomes
   recorded.
2. The changelog written or generated, and read.
3. The version bumped per the rules above; a breaking change coordinated
   with every caller.
4. The rollback procedure confirmed to apply to this release.
