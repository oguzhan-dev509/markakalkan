# MK-RST-0D — Identity and Idempotency V1

## Identity namespaces

`tenantId`, `brandId`, `brandUid` and `ownerUid` identify different domains and
remain separate even when their strings happen to match. No resolver branch
copies a value into another namespace. An `IdentityClaimV1` records the asserted
namespace, value, source module and whether the assertion came from a source
record, an authoritative mapping or explicit caller context.

## Authoritative mappings

An `AuthoritativeIdentityMappingV1` is explicit evidence linking a tenant to at
least one brand or owner identity. It has its own ID, source and provenance.
Optional `effectiveAt` is inclusive; `expiresAt` is exclusive. Resolution uses
only caller-supplied `resolutionAt`, never the system clock. Inactive mappings
are ignored rather than silently accepted.

## Resolution outcomes

- `resolved`: a source tenant or active authoritative mapping supplies tenant ID
  without contradiction.
- `partial`: some namespaced identity is known, but tenant ID is not established.
- `unresolved`: no usable identity evidence exists.
- `conflict`: source scope, claims or matched mappings disagree.

Conflict is fail-closed: no resolved identity scope is returned. Multiple
mappings that bind one claim to different tenants are conflicts. Mapping lookup
uses namespace plus value; identical strings in different namespaces do not
match each other. Input claims and mappings are sorted in output references so
input order cannot affect result JSON.

## Idempotency meanings

These keys intentionally solve three different problems:

1. Exact source idempotency prevents repeated ingestion of one authoritative
   source occurrence. Traceability uses verification scan ID; Monitoring uses
   signal ID; Digital Detective uses task, execution and finding IDs.
2. Stable finding recurrence uses Digital Detective task and finding IDs without
   execution ID. It supports recurrence analysis across executions but does not
   assert that two sources describe one real-world event.
3. Candidate promotion idempotency uses case candidate ID plus an explicit target
   case namespace. It prevents repeating the same promotion attempt to one target.

Case candidate `deduplicationKey` and promotion key are not interchangeable.
Cross-source semantic deduplication—such as deciding that a Monitoring signal and
a Digital Detective finding are the same infringement—is deliberately deferred.

## Canonical key encoding

Keys use ordered length-prefix encoding: every component is represented as
`length:value`, separated by `|`. Contract version, source module, source type,
key kind and stable parts are all encoded. Therefore `ab,c` cannot collide with
`a,bc`. Empty parts fail validation. No hash, random value, timestamp, external
dependency, I/O or global state participates.

## Persistence gate

Before future persistence, the caller must require a non-conflict result, an
explicitly allowed resolution status, an active authoritative mapping when the
tenant did not originate from trusted scope, and the appropriate exact source
key. Promotion additionally requires a target-specific promotion key. This phase
does not persist, bind runtime objects or create a case.

## Binding helper decision

MK-RST-0D does not add a helper that reconstructs RiskSignal, RiskAssessment or
CaseCandidate objects. Their immutable constructors have no copy API, so a helper
would duplicate every contract field and create another error-prone adapter
surface. A later phase may add explicit `copyWithIdentity` APIs after defining
which partial results are permitted. Conflict and unresolved results must never
invent tenant identity.

## Runtime exclusions and MK-RST-0E

No Firestore access, collection, migration, repository/service/callable wiring,
UI/route, Rules/index, n8n artifact, domain model, automatic candidate generation,
case creation or deployment is included.

MK-RST-0E should define a read-only persistence-readiness decision contract. It
can combine an existing shared object, `IdentityResolutionResultV1` and the
appropriate idempotency key, returning an auditable allow/deny decision without
performing a write. Runtime integration should remain separately authorized.
