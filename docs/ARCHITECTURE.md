# Architecture

This document owns the system's components, the communication paths between
them, the API and channel contracts, the data and sync formats, and the auth
model. It describes what *is*; why it is that way lives in `docs/adr/`, and
the rules it must keep to live in `docs/ARCHITECTURE_PRINCIPLES.md`.

## Components

*(One subsection per deployable unit: what it owns, what it must never own,
what it depends on, what depends on it.)*

## Communication paths

*(One subsection per pair that talks: the transport, the direction of the
connection, who reconnects, what the closed exception list contains.)*

## Contracts

*(The wire formats, their version, what is additive and what is a version
bump. The persistence formats. The sync format and its cursor semantics.)*

## Trust boundaries

*(One subsection per boundary — every component that accepts input from
outside its own trust: who calls across it and with what level of trust,
what it accepts, what it must never do. This is the threat model a
reviewer and a test author check against
(`docs/ARCHITECTURE_PRINCIPLES.md` §"Boundaries").)*

## Auth

*(Who authenticates to whom, with what, and what is reachable without
authentication and why that is acceptable.)*

## Data

*(The data model per component, and which data is personal or otherwise
classified — including what the audit trail carries
(`docs/ARCHITECTURE_PRINCIPLES.md` §"Secrets, cryptography and logs").
Retention, deletion and export procedures live in the dossier where it is
maintained, `docs/DOSSIER.md` §6.)*

## Deployment shape

*(Replica counts; the reasons for the ones that are fixed are in
`docs/HORIZONTAL_SCALING.md`.)*
