const assert = require("node:assert/strict");

const {
  COLLECTIONS,
  IMMUTABLE_SUBJECT_FIELDS,
  OPERATIONS,
  OUTCOMES,
  PAYLOAD_LIMITS,
  buildAuditEventStorageDocumentV1,
  buildPersistenceDocumentIdV1,
  buildReceiptStorageDocumentV1,
  buildServerPersistenceFactsV1,
  buildSubjectStorageDocumentV1,
  existingPersistenceReceiptSnapshotV1,
  planPersistenceTransactionV1,
} = require("./index");

const plannedAt = "2026-07-19T18:00:00.000Z";

function authoritative(overrides = {}) {
  return {
    authenticatedActor: {
      uid: "server-actor-1",
      actorType: "service_account",
      serviceIdentity: "risk-persistence-handler",
    },
    resolvedIdentityScope: {tenantId: "tenant-1", brandId: "brand-1"},
    grantedPermissions: ["risk_signal.persist"],
    subjectType: "risk_signal",
    subjectId: "signal-1",
    subjectContractVersion: "shared-risk-contract-v1",
    canonicalSubjectPayload: {
      signalId: "signal-1",
      summary: "Authoritative signal",
      evidenceRefs: [{id: "evidence-1"}],
      relatedEntityRefs: [{id: "entity-1"}],
      metadata: {source: "verified"},
    },
    exactIdempotencyBinding: {
      purpose: "exact_source_occurrence",
      canonicalKey: "27:source-ingestion-key-v1|12:traceability|" +
        "18:verification_scan|8:record-1",
    },
    sourceModule: "traceability",
    sourceRecordRef: "verificationScans/record-1",
    sourceRecordVersion: "7",
    sourceRecordUpdateTime: "2026-07-19T15:00:00.000Z",
    readinessDecision: {
      allowed: true,
      blockers: [],
      policyVersion: "risk-persistence-readiness-v1",
    },
    serverEvaluationTime: "2026-07-19T17:00:00.000Z",
    commandRequestedAt: "2026-07-19T16:00:00.000Z",
    provenance: {
      sourceModule: "traceability",
      sourceRecordId: "record-1",
      sourceCreatedAt: "2026-07-19T14:00:00.000Z",
    },
    ...overrides,
  };
}

function facts(overrides = {}, clientClaims = {}) {
  return buildServerPersistenceFactsV1({
    authoritativeInput: authoritative(overrides),
    ...clientClaims,
  });
}

function receiptFor(serverFacts, overrides = {}) {
  return existingPersistenceReceiptSnapshotV1({
    status: "completed",
    receiptId: serverFacts.receiptId,
    tenantId: serverFacts.resolvedIdentityScope.tenantId,
    targetNamespace: serverFacts.targetNamespace,
    subjectType: serverFacts.subjectType,
    subjectId: serverFacts.subjectId,
    commandId: serverFacts.commandId,
    idempotencyCanonicalKey:
      serverFacts.exactIdempotencyBinding.canonicalKey,
    subjectFingerprint: serverFacts.subjectFingerprint,
    persistenceDocumentId: serverFacts.persistenceDocumentId,
    sourceRecordVersion: serverFacts.sourceRecordVersion,
    sourceRecordUpdateTime: serverFacts.sourceRecordUpdateTime,
    completedAt: "2026-07-19T17:30:00.000Z",
    ...overrides,
  });
}

function plan(serverFacts, existingReceipt, overrides = {}) {
  return planPersistenceTransactionV1({
    facts: serverFacts,
    existingReceipt,
    sourceVersionStillCurrent: true,
    sourceRecordStillExists: true,
    plannedAt,
    ...overrides,
  });
}

function testDocumentIds() {
  const input = {
    tenantId: "tenant-1",
    targetNamespace: COLLECTIONS.riskSignal,
    idempotencyCanonicalKey: "exact-key-1",
  };
  const first = buildPersistenceDocumentIdV1(input);
  assert.equal(first, buildPersistenceDocumentIdV1({...input}));
  assert.match(first, /^[a-f0-9]{64}$/);
  assert.notEqual(first, buildPersistenceDocumentIdV1({
    ...input, tenantId: "tenant-2",
  }));
  assert.notEqual(first, buildPersistenceDocumentIdV1({
    ...input, targetNamespace: COLLECTIONS.riskAssessment,
  }));
  assert.notEqual(first, buildPersistenceDocumentIdV1({
    ...input, idempotencyCanonicalKey: "exact-key-2",
  }));
  assert.notEqual(
      buildPersistenceDocumentIdV1({
        tenantId: "ab", targetNamespace: "c", idempotencyCanonicalKey: "d",
      }),
      buildPersistenceDocumentIdV1({
        tenantId: "a", targetNamespace: "bc", idempotencyCanonicalKey: "d",
      }),
  );
  assert.doesNotMatch(first, /tenant|exact/);
}

function testTrustBoundary() {
  const serverFacts = facts({}, {
    tenantId: "attacker-tenant",
    permissions: ["admin"],
    commandId: "forged",
  });
  assert.equal(serverFacts.resolvedIdentityScope.tenantId, "tenant-1");
  assert.deepEqual(serverFacts.grantedPermissions, ["risk_signal.persist"]);
  assert.notEqual(serverFacts.commandId, "forged");
  assert.throws(() => facts({resolvedIdentityScope: {tenantId: ""}}));
  assert.deepEqual(facts({grantedPermissions: ["admin"]}).validationBlockers,
      ["authorization.exact_permission_missing"]);
  assert.ok(facts({readinessDecision: {allowed: false, blockers: ["x"]}})
      .validationBlockers.includes("readiness.server_decision_denied"));
  assert.ok(facts({sourceModule: "public_ui"}).validationBlockers
      .includes("source.module_unsupported"));
  assert.throws(() => facts({provenance: undefined}));
}

function testCreateAndDeterminism() {
  const serverFacts = facts();
  const absent = existingPersistenceReceiptSnapshotV1();
  const first = plan(serverFacts, absent);
  const second = plan(serverFacts, absent);
  assert.equal(first.outcome, OUTCOMES.create);
  assert.equal(first.executable, true);
  assert.deepEqual(first.operations, [
    OPERATIONS.createSubject,
    OPERATIONS.createReceipt,
    OPERATIONS.completeReceipt,
    OPERATIONS.appendAuditEvent,
  ]);
  assert.equal(JSON.stringify(first), JSON.stringify(second));
  assert.equal(absent.status, "absent");
  assert.ok(Object.isFrozen(serverFacts));
  assert.ok(Object.isFrozen(serverFacts.provenance));
}

function testIdempotencyAndConflicts() {
  const serverFacts = facts();
  const completed = receiptFor(serverFacts);
  const success = plan(serverFacts, completed);
  assert.equal(success.outcome, OUTCOMES.idempotentSuccess);
  assert.ok(success.operations.includes(OPERATIONS.noWrite));
  assert.ok(success.operations.includes(OPERATIONS.appendAuditEvent));
  assert.ok(!success.operations.includes(OPERATIONS.createSubject));
  const mismatches = [
    {subjectFingerprint: "different"},
    {subjectId: "signal-2"},
    {commandId: "different"},
    {tenantId: "tenant-2"},
    {targetNamespace: COLLECTIONS.riskAssessment},
    {subjectType: "risk_assessment"},
    {idempotencyCanonicalKey: "different"},
  ];
  for (const mismatch of mismatches) {
    const result = plan(serverFacts, receiptFor(serverFacts, mismatch));
    assert.equal(result.outcome, OUTCOMES.conflict);
    assert.deepEqual(result.operations,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent]);
  }
}

function testSourceAndRetryPolicies() {
  const serverFacts = facts();
  const absent = existingPersistenceReceiptSnapshotV1();
  assert.equal(plan(serverFacts, absent, {sourceVersionStillCurrent: false})
      .outcome, OUTCOMES.recomputeRequired);
  assert.equal(plan(serverFacts, absent, {sourceVersionStillCurrent: null})
      .outcome, OUTCOMES.recomputeRequired);
  assert.equal(plan(serverFacts, absent, {sourceRecordStillExists: false})
      .outcome, OUTCOMES.deny);
  assert.equal(plan(serverFacts, receiptFor(serverFacts, {tenantId: "moved"}))
      .outcome, OUTCOMES.conflict);
  assert.equal(plan(serverFacts, receiptFor(serverFacts, {status: "pending"}))
      .outcome, OUTCOMES.deny);
  assert.equal(plan(serverFacts, receiptFor(serverFacts, {
    status: "failed", retryable: true,
  })).outcome, OUTCOMES.recomputeRequired);
  assert.equal(plan(serverFacts, receiptFor(serverFacts, {
    status: "failed", retryable: false,
  })).outcome, OUTCOMES.deny);
}

function testLimitsAndImmutabilityPolicy() {
  assert.ok(IMMUTABLE_SUBJECT_FIELDS.includes("tenantId"));
  assert.ok(IMMUTABLE_SUBJECT_FIELDS.includes("creationAuditLink"));
  const related = Array.from({length: PAYLOAD_LIMITS.relatedRefs + 1},
      (_, index) => ({id: String(index)}));
  assert.ok(facts({canonicalSubjectPayload: {
    signalId: "signal-1", relatedEntityRefs: related,
  }}).validationBlockers.includes("payload.too_many_related_refs"));
  const evidence = Array.from({length: PAYLOAD_LIMITS.evidenceRefs + 1},
      (_, index) => ({id: String(index)}));
  assert.ok(facts({canonicalSubjectPayload: {
    signalId: "signal-1", evidenceRefs: evidence,
  }}).validationBlockers.includes("payload.too_many_evidence_refs"));
  const deepMetadata = {a: {b: {c: {d: {e: {f: {g: true}}}}}}};
  assert.ok(facts({canonicalSubjectPayload: {
    signalId: "signal-1", metadata: deepMetadata,
  }}).validationBlockers.includes("payload.metadata_too_deep"));
  assert.ok(facts({canonicalSubjectPayload: {
    signalId: "signal-1", evidenceRefs: [{id: "x"}, {id: "x"}],
  }}).validationBlockers.includes("payload.duplicate_evidence_refs"));
  assert.deepEqual(facts().validationBlockers, []);
}

function testImmutableStorageContracts() {
  const serverFacts = facts();
  const createPlan = plan(serverFacts,
      existingPersistenceReceiptSnapshotV1());
  const subject = buildSubjectStorageDocumentV1(serverFacts,
      "SERVER_TIMESTAMP");
  const receipt = buildReceiptStorageDocumentV1(createPlan, serverFacts,
      "SERVER_TIMESTAMP");
  const audit = buildAuditEventStorageDocumentV1({
    plan: createPlan,
    facts: serverFacts,
    occurredAt: plannedAt,
    serverRecordedAt: "SERVER_TIMESTAMP",
    correlationId: "correlation-1",
  });
  assert.equal(subject.tenantId, "tenant-1");
  assert.equal(subject.persistedAt, "SERVER_TIMESTAMP");
  assert.equal(receipt.receiptId, serverFacts.receiptId);
  assert.equal(audit.idempotencyKeyHash.length, 64);
  assert.ok(Object.isFrozen(subject));
  assert.ok(Object.isFrozen(receipt));
  assert.ok(Object.isFrozen(audit));
}

function main() {
  testDocumentIds();
  testTrustBoundary();
  testCreateAndDeterminism();
  testIdempotencyAndConflicts();
  testSourceAndRetryPolicies();
  testLimitsAndImmutabilityPolicy();
  testImmutableStorageContracts();
  console.log("transaction_planner.test.js: PASS (40 scenarios)");
}

main();
