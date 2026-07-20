/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {COLLECTIONS, PILOT_CODE, PROJECT_ID,
  createInternalTenantBrandProvisioningServiceV1} = require("./index");

function guard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(host)) {
    throw new Error("loopback Firestore emulator required");
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("production credentials forbidden");
  }
}
async function clear(host) {
  const r = await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}` +
    "/databases/(default)/documents", {method: "DELETE"});
  assert.equal(r.ok, true);
}
async function count(db, name) {
  return (await db.collection(name).get()).size;
}

async function main() {
  guard(); const host = process.env.FIRESTORE_EMULATOR_HOST;
  const app = initializeApp({projectId: PROJECT_ID}, "rst-0k-test");
  const db = getFirestore(app);
  let at = "2026-07-20T00:00:00.000Z";
  const service = createInternalTenantBrandProvisioningServiceV1({db,
    clock: {now: () => at}});
  const request = {pilotCode: PILOT_CODE, dryRun: true};
  const invocation = {authenticatedUid: "super-1", projectId: PROJECT_ID,
    receivedAt: at};
  try {
    await clear(host);
    const denied = await service.execute(request, invocation);
    assert.equal(denied.outcome, "denied");
    await db.collection("platform_admins").doc("super-1").set({active: true,
      roles: ["super_admin"]});
    const dry = await service.execute(request, invocation);
    assert.equal(dry.outcome, "dry_run_ready"); assert.equal(dry.writeCount, 0);
    for (const name of Object.values(COLLECTIONS)) assert.equal(await count(db, name), 0);
    const concurrent = await Promise.all([
      service.execute({...request, dryRun: false}, invocation),
      service.execute({...request, dryRun: false}, invocation),
    ]);
    assert.deepEqual(concurrent.map((x) => x.outcome).sort(),
        ["created", "idempotent_success"]);
    const created = concurrent.find((item) => item.outcome === "created");
    assert.equal(created.writeCount, 5);
    for (const name of Object.values(COLLECTIONS)) assert.equal(await count(db, name), 1);
    const [tenant, brand, membership] = await Promise.all([
      db.collection(COLLECTIONS.tenant).doc(created.tenantId).get(),
      db.collection(COLLECTIONS.brand).doc(created.brandId).get(),
      db.collection(COLLECTIONS.membership).doc(created.membershipId).get()]);
    assert.equal(brand.data().tenantId, tenant.id);
    assert.equal(brand.data().visibility, "private");
    assert.equal(membership.data().uid, "super-1");
    at = "2026-07-20T01:00:00.000Z";
    const replay = await service.execute({...request, dryRun: false}, invocation);
    assert.equal(replay.outcome, "idempotent_success");
    await clear(host);
    await db.collection("platform_admins").doc("super-1").set({active: true,
      roles: ["super_admin"]});
    const dry2 = await service.execute(request, invocation);
    await db.collection(COLLECTIONS.tenant).doc(dry2.tenantId).set({orphan: true});
    const conflict = await service.execute({...request, dryRun: false}, invocation);
    assert.equal(conflict.outcome, "conflict");
    assert.equal(await count(db, COLLECTIONS.brand), 0);
    await clear(host);
    await db.collection("platform_admins").doc("super-1").set({active: true,
      roles: ["super_admin"]});
    const dry3 = await service.execute(request, invocation);
    const sentinel = {sentinel: true};
    await db.collection(COLLECTIONS.audit).doc(dry3.auditId).set(sentinel);
    const atomicConflict = await service.execute({...request, dryRun: false},
        invocation);
    assert.equal(atomicConflict.outcome, "conflict");
    assert.deepEqual((await db.collection(COLLECTIONS.audit)
        .doc(dry3.auditId).get()).data(), sentinel);
    for (const name of [COLLECTIONS.tenant, COLLECTIONS.brand,
      COLLECTIONS.membership, COLLECTIONS.receipt]) {
      assert.equal(await count(db, name), 0);
    }
    console.log("MK-RST-0K emulator: authorization/dry-run/create/replay/concurrency/integrity passed");
  } finally {
    await deleteApp(app);
  }
}
main().catch((error) => {
  console.error(error); process.exitCode = 1;
});
