/* eslint-disable max-len */
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {createFirestorePersistenceStoreV1} = require("../../persistence/v1");
const {createPromotionServiceV1} = require("./service");
const {readSources} = require("../../../risk_operations/v1/service");

async function main() {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
  assert.equal(process.env.GCLOUD_PROJECT, "demo-markakalkan-rst-1c");
  assert.equal(process.env.GOOGLE_APPLICATION_CREDENTIALS, undefined);
  admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
  const db = admin.firestore();
  const now = "2026-07-21T00:00:00.000Z";
  await db.collection("tenant_memberships").doc("membership-1").create({
    uid: "user-1", tenantId: "tenant-1", role: "owner", status: "active"});
  await db.collection("canonical_brands").doc("brand-1").create({
    tenantId: "tenant-1", status: "active"});
  await db.collection("verificationScans").doc("scan-1").create({
    ownerUid: "user-1", productId: "product-1", productName: "Ürün",
    riskLevel: "high", riskScore: 80, found: true, repeatScan: true,
    status: "active", reviewStatus: "pending", createdAt: now});
  const context = {uid: "user-1", tenantId: "tenant-1", brandId: "brand-1"};
  const sources = await readSources({db, context, evaluatedAt: now});
  const projection = sources.items.find((item) =>
    item.sourceSystem === "traceability" && item.sourceRecordId === "scan-1");
  assert.ok(projection);
  const clock = {now: () => now};
  const service = createPromotionServiceV1({db, clock,
    projectIdProvider: () => "demo-markakalkan-rst-1c",
    persistenceStore: createFirestorePersistenceStoreV1(db)});
  const command = {sourceSystem: "traceability", sourceRecordId: "scan-1",
    expectedSourceRecordVersion: projection.sourceRecordVersion,
    expectedProjectionFingerprint: projection.projectionFingerprint,
    dryRun: true, correlationId: "emulator-correlation"};
  const dryRun = await service.execute(command, {uid: "user-1"});
  assert.equal(dryRun.outcome, "dry_run_ready");
  assert.equal(dryRun.transactionCommitted, false);
  assert.equal((await db.collection("shared_risk_signals").get()).size, 0);
  const [first, second] = await Promise.all([
    service.execute({...command, dryRun: false}, {uid: "user-1"}),
    service.execute({...command, dryRun: false}, {uid: "user-1"}),
  ]);
  assert.deepEqual([first.outcome, second.outcome].sort(),
      ["created", "idempotent_success"]);
  assert.equal((await db.collection("shared_risk_signals").get()).size, 1);
  assert.equal((await db.collection("shared_risk_persistence_receipts").get()).size, 1);
  assert.equal((await db.collection("shared_risk_persistence_audit_events").get()).size, 1);
  assert.equal((await db.collection("verificationScans").doc("scan-1").get()).data().productId, "product-1");
  const stale = await service.execute({...command,
    expectedProjectionFingerprint: "f".repeat(64)}, {uid: "user-1"});
  assert.equal(stale.outcome, "conflict");
  assert.equal(stale.writeAttempted, false);
  console.log("promotion_emulator.test.js: PASS (dry-run, atomic create, replay, concurrency, stale, source immutability)");
  await admin.app().delete();
}
main().catch((error) => {
  console.error(error); process.exitCode = 1;
});
