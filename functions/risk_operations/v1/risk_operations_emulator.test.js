/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {createRiskOperationsCallableHandlerV1} = require("./callable");

const projectId = "demo-markakalkan-rst-1a";
assert.equal(process.env.GCLOUD_PROJECT, projectId);
assert.equal(process.env.GOOGLE_APPLICATION_CREDENTIALS, undefined);
const app = initializeApp({projectId}, "risk-operations-emulator");
const db = getFirestore(app);
const uid = "risk-operations-user";
const paths = [
  "tenant_memberships/membership-1",
  "canonical_brands/brand-1",
  "monitoring_signals/signal-1",
];
const diagnostics = {clientTabId: "client-tab-0001", navigationId: "navigation-0001", pageInstanceId: "page-instance-0001", loadAttemptId: "load-attempt-0001", trigger: "initial_mount", attemptSequence: 1};

async function state() {
  const snapshots = await db.getAll(...paths.map((path) => db.doc(path)));
  return snapshots.map((snapshot) => JSON.stringify(snapshot.data()));
}

async function main() {
  try {
    await db.doc(paths[0]).set({uid, tenantId: "tenant-1", status: "active"});
    await db.doc(paths[1]).set({tenantId: "tenant-1", status: "active"});
    await db.doc(paths[2]).set({tenantId: "tenant-1", brandId: "brand-1", signalLevel: "high", status: "new", title: "Emulator signal", summary: "Read-only fixture", detectedAt: "2026-07-21T00:00:00.000Z"});
    const before = await state();
    const handler = createRiskOperationsCallableHandlerV1({db, clock: {now: () => "2026-07-21T01:00:00.000Z"}});
    const result = await handler({auth: {uid}, app: {appId: "emulator-app-check"}, data: {...diagnostics, pageSize: 10}});
    const after = await state();
    assert.equal(result.readOnly, true);
    assert.equal(result.writesPerformed, 0);
    assert.equal(result.items.length, 1);
    assert.deepEqual(after, before);
    await assert.rejects(() => handler({auth: {uid}, app: {appId: "emulator-app-check"}, data: {...diagnostics, tenantId: "other"}}), /mismatch/);
    assert.deepEqual(await state(), before);
    console.log("MK-RST-1A read-only application harness: PASS; writes 0");
  } finally {
    await Promise.all(paths.map((path) => db.doc(path).delete()));
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
