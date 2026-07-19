# MK-RST-0J Monitoring Callable Rollout V1

## Callable boundary

`persistMonitoringRiskSignalPilot` is a 2nd Gen Node.js 24 callable in
`europe-west3`. It accepts only `monitoringSignalId`, `dryRun`, optional
`correlationId`, and diagnostic `requestedAt`. Firebase callable auth supplies
the actor. App Check is enforced and maximum instances is one for the pilot.
The adapter delegates all authorization, adaptation, readiness, identity,
fingerprint, idempotency and transaction work to the MK-RST-0I service.

The response exposes only outcome, dry-run flag, signal/subject/storage IDs,
transaction status, blocker/warning codes, correlation and rollout metadata.
Structured logs hash actor and tenant identifiers and omit source payload,
evidence, admin data, permissions, canonical idempotency key and metadata.

## Rollout policy

The callable uses Firebase `defineString` deployment parameters:

* `MONITORING_RISK_ROLLOUT_MODE`, default `dry_run_only`
* `MONITORING_RISK_ALLOWED_SIGNAL_IDS`, default empty

Supported modes are `disabled`, `dry_run_only`, and `single_signal_write`.
Write mode requires exactly one allowlisted signal. Invalid, duplicate-expanded
multi-item, expired, not-yet-effective or wrong-project policies fail closed.
The production project guard is exactly `markakalkan-app`, as confirmed by
`.firebaserc` and `firebase.json`. Emulator project IDs never satisfy the
production callable guard.

The exact-source transaction idempotency from MK-RST-0I remains the replay
control; no second lock or client request-ID identity is introduced.

## Controlled deployment gates

Gate A deploys only this callable with the default dry-run-only policy. Before
any live invocation, the active Firebase project, deployed parameter values,
authenticated super-admin test actor and one safe existing Monitoring candidate
must be independently verified. Dry-run must return deterministic IDs and
leave the subject, receipt and creation-audit documents absent.

Gate B requires a separately observed, unique and safe candidate. The parameter
is changed to `single_signal_write` with exactly that ID, and only the target
callable is redeployed. One write must create subject/receipt/audit atomically;
one replay must be idempotent with counts remaining 1/1/1. The mode is then
immediately returned to `dry_run_only` or `disabled` with an empty allowlist and
the target callable redeployed.

No candidate may be selected automatically when several are suitable. No test
signal, backfill or manual shared-persistence document may be created.

## Stop and rollback

Stop before Gate B on any auth ambiguity, candidate ambiguity, tenant/brand or
event mismatch, readiness/fingerprint divergence, unexpected ID or write,
Rules failure, sensitive log field, source-version change, cross-tenant result,
or deploy scope uncertainty. First set rollout to `disabled`; if necessary,
rollback or delete only the target callable. Do not manually edit or delete
pilot subject/receipt/audit documents. Any cleanup is a separate audited phase.
