const {OPERATIONS, OUTCOMES, buildPlanV1} = require("./transaction_plan");

function mismatchCodes(facts, receipt) {
  const checks = [
    ["receipt.id_mismatch", receipt.receiptId, facts.receiptId],
    ["receipt.tenant_mismatch", receipt.tenantId,
      facts.resolvedIdentityScope.tenantId],
    ["receipt.target_mismatch", receipt.targetNamespace,
      facts.targetNamespace],
    ["receipt.subject_type_mismatch", receipt.subjectType,
      facts.subjectType],
    ["receipt.subject_id_mismatch", receipt.subjectId, facts.subjectId],
    ["receipt.command_mismatch", receipt.commandId, facts.commandId],
    ["receipt.idempotency_mismatch", receipt.idempotencyCanonicalKey,
      facts.exactIdempotencyBinding.canonicalKey],
    ["receipt.fingerprint_mismatch", receipt.subjectFingerprint,
      facts.subjectFingerprint],
    ["receipt.document_id_mismatch", receipt.persistenceDocumentId,
      facts.persistenceDocumentId],
  ];
  return checks.filter((entry) => entry[1] !== entry[2])
      .map((entry) => entry[0]);
}

function planPersistenceTransactionV1({facts, existingReceipt,
  sourceVersionStillCurrent, sourceRecordStillExists, plannedAt}) {
  if (typeof plannedAt !== "string" || plannedAt.length === 0) {
    throw new TypeError("plannedAt is required");
  }
  if (!sourceRecordStillExists) {
    return buildPlanV1(facts, plannedAt, OUTCOMES.deny,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        ["source.record_missing"]);
  }
  if (facts.validationBlockers.length > 0) {
    return buildPlanV1(facts, plannedAt, OUTCOMES.deny,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        facts.validationBlockers);
  }
  if (sourceVersionStillCurrent !== true) {
    return buildPlanV1(facts, plannedAt, OUTCOMES.recomputeRequired,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        [sourceVersionStillCurrent === false ?
          "source.version_changed" : "source.version_unavailable"]);
  }
  if (existingReceipt.status === "absent") {
    return buildPlanV1(facts, plannedAt, OUTCOMES.create, [
      OPERATIONS.createSubject,
      OPERATIONS.createReceipt,
      OPERATIONS.completeReceipt,
      OPERATIONS.appendAuditEvent,
    ], ["receipt.absent"]);
  }
  const conflicts = mismatchCodes(facts, existingReceipt);
  if (conflicts.length > 0 || existingReceipt.status === "conflicted") {
    return buildPlanV1(facts, plannedAt, OUTCOMES.conflict,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        conflicts.length > 0 ? conflicts : ["receipt.already_conflicted"]);
  }
  if (existingReceipt.status === "completed") {
    return buildPlanV1(facts, plannedAt, OUTCOMES.idempotentSuccess,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        ["receipt.integrity_match"]);
  }
  if (existingReceipt.status === "pending") {
    return buildPlanV1(facts, plannedAt, OUTCOMES.deny,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        ["receipt.pending_controlled_resume_required"]);
  }
  if (existingReceipt.retryable === true) {
    return buildPlanV1(facts, plannedAt, OUTCOMES.recomputeRequired,
        [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
        ["receipt.failed_retry_revalidation_required"]);
  }
  return buildPlanV1(facts, plannedAt, OUTCOMES.deny,
      [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent],
      ["receipt.failed_non_retryable"]);
}

module.exports = {planPersistenceTransactionV1};
