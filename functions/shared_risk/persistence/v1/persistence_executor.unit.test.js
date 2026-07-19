const assert = require("node:assert/strict");

const {
  EMULATOR_PROJECT_ID,
  buildCreationAuditEventIdV1,
  buildServerPersistenceFactsV1,
  creationAuditSnapshotV1,
  existingPersistenceReceiptSnapshotV1,
  subjectSnapshotV1,
  validateAuthoritativeFactsForPortV1,
  validateStorageIntegrityV1,
  assertFirestoreEmulatorV1,
} = require("./index");

function facts() {
  return buildServerPersistenceFactsV1({authoritativeInput: {
    authenticatedActor: {uid: "actor-1", actorType: "system",
      serviceIdentity: "test-handler"},
    resolvedIdentityScope: {tenantId: "tenant-unit", brandId: "brand-1"},
    grantedPermissions: ["risk_signal.persist"],
    subjectType: "risk_signal",
    subjectId: "signal-unit",
    subjectContractVersion: "shared-risk-contract-v1",
    canonicalSubjectPayload: {signalId: "signal-unit", summary: "unit"},
    exactIdempotencyBinding: {purpose: "exact_source_occurrence",
      canonicalKey: "unit-key"},
    sourceModule: "traceability",
    sourceRecordRef: "verificationScans/unit",
    sourceRecordVersion: "1",
    readinessDecision: {allowed: true, blockers: [],
      policyVersion: "risk-persistence-readiness-v1"},
    serverEvaluationTime: "2026-07-19T18:00:00.000Z",
    provenance: {sourceModule: "traceability", correlationId: "unit"},
  }});
}

function snapshot(exists, data = {}) {
  return {exists, data: () => data};
}

function main() {
  const serverFacts = facts();
  assert.deepEqual(validateAuthoritativeFactsForPortV1(serverFacts), []);
  assert.ok(validateAuthoritativeFactsForPortV1({
    ...serverFacts, grantedPermissions: [],
  }).includes("port.exact_permission_missing"));
  assert.ok(validateAuthoritativeFactsForPortV1({
    ...serverFacts, readinessDecision: {allowed: false},
  }).includes("port.readiness_denied"));
  assert.throws(() => assertFirestoreEmulatorV1({
    projectId: EMULATOR_PROJECT_ID, emulatorHost: "",
  }), /FIRESTORE_EMULATOR_HOST/);
  assert.throws(() => assertFirestoreEmulatorV1({
    projectId: "production-project", emulatorHost: "127.0.0.1:8080",
  }), /dedicated/);

  const auditId = buildCreationAuditEventIdV1({
    receiptId: serverFacts.receiptId,
    persistenceDocumentId: serverFacts.persistenceDocumentId,
    commandId: serverFacts.commandId,
  });
  assert.equal(auditId.length, 64);
  assert.equal(auditId, buildCreationAuditEventIdV1({
    receiptId: serverFacts.receiptId,
    persistenceDocumentId: serverFacts.persistenceDocumentId,
    commandId: serverFacts.commandId,
  }));
  assert.notEqual(auditId, buildCreationAuditEventIdV1({
    receiptId: serverFacts.receiptId,
    persistenceDocumentId: serverFacts.persistenceDocumentId,
    commandId: `${serverFacts.commandId}-different`,
  }));

  const absentSubject = subjectSnapshotV1(snapshot(false));
  const absentAudit = creationAuditSnapshotV1(snapshot(false));
  const absentReceipt = existingPersistenceReceiptSnapshotV1();
  assert.deepEqual(validateStorageIntegrityV1({facts: serverFacts,
    receipt: absentReceipt, subject: absentSubject, audit: absentAudit,
    creationAuditEventId: auditId}), []);
  assert.ok(validateStorageIntegrityV1({facts: serverFacts,
    receipt: absentReceipt,
    subject: subjectSnapshotV1(snapshot(true, {tenantId: "tenant-unit"})),
    audit: absentAudit, creationAuditEventId: auditId})
      .includes("integrity.orphan_subject"));
  assert.ok(validateStorageIntegrityV1({facts: serverFacts,
    receipt: absentReceipt, subject: absentSubject,
    audit: creationAuditSnapshotV1(snapshot(true, {auditEventId: auditId})),
    creationAuditEventId: auditId}).includes("integrity.orphan_audit"));
  const completed = {status: "completed"};
  const missing = validateStorageIntegrityV1({facts: serverFacts,
    receipt: completed, subject: absentSubject, audit: absentAudit,
    creationAuditEventId: auditId});
  assert.ok(missing.includes("integrity.subject_missing"));
  assert.ok(missing.includes("integrity.audit_missing"));
  assert.ok(Object.isFrozen(absentSubject));
  assert.ok(Object.isFrozen(serverFacts));
  console.log("persistence_executor.unit.test.js: PASS (16 scenarios)");
}

main();
