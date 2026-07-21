const {buildCreationAuditEventIdV1} = require("./document_id");
const {buildExecutionResultV1} = require("./persistence_execution_result");
const {assertPersistenceStorePortV1,
  validateAuthoritativeFactsForPortV1} = require("./persistence_store_port");
const {buildPlanV1, OPERATIONS, OUTCOMES} = require("./transaction_plan");
const {planPersistenceTransactionV1} = require("./transaction_planner");
const {buildAuditEventStorageDocumentV1,
  buildReceiptStorageDocumentV1, buildSubjectStorageDocumentV1,
  immutableSnapshot} = require("./storage_contracts");
const {creationAuditSnapshotV1, receiptSnapshotV1, subjectSnapshotV1,
  validateStorageIntegrityV1} = require("./storage_state_snapshots");

function nonWritePlan(facts, plannedAt, outcome, reasonCodes) {
  return buildPlanV1(facts, plannedAt, outcome,
      [OPERATIONS.noWrite, OPERATIONS.appendAuditEvent], reasonCodes);
}

function buildCreateDocumentsV1({facts, plan, creationAuditEventId,
  executedAt}) {
  const subject = buildSubjectStorageDocumentV1(facts, executedAt);
  const receipt = immutableSnapshot({
    ...buildReceiptStorageDocumentV1(plan, facts, executedAt),
    status: "completed",
    outcome: "created",
    completedAt: executedAt,
    creationAuditEventId,
    ...(plan.subjectType === "risk_signal" &&
      facts.provenance.contractVersion ===
        "shared-risk-promotion-command-v1" ?
      {auditEventId: creationAuditEventId} : {}),
  });
  const audit = immutableSnapshot({
    ...buildAuditEventStorageDocumentV1({
      plan,
      facts,
      occurredAt: executedAt,
      serverRecordedAt: executedAt,
      correlationId: facts.provenance.correlationId || null,
      auditEventId: creationAuditEventId,
    }),
    eventType: "persistence_created",
  });
  return Object.freeze({subject, receipt, audit});
}

function executeAtomicCreateDocumentsV1(transaction, references, documents) {
  transaction.create(references.subject, documents.subject);
  transaction.create(references.receipt, documents.receipt);
  transaction.create(references.audit, documents.audit);
}

async function executePersistenceTransactionV1({store, facts,
  sourceVersionStillCurrent, sourceRecordStillExists, plannedAt, executedAt,
  sourceRevalidation = null}) {
  const port = assertPersistenceStorePortV1(store);
  const creationAuditEventId = buildCreationAuditEventIdV1({
    receiptId: facts.receiptId,
    persistenceDocumentId: facts.persistenceDocumentId,
    commandId: facts.commandId,
  });
  const portBlockers = validateAuthoritativeFactsForPortV1(facts);
  if (portBlockers.length > 0) {
    const denied = nonWritePlan(facts, plannedAt, OUTCOMES.deny, portBlockers);
    return buildExecutionResultV1({facts, plan: denied,
      creationAuditEventId, transactionCommitted: false, executedAt});
  }
  const references = port.referencesFor({facts, creationAuditEventId});
  const transactionResult = await port.runTransaction(async (transaction) => {
    const readReferences = [references.receipt, references.subject,
      references.audit];
    if (sourceRevalidation) readReferences.push(sourceRevalidation.reference);
    const snapshots = await transaction.getAll(...readReferences);
    const receipt = receiptSnapshotV1(snapshots[0]);
    const subject = subjectSnapshotV1(snapshots[1]);
    const audit = creationAuditSnapshotV1(snapshots[2]);
    if (sourceRevalidation) {
      const source = snapshots[3];
      if (!source.exists) {
        return {plan: nonWritePlan(facts, plannedAt, OUTCOMES.deny,
            ["source.record_missing"]), committed: false};
      }
      const data = source.data() || {};
      if (typeof sourceRevalidation.validate === "function") {
        const sourceBlockers = sourceRevalidation.validate({source, data});
        if (Array.isArray(sourceBlockers) && sourceBlockers.length > 0) {
          return {plan: nonWritePlan(facts, plannedAt, OUTCOMES.conflict,
              sourceBlockers), committed: false};
        }
      } else {
        if (data.tenantId !== sourceRevalidation.tenantId) {
          return {plan: nonWritePlan(facts, plannedAt, OUTCOMES.conflict,
              ["source.tenant_changed"]), committed: false};
        }
        if ((data.brandId || null) !== (sourceRevalidation.brandId || null)) {
          return {plan: nonWritePlan(facts, plannedAt,
              OUTCOMES.recomputeRequired, ["source.brand_changed"]),
          committed: false};
        }
      }
      const updateTime = source.updateTime.toDate().toISOString();
      if (updateTime !== sourceRevalidation.updateTime) {
        return {plan: nonWritePlan(facts, plannedAt,
            OUTCOMES.recomputeRequired, ["source.version_changed"]),
        committed: false};
      }
    }
    const integrity = validateStorageIntegrityV1({
      facts, receipt, subject, audit, creationAuditEventId,
    });
    if (integrity.length > 0) {
      return {
        plan: nonWritePlan(facts, plannedAt, OUTCOMES.conflict, integrity),
        committed: false,
      };
    }
    const plan = planPersistenceTransactionV1({
      facts,
      existingReceipt: receipt,
      sourceVersionStillCurrent,
      sourceRecordStillExists,
      plannedAt,
    });
    if (plan.outcome !== OUTCOMES.create) {
      return {plan, committed: false};
    }
    const documents = buildCreateDocumentsV1({
      facts, plan, creationAuditEventId, executedAt,
    });
    executeAtomicCreateDocumentsV1(transaction, references, documents);
    return {plan, committed: true};
  });
  return buildExecutionResultV1({
    facts,
    plan: transactionResult.plan,
    creationAuditEventId,
    transactionCommitted: transactionResult.committed,
    executedAt,
  });
}

module.exports = {
  buildCreateDocumentsV1,
  executeAtomicCreateDocumentsV1,
  executePersistenceTransactionV1,
};
