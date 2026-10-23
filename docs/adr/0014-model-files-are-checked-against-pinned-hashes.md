# 0014 – Every model file is checked against the hash the catalogue pins, after the download and before it is loaded when it changed

- Status: accepted
- Date: 2026-10-23

## Context

Model files come from Hugging Face and, on macOS, lie in a cache every process of the user can
write to (ADR 0010; `docs/ARCHITECTURE.md` §"Model downloads"). A model file is loaded into
CoreML or llama.cpp, so a replaced file is code-adjacent input from outside Outloud's trust.

The hub names each blob by its etag: the SHA-256 of the content for files in Git LFS, the Git
blob SHA-1 otherwise. Hashing the 445 MB Parakeet encoder takes about a second on an M1 Pro;
doing it at every launch would delay the first dictation.

Rejected alternatives: trusting the cache as it is — any process could swap a model; hashing
every file at every launch — a delay at each start for a change that rarely happens.

The user was asleep when this was decided (2026-10-23); see
`plans/FIRST_VERSION.md` §"Decisions for the user".

## Decision

The catalogue (`ModelCatalog`) pins every file of a model by path, size and hash at a pinned
revision. `ModelStore` downloads each file over HTTPS to `blobs/<etag>.incomplete`, checks its
hash, and only then renames it into place; a file another tool already downloaded is checked
the same way before it is linked. Before a model is loaded, each file's size and modification
date are compared with those recorded at its last check, in Outloud's own storage; a file that
changed is hashed again, and a mismatch refuses the model.

## Consequences

- A tampered or damaged model file is refused with "A downloaded file was damaged"; the user
  can download it again.
- A file changed without its size or modification date changing is not noticed between two
  checks; that requires writing the user's cache with a preserved timestamp.
- A new model revision needs its hashes in the catalogue, read from the hub's `paths-info` API.
