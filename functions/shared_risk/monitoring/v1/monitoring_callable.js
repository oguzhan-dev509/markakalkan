const {createHash, randomUUID} = require("node:crypto");
const {defineString} = require("firebase-functions/params");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const {createFirestorePersistenceStoreV1} = require("../../persistence/v1");
const {createMonitoringEventAuthorityPortV1,
  createMonitoringSignalAuthorityPortV1,
  createPlatformAdminAuthorityPortV1} = require("./monitoring_authority_ports");
const {MonitoringPersistenceErrorV1} = require("./monitoring_contracts");
const {createMonitoringRiskPersistenceApplicationServiceV1} = require(
    "./monitoring_persistence_service");
const {evaluateMonitoringRolloutPolicyV1,
  parseAllowedSignalIds} = require("./monitoring_rollout_policy");

const CALLABLE_NAME = "persistMonitoringRiskSignalPilot";
const EXPECTED_PROJECT_ID = "markakalkan-app";
const rolloutMode = defineString("MONITORING_RISK_ROLLOUT_MODE", {
  default: "dry_run_only",
});
const rolloutSignalIds = defineString("MONITORING_RISK_ALLOWED_SIGNAL_IDS", {
  default: "",
});

function opaque(value) {
  if (!value) return null;
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function sanitizedResult(result, policy) {
  return Object.freeze({outcome: result.outcome, dryRun: result.dryRun,
    monitoringSignalId: result.monitoringSignalId,
    subjectId: result.subjectId, persistenceDocumentId:
      result.persistenceDocumentId, receiptId: result.receiptId,
    creationAuditEventId: result.creationAuditEventId,
    transactionCommitted: result.transactionCommitted,
    blockerCodes: result.blockers, warningCodes: result.warnings,
    correlationId: result.correlationId,
    policyVersion: policy.policyVersion, rolloutMode: policy.mode});
}

function applicationError(result) {
  if (result.blockers.includes("authorization.denied")) {
    return new HttpsError("permission-denied", "Islem yetkisi bulunamadi.");
  }
  if (result.outcome === "conflict") {
    return new HttpsError("aborted", "Kaynak kapsaminda cakisma olustu.");
  }
  if (result.outcome === "recompute_required") {
    return new HttpsError("aborted", "Kaynak degisti; yeniden deneyin.");
  }
  return new HttpsError("failed-precondition", "Persistence hazir degil.");
}

function createMonitoringCallableHandlerV1({db, policyProvider,
  projectIdProvider, clock, log = logger}) {
  const service = createMonitoringRiskPersistenceApplicationServiceV1({
    adminAuthority: createPlatformAdminAuthorityPortV1(db),
    signalAuthority: createMonitoringSignalAuthorityPortV1(db),
    eventAuthority: createMonitoringEventAuthorityPortV1(db),
    clock, persistenceStore: createFirestorePersistenceStoreV1(db),
  });
  return async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Oturum acmaniz gerekir.");
    }
    const receivedAt = clock.now();
    let internalRequest;
    try {
      internalRequest = require("./monitoring_contracts")
          .monitoringRiskPersistenceRequestV1(request.data);
    } catch (error) {
      if (error instanceof MonitoringPersistenceErrorV1) {
        throw new HttpsError("invalid-argument", "Gecersiz istek.");
      }
      throw error;
    }
    const config = policyProvider();
    const policy = evaluateMonitoringRolloutPolicyV1({
      ...config, monitoringSignalId: internalRequest.monitoringSignalId,
      dryRun: internalRequest.dryRun, projectId: projectIdProvider(),
      expectedProjectId: config.expectedProjectId || EXPECTED_PROJECT_ID,
      evaluatedAt: receivedAt,
    });
    if (!policy.allowed) {
      throw new HttpsError("failed-precondition", "Pilot kullanima kapali.");
    }
    const correlationId = internalRequest.correlationId || randomUUID();
    const result = await service.execute({...internalRequest, correlationId}, {
      authenticatedUid: request.auth.uid,
      authenticationType: "firebase_auth",
      invocationId: request.rawRequest && request.rawRequest.get ?
        request.rawRequest.get("function-execution-id") || correlationId :
        correlationId,
      receivedAt, correlationId,
      metadata: {callableName: CALLABLE_NAME},
    });
    const safe = sanitizedResult(result, policy);
    log.info("Monitoring risk persistence pilot evaluated", {
      event: "monitoring_risk_persistence_pilot", callableName: CALLABLE_NAME,
      outcome: safe.outcome, actorHash: opaque(request.auth.uid),
      tenantHash: opaque(result.tenantId),
      monitoringSignalId: safe.monitoringSignalId,
      commandId: result.commandId,
      persistenceDocumentId: safe.persistenceDocumentId,
      receiptId: safe.receiptId, rolloutMode: safe.rolloutMode,
      dryRun: safe.dryRun, transactionCommitted: safe.transactionCommitted,
      blockerCodes: safe.blockerCodes, warningCodes: safe.warningCodes,
      correlationId: safe.correlationId, serverTimestamp: receivedAt,
    });
    if (["denied", "conflict", "recompute_required"].includes(result.outcome)) {
      throw applicationError(result);
    }
    return safe;
  };
}

function buildPersistMonitoringRiskSignalPilot({db}) {
  const clock = Object.freeze({now: () => new Date().toISOString()});
  const handler = createMonitoringCallableHandlerV1({db, clock,
    projectIdProvider: () => process.env.GCLOUD_PROJECT || "",
    policyProvider: () => ({mode: rolloutMode.value(),
      allowedSignalIds: parseAllowedSignalIds(rolloutSignalIds.value())}),
  });
  return onCall({region: "europe-west3", enforceAppCheck: true,
    maxInstances: 1}, handler);
}

module.exports = {CALLABLE_NAME, EXPECTED_PROJECT_ID,
  buildPersistMonitoringRiskSignalPilot,
  createMonitoringCallableHandlerV1, sanitizedResult};
