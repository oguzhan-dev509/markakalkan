const {encodeParts} = require("../../persistence/v1/document_id");
const {buildServerPersistenceFactsV1} = require(
    "../../persistence/v1/server_persistence_facts");
const {MonitoringPersistenceErrorV1} = require("./monitoring_contracts");
const {evaluateMonitoringPersistencePermissionV1} = require(
    "./monitoring_permission_policy");
const {evaluateMonitoringReadinessV1} = require("./monitoring_readiness");
const {adaptMonitoringRiskSignalV1} = require("./monitoring_server_adapter");

function exactKey(signalId) {
  const parts = ["source-ingestion-key-v1", "digital_market_monitoring",
    "monitoring_signal", "exactOccurrence", signalId];
  return Object.freeze({purpose: "exact_source_occurrence",
    canonicalKey: encodeParts(parts), sourceModule: "digital_market_monitoring",
    sourceType: "monitoring_signal", signalId});
}

function assembleMonitoringServerPersistenceFactsV1({invocation, adminSnapshot,
  signalSnapshot, eventSnapshot, evaluationTime, correlationId}) {
  const permission = evaluateMonitoringPersistencePermissionV1({adminSnapshot,
    requestedPermission: "risk_signal.persist", evaluationTime});
  if (!permission.granted) {
    throw new MonitoringPersistenceErrorV1(
        "authorization.denied", "Active super admin is required");
  }
  if (!signalSnapshot.exists) {
    throw new MonitoringPersistenceErrorV1(
        "source.not_found", "Monitoring signal not found");
  }
  const signal = signalSnapshot.data;
  if (!signal.tenantId || !signal.brandId) {
    throw new MonitoringPersistenceErrorV1(
        "source.identity_missing", "Monitoring tenant and brand are required");
  }
  if (!eventSnapshot || !eventSnapshot.exists) {
    throw new MonitoringPersistenceErrorV1(
        "source.event_missing", "Monitoring event not found");
  }
  let subject;
  try {
    subject = adaptMonitoringRiskSignalV1({signalId: signalSnapshot.id,
      signal, event: eventSnapshot.data, adaptedAt: evaluationTime});
  } catch (error) {
    throw new MonitoringPersistenceErrorV1("adapter.invalid", error.message);
  }
  const binding = exactKey(signalSnapshot.id);
  const readiness = evaluateMonitoringReadinessV1({subject,
    exactKey: binding, evaluatedAt: evaluationTime});
  if (!readiness.allowed) {
    throw new MonitoringPersistenceErrorV1(
        "readiness.denied", readiness.blockers.join(","));
  }
  const facts = buildServerPersistenceFactsV1({authoritativeInput: {
    authenticatedActor: {uid: invocation.authenticatedUid,
      actorType: "user"},
    resolvedIdentityScope: {tenantId: signal.tenantId,
      brandId: signal.brandId},
    grantedPermissions: permission.derivedExactPermissions,
    subjectType: "risk_signal", subjectId: subject.signalId,
    subjectContractVersion: subject.contractVersion,
    canonicalSubjectPayload: subject,
    exactIdempotencyBinding: binding,
    sourceModule: "digital_market_monitoring",
    sourceRecordRef: signalSnapshot.documentPath,
    sourceRecordUpdateTime: signalSnapshot.updateTime,
    readinessDecision: readiness,
    serverEvaluationTime: evaluationTime,
    commandRequestedAt: invocation.receivedAt,
    provenance: {requestedByModule: "digital_market_monitoring",
      sourceRecordId: signalSnapshot.id, correlationId: correlationId ||
        invocation.correlationId || invocation.invocationId},
  }});
  if (facts.validationBlockers.length > 0) {
    throw new MonitoringPersistenceErrorV1(
        "facts.invalid", facts.validationBlockers.join(","));
  }
  return facts;
}

module.exports = {assembleMonitoringServerPersistenceFactsV1, exactKey};
