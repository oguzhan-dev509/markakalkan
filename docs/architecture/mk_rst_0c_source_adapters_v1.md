# MK-RST-0C — Source Adapters V1

## Purpose and boundary

These adapters prove that existing Traceability, Digital Market Monitoring and
Digital Detective records can target MK-RST-0B contracts without changing their
authoritative models. Every adapter is synchronous and pure: its output depends
only on explicit input values. No adapter reads Firestore, calls a service, reads
the clock, creates a case or writes a record.

## Source mapping

| Source | Shared field | Mapping |
|---|---|---|
| `SuspiciousVerificationScan.id` | signal/provenance | namespaced signal ID and `sourceRecordId` |
| Traceability `productId`, `batchId` | asset/entity refs | typed product and batch references when non-empty |
| Traceability `riskScore` | risk score | original 0–100 scale, without normalization |
| Traceability `riskReasons` | risk reasons | copied losslessly into an immutable list |
| `MonitoringSignalModel.id` | `signalId` | retained unchanged |
| Monitoring source/page/event/rule/listing/seller/store IDs | entity refs | typed references; no repository lookup |
| Monitoring event type | `signalType` | `digital_market_monitoring.event_type` namespace |
| Digital Detective finding key | signal/provenance | namespaced signal ID and exact `findingKey` |
| Finding `evidenceReferences[]` | evidence refs | `structured_evidence` / `snapshot_id`; no inferred payload |

## Identity resolution

Traceability's callable DTO omits `ownerUid`; callers may supply the owner as
explicit source context. Owner-only identity is `partial`; it is never copied to
tenant or brand. No identity is `unresolved`. Monitoring preserves its required
tenant and brand and is `resolved`. Digital Detective preserves every supplied
identity independently; brand UID alone is `partial`, not a tenant ID.

## Severity normalization

| Source | Canonical |
|---|---|
| Traceability `low/medium/high/critical` | same value |
| Traceability `none` or unknown | adapter error |
| Monitoring `info/low/medium/high/critical` | same value |
| Digital Detective `low/medium/high/critical` | same value |
| Any unknown value | adapter error |

The exact source severity is also stored in `originalSeverity`.

## Review status mapping

| Source | Shared review status |
|---|---|
| Traceability `pending/reviewed/dismissed/escalated` | `new/under_review/dismissed/escalated` |
| Monitoring signal lifecycle | exact corresponding shared lifecycle |
| Digital Detective `requiresHumanReview: true` | `under_review` |

Unknown lifecycle values fail closed. Monitoring forwarding status is not a
review lifecycle and therefore cannot create or promote a case.

## Timestamp semantics

Traceability has no separate detection time in its DTO, so its source `createdAt`
is explicitly used as `detectedAt` and remains `createdAt`. Monitoring preserves
its distinct `detectedAt` and `createdAt`; reviewed, forwarded and resolved times
are not substituted. Digital Detective requires both times from its caller.
Every adapter requires caller-supplied `adaptedAt`; none calls `DateTime.now`.

## Evidence and provenance

Traceability does not expose evidence records, so no EvidenceRef is synthesized
from an evidence count. Monitoring preserves available event and snapshot IDs as
typed entity/provenance references. Digital Detective preserves task, execution,
workflow, source, snapshot, finding and content-hash fields when supplied. Its
string evidence IDs remain explicitly typed snapshot references.

## Determinism and errors

Adapter IDs are either the authoritative source ID or a documented namespace
plus that ID. There is no random value, I/O, clock access or global state. Missing
required source/context fields, unknown severity/lifecycle values, and mismatched
Monitoring signal/event pairs throw `FormatException`. Contract constructors
deep-freeze lists and metadata maps, leaving source inputs unmodified.

## Case-candidate readiness

Outputs carry identity scope, deterministic signal ID, provenance, available
evidence, related entities and optional canonical asset references. These are
sufficient inputs for a later, separately authorized deduplication/review policy;
they do not themselves establish a final case or authorize automatic promotion.

## Deliberately excluded runtime work

No Firestore collection/write/migration, callable/service/repository wiring,
Rules/index change, UI/route change, n8n schema/workflow/runtime change, deployment
or existing domain-model edit is part of MK-RST-0C.

## MK-RST-0D recommendation

Add read-only orchestration boundaries that invoke these adapters only after each
source has been loaded and validated by its existing authority. Define explicit
identity-resolution and case-candidate deduplication policies before authorizing
any persistence or runtime wiring.
