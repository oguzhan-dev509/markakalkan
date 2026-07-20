const assert = require("node:assert/strict");
const test = require("node:test");
const {PILOT_CODE, PROJECT_ID, buildIdsV1, documents,
  evaluateProvisioningPolicyV1, provisioningRequestV1,
  stateOutcome} = require("./index");

test("request is minimal and rejects authority fields", () => {
  assert.deepEqual(provisioningRequestV1({pilotCode: PILOT_CODE, dryRun: true}),
      {pilotCode: PILOT_CODE, dryRun: true, correlationId: null});
  for (const key of ["tenantId", "brandId", "ownerUid", "role", "permission"]) {
    assert.throws(() => provisioningRequestV1({pilotCode: PILOT_CODE,
      dryRun: true, [key]: "forged"}), /unknown fields/);
  }
});

test("policy is exact super-admin and project scoped", () => {
  const request = {pilotCode: PILOT_CODE};
  const invocation = {projectId: PROJECT_ID, authenticatedUid: "admin-1"};
  const granted = evaluateProvisioningPolicyV1({request, invocation,
    admin: {exists: true, data: {active: true, roles: ["super_admin"]}}});
  assert.equal(granted.allowed, true);
  assert.deepEqual(granted.permissions, ["internal_tenant_brand.provision"]);
  for (const admin of [{exists: false}, {exists: true, data: {active: false,
    roles: ["super_admin"]}}, {exists: true, data: {active: true,
    roles: ["viewer"]}}]) {
    assert.equal(evaluateProvisioningPolicyV1({request,
      invocation, admin}).allowed, false);
  }
  assert.equal(evaluateProvisioningPolicyV1({request, admin: {exists: true,
    data: {active: true, roles: ["super_admin"]}}, invocation: {...invocation,
    projectId: "wrong-project"}}).allowed, false);
});

test("ids and internal documents are deterministic and private", () => {
  const input = {pilotCode: PILOT_CODE, projectId: PROJECT_ID, uid: "admin-1"};
  const a = buildIdsV1(input); const b = buildIdsV1(input);
  assert.deepEqual(a, b);
  for (const key of ["tenantId", "brandId", "membershipId", "receiptId",
    "auditId"]) assert.match(a[key], /^[a-f0-9]{64}$/);
  const built = documents({ids: a, uid: "admin-1", pilotCode: PILOT_CODE,
    at: "2026-07-20T00:00:00.000Z"});
  assert.equal(built.tenant.tenantType, "internal");
  assert.equal(built.tenant.visibility, "private");
  assert.equal(built.brand.verificationStatus, "unverified");
  assert.equal(built.membership.role, "owner");
  for (const value of Object.values(built)) {
    const text = JSON.stringify(value);
    assert.doesNotMatch(text, /tax|phone|billing|subscription|email/i);
  }
});

function snapshot(id, data) {
  return {id, exists: true, data: () => data};
}

test("receipt replay validates every immutable field and timestamps", () => {
  const ids = buildIdsV1({pilotCode: PILOT_CODE, projectId: PROJECT_ID,
    uid: "admin-1"});
  const built = documents({ids, uid: "admin-1", pilotCode: PILOT_CODE,
    at: "2026-07-20T00:00:00.000Z"});
  const snapshots = (receipt) => ({
    tenant: snapshot(ids.tenantId, built.tenant),
    brand: snapshot(ids.brandId, built.brand),
    membership: snapshot(ids.membershipId, built.membership),
    receipt: snapshot(ids.receiptId, receipt),
    audit: snapshot(ids.auditId, built.audit),
  });
  assert.equal(stateOutcome(snapshots(built.receipt), built), "complete");

  const immutableFields = ["schemaVersion", "status", "operation",
    "pilotCode", "tenantId", "brandId", "membershipId", "commandId",
    "tenantFingerprint", "brandFingerprint", "auditEventId"];
  for (const field of immutableFields) {
    assert.equal(stateOutcome(snapshots({...built.receipt,
      [field]: `mutated-${field}`}), built), "conflict", field);
  }
  for (const field of ["createdAt", "completedAt"]) {
    const missing = {...built.receipt}; delete missing[field];
    assert.equal(stateOutcome(snapshots(missing), built), "conflict", field);
    assert.equal(stateOutcome(snapshots({...built.receipt,
      [field]: "invalid-timestamp"}), built), "conflict", field);
  }
  assert.equal(stateOutcome(snapshots({...built.receipt,
    unexpectedImmutable: true}), built), "conflict");
  assert.equal(stateOutcome(snapshots({...built.receipt,
    createdAt: "2026-07-21T00:00:00.000Z",
    completedAt: "2026-07-21T00:00:01.000Z"}), built), "complete");
});
