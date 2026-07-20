/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {COLLECTIONS, CALLABLE_EMULATOR_PROJECT_ID, PILOT_CODE,
  PERMISSION, evaluateProvisioningPolicyV1} = require("./index");
const {createProvisioningCallableHandlerV1} = require("./callable");

const now = "2026-07-20T12:00:00.000Z";
function guard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(host)) {
    throw new Error("loopback Firestore emulator required");
  }
  assert.equal(process.env.GCLOUD_PROJECT, CALLABLE_EMULATOR_PROJECT_ID);
  assert.equal(process.env.GOOGLE_APPLICATION_CREDENTIALS, undefined);
  return host;
}
async function clear(host) {
  const response = await fetch(`http://${host}/emulator/v1/projects/` +
    `${CALLABLE_EMULATOR_PROJECT_ID}/databases/(default)/documents`,
  {method: "DELETE"});
  assert.equal(response.ok, true);
}
function request(data, uid = "super-emulator") {
  return {data, auth: uid ? {uid} : null,
    app: {appId: "rst-0l-test-application"},
    rawRequest: {get: () => "local-emulator"}};
}
async function absent(db, collection, id) {
  assert.equal((await db.collection(collection).doc(id).get()).exists, false);
}

async function main() {
  const host = guard();
  const app = initializeApp({projectId: CALLABLE_EMULATOR_PROJECT_ID},
      "rst-0l-application-harness");
  const db = getFirestore(app);
  const logs = [];
  let policy = {mode: "dry_run_only", allowedPilotCodes: [],
    expectedProjectId: CALLABLE_EMULATOR_PROJECT_ID};
  let projectId = CALLABLE_EMULATOR_PROJECT_ID;
  const handler = createProvisioningCallableHandlerV1({db,
    clock: {now: () => now}, policyProvider: () => policy,
    projectIdProvider: () => projectId,
    log: {info: (...items) => logs.push(items)}});
  const input = {pilotCode: PILOT_CODE, dryRun: true,
    correlationId: "rst-0l-r2-dry-run"};
  try {
    await clear(host);
    await assert.rejects(handler({...request(input), app: null}),
        (error) => error.code === "unauthenticated");
    for (const uid of ["missing", "inactive", "viewer"]) {
      if (uid !== "missing") {
        await db.collection("platform_admins").doc(uid).set({
          active: uid !== "inactive", roles: uid === "viewer" ? ["viewer"] :
            ["super_admin"]});
      }
      await assert.rejects(handler(request(input, uid)),
          (error) => error.code === "permission-denied");
    }
    await db.collection("platform_admins").doc("super-emulator").set({
      active: true, roles: ["super_admin"]});
    const permission = evaluateProvisioningPolicyV1({request: input,
      invocation: {authenticatedUid: "super-emulator", projectId,
        receivedAt: now}, admin: {exists: true,
        data: {active: true, roles: ["super_admin"]}}});
    assert.deepEqual(permission.permissions, [PERMISSION]);
    for (const forged of [{unknown: true}, {tenantId: "x"}, {brandId: "x"},
      {ownerUid: "x"}, {role: "owner"}, {permission: PERMISSION}]) {
      await assert.rejects(handler(request({...input, ...forged})),
          (error) => error.code === "invalid-argument");
    }
    await assert.rejects(handler(request({...input, dryRun: false})),
        (error) => error.code === "failed-precondition");
    policy = {...policy, mode: "disabled"};
    await assert.rejects(handler(request(input)),
        (error) => error.code === "failed-precondition");
    policy = {...policy, mode: "dry_run_only"};
    projectId = "wrong-project";
    await assert.rejects(handler(request(input)),
        (error) => error.code === "failed-precondition");
    projectId = CALLABLE_EMULATOR_PROJECT_ID;
    await assert.rejects(handler(request({...input, pilotCode: "wrong"})),
        (error) => error.code === "permission-denied");

    const first = await handler(request(input));
    const second = await handler(request(input));
    assert.equal(first.outcome, "dry_run_ready");
    assert.equal(first.transactionCommitted, false);
    assert.equal(first.rolloutMode, "dry_run_only");
    assert.deepEqual(first.blockerCodes, []);
    for (const key of ["tenantId", "brandId", "membershipId", "receiptId",
      "auditEventId"]) {
      assert.match(first[key], /^[a-f0-9]{64}$/);
      assert.equal(first[key], second[key]);
    }
    for (const [collection, key] of [[COLLECTIONS.tenant, "tenantId"],
      [COLLECTIONS.brand, "brandId"],
      [COLLECTIONS.membership, "membershipId"],
      [COLLECTIONS.receipt, "receiptId"],
      [COLLECTIONS.audit, "auditEventId"]]) await absent(db, collection, first[key]);
    assert.equal(JSON.stringify(logs).includes("super-emulator"), false);
    assert.equal(JSON.stringify(logs).includes("rst-0l-r2-dry-run"), false);
    console.log("MK-RST-0L-R2 application harness: PASS; writes 0/0/0/0/0");
  } finally {
    await clear(host);
    await deleteApp(app);
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
