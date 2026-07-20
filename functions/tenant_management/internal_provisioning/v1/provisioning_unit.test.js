const assert = require("node:assert/strict");
const test = require("node:test");
const {PILOT_CODE, PROJECT_ID, buildIdsV1, documents,
  evaluateProvisioningPolicyV1, provisioningRequestV1} = require("./index");

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
