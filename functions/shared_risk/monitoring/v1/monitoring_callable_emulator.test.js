const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const {COLLECTIONS, MONITORING_EMULATOR_PROJECT_ID,
  assertFirestoreEmulatorV1} = require("../../persistence/v1");
const {createMonitoringCallableHandlerV1} = require("./monitoring_callable");

const now = "2026-07-19T21:00:00.000Z";

async function clearEmulator(host) {
  const url = `http://${host}/emulator/v1/projects/` +
    `${MONITORING_EMULATOR_PROJECT_ID}/databases/(default)/documents`;
  const response = await fetch(url, {method: "DELETE"});
  assert.equal(response.ok, true);
}

async function seed(db) {
  await Promise.all([
    db.collection("platform_admins").doc("super-1").set({active: true,
      roles: ["super_admin"]}),
    db.collection("platform_admins").doc("inactive").set({active: false,
      roles: ["super_admin"]}),
    db.collection("platform_admins").doc("reviewer").set({active: true,
      roles: ["brand_application_reviewer"]}),
    db.collection("monitoring_signals").doc("signal-1").set({
      tenantId: "tenant-1", brandId: "brand-1", sourceId: "source-1",
      pageId: "page-1", eventId: "event-1", ruleId: "rule-1",
      ruleName: "Price rule", eventType: "price_decreased",
      signalLevel: "high", status: "confirmed", summary: "Price decreased",
      detectedAt: new Date("2026-07-19T20:00:00.000Z"),
      createdAt: new Date("2026-07-19T20:01:00.000Z"),
    }),
    db.collection("monitoring_events").doc("event-1").set({
      tenantId: "tenant-1", brandId: "brand-1", sourceId: "source-1",
      pageId: "page-1", eventType: "price_decreased",
      eventCategory: "price", previousSnapshotId: "snapshot-before",
      currentSnapshotId: "snapshot-after",
    }),
  ]);
}

function callableRequest(data, uid = "super-1") {
  return {data, auth: uid ? {uid} : null,
    rawRequest: {get: () => "emulator-execution"}};
}

function input(dryRun = true) {
  return {monitoringSignalId: "signal-1", dryRun,
    correlationId: "callable-emulator",
    requestedAt: "2026-07-19T20:59:00.000Z"};
}

async function count(db, collection) {
  return (await db.collection(collection).get()).size;
}

async function main() {
  const guard = assertFirestoreEmulatorV1({
    projectId: MONITORING_EMULATOR_PROJECT_ID,
  });
  await clearEmulator(guard.emulatorHost);
  const app = initializeApp({projectId: guard.projectId},
      "mk-rst-0j-callable-tests");
  const db = getFirestore(app);
  await seed(db);
  let policy = {mode: "dry_run_only", allowedSignalIds: [],
    expectedProjectId: MONITORING_EMULATOR_PROJECT_ID};
  let projectId = MONITORING_EMULATOR_PROJECT_ID;
  const logs = [];
  const handler = createMonitoringCallableHandlerV1({db,
    policyProvider: () => policy, projectIdProvider: () => projectId,
    clock: {now: () => now}, log: {info: (...items) => logs.push(items)}});

  await assert.rejects(handler(callableRequest(input(), null)),
      (error) => error.code === "unauthenticated");
  for (const [field, value] of [["actorUid", "forged"],
    ["tenantId", "forged"], ["readinessDecision", {allowed: true}],
    ["fingerprint", "forged"], ["idempotencyKey", "forged"],
    ["commandId", "forged"], ["targetNamespace", "forged"]]) {
    await assert.rejects(handler(callableRequest({...input(), [field]: value})),
        (error) => error.code === "invalid-argument");
  }
  for (const uid of ["inactive", "reviewer", "missing"]) {
    await assert.rejects(handler(callableRequest(input(), uid)),
        (error) => error.code === "permission-denied");
  }

  const dryRun = await handler(callableRequest(input()));
  assert.equal(dryRun.outcome, "dry_run_ready");
  assert.equal(dryRun.transactionCommitted, false);
  assert.deepEqual(Object.keys(dryRun).sort(), ["blockerCodes",
    "correlationId", "creationAuditEventId", "dryRun",
    "monitoringSignalId", "outcome", "persistenceDocumentId",
    "policyVersion", "receiptId", "rolloutMode", "subjectId",
    "transactionCommitted", "warningCodes"].sort());
  assert.equal(JSON.stringify(dryRun).includes("subjectFingerprint"), false);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);
  assert.equal(await count(db, COLLECTIONS.receipt), 0);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 0);

  await assert.rejects(handler(callableRequest(input(false))),
      (error) => error.code === "failed-precondition");
  policy = {...policy, mode: "disabled"};
  await assert.rejects(handler(callableRequest(input())),
      (error) => error.code === "failed-precondition");
  policy = {...policy, mode: "single_signal_write",
    allowedSignalIds: ["other"]};
  await assert.rejects(handler(callableRequest(input(false))),
      (error) => error.code === "failed-precondition");
  policy = {...policy, allowedSignalIds: ["signal-1", "other"]};
  await assert.rejects(handler(callableRequest(input())),
      (error) => error.code === "failed-precondition");
  projectId = "wrong-project";
  policy = {...policy, mode: "dry_run_only", allowedSignalIds: []};
  await assert.rejects(handler(callableRequest(input())),
      (error) => error.code === "failed-precondition");

  projectId = MONITORING_EMULATOR_PROJECT_ID;
  policy = {...policy, mode: "single_signal_write",
    allowedSignalIds: ["signal-1"]};
  const created = await handler(callableRequest(input(false)));
  assert.equal(created.outcome, "created");
  assert.equal(created.transactionCommitted, true);
  const replay = await handler(callableRequest(input(false)));
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(replay.transactionCommitted, false);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 1);
  assert.equal(await count(db, COLLECTIONS.receipt), 1);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 1);
  assert.equal(JSON.stringify(logs).includes("Price decreased"), false);
  assert.equal(JSON.stringify(logs).includes("super-1"), false);

  await clearEmulator(guard.emulatorHost);
  await deleteApp(app);
  console.log("monitoring_callable_emulator.test.js: PASS (42 assertions)");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
