# MK-RST-0E — Persistence Readiness Policy V1

## Purpose

The readiness layer makes a pure, auditable allow/deny decision from an existing
shared subject, an already-computed identity result, an explicit evaluation time
and the applicable source ingestion key. It neither rewrites the subject nor
performs persistence.

## Decision and issue model

`PersistenceReadinessDecisionV1` contains deterministically sorted blockers and
warnings. Any blocker makes `allowed` false. Warnings describe missing optional
context and never deny by themselves. Codes are stable, namespaced machine keys;
messages and field paths support operators.

## Identity policy

Persistence requires a `resolved` result and a resolved tenant ID. Tenant ID is
the isolation boundary. Brand ID is not universally mandatory because valid
tenant-scoped records can precede brand resolution; its absence is a warning.
Subject and resolved identities must agree namespace by namespace. Owner UID,
brand UID and brand ID never substitute for tenant ID.

## Exact idempotency

Risk signals and assessments require an exact-occurrence `SourceIngestionKeyV1`
whose module agrees with source and provenance. Digital Detective persistence
requires task, execution and finding components. Its task/finding stable recurrence
key supports analysis only and is denied as a persistence key. Case Candidate's
own deduplication key is sufficient for initial candidate persistence; a promotion
key is intentionally not evaluated.

## Provenance and source allowlist

V1 recognizes `traceability`, `monitoring`, `digital_market_monitoring` and
`digital_detective`. Unknown producers fail closed. Traceability and Monitoring
require exact source record provenance. Digital Detective requires task,
execution and finding identifiers. Optional source, snapshot and content hashes
are preserved when available but never fabricated.

## Timestamp policy

`evaluatedAt` is caller-supplied; no system clock is read. Existing typed contracts
require created/detected/assessed/proposed timestamps. The policy rejects only
clear contradictions: next review before assessment, or candidate review before
proposal. Processing delays do not fail readiness.

## Subject policies

Risk Signal requires resolved identity, exact key, consistent modules and exact
source provenance. Missing asset, evidence, related entities, brand or confidence
are warnings.

Risk Assessment additionally requires reasons and either a source signal or exact
provenance. Score is optional; missing score/scale, evidence, asset, next review
and related entities are warnings.

Case Candidate requires a signal or risk source and its contract deduplication
key. Accepted and dismissed states require review time and reviewer. Promoted also
requires a promoted case reference. Proposed needs no review fields. Empty evidence,
assets and related entities are warnings.

## Determinism

Evaluators use no randomness, clock, network, filesystem, Firestore or global
mutable state. Issues sort by code, field path and related reference. Duplicate
reference checks sort their input first, so reference order cannot change the
decision. Inputs remain immutable and are not reconstructed.

## Excluded runtime work and MK-RST-0F

No collection, write, migration, repository/service/callable wiring, UI/route,
Rules/index, n8n artifact, automatic candidate/case action or deployment is part
of this phase.

MK-RST-0F should define a separately authorized persistence command envelope and
dry-run audit record that consumes an allowed decision and rechecks policy/key
binding, while still postponing actual writes until storage ownership, Rules and
retry semantics are approved.
