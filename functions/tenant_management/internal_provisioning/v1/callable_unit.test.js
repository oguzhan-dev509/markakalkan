/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {PILOT_CODE, PRODUCTION_PROJECT_ID} = require("./contracts");
const {MODES, evaluateProvisioningRolloutPolicyV1,
  parseAllowedPilotCodes} = require("./rollout_policy");
const {CALLABLE_OPTIONS, sanitizedResult} = require("./callable");

const base = {pilotCode: PILOT_CODE, dryRun: true,
  projectId: PRODUCTION_PROJECT_ID, expectedProjectId: PRODUCTION_PROJECT_ID,
  evaluatedAt: "2026-07-20T00:00:00.000Z", allowedPilotCodes: []};

test("rollout modes are fail-closed", () => {
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.disabled}).allowed, false);
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.dryRunOnly}).allowed, true);
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.dryRunOnly, dryRun: false}).allowed, false);
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.singlePilotCreate, dryRun: false,
    allowedPilotCodes: [PILOT_CODE]}).allowed, true);
  for (const codes of [[], [PILOT_CODE, "other"]]) {
    assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
      mode: MODES.singlePilotCreate, dryRun: false,
      allowedPilotCodes: codes}).allowed, false);
  }
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.singlePilotCreate, dryRun: false,
    allowedPilotCodes: [PILOT_CODE], expiresAt: base.evaluatedAt}).allowed,
  false);
  assert.equal(evaluateProvisioningRolloutPolicyV1({...base,
    mode: MODES.dryRunOnly, projectId: "wrong"}).allowed, false);
});

test("allowlist parser is deterministic", () => {
  assert.deepEqual(parseAllowedPilotCodes(""), []);
  assert.deepEqual(parseAllowedPilotCodes(`${PILOT_CODE},${PILOT_CODE}`),
      [PILOT_CODE]);
});

test("production callable security metadata is immutable", () => {
  assert.deepEqual(CALLABLE_OPTIONS, {region: "europe-west3",
    enforceAppCheck: true, maxInstances: 1});
  assert.equal(Object.isFrozen(CALLABLE_OPTIONS), true);
});

test("sanitized response contains no payload or authority", () => {
  const result = sanitizedResult({outcome: "dry_run_ready", dryRun: true,
    tenantId: "tenant", brandId: "brand", membershipId: "membership",
    receiptId: "receipt", auditId: "audit", transactionCommitted: false},
  {mode: MODES.dryRunOnly, policyVersion: "policy-v1"}, PILOT_CODE, "corr");
  assert.deepEqual(Object.keys(result).sort(), ["auditEventId", "blockerCodes",
    "brandId", "correlationId", "dryRun", "membershipId", "outcome",
    "pilotCode", "policyVersion", "receiptId", "rolloutMode", "tenantId",
    "transactionCommitted", "warningCodes"].sort());
  assert.doesNotMatch(JSON.stringify(result), /admin|permission|payload|token/i);
  assert.equal(HttpsError !== undefined, true);
});
