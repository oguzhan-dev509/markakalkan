const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const {createFirestorePersistenceStoreV1, COLLECTIONS,
  MONITORING_EMULATOR_PROJECT_ID,
  assertFirestoreEmulatorV1} = require("../../persistence/v1");
const {createMonitoringEventAuthorityPortV1,
  createMonitoringRiskPersistenceApplicationServiceV1,
  createMonitoringSignalAuthorityPortV1,
  createPlatformAdminAuthorityPortV1,
  fixedServerClockPortV1} = require("./index");

const now = "2026-07-19T20:00:00.000Z";

async function clearEmulator(host) {
  const url = `http://${host}/emulator/v1/projects/` +
    `${MONITORING_EMULATOR_PROJECT_ID}/databases/(default)/documents`;
  const response = await fetch(url, {method: "DELETE"});
  assert.equal(response.ok, true, `emulator clear failed: ${response.status}`);
}

function signal(overrides = {}) {
  return {tenantId: "tenant-1", brandId: "brand-1",
    sourceId: "source-1", pageId: "page-1", eventId: "event-1",
    ruleId: "rule-1", ruleName: "Price rule", eventType: "price_decreased",
    signalLevel: "high", status: "confirmed", summary: "Price decreased",
    detectedAt: new Date("2026-07-19T19:00:00.000Z"),
    createdAt: new Date("2026-07-19T19:01:00.000Z"), ...overrides};
}

function event(overrides = {}) {
  return {tenantId: "tenant-1", brandId: "brand-1", sourceId: "source-1",
    pageId: "page-1", eventType: "price_decreased", eventCategory: "price",
    previousSnapshotId: "snapshot-before",
    currentSnapshotId: "snapshot-after", ...overrides};
}

function request(id, dryRun = false) {
  return {monitoringSignalId: id, dryRun, correlationId: `corr-${id}`,
    requestedAt: "2026-07-19T19:59:00.000Z"};
}

function invocation(uid = "super-1") {
  return {authenticatedUid: uid, authenticationType: "firebase_auth",
    invocationId: `invoke-${uid}`, receivedAt: "2026-07-19T19:59:30.000Z"};
}

async function count(db, collection) {
  return (await db.collection(collection).get()).size;
}

function service(db, store = createFirestorePersistenceStoreV1(db)) {
  return createMonitoringRiskPersistenceApplicationServiceV1({
    adminAuthority: createPlatformAdminAuthorityPortV1(db),
    signalAuthority: createMonitoringSignalAuthorityPortV1(db),
    eventAuthority: createMonitoringEventAuthorityPortV1(db),
    clock: fixedServerClockPortV1(now), persistenceStore: store,
  });
}

function mutatingStore(db, id, mutation) {
  const base = createFirestorePersistenceStoreV1(db);
  let mutated = false;
  return {
    referencesFor: base.referencesFor,
    async runTransaction(callback) {
      if (!mutated) {
        mutated = true;
        await mutation(db.collection("monitoring_signals").doc(id));
      }
      return base.runTransaction(callback);
    },
  };
}

async function seed(db, id = "signal-1", overrides = {}) {
  const eventId = overrides.eventId || `event-${id}`;
  await Promise.all([
    db.collection("platform_admins").doc("super-1").set({active: true,
      roles: ["super_admin"]}),
    db.collection("monitoring_signals").doc(id)
        .set(signal({...overrides, eventId})),
    db.collection("monitoring_events").doc(eventId)
        .set(event({tenantId: overrides.tenantId || "tenant-1",
          brandId: overrides.brandId || "brand-1"})),
  ]);
}

async function main() {
  const guard = assertFirestoreEmulatorV1({
    projectId: MONITORING_EMULATOR_PROJECT_ID,
  });
  await clearEmulator(guard.emulatorHost);
  const app = initializeApp({projectId: guard.projectId}, "mk-rst-0i-tests");
  const db = getFirestore(app);

  await seed(db);
  const dryRun = await service(db).execute(request("signal-1", true),
      invocation());
  assert.equal(dryRun.outcome, "dry_run_ready");
  assert.equal(dryRun.transactionCommitted, false);
  assert.ok(dryRun.persistenceDocumentId);
  assert.ok(dryRun.commandId);
  assert.ok(dryRun.creationAuditEventId);
  const repeatedDryRun = await service(db)
      .execute(request("signal-1", true), invocation());
  assert.equal(repeatedDryRun.subjectFingerprint, dryRun.subjectFingerprint);
  assert.equal(repeatedDryRun.persistenceDocumentId,
      dryRun.persistenceDocumentId);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);
  assert.equal(await count(db, COLLECTIONS.receipt), 0);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 0);

  const created = await service(db).execute(request("signal-1"), invocation());
  assert.equal(created.outcome, "created");
  assert.equal(created.transactionCommitted, true);
  const replay = await service(db).execute(request("signal-1"), invocation());
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(await count(db, COLLECTIONS.riskSignal), 1);
  assert.equal(await count(db, COLLECTIONS.receipt), 1);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 1);
  const stored = await db.collection(COLLECTIONS.riskSignal)
      .doc(created.persistenceDocumentId).get();
  assert.equal(stored.data().tenantId, "tenant-1");
  assert.equal(stored.data().brandId, "brand-1");
  assert.ok(stored.data().sourceRecordUpdateTime);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "parallel-signal");
  const parallel = await Promise.all([
    service(db).execute(request("parallel-signal"), invocation()),
    service(db).execute(request("parallel-signal"), invocation()),
  ]);
  assert.deepEqual(parallel.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "auth-signal");
  await Promise.all([
    db.collection("platform_admins").doc("inactive").set({active: false,
      roles: ["super_admin"]}),
    db.collection("platform_admins").doc("reviewer").set({active: true,
      roles: ["brand_application_reviewer"]}),
  ]);
  for (const uid of ["missing", "inactive", "reviewer"]) {
    const denied = await service(db).execute(request("auth-signal"),
        invocation(uid));
    assert.equal(denied.outcome, "denied");
    assert.deepEqual(denied.blockers, ["authorization.denied"]);
  }
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);

  const missingAuth = await service(db).execute(request("auth-signal"), {
    authenticationType: "firebase_auth", invocationId: "missing-auth",
    receivedAt: now,
  });
  assert.equal(missingAuth.outcome, "denied");
  for (const forged of [{tenantId: "forged"}, {actorUid: "forged"},
    {readiness: {allowed: true}}, {subjectFingerprint: "forged"},
    {idempotencyKey: "forged"}, {commandId: "forged"},
    {targetNamespace: "shared_risk_signals"}, {subject: {}}]) {
    await assert.rejects(service(db).execute(
        {...request("auth-signal"), ...forged}, invocation()),
    (error) => error.code === "request.untrusted_field");
  }

  await clearEmulator(guard.emulatorHost);
  await seed(db, "missing-tenant", {tenantId: ""});
  await seed(db, "bad-severity", {signalLevel: "urgent"});
  await seed(db, "bad-lifecycle", {status: "forwarded"});
  for (const id of ["missing-tenant", "bad-severity", "bad-lifecycle"]) {
    const denied = await service(db).execute(request(id), invocation());
    assert.equal(denied.outcome, "denied");
  }

  await clearEmulator(guard.emulatorHost);
  await seed(db, "changed-signal");
  const changingStore = mutatingStore(db, "changed-signal",
      (reference) => reference.update({
        summary: "Changed after authoritative read",
      }));
  const stale = await service(db, changingStore)
      .execute(request("changed-signal"), invocation());
  assert.equal(stale.outcome, "recompute_required");
  assert.deepEqual(stale.blockers, ["source.version_changed"]);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "deleted-signal");
  const deleted = await service(db, mutatingStore(db, "deleted-signal",
      (reference) => reference.delete()))
      .execute(request("deleted-signal"), invocation());
  assert.equal(deleted.outcome, "denied");
  assert.deepEqual(deleted.blockers, ["source.record_missing"]);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "tenant-changed");
  const moved = await service(db, mutatingStore(db, "tenant-changed",
      (reference) => reference.update({tenantId: "tenant-other"})))
      .execute(request("tenant-changed"), invocation());
  assert.equal(moved.outcome, "conflict");
  assert.deepEqual(moved.blockers, ["source.tenant_changed"]);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "brand-changed");
  const rebranded = await service(db, mutatingStore(db, "brand-changed",
      (reference) => reference.update({brandId: "brand-other"})))
      .execute(request("brand-changed"), invocation());
  assert.equal(rebranded.outcome, "recompute_required");
  assert.deepEqual(rebranded.blockers, ["source.brand_changed"]);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "tenant-a", {tenantId: "tenant-a"});
  await seed(db, "tenant-b", {tenantId: "tenant-b"});
  const tenantA = await service(db).execute(request("tenant-a"), invocation());
  const tenantB = await service(db).execute(request("tenant-b"), invocation());
  assert.equal(tenantA.outcome, "created");
  assert.equal(tenantB.outcome, "created");
  assert.notEqual(tenantA.persistenceDocumentId, tenantB.persistenceDocumentId);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 2);

  await clearEmulator(guard.emulatorHost);
  await seed(db, "bad-event");
  await db.collection("monitoring_events").doc("event-bad-event")
      .update({tenantId: "other-tenant"});
  const mismatch = await service(db)
      .execute(request("bad-event"), invocation());
  assert.equal(mismatch.outcome, "denied");
  assert.deepEqual(mismatch.blockers, ["adapter.invalid"]);

  const absent = await service(db).execute(request("absent"), invocation());
  assert.equal(absent.outcome, "denied");
  assert.deepEqual(absent.blockers, ["source.not_found"]);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);

  await clearEmulator(guard.emulatorHost);
  await deleteApp(app);
  console.log("monitoring_emulator.test.js: PASS (58 assertions)");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
