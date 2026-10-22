# Horizontal scaling register

This document owns the register of everything that keeps a service from
running as more than one instance. It is a living document, never "done":
it exists from day one so that the first single-instance assumption is
recorded when it is written, not reconstructed from an incident after the
second instance is running. `docs/ARCHITECTURE.md` §"Deployment shape"
states the replica counts; this register says why the fixed ones are fixed.

## Purpose

Every service here runs as one instance until it does not. The moment a
second one starts, everything that silently assumed it was alone breaks,
duplicates or diverges — and the assumptions are scattered across the code,
each one obvious to whoever wrote it and invisible to whoever scales it.

`AGENTS.md` §"Living documents and their owners" makes this register a
duty: whoever writes
something a second node would break, duplicate or diverge from adds it here
in the same change set. Writing it down costs a paragraph while the reasoning
is fresh; finding it again from the symptoms costs an incident.

## What belongs here

The usual shapes:

- a singleton process or supervisor that must not exist twice
- a periodic timer or scheduled job that would run twice
- an in-memory cache, counter or rate limiter that would diverge
- node-local pub/sub that a second node would not hear
- a write to the container's own filesystem
- an unclaimed poll of an upstream that rate-limits per address
- a connection the account gets exactly one of

## Register

For each entry: **what it is** (module, process, path), **what goes wrong at
two nodes**, and **what coordinating it would take** (a lease, a leader
election, an external store, a per-node shard, or a decision that the
service stays single-instance by design and the manifest says so).

| Service | What | What goes wrong at two nodes | What coordinating it would take |
| --- | --- | --- | --- |
