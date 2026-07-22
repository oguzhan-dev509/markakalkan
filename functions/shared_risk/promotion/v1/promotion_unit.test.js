/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {promotionRequestV1} = require("./contracts");
const {evaluateRolloutV1, MODES, sourceKey} = require("./rollout_policy");
const {baseProjection, evidenceQuality, caseCandidacy} = require(
    "../../../risk_operations/v1/projection");
const {canonicalSignal} = require("./service");
const {createPromotionCallableHandlerV1} = require("./callable");

const request = (extra = {}) => ({sourceSystem: "traceability",
  sourceRecordId: "scan-1", expectedSourceRecordVersion: "version-1",
  expectedProjectionFingerprint: "a".repeat(64), dryRun: true,
  correlationId: "correlation-1", ...extra});

test("command accepts only six non-authoritative fields", () => {
  assert.deepEqual(Object.keys(promotionRequestV1(request())), [
    "sourceSystem", "sourceRecordId", "expectedSourceRecordVersion",
    "expectedProjectionFingerprint", "dryRun", "correlationId"]);
  for (const forbidden of ["tenantId", "canonicalBrandId", "ownerUid",
    "role", "permission", "severity", "evidenceQuality", "caseCandidacy",
    "status", "title", "summary", "signalId", "createdAt"]) {
    assert.throws(() => promotionRequestV1(request({[forbidden]: "x"})),
        /authority_field_forbidden/);
  }
});

test("command rejects unsupported source and malformed values", () => {
  assert.throws(() => promotionRequestV1(request({sourceSystem: "shared_risk"})),
      /unsupported/);
  assert.throws(() => promotionRequestV1(request({dryRun: "false"})),
      /dry_run_invalid/);
  assert.throws(() => promotionRequestV1({...request(), correlationId: ""}),
      /correlation_id_invalid/);
});

test("rollout is fail closed and exact source version allowlisted", () => {
  const base = {request: request(), projectId: "markakalkan-app",
    expectedProjectId: "markakalkan-app", allowlist: []};
  assert.equal(evaluateRolloutV1({...base, mode: MODES.disabled}).allowed,
      false);
  assert.equal(evaluateRolloutV1({...base, mode: MODES.dryRunOnly}).allowed,
      true);
  const write = request({dryRun: false});
  assert.equal(evaluateRolloutV1({...base, request: write,
    mode: MODES.dryRunOnly}).allowed, false);
  assert.equal(evaluateRolloutV1({...base, request: write,
    mode: MODES.singleSourceCreate}).allowed, false);
  assert.equal(evaluateRolloutV1({...base, request: write,
    mode: MODES.singleSourceCreate,
    allowlist: [sourceKey(write)]}).allowed, true);
});

test("projection fingerprint is deterministic and signal safe", () => {
  const evidence = evidenceQuality({sourceCount: 1});
  const candidacy = caseCandidacy({severity: "medium", confidenceValue: .5,
    evidence, sourceCount: 1, identityResolved: true,
    evaluatedAt: "2026-07-21T00:00:00.000Z"});
  const input = {sourceSystem: "traceability", sourceRecordId: "scan-1",
    sourceRecordVersion: "version-1", tenantId: "tenant-1",
    canonicalBrandId: "brand-1", canonicalSubjectId: "product-1",
    subjectType: "product", title: "Risk", summary: "Özet",
    currentStatus: "pending", riskClass: "traceability_anomaly",
    severity: "medium", confidenceValue: .5, evidence, candidacy,
    timeline: []};
  const first = baseProjection(input); const second = baseProjection(input);
  assert.equal(first.projectionFingerprint, second.projectionFingerprint);
  const signal = canonicalSignal(first, "2026-07-21T00:00:00.000Z");
  assert.equal(signal.caseCandidacy.requiresHumanReview, true);
  assert.equal(signal.projectionFingerprint, first.projectionFingerprint);
  assert.equal(Object.hasOwn(signal, "sourcePayload"), false);
});

test("callable requires Auth, allows dry-run recovery and protects writes", async () => {
  const logs = [];
  const handler = createPromotionCallableHandlerV1({db: {runTransaction() {
    throw new Error("transaction must not start");
  }},
  clock: {now: () => "2026-07-21T00:00:00.000Z"},
  projectIdProvider: () => "markakalkan-app",
  policyProvider: () => ({mode: MODES.disabled, allowlist: []}),
  log: {info(_message, fields) {
    logs.push(fields);
  }}});
  const dryRun = await handler({auth: {uid: "user-1"}, data: request()});
  assert.equal(dryRun.outcome, "blocked");
  assert.equal(dryRun.transactionCommitted, false);
  assert.equal(dryRun.writeAttempted, false);
  assert.equal(logs[0].appCheckPresent, false);
  assert.equal(logs[0].appCheckRequired, false);
  await assert.rejects(handler({auth: {uid: "user-1"},
    data: request({dryRun: false})}),
  (error) => error.code === "failed-precondition");
  await assert.rejects(handler({app: {appId: "app"}, data: request()}),
      (error) => error.code === "unauthenticated");
});

test("callable blocks writes before Firestore and logs hashes only", async () => {
  const logs = [];
  const handler = createPromotionCallableHandlerV1({db: {runTransaction() {
    throw new Error("transaction must not start");
  }}, clock: {now: () => "2026-07-21T00:00:00.000Z"},
  projectIdProvider: () => "markakalkan-app",
  policyProvider: () => ({mode: MODES.dryRunOnly, allowlist: []}),
  log: {info(_message, fields) {
    logs.push(fields);
  }}});
  const result = await handler({app: {appId: "app"}, auth: {uid: "user-1"},
    data: request({dryRun: false})});
  assert.equal(result.outcome, "blocked");
  assert.equal(result.transactionCommitted, false);
  assert.equal(result.writeAttempted, false);
  assert.equal(logs[0].appCheckPresent, true);
  assert.equal(logs[0].appCheckRequired, true);
  const serialized = JSON.stringify(logs);
  assert.equal(serialized.includes("user-1"), false);
  assert.equal(serialized.includes("scan-1"), false);
  assert.equal(serialized.includes("correlation-1"), false);
});
