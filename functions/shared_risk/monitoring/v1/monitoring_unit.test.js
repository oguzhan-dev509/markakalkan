const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {canonicalize} = require("../../persistence/v1/server_persistence_facts");
const {createHash} = require("node:crypto");
const {
  adaptMonitoringRiskSignalV1,
  assembleMonitoringServerPersistenceFactsV1,
  evaluateMonitoringPersistencePermissionV1,
  exactKey,
  evaluateMonitoringRolloutPolicyV1,
  monitoringRiskPersistenceRequestV1,
  verifiedServerInvocationContextV1,
} = require("./index");

const fixture = JSON.parse(fs.readFileSync(path.join(__dirname,
    "../../../../test_fixtures/shared_risk/v1/monitoring/" +
    "monitoring_conformance_v1.json"),
"utf8",
));

function invocation() {
  return verifiedServerInvocationContextV1({authenticatedUid: "admin-1",
    authenticationType: "firebase_auth", invocationId: "invocation-1",
    receivedAt: "2026-07-19T12:01:00.000Z"});
}

function main() {
  for (const item of fixture.validCases) {
    const output = adaptMonitoringRiskSignalV1({signalId: item.signalId,
      signal: item.signal, event: item.event, adaptedAt: item.adaptedAt});
    assert.deepEqual(output, item.expectedCanonical);
    assert.equal(exactKey(item.signalId).canonicalKey,
        item.expectedExactIdempotencyKey);
    const hash = createHash("sha256")
        .update(JSON.stringify(canonicalize(output))).digest("hex");
    assert.equal(hash, item.expectedFingerprint);
  }
  for (const severity of fixture.severityValues) {
    const source = {...fixture.validCases[0].signal, signalLevel: severity};
    assert.equal(adaptMonitoringRiskSignalV1({signalId: "severity",
      signal: source, event: null, adaptedAt: fixture.validCases[0].adaptedAt})
        .canonicalSeverity, severity);
  }
  for (const status of fixture.lifecycleValues) {
    const source = {...fixture.validCases[0].signal, status};
    assert.equal(adaptMonitoringRiskSignalV1({signalId: "status",
      signal: source, event: null, adaptedAt: fixture.validCases[0].adaptedAt})
        .reviewStatus, status);
  }
  for (const error of fixture.errorCases) {
    const source = {...fixture.validCases[0].signal,
      [error.field]: error.value};
    assert.throws(() => adaptMonitoringRiskSignalV1({signalId: "invalid",
      signal: source, event: null, adaptedAt: fixture.validCases[0].adaptedAt}),
    new RegExp(error.expectedError));
  }
  const source = fixture.validCases[1];
  assert.throws(() => adaptMonitoringRiskSignalV1({signalId: source.signalId,
    signal: source.signal, event: {...source.event, tenantId: "other"},
    adaptedAt: source.adaptedAt}), /event_scope_mismatch/);

  const granted = evaluateMonitoringPersistencePermissionV1({
    adminSnapshot: {exists: true, data: {active: true,
      roles: ["super_admin", "super_admin"]}},
    requestedPermission: "risk_signal.persist",
    evaluationTime: "2026-07-19T12:00:00.000Z"});
  assert.equal(granted.granted, true);
  assert.deepEqual(granted.derivedExactPermissions, ["risk_signal.persist"]);
  for (const data of [{active: false, roles: ["super_admin"]},
    {active: true, roles: ["brand_application_reviewer"]}]) {
    assert.equal(evaluateMonitoringPersistencePermissionV1({
      adminSnapshot: {exists: true, data},
      requestedPermission: "risk_signal.persist",
      evaluationTime: "2026-07-19T12:00:00.000Z"}).granted, false);
  }
  assert.throws(() => monitoringRiskPersistenceRequestV1({
    monitoringSignalId: "signal", dryRun: true,
    requestedAt: "2026-07-19T12:00:00.000Z", tenantId: "forged",
  }), (error) => error.code === "request.untrusted_field");
  const full = fixture.validCases[1];
  const facts = assembleMonitoringServerPersistenceFactsV1({
    invocation: invocation(),
    adminSnapshot: {exists: true, data: {active: true,
      roles: ["super_admin"]}},
    signalSnapshot: {exists: true, id: full.signalId, data: full.signal,
      documentPath: `monitoring_signals/${full.signalId}`,
      updateTime: "2026-07-19T12:00:30.000Z"},
    eventSnapshot: {exists: true, data: full.event},
    evaluationTime: full.adaptedAt,
  });
  assert.equal(facts.subjectFingerprint, full.expectedFingerprint);
  assert.equal(facts.targetNamespace, "shared_risk_signals");
  assert.equal(facts.readinessDecision.allowed, true);
  const rolloutBase = {monitoringSignalId: "signal", dryRun: true,
    projectId: "markakalkan-app", expectedProjectId: "markakalkan-app",
    evaluatedAt: "2026-07-19T12:00:00.000Z", allowedSignalIds: []};
  assert.equal(evaluateMonitoringRolloutPolicyV1({...rolloutBase,
    mode: "dry_run_only"}).allowed, true);
  assert.equal(evaluateMonitoringRolloutPolicyV1({...rolloutBase,
    mode: "disabled"}).allowed, false);
  assert.equal(evaluateMonitoringRolloutPolicyV1({...rolloutBase,
    mode: "single_signal_write", dryRun: false,
    allowedSignalIds: ["signal"]}).allowed, true);
  assert.equal(evaluateMonitoringRolloutPolicyV1({...rolloutBase,
    mode: "single_signal_write", dryRun: false,
    allowedSignalIds: ["other"]}).allowed, false);
  assert.equal(evaluateMonitoringRolloutPolicyV1({...rolloutBase,
    mode: "dry_run_only", projectId: "wrong"}).allowed, false);
  console.log("monitoring_unit.test.js: PASS (37 scenarios)");
}

main();
