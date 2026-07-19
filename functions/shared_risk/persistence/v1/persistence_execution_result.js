const {immutableSnapshot} = require("./storage_contracts");

function buildExecutionResultV1({facts, plan, creationAuditEventId,
  transactionCommitted, executedAt}) {
  const outcomes = {
    create: "created",
    idempotent_success: "idempotent_success",
    conflict: "conflict",
    deny: "denied",
    recompute_required: "recompute_required",
  };
  return immutableSnapshot({
    contractVersion: "persistence-execution-result-v1",
    outcome: outcomes[plan.outcome],
    executable: plan.executable,
    transactionCommitted,
    subjectType: facts.subjectType,
    subjectId: facts.subjectId,
    persistenceDocumentId: facts.persistenceDocumentId,
    receiptId: facts.receiptId,
    creationAuditEventId,
    commandId: facts.commandId,
    idempotencyCanonicalKey: facts.exactIdempotencyBinding.canonicalKey,
    subjectFingerprint: facts.subjectFingerprint,
    blockers: plan.blockers,
    warnings: plan.warnings,
    operationResults: plan.operations,
    executedAt,
    provenance: facts.provenance,
  });
}

module.exports = {buildExecutionResultV1};
