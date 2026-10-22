# 0012 – iOS 27 and macOS 27 are the oldest versions Outloud supports

- Status: accepted
- Date: 2026-10-22

## Context

ADR 0002 left the oldest supported versions open. The model runtimes set
a floor: FluidAudio requires iOS 17 and macOS 14, LLM.swift iOS 16 and
macOS 13 (their `Package.swift`, read 2026-10-22). The current releases
are iOS 27 and macOS 27; the toolchain is Xcode 27.1 with
Swift 6.4.

Proposed on 2026-10-22: iOS 17 and macOS 14, the floor the runtimes set.
The user decided instead to go entirely to the newest versions, 27.

Rejected alternative: iOS 17 and macOS 14 — more devices, but code paths
and testing for ten years of older releases.

## Decision

Outloud supports iOS 27 and later and macOS 27 and later. The package and
both apps set these deployment targets.

## Consequences

- Every API of iOS 27 and macOS 27 is available without availability
  checks.
- Devices that cannot run iOS 27 or macOS 27 cannot run Outloud.
