/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {defineString} = require("firebase-functions/params");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {createFirestorePersistenceStoreV1} = require("../../persistence/v1");
const {CALLABLE_NAME, PromotionError, promotionRequestV1} = require("./contracts");
const {evaluateRolloutV1, parseAllowlist} = require("./rollout_policy");
const {createPromotionServiceV1} = require("./service");

const EXPECTED_PROJECT_ID = "markakalkan-app";
const rolloutMode = defineString("SHARED_RISK_PROMOTION_ROLLOUT_MODE",
    {default: "dry_run_only"});
const rolloutAllowlist = defineString("SHARED_RISK_PROMOTION_ALLOWLIST",
    {default: ""});
const opaque = (value) => createHash("sha256").update(value)
    .digest("hex").slice(0, 16);

function errorFor(error) {
  if (error.code === "auth.required") {
    return new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  }
  if (error.code === "source.not_found") {
    return new HttpsError("not-found", "Kaynak kayıt bulunamadı.");
  }
  if (["authorization.denied", "source.denied"].includes(error.code)) {
    return new HttpsError("permission-denied", "İşlem yetkisi bulunamadı.");
  }
  return new HttpsError("invalid-argument", "Geçersiz istek.");
}

function createPromotionCallableHandlerV1({db, clock, projectIdProvider,
  policyProvider, log = logger}) {
  const service = createPromotionServiceV1({db, clock, projectIdProvider,
    persistenceStore: createFirestorePersistenceStoreV1(db)});
  return async (invocation) => {
    if (!invocation.auth || !invocation.auth.uid) {
      throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    }
    let request;
    try {
      request = promotionRequestV1(invocation.data);
    } catch (error) {
      if (error instanceof PromotionError) throw errorFor(error);
      throw error;
    }
    const appCheckPresent = Boolean(invocation.app?.appId);
    if (!request.dryRun && !appCheckPresent) {
      throw new HttpsError("failed-precondition",
          "Uygulama doğrulaması gerekli.");
    }
    const policy = evaluateRolloutV1({...policyProvider(), request,
      projectId: projectIdProvider(), expectedProjectId: EXPECTED_PROJECT_ID});
    const logBase = {callableName: CALLABLE_NAME,
      correlationHash: opaque(request.correlationId),
      sourceIdentityHash: opaque(`${request.sourceSystem}:${request.sourceRecordId}`),
      dryRun: request.dryRun, rolloutMode: policy.mode,
      appCheckPresent, appCheckRequired: !request.dryRun,
      contractVersion: "shared-risk-promotion-command-v1"};
    log.info("Shared risk promotion started", {event:
      "shared_risk_promotion_started", ...logBase});
    if (!policy.allowed) {
      const blocked = {outcome: "blocked", blockerCodes: policy.reasons,
        dryRun: request.dryRun, rolloutMode: policy.mode,
        transactionCommitted: false, writeAttempted: false};
      log.info("Shared risk promotion blocked", {event:
        "shared_risk_promotion_blocked", ...logBase, ...blocked});
      return blocked;
    }
    let result;
    try {
      result = await service.execute(request, {uid: invocation.auth.uid});
    } catch (error) {
      if (error instanceof PromotionError) throw errorFor(error);
      throw error;
    }
    const safe = {...result, rolloutMode: policy.mode};
    log.info("Shared risk promotion evaluated", {event:
      result.outcome === "conflict" ? "shared_risk_promotion_conflict" :
        "shared_risk_promotion_completed", ...logBase,
    outcome: result.outcome,
    transactionCommitted: result.transactionCommitted,
    writeAttempted: result.writeAttempted,
    blockerCodes: result.blockers});
    return safe;
  };
}

function buildPromoteRiskOperationToSharedRisk({db}) {
  const clock = {now: () => new Date().toISOString()};
  return onCall({region: "europe-west3", enforceAppCheck: false,
    maxInstances: 1}, createPromotionCallableHandlerV1({db, clock,
    projectIdProvider: () => process.env.GCLOUD_PROJECT || "",
    policyProvider: () => ({mode: rolloutMode.value(),
      allowlist: parseAllowlist(rolloutAllowlist.value())})}));
}
module.exports = {EXPECTED_PROJECT_ID, buildPromoteRiskOperationToSharedRisk,
  createPromotionCallableHandlerV1};
