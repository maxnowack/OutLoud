# Commits and history

This document owns the commit message, the staging discipline and the
history rules. `AGENTS.md` §"Reporting and delivery" says when it is read
and decides whether a commit is made at all.

- **(MUST)** Write semantic commit messages in the Conventional Commits
  format: `type(scope): subject`, e.g. `fix(search): keep results on
  cooldown dimmed`. The scope is optional — use it when the change clearly
  belongs to one area or feature and omit it for changes that span the
  repository. The subject is English, imperative, lower-case after the colon,
  without a trailing period, and stays within roughly 72 characters; detail
  and rationale belong in the body. A breaking change carries `!` before
  the colon and a `BREAKING CHANGE:` footer naming what breaks; the
  changelog and the version bump read exactly these markers
  (`docs/ARCHITECTURE_PRINCIPLES.md` §"Release and versioning").
- **(MUST)** Stage explicitly, by path. Never `git add -A`, `git add .`, or
  `git commit -a`. Other sessions, batch loops and the user's own editor
  write to the same working tree, and a blanket stage sweeps their work into
  your commit.
- **(MUST)** Commit only what you changed yourself. Read `git status` before
  committing and confirm every staged path is your own work; if another
  session has left something staged, unstage it rather than carrying it
  along. Verify afterwards with `git show --stat` — a commit that turns out to
  hold someone else's files is split before anything is pushed, not explained
  away.
- **(MUST)** A rebase adds no commits. Whatever the rebase makes necessary — a
  resolved conflict, a renumbered ADR, an adjusted reference — belongs in the
  commit that introduced the thing, edited there during the rebase (`git
  rebase --continue`, or an `edit` stop for a commit git did not stop at by
  itself), never appended afterwards as a "fix conflict" or "renumber ADR"
  commit. A branch that carries such a commit is rebased again properly: the
  history a reviewer reads must look as though the work had been written on
  top of the new base from the start.
- **(MUST)** When a rebase collides over a number upstream has taken in the
  meantime — a new ADR is the usual case — assign the new number in the
  commit that created the file (the `git mv` included) and rewrite *every*
  reference to it in that same commit, repo-wide: other ADRs,
  `docs/adr/README.md`, plans, living documents, code comments, and the
  bodies of the branch's own later commits. Fixing only what git marked as
  conflicting is the trap — git marks the lines both sides touched, not the
  lines that are now wrong, so every untouched citation keeps pointing at the
  upstream document that took the number. Search the whole repository for
  the old number before continuing the rebase, and search again once it has
  finished.
