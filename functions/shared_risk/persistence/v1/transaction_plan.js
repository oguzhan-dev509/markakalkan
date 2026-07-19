const OUTCOMES = Object.freeze({
  create: "create",
  idempotentSuccess: "idempotent_success",
  conflict: "conflict",
  deny: "deny",
  recomputeRequired: "recompute_required",
});

const OPERATIONS = Object.freeze({
  createSubject: "create_subject",
  createReceipt: "create_receipt",
  completeReceipt: "complete_receipt",
  appendAuditEvent: "append_audit_event",
  noWrite: "no_write",
  markConflict: "mark_conflict",
  markFailed: "mark_failed",
});

const RECEIPT_STATUSES = Object.freeze([
  "absent", "completed", "pending", "failed", "conflicted",
]);

function existingPersistenceReceiptSnapshotV1(input = {status: "absent"}) {
  if (!RECEIPT_STATUSES.includes(input.status)) {
    throw new TypeError("receipt status is unsupported");
  }
  if (input.status === "absent") return Object.freeze({status: "absent"});
  const required = ["receiptId", "tenantId", "targetNamespace",
    "subjectType", "subjectId", "commandId", "idempotencyCanonicalKey",
    "subjectFingerprint", "persistenceDocumentId"];
  for (const field of required) {
    if (typeof input[field] !== "string" || input[field].length === 0) {
      throw new TypeError(`receipt ${field} is required`);
    }
  }
  return Object.freeze({...input});
}

function buildPlanV1(facts, plannedAt, outcome, operations, reasonCodes) {
  const blockers = outcome === OUTCOMES.create ||
    outcome === OUTCOMES.idempotentSuccess ? [] : reasonCodes;
  return Object.freeze({
    contractVersion: "persistence-transaction-plan-v1",
    outcome,
    executable: outcome === OUTCOMES.create,
    persistenceDocumentId: facts.persistenceDocumentId,
    receiptId: facts.receiptId,
    subjectType: facts.subjectType,
    subjectId: facts.subjectId,
    targetNamespace: facts.targetNamespace,
    tenantId: facts.resolvedIdentityScope.tenantId,
    commandId: facts.commandId,
    idempotencyCanonicalKey: facts.exactIdempotencyBinding.canonicalKey,
    subjectFingerprint: facts.subjectFingerprint,
    operations: Object.freeze([...operations]),
    blockers: Object.freeze([...blockers].sort()),
    warnings: Object.freeze([]),
    auditEventType: `persistence_${outcome}`,
    reasonCodes: Object.freeze([...reasonCodes].sort()),
    plannedAt,
    provenance: facts.provenance,
  });
}

module.exports = {
  OPERATIONS,
  OUTCOMES,
  buildPlanV1,
  existingPersistenceReceiptSnapshotV1,
};
