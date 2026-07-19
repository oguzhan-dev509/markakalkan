const {executePersistenceTransactionV1} = require(
    "../../persistence/v1/persistence_transaction_executor");
const {buildCreationAuditEventIdV1} = require(
    "../../persistence/v1/document_id");
const {monitoringApplicationResultV1} = require(
    "./monitoring_application_result");
const {monitoringRiskPersistenceRequestV1,
  MonitoringPersistenceErrorV1,
  verifiedServerInvocationContextV1} = require("./monitoring_contracts");
const {assembleMonitoringServerPersistenceFactsV1} = require(
    "./monitoring_facts_assembler");

function createMonitoringRiskPersistenceApplicationServiceV1({
  adminAuthority, signalAuthority, eventAuthority, clock, persistenceStore,
}) {
  return Object.freeze({async execute(rawRequest, invocation) {
    const request = monitoringRiskPersistenceRequestV1(rawRequest);
    const evaluationTime = clock.now();
    let facts;
    try {
      const verifiedInvocation = verifiedServerInvocationContextV1(invocation);
      const [adminSnapshot, signalSnapshot] = await Promise.all([
        adminAuthority.load(verifiedInvocation.authenticatedUid),
        signalAuthority.load(request.monitoringSignalId),
      ]);
      const hasEvent = signalSnapshot.exists && signalSnapshot.data.eventId;
      const eventSnapshot = hasEvent ?
        await eventAuthority.load(signalSnapshot.data.eventId) :
        {exists: false};
      facts = assembleMonitoringServerPersistenceFactsV1({
        invocation: verifiedInvocation,
        adminSnapshot, signalSnapshot, eventSnapshot, evaluationTime,
        correlationId: request.correlationId});
      if (request.dryRun) {
        const creationAuditEventId = buildCreationAuditEventIdV1({
          receiptId: facts.receiptId,
          persistenceDocumentId: facts.persistenceDocumentId,
          commandId: facts.commandId,
        });
        return monitoringApplicationResultV1({outcome: "dry_run_ready",
          request, facts, warnings: facts.readinessDecision.warnings,
          evaluatedAt: evaluationTime, creationAuditEventId});
      }
      const executedAt = clock.now();
      const execution = await executePersistenceTransactionV1({
        store: persistenceStore, facts, sourceVersionStillCurrent: true,
        sourceRecordStillExists: true, plannedAt: evaluationTime, executedAt,
        sourceRevalidation: {
          reference: signalAuthority.reference(request.monitoringSignalId),
          updateTime: facts.sourceRecordUpdateTime,
          tenantId: facts.resolvedIdentityScope.tenantId,
          brandId: facts.resolvedIdentityScope.brandId,
        },
      });
      return monitoringApplicationResultV1({outcome: execution.outcome,
        request, facts, execution, blockers: execution.blockers,
        warnings: execution.warnings, evaluatedAt: evaluationTime, executedAt});
    } catch (error) {
      if (!(error instanceof MonitoringPersistenceErrorV1)) throw error;
      return monitoringApplicationResultV1({outcome: "denied", request,
        facts, blockers: [error.code], evaluatedAt: evaluationTime});
    }
  }});
}

module.exports = {createMonitoringRiskPersistenceApplicationServiceV1};
