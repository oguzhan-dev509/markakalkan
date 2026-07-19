# MK-RST-0B — Shared Risk Contracts V1

## Decision

The shared layer is a versioned, immutable adapter target. Existing traceability,
monitoring, Digital Detective, counterfeit twin, trade-secret and supply-security
models remain authoritative for their own runtime behavior. No existing record is
rewritten into a shared model in place.

## Why adapters

The source modules use different identity, severity, confidence, status, score and
timestamp semantics. An adapter can preserve the source namespace and original
value while exposing a deliberately small canonical view. Replacing source models
would lose meaning and destabilize proven workflows.

## Identity resolution

`tenantId`, `brandId`, `brandUid` and `ownerUid` are independent facts. Adapters
must not copy one into another. `IdentityScope.resolutionStatus` records whether
resolution is `resolved`, `partial` or `unresolved`; reasons are retained. A future
persistence boundary must require a resolved `tenantId`. This phase does not write
shared records.

## Enum normalization

Only the small canonical lifecycle/severity enums are normalized. Source values
remain available through namespaced values, `originalSeverity`, `originalValue`,
`originalScale` and `sourceNamespace`. Unknown canonical values fail closed instead
of silently falling back.

## Timestamp semantics

`occurredAt`, `detectedAt`, evidence `capturedAt`, provenance `sourceCreatedAt`,
contract `createdAt`, assessment `assessedAt` and provenance `adaptedAt` retain
separate fields. Adapters must not synthesize one timestamp from another without
an explicit source rule.

## Provenance immutability

`ProvenanceEnvelope` is immutable and round-trips source record, workflow,
execution, task, source, snapshot, finding and content-hash identifiers. Adapters
create a new envelope; downstream code must not rewrite it.

## Case candidate boundary

`CaseCandidateContractV1` is a review proposal, not a Traceability Case, IP
Enforcement Case or future platform case. Promotion records a reference to the
authoritative final case; it does not replace that case model.

## Next phase boundary

The next adapter phase may map existing read models into these contracts and test
lossless mappings. It must not add Firestore collections, writes, Rules, indexes,
UI routes, n8n runtime nodes, migrations or automatic case promotion without a
separate decision and authorization.

## JSON Schema decision

The Flutter application has no existing JSON Schema validator. The repository's
AJV pipeline is isolated under the Digital Detective n8n package. Adding another
schema runtime or duplicating these contracts there would violate the dependency
and single-copy constraints. V1 therefore uses strict `fromJson` validation and
round-trip tests as its canonical executable contract.
