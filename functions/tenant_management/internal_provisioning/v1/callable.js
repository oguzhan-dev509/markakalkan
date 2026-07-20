/* eslint-disable max-len */
const {createHash, randomUUID} = require("node:crypto");
const {defineString} = require("firebase-functions/params");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {PRODUCTION_PROJECT_ID, createInternalTenantBrandProvisioningServiceV1,
  CALLABLE_EMULATOR_PROJECT_ID, provisioningRequestV1} = require("./index");
const {evaluateProvisioningRolloutPolicyV1,
  parseAllowedPilotCodes} = require("./rollout_policy");

const CALLABLE_NAME = "provisionInternalTenantBrandPilot";
const CALLABLE_OPTIONS = Object.freeze({region: "europe-west3",
  enforceAppCheck: true, maxInstances: 1});
const rolloutMode = defineString("INTERNAL_PROVISIONING_ROLLOUT_MODE",
    {default: "dry_run_only"});
const rolloutCodes = defineString("INTERNAL_PROVISIONING_ALLOWED_PILOT_CODES",
    {default: ""});
const opaque = (value) => createHash("sha256").update(value)
    .digest("hex").slice(0, 16);

function sanitizedResult(result, policy, pilotCode, correlationId) {
  return Object.freeze({outcome: result.outcome, dryRun: result.dryRun,
    pilotCode, tenantId: result.tenantId || null,
    brandId: result.brandId || null, membershipId: result.membershipId || null,
    receiptId: result.receiptId || null, auditEventId: result.auditId || null,
    transactionCommitted: result.transactionCommitted === true,
    blockerCodes: result.blockerCodes || [], warningCodes: [],
    policyVersion: policy.policyVersion, rolloutMode: policy.mode,
    correlationId});
}

function createProvisioningCallableHandlerV1({db, clock, policyProvider,
  projectIdProvider, log = logger}) {
  const service = createInternalTenantBrandProvisioningServiceV1({db, clock});
  return async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Oturum acmaniz gerekir.");
    }
    if (!request.app || !request.app.appId) {
      throw new HttpsError("unauthenticated", "App Check dogrulamasi gerekir.");
    }
    log.info("Internal provisioning application handler invoked", {
      event: "internal_tenant_brand_provisioning_application_invoked",
      callableName: CALLABLE_NAME,
    });
    let input;
    try {
      input = provisioningRequestV1(request.data);
    } catch (_) {
      throw new HttpsError("invalid-argument", "Gecersiz istek.");
    }
    const receivedAt = clock.now();
    const config = policyProvider();
    const policy = evaluateProvisioningRolloutPolicyV1({...config,
      pilotCode: input.pilotCode, dryRun: input.dryRun,
      projectId: projectIdProvider(), evaluatedAt: receivedAt});
    if (!policy.allowed) {
      throw new HttpsError("failed-precondition", "Pilot kullanima kapali.");
    }
    const correlationId = input.correlationId || randomUUID();
    const result = await service.execute({...input, correlationId}, {
      authenticatedUid: request.auth.uid, projectId: projectIdProvider(),
      receivedAt});
    if (result.outcome === "denied") {
      throw new HttpsError("permission-denied", "Islem yetkisi bulunamadi.");
    }
    if (result.outcome === "conflict") {
      throw new HttpsError("already-exists", "Provisioning cakismasi.");
    }
    const safe = sanitizedResult(result, policy, input.pilotCode, correlationId);
    log.info("Internal tenant brand provisioning pilot evaluated", {
      event: "internal_tenant_brand_provisioning_pilot",
      callableName: CALLABLE_NAME, outcome: safe.outcome,
      actorHash: opaque(request.auth.uid), dryRun: safe.dryRun,
      rolloutMode: safe.rolloutMode, policyVersion: safe.policyVersion,
      pilotCode: safe.pilotCode, tenantId: safe.tenantId,
      brandId: safe.brandId, membershipId: safe.membershipId,
      receiptId: safe.receiptId, auditEventId: safe.auditEventId,
      transactionCommitted: safe.transactionCommitted,
      blockerCodes: safe.blockerCodes, correlationHash: opaque(correlationId),
      serverTimestamp: receivedAt});
    return safe;
  };
}

function buildProvisionInternalTenantBrandPilot({db}) {
  const clock = Object.freeze({now: () => new Date().toISOString()});
  return onCall(CALLABLE_OPTIONS, createProvisioningCallableHandlerV1({db, clock,
    projectIdProvider: () => process.env.GCLOUD_PROJECT || "",
    policyProvider: () => ({mode: rolloutMode.value(),
      allowedPilotCodes: parseAllowedPilotCodes(rolloutCodes.value()),
      expectedProjectId: process.env.FUNCTIONS_EMULATOR === "true" ?
        CALLABLE_EMULATOR_PROJECT_ID : PRODUCTION_PROJECT_ID})}));
}

module.exports = {CALLABLE_NAME, CALLABLE_OPTIONS,
  buildProvisionInternalTenantBrandPilot,
  createProvisioningCallableHandlerV1, sanitizedResult};
