/* eslint-disable max-len */
"use strict";

const crypto = require("crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const CONTRACT_VERSION = "ai-field-operation-authority-v1";
const SERVICE_CODE = "ai_field_operation_twelve_agent";
const PERMISSION = "create_operation";
const CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 3,
  timeoutSeconds: 60,
});
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PRIORITIES = new Set(["low", "normal", "high", "critical"]);
const AGENTS = Object.freeze([
  ["task_planner", "Görev Planlama Ajanı"],
  ["digital_field_scanner", "Dijital Saha Tarama Ajanı"],
  ["page_change_monitor", "Sayfa Değişim İzleme Ajanı"],
  ["visual_matcher", "Görsel Eşleştirme Ajanı"],
  ["text_language_analyzer", "Metin ve Dil Analizi Ajanı"],
  ["seller_entity_linker", "Satıcı ve Varlık Eşleştirme Ajanı"],
  ["domain_technical_trace", "Alan Adı ve Teknik İz Ajanı"],
  ["price_commercial_pattern", "Fiyat ve Ticari Örüntü Ajanı"],
  ["geographic_channel_analyzer", "Coğrafi ve Kanal Analizi Ajanı"],
  ["evidence_validator", "Delil Doğrulama Ajanı"],
  ["risk_prioritizer", "Risk Önceliklendirme Ajanı"],
  ["reporting_intervention_preparer", "Raporlama ve Müdahale Hazırlama Ajanı"],
]);

function clean(value, maximum) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

function fail(code, message) {
  throw new HttpsError(code, message);
}

function assertRequest(request) {
  if (!request?.auth?.uid) fail("unauthenticated", "Oturum açmanız gerekir.");
  if (!request?.app?.appId) fail("failed-precondition", "Uygulama doğrulaması gerekir.");
  return request.auth.uid;
}

function millis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number.NaN;
}

function evaluateReadiness({brand, entitlement, nowMillis}) {
  const verifiedBrand = Boolean(brand) && clean(brand.status, 40).toLowerCase() === "active";
  const permissions = Array.isArray(entitlement?.permissions) ? entitlement.permissions : [];
  const starts = millis(entitlement?.validFrom);
  const ends = millis(entitlement?.validUntil);
  const timeValid = Number.isFinite(starts) && Number.isFinite(ends) && starts <= nowMillis && nowMillis < ends;
  const serviceAccess = entitlement?.serviceCode === SERVICE_CODE && entitlement?.status === "active" && timeValid;
  const operationAuthority = serviceAccess && entitlement?.operationCreationAuthorized === true && permissions.includes(PERMISSION);
  const reasons = [];
  if (!verifiedBrand) reasons.push("verified_brand_required");
  if (!serviceAccess) reasons.push("active_service_entitlement_required");
  if (!operationAuthority) reasons.push("operation_create_authority_required");
  return Object.freeze({
    verifiedBrand,
    serviceAccess,
    operationAuthority,
    ready: verifiedBrand && serviceAccess && operationAuthority,
    reasons: Object.freeze(reasons),
  });
}

function normalizeInput(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) fail("invalid-argument", "İstek verisi geçersiz.");
  const allowed = new Set(["contractVersion", "requestId", "idempotencyKey", "title", "objective", "priority", "initialInput"]);
  const unsupported = Object.keys(raw).filter((key) => !allowed.has(key));
  if (unsupported.length) fail("invalid-argument", "Desteklenmeyen istek alanı var.");
  if (raw.contractVersion !== CONTRACT_VERSION) fail("invalid-argument", "Sözleşme sürümü geçersiz.");
  const requestId = clean(raw.requestId, 64);
  if (!UUID.test(requestId)) fail("invalid-argument", "İstek kimliği geçersiz.");
  const idempotencyKey = clean(raw.idempotencyKey, 160);
  if (idempotencyKey !== `ai-field-operation:${requestId}`) fail("invalid-argument", "Idempotency anahtarı geçersiz.");
  const title = clean(raw.title, 180);
  const objective = clean(raw.objective, 2000);
  const priority = clean(raw.priority, 40).toLowerCase();
  if (title.length < 2) fail("invalid-argument", "Operasyon başlığı zorunludur.");
  if (objective.length < 3) fail("invalid-argument", "Operasyon amacı zorunludur.");
  if (!PRIORITIES.has(priority)) fail("invalid-argument", "Operasyon önceliği geçersiz.");
  const initial = raw.initialInput;
  if (!initial || typeof initial !== "object" || Array.isArray(initial)) fail("invalid-argument", "Başlangıç verileri geçersiz.");
  const inputAllowed = new Set(["brandName", "productName", "sellerName", "targetUrl", "requestedAgentCount"]);
  if (Object.keys(initial).some((key) => !inputAllowed.has(key))) fail("invalid-argument", "Desteklenmeyen başlangıç alanı var.");
  const productName = clean(initial.productName, 240);
  const sellerName = clean(initial.sellerName, 500);
  const targetUrl = clean(initial.targetUrl, 2000);
  if (!productName && !sellerName && !targetUrl) fail("invalid-argument", "En az bir somut hedef girilmelidir.");
  if (targetUrl) {
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch {
      fail("invalid-argument", "Hedef URL geçersiz.");
    }
    if (!parsed || !["http:", "https:"].includes(parsed.protocol)) fail("invalid-argument", "Hedef URL geçersiz.");
  }
  return Object.freeze({requestId, idempotencyKey, title, objective, priority, productName, sellerName, targetUrl});
}

function fingerprint(command) {
  return crypto.createHash("sha256").update(JSON.stringify(command)).digest("hex");
}

function operationId(uid, requestId) {
  return `afo_${crypto.createHash("sha256").update(`${uid}:${requestId}`).digest("hex").slice(0, 32)}`;
}

function refs(db, uid, id) {
  const brand = db.collection("brands").doc(uid);
  return {
    brand,
    entitlement: brand.collection("serviceEntitlements").doc(SERVICE_CODE),
    operation: brand.collection("aiFieldOperations").doc(id),
    receipt: brand.collection("aiFieldOperationCommandReceipts").doc(id),
  };
}

async function readinessData({db, uid, nowMillis = Date.now()}) {
  const target = refs(db, uid, "unused");
  const [brandSnap, entitlementSnap] = await db.getAll(target.brand, target.entitlement);
  const brand = brandSnap.exists ? brandSnap.data() || {} : null;
  const entitlement = entitlementSnap.exists ? entitlementSnap.data() || {} : null;
  const gates = evaluateReadiness({brand, entitlement, nowMillis});
  return Object.freeze({
    contractVersion: CONTRACT_VERSION,
    serviceCode: SERVICE_CODE,
    brand: gates.verifiedBrand ? Object.freeze({brandUid: uid, brandName: clean(brand.brandName, 180), companyName: clean(brand.companyName, 240), status: "active"}) : null,
    gates,
  });
}

function buildGetAiFieldOperationReadiness({db, onCallImpl = onCall}) {
  return onCallImpl(CALLABLE_OPTIONS, async (request) => readinessData({db, uid: assertRequest(request)}));
}

function buildCreateAiFieldOperation({db, admin, onCallImpl = onCall, log = logger}) {
  return onCallImpl(CALLABLE_OPTIONS, async (request) => {
    const uid = assertRequest(request);
    const command = normalizeInput(request.data);
    const id = operationId(uid, command.requestId);
    const digest = fingerprint(command);
    const target = refs(db, uid, id);
    const now = admin.firestore.Timestamp.now();
    const result = await db.runTransaction(async (transaction) => {
      const [brandSnap, entitlementSnap, operationSnap, receiptSnap] = await Promise.all([
        transaction.get(target.brand),
        transaction.get(target.entitlement),
        transaction.get(target.operation),
        transaction.get(target.receipt),
      ]);
      if (receiptSnap.exists) {
        const receipt = receiptSnap.data() || {};
        if (receipt.fingerprintSha256 !== digest || !operationSnap.exists) fail("already-exists", "İstek kimliği farklı bir içerikle kullanılmış.");
        return {operationId: id, idempotentReplay: true};
      }
      const brand = brandSnap.exists ? brandSnap.data() || {} : null;
      const entitlement = entitlementSnap.exists ? entitlementSnap.data() || {} : null;
      const gates = evaluateReadiness({brand, entitlement, nowMillis: now.toMillis()});
      if (!gates.ready) fail("permission-denied", "Operasyon için marka, hizmet ve işlem yetkisi birlikte gereklidir.");
      if (operationSnap.exists) fail("already-exists", "Operasyon kimliği zaten kullanılıyor.");
      const canonicalInput = {
        brandName: clean(brand.brandName, 180),
        productName: command.productName,
        sellerName: command.sellerName,
        targetUrl: command.targetUrl,
        requestedAgentCount: AGENTS.length,
      };
      transaction.create(target.operation, {
        contractVersion: CONTRACT_VERSION,
        ownerUid: uid,
        createdByUid: uid,
        requestId: command.requestId,
        title: command.title,
        objective: command.objective,
        status: "queued",
        priority: command.priority,
        createdAt: now,
        updatedAt: now,
        currentAgentId: AGENTS[0][0],
        requiresHumanApproval: true,
        expectedAgentCount: AGENTS.length,
      });
      AGENTS.forEach(([agentId, agentName], index) => {
        transaction.create(target.operation.collection("agentTasks").doc(agentId), {
          agentId,
          agentName,
          agentOrder: index + 1,
          status: index === 0 ? "queued" : "pending",
          input: index === 0 ? {operationTitle: command.title, operationObjective: command.objective, ...canonicalInput} : {},
          output: {},
          startedAt: null,
          completedAt: null,
          errorMessage: "",
          handoffToAgentId: index + 1 < AGENTS.length ? AGENTS[index + 1][0] : "",
        });
      });
      transaction.create(target.receipt, {
        contractVersion: CONTRACT_VERSION,
        requestId: command.requestId,
        idempotencyKey: command.idempotencyKey,
        fingerprintSha256: digest,
        operationId: id,
        actorUid: uid,
        createdAt: now,
      });
      return {operationId: id, idempotentReplay: false};
    });
    log.info("AI field operation create completed", {operationId: result.operationId, idempotentReplay: result.idempotentReplay});
    return Object.freeze({contractVersion: CONTRACT_VERSION, resultType: "ai_field_operation", ...result});
  });
}

module.exports = Object.freeze({
  AGENTS,
  CALLABLE_OPTIONS,
  CONTRACT_VERSION,
  SERVICE_CODE,
  buildCreateAiFieldOperation,
  buildGetAiFieldOperationReadiness,
  evaluateReadiness,
  fingerprint,
  normalizeInput,
  operationId,
  readinessData,
});
