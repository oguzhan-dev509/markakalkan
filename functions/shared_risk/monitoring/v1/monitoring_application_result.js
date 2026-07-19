const {immutableSnapshot} = require("../../persistence/v1/storage_contracts");

function monitoringApplicationResultV1({
  outcome, request, facts = null, execution = null, blockers = [],
  warnings = [], evaluatedAt, executedAt = null,
  creationAuditEventId = null,
}) {
  return immutableSnapshot({
    contractVersion: "monitoring-risk-persistence-result-v1",
    outcome, monitoringSignalId: request.monitoringSignalId,
    tenantId: facts ? facts.resolvedIdentityScope.tenantId : null,
    brandId: facts ? facts.resolvedIdentityScope.brandId : null,
    subjectId: facts ? facts.subjectId : null,
    persistenceDocumentId: facts ? facts.persistenceDocumentId : null,
    receiptId: facts ? facts.receiptId : null,
    creationAuditEventId: execution ? execution.creationAuditEventId :
      creationAuditEventId,
    commandId: facts ? facts.commandId : null,
    subjectFingerprint: facts ? facts.subjectFingerprint : null,
    sourceRecordVersion: facts ? facts.sourceRecordVersion : null,
    sourceRecordUpdateTime: facts ? facts.sourceRecordUpdateTime : null,
    blockers, warnings, transactionCommitted: execution ?
      execution.transactionCommitted : false,
    dryRun: request.dryRun, evaluatedAt, executedAt,
    correlationId: request.correlationId,
    provenance: facts ? facts.provenance : {}});
}

module.exports = {monitoringApplicationResultV1};
