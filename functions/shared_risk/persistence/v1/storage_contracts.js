const {createHash} = require("node:crypto");

const STORAGE_SCHEMA_VERSION = "shared-risk-storage-v1";
const RECEIPT_SCHEMA_VERSION = "shared-risk-receipt-v1";
const AUDIT_SCHEMA_VERSION = "shared-risk-audit-v1";

const COLLECTIONS = Object.freeze({
  riskSignal: "shared_risk_signals",
  riskAssessment: "shared_risk_assessments",
  caseCandidate: "shared_case_candidates",
  receipt: "shared_risk_persistence_receipts",
  auditEvent: "shared_risk_persistence_audit_events",
});

const TARGETS = Object.freeze({
  risk_signal: COLLECTIONS.riskSignal,
  risk_assessment: COLLECTIONS.riskAssessment,
  case_candidate: COLLECTIONS.caseCandidate,
});

const EXACT_PERMISSIONS = Object.freeze({
  risk_signal: "risk_signal.persist",
  risk_assessment: "risk_assessment.persist",
  case_candidate: "case_candidate.persist",
});

const ALLOWED_SOURCE_MODULES = Object.freeze([
  "digital_detective",
  "digital_market_monitoring",
  "monitoring",
  "risk_orchestration",
  "traceability",
]);

const IMMUTABLE_SUBJECT_FIELDS = Object.freeze([
  "tenantId",
  "subjectType",
  "subjectId",
  "sourceModule",
  "sourceRecordRef",
  "exactIdempotencyKey",
  "commandId",
  "subjectFingerprint",
  "fingerprintAlgorithm",
  "sourceExecutionId",
  "sourceTaskId",
  "sourceFindingId",
  "sourceTimestamps",
  "persistedAt",
  "persistedBy",
  "creationAuditLink",
]);

function deepFreeze(value) {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    for (const child of Object.values(value)) {
      deepFreeze(child);
    }
    Object.freeze(value);
  }
  return value;
}

function snapshot(value) {
  if (value === null || typeof value === "string" ||
      typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map(snapshot);
  }
  if (value && typeof value === "object") {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      result[key] = snapshot(value[key]);
    }
    return result;
  }
  throw new TypeError("Only JSON-compatible values are supported");
}

function immutableSnapshot(value) {
  return deepFreeze(snapshot(value));
}

function buildSubjectStorageDocumentV1(facts, persistedAtPlaceholder) {
  return immutableSnapshot({
    schemaVersion: STORAGE_SCHEMA_VERSION,
    tenantId: facts.resolvedIdentityScope.tenantId,
    brandId: facts.resolvedIdentityScope.brandId || null,
    subjectType: facts.subjectType,
    subjectId: facts.subjectId,
    contractVersion: facts.subjectContractVersion,
    canonicalSubjectPayload: facts.canonicalSubjectPayload,
    subjectFingerprint: facts.subjectFingerprint,
    fingerprintAlgorithm: facts.fingerprintAlgorithm,
    sourceModule: facts.sourceModule,
    exactIdempotencyKey: facts.exactIdempotencyBinding.canonicalKey,
    commandId: facts.commandId,
    readinessPolicyVersion: facts.readinessDecision.policyVersion,
    persistedByUid: facts.authenticatedActor.actorType === "user" ?
      facts.authenticatedActor.uid : null,
    persistedByService: facts.authenticatedActor.serviceIdentity || null,
    persistedAt: persistedAtPlaceholder,
    immutableProvenance: facts.provenance,
    sourceRecordRef: facts.sourceRecordRef,
    sourceRecordVersion: facts.sourceRecordVersion || null,
    sourceRecordUpdateTime: facts.sourceRecordUpdateTime || null,
  });
}

function buildReceiptStorageDocumentV1(plan, facts, createdAtPlaceholder) {
  return immutableSnapshot({
    schemaVersion: RECEIPT_SCHEMA_VERSION,
    receiptId: plan.receiptId,
    tenantId: plan.tenantId,
    targetNamespace: plan.targetNamespace,
    persistenceDocumentId: plan.persistenceDocumentId,
    subjectType: plan.subjectType,
    subjectId: plan.subjectId,
    commandId: plan.commandId,
    idempotencyCanonicalKey: plan.idempotencyCanonicalKey,
    subjectFingerprint: plan.subjectFingerprint,
    fingerprintAlgorithm: facts.fingerprintAlgorithm,
    outcome: plan.outcome,
    createdAt: createdAtPlaceholder,
    completedAt: null,
    sourceRecordVersion: facts.sourceRecordVersion || null,
    sourceRecordUpdateTime: facts.sourceRecordUpdateTime || null,
    immutableProvenanceSummary: facts.provenance,
  });
}

function buildAuditEventStorageDocumentV1({plan, facts,
  occurredAt, serverRecordedAt, correlationId = null}) {
  return immutableSnapshot({
    schemaVersion: AUDIT_SCHEMA_VERSION,
    tenantId: plan.tenantId,
    actorUid: facts.authenticatedActor.uid,
    serviceIdentity: facts.authenticatedActor.serviceIdentity || null,
    commandId: plan.commandId,
    subjectType: plan.subjectType,
    subjectId: plan.subjectId,
    target: plan.targetNamespace,
    eventType: plan.auditEventType,
    outcome: plan.outcome,
    blockerCodes: plan.blockers,
    warningCodes: plan.warnings,
    idempotencyKeyHash: createHash("sha256")
        .update(plan.idempotencyCanonicalKey, "utf8").digest("hex"),
    subjectFingerprint: plan.subjectFingerprint,
    occurredAt,
    serverRecordedAt,
    correlationId,
    immutableMetadata: facts.provenance,
  });
}

module.exports = {
  ALLOWED_SOURCE_MODULES,
  AUDIT_SCHEMA_VERSION,
  COLLECTIONS,
  EXACT_PERMISSIONS,
  IMMUTABLE_SUBJECT_FIELDS,
  RECEIPT_SCHEMA_VERSION,
  STORAGE_SCHEMA_VERSION,
  TARGETS,
  buildAuditEventStorageDocumentV1,
  buildReceiptStorageDocumentV1,
  buildSubjectStorageDocumentV1,
  immutableSnapshot,
};
