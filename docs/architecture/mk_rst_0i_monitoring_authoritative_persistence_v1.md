# MK-RST-0I Monitoring Authoritative Persistence V1

## Scope and source choice

Digital Market Monitoring is the first persistence source because its existing
`monitoring_signals/{signalId}` record already carries the required tenant,
brand, source, page, rule, severity, lifecycle and timestamps. The linked
`monitoring_events/{eventId}` record is also loaded: it is required to preserve
snapshot, event type and event category references without inventing data.
No Monitoring model, repository, UI or route is changed.

This phase exports no callable or HTTP function. The future callable request is
limited to `monitoringSignalId`, `dryRun`, optional `correlationId`, and
`requestedAt`. Actor identity is a separate verified invocation context. Client
tenant, brand, actor, roles, permissions, payload, readiness, fingerprint,
idempotency key, command ID, target, source module, provenance, update time and
timestamps are untrusted and rejected by the request allowlist.

## Authority and permission

The application service uses explicit authority ports for
`platform_admins/{uid}`, `monitoring_signals/{signalId}` and the linked
`monitoring_events/{eventId}`, plus an injected server clock. The pilot policy
grants only when the authoritative admin record has `active == true` and its
`roles` array contains `super_admin`. It then derives exactly
`risk_signal.persist`; a role string in a command never grants permission.

The signal document supplies tenant and brand. Both are mandatory in the
existing Monitoring model, so absence is denied. Resolution is marked
`resolved`; no owner or brand UID is inferred. Event tenant, brand, source and
page must match the signal.

## Adapter conformance and server-derived facts

The pure Node adapter and the existing Dart `MonitoringRiskAdapterV1` consume
the same versioned fixture package. Tests compare byte-semantic canonical JSON,
all five severities, all seven lifecycles, timestamps, provenance, related
references, exact keys and fingerprints. Unknown enums and scope mismatch fail
closed. Canonical set-like array sorting uses locale-independent JSON lexical
ordering in both runtimes.

The server creates an exact-source-occurrence key from the canonical module
`digital_market_monitoring`, source type `monitoring_signal`, and authoritative
document ID using the existing length-prefixed encoder. Existing MK-RST-0F–0H
helpers derive `sha256-canonical-json-v1` fingerprint,
`shared_risk_signals` target, document ID, receipt ID, creation audit ID and
command ID. No second identity or hashing scheme is introduced.

Readiness checks contract version, resolved tenant, signal ID/key consistency,
source/provenance module, type namespace/value, supported severity, summary,
timestamps, source record and relationship shape. Missing evidence produces a
warning; unsupported or inconsistent authoritative data blocks facts assembly.

## Application flow and dry-run

`MonitoringRiskPersistenceApplicationServiceV1` validates the request and
verified invocation, loads admin/signal/event, applies permission and adapter
policies, evaluates readiness and assembles `ServerPersistenceFactsV1`.
Dry-run returns deterministic fingerprint, document, receipt, audit and command
identities without opening the persistence transaction and without writing a
subject, receipt or audit document.

For persistence, the service delegates to the MK-RST-0H transaction executor.
Before any write, the same Firestore transaction reads the source reference and
rechecks existence, tenant, brand and Firestore `updateTime`. Deletion denies;
tenant movement conflicts; brand or version changes require recomputation. A
current source permits the existing atomic subject + receipt + audit create.
Replay is idempotent and concurrent identical calls produce one create and one
idempotent success.

## Emulator evidence and production boundary

The integration suite runs only with a loopback `FIRESTORE_EMULATOR_HOST`, no
`GOOGLE_APPLICATION_CREDENTIALS`, and demo project
`demo-markakalkan-rst-0i`. It covers authority denial, tampering, invalid source
data, dry-run, persistence, replay, tenant isolation, concurrency and source
TOCTOU changes. Existing server-only Rules tests prove clients cannot read or
write shared persistence collections while Admin SDK emulator persistence can.
No Rules or index change is needed for document-ID reads.

No callable was exported, `functions/index.js` was not changed, and no deploy or
live Firebase access occurred.

## MK-RST-0J controlled live pilot proposal

0J should add a separately reviewed callable adapter that constructs verified
context only from Firebase Auth/server metadata, retains the super-admin-only
policy, begins in dry-run mode, and uses an explicit allowlisted project and
signal. Deployment should be stopped or rolled back on any authorization
discrepancy, unexpected write count, source-version conflict spike, fingerprint
parity failure, receipt/audit mismatch, or evidence of cross-tenant access.
Rollback must disable the callable first; persisted immutable records should be
handled by a separately authorized remediation procedure rather than deleted by
the pilot.
