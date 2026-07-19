const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const {
  COLLECTIONS,
  EMULATOR_PROJECT_ID,
  buildCreateDocumentsV1,
  buildCreationAuditEventIdV1,
  buildServerPersistenceFactsV1,
  createFirestorePersistenceStoreV1,
  executeAtomicCreateDocumentsV1,
  executePersistenceTransactionV1,
  assertFirestoreEmulatorV1,
} = require("./index");

const plannedAt = "2026-07-19T19:00:00.000Z";
const executedAt = "2026-07-19T19:00:01.000Z";

function facts({tenant = "tenant-emulator", subjectId = "signal-emulator",
  key = "emulator-exact-key", summary = "authoritative payload"} = {}) {
  return buildServerPersistenceFactsV1({authoritativeInput: {
    authenticatedActor: {uid: "emulator-actor", actorType: "system",
      serviceIdentity: "emulator-handler"},
    resolvedIdentityScope: {tenantId: tenant, brandId: "brand-emulator"},
    grantedPermissions: ["risk_signal.persist"],
    subjectType: "risk_signal",
    subjectId,
    subjectContractVersion: "shared-risk-contract-v1",
    canonicalSubjectPayload: {signalId: subjectId, summary,
      evidenceRefs: [], relatedEntityRefs: [], metadata: {}},
    exactIdempotencyBinding: {purpose: "exact_source_occurrence",
      canonicalKey: key},
    sourceModule: "traceability",
    sourceRecordRef: `verificationScans/${subjectId}`,
    sourceRecordVersion: "1",
    sourceRecordUpdateTime: "2026-07-19T18:00:00.000Z",
    readinessDecision: {allowed: true, blockers: [],
      policyVersion: "risk-persistence-readiness-v1"},
    serverEvaluationTime: "2026-07-19T18:30:00.000Z",
    provenance: {sourceModule: "traceability",
      correlationId: `correlation-${subjectId}`},
  }});
}

async function clearEmulator(host) {
  const url = `http://${host}/emulator/v1/projects/${EMULATOR_PROJECT_ID}` +
    "/databases/(default)/documents";
  const response = await fetch(url, {method: "DELETE"});
  assert.equal(response.ok, true, `emulator clear failed: ${response.status}`);
}

function execute(store, serverFacts, overrides = {}) {
  return executePersistenceTransactionV1({
    store,
    facts: serverFacts,
    sourceVersionStillCurrent: true,
    sourceRecordStillExists: true,
    plannedAt,
    executedAt,
    ...overrides,
  });
}

async function count(db, collection) {
  return (await db.collection(collection).get()).size;
}

async function main() {
  const guard = assertFirestoreEmulatorV1();
  await clearEmulator(guard.emulatorHost);
  const app = initializeApp({projectId: guard.projectId}, "mk-rst-0h-tests");
  const db = getFirestore(app);
  const store = createFirestorePersistenceStoreV1(db);

  const firstFacts = facts();
  const created = await execute(store, firstFacts);
  assert.equal(created.outcome, "created");
  assert.equal(created.transactionCommitted, true);
  const replay = await execute(store, firstFacts);
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(replay.transactionCommitted, false);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 1);
  assert.equal(await count(db, COLLECTIONS.receipt), 1);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 1);

  await clearEmulator(guard.emulatorHost);
  const concurrentFacts = facts({subjectId: "parallel-same"});
  const sameResults = await Promise.all([
    execute(store, concurrentFacts), execute(store, concurrentFacts),
  ]);
  assert.deepEqual(sameResults.map((value) => value.outcome).sort(),
      ["created", "idempotent_success"]);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 1);
  assert.equal(await count(db, COLLECTIONS.receipt), 1);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 1);

  await clearEmulator(guard.emulatorHost);
  const winnerA = facts({subjectId: "parallel-conflict", summary: "A"});
  const winnerB = facts({subjectId: "parallel-conflict", summary: "B"});
  const conflictResults = await Promise.all([
    execute(store, winnerA), execute(store, winnerB),
  ]);
  assert.deepEqual(conflictResults.map((value) => value.outcome).sort(),
      ["conflict", "created"]);
  assert.equal(await count(db, COLLECTIONS.riskSignal), 1);
  assert.equal(await count(db, COLLECTIONS.receipt), 1);
  assert.equal(await count(db, COLLECTIONS.auditEvent), 1);

  const differentSubject = facts({subjectId: "different-subject"});
  assert.equal((await execute(store, differentSubject)).outcome, "conflict");
  const tenantTwo = facts({tenant: "tenant-emulator-2",
    subjectId: "tenant-two"});
  assert.equal((await execute(store, tenantTwo)).outcome, "created");
  assert.notEqual(
      tenantTwo.persistenceDocumentId,
      winnerA.persistenceDocumentId,
  );

  const wrongTarget = {...facts({subjectId: "wrong-target"}),
    targetNamespace: COLLECTIONS.riskAssessment};
  assert.equal((await execute(store, wrongTarget)).outcome, "denied");

  await clearEmulator(guard.emulatorHost);
  const atomicFacts = facts({subjectId: "atomic-failure"});
  const auditId = buildCreationAuditEventIdV1({
    receiptId: atomicFacts.receiptId,
    persistenceDocumentId: atomicFacts.persistenceDocumentId,
    commandId: atomicFacts.commandId,
  });
  const refs = store.referencesFor({facts: atomicFacts,
    creationAuditEventId: auditId});
  await refs.audit.create({sentinel: "unchanged"});
  const planner = require("./transaction_planner");
  const createPlan = planner.planPersistenceTransactionV1({
    facts: atomicFacts,
    existingReceipt: {status: "absent"},
    sourceVersionStillCurrent: true,
    sourceRecordStillExists: true,
    plannedAt,
  });
  const documents = buildCreateDocumentsV1({facts: atomicFacts,
    plan: createPlan, creationAuditEventId: auditId, executedAt});
  await assert.rejects(db.runTransaction(async (transaction) => {
    await transaction.getAll(refs.receipt, refs.subject, refs.audit);
    executeAtomicCreateDocumentsV1(transaction, refs, documents);
  }));
  assert.equal((await refs.subject.get()).exists, false);
  assert.equal((await refs.receipt.get()).exists, false);
  assert.deepEqual((await refs.audit.get()).data(), {sentinel: "unchanged"});

  await clearEmulator(guard.emulatorHost);
  const sourceFacts = facts({subjectId: "source-policy"});
  assert.equal((await execute(store, sourceFacts,
      {sourceVersionStillCurrent: false})).outcome, "recompute_required");
  assert.equal((await execute(store, sourceFacts,
      {sourceRecordStillExists: false})).outcome, "denied");
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);

  const limited = facts({subjectId: "payload-limit"});
  const excessive = {...limited, validationBlockers:
    Object.freeze(["payload.too_many_evidence_refs"])};
  assert.equal((await execute(store, excessive)).outcome, "denied");
  assert.equal(await count(db, COLLECTIONS.riskSignal), 0);

  await clearEmulator(guard.emulatorHost);
  await deleteApp(app);
  console.log("persistence_emulator.test.js: PASS (30 scenarios)");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
