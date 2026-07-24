/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const HOLD_SCOPE = "case_and_descendants";
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class CaseLegalHoldError extends Error {
  constructor(code, message) {
    super(message); this.name = "CaseLegalHoldError"; this.code = code;
  }
}

function objectRequired(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new CaseLegalHoldError("invalid-argument", "request object required");
}
function text(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== "string") throw new CaseLegalHoldError("invalid-argument", `${field} invalid`);
  const clean = value.trim(); const forbidden = [...clean].some((character) => {
    const code = character.charCodeAt(0); return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  });
  if (clean.length < minimum || clean.length > maximum || forbidden) throw new CaseLegalHoldError("invalid-argument", `${field} invalid`);
  return clean;
}
function uuid(value) {
  const clean = text(value, "requestId", 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clean)) throw new CaseLegalHoldError("invalid-argument", "requestId invalid");
  return clean.toLowerCase();
}
function strict(raw, version, fields) {
  objectRequired(raw); const allowed = ["contractVersion", ...fields];
  if (Object.keys(raw).some((key) => !allowed.includes(key)) || raw.contractVersion !== version) throw new CaseLegalHoldError("invalid-argument", "request contract invalid");
}
function detailRequest(raw) {
  strict(raw, "case-legal-hold-detail-request-v1", ["caseId"]);
  return Object.freeze({contractVersion: raw.contractVersion, caseId: text(raw.caseId, "caseId", 1, 128)});
}
function startRequest(raw) {
  strict(raw, "case-legal-hold-start-request-v1", ["caseId", "reason", "authorityReference", "requestId"]);
  return Object.freeze({contractVersion: raw.contractVersion, caseId: text(raw.caseId, "caseId", 1, 128), reason: text(raw.reason, "reason", 10, 2000), authorityReference: text(raw.authorityReference, "authorityReference", 1, 500, true), requestId: uuid(raw.requestId)});
}
function releaseRequest(raw) {
  strict(raw, "case-legal-hold-release-request-v1", ["holdId", "reason", "requestId"]);
  return Object.freeze({contractVersion: raw.contractVersion, holdId: text(raw.holdId, "holdId", 1, 128), reason: text(raw.reason, "reason", 10, 1000), requestId: uuid(raw.requestId)});
}
function nowIso(clock) {
  const value = clock.now(); const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) throw new CaseLegalHoldError("internal", "clock invalid");
  return date.toISOString();
}
function dataOf(snapshot) {
  return {id: snapshot.id, data: snapshot.data() || {}};
}
async function ownerRequired({db, context}) {
  const snapshot = await db.collection("tenant_memberships").doc(context.membershipId).get(); const data = snapshot.data() || {};
  if (!snapshot.exists || data.status !== "active" || data.role !== "owner") throw new CaseLegalHoldError("authorization.denied", "owner required");
}
async function scopedCase({db, caseId, context, transaction = null}) {
  const ref = db.collection("case_files").doc(caseId); const snapshot = transaction ? await transaction.get(ref) : await ref.get(); const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseLegalHoldError("case.not_found", "case not found");
  return {ref, data};
}
function projectionOf(data) {
  const value = data?.legalHold && typeof data.legalHold === "object" ? data.legalHold : {};
  return {active: value.active === true, activeCount: Math.max(0, Number(value.activeCount || (value.active === true ? 1 : 0))), latestHoldId: value.latestHoldId || null, startedAt: value.startedAt || null, releasedAt: value.releasedAt || null, lastChangedAt: value.lastChangedAt || null};
}
function safeHold(id, data) {
  return {holdId: id, holdNumber: data.holdNumber, caseId: data.caseId, scope: data.scope, status: data.status, reason: data.reason, authorityReference: data.authorityReference || null, startedAt: data.startedAt, releasedAt: data.releasedAt || null, releaseReason: data.releaseReason || null, eventCount: Number(data.eventCount || 0), lastEventType: data.lastEventType || null, lastEventAt: data.lastEventAt || null};
}
function safeEvent(data) {
  return {holdId: data.holdId, sequence: Number(data.sequence || 0), eventType: data.eventType, note: data.note, actorLabel: data.actorLabel || "Yetkili kullanıcı", recordedAt: data.recordedAt};
}
function optional(target, values) {
  for (const [key, value] of Object.entries(values)) if (value != null) target[key] = value;
  return target;
}

function createLegalHoldService({db, clock = {now: () => new Date().toISOString()}, resolveContext = resolveTenantContextV1}) {
  return Object.freeze({
    async detail(raw, invocation) {
      const request = detailRequest(raw); if (!invocation?.uid) throw new CaseLegalHoldError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); const linkedCase = await scopedCase({db, caseId: request.caseId, context});
      const [holdSnapshot, eventSnapshot] = await Promise.all([
        db.collection("case_legal_holds").where("caseId", "==", request.caseId).limit(101).get(),
        db.collection("case_legal_hold_events").where("caseId", "==", request.caseId).limit(201).get(),
      ]);
      if (holdSnapshot.docs.length > 100 || eventSnapshot.docs.length > 200) throw new CaseLegalHoldError("scope.too_large", "legal hold scope too large");
      const belongs = (item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId;
      const holds = holdSnapshot.docs.map(dataOf).filter(belongs).map((item) => safeHold(item.id, item.data)).sort((a, b) => String(b.startedAt || "").localeCompare(String(a.startedAt || "")));
      const events = eventSnapshot.docs.map(dataOf).filter(belongs).map((item) => safeEvent(item.data)).sort((a, b) => String(a.recordedAt || "").localeCompare(String(b.recordedAt || "")) || a.sequence - b.sequence);
      const projection = projectionOf(linkedCase.data); const computedActiveCount = holds.filter((item) => item.status === "active").length;
      return {contractVersion: "case-legal-hold-detail-v1", case: {caseId: request.caseId, caseNumber: linkedCase.data.caseNumber, title: linkedCase.data.title, status: linkedCase.data.status}, legalHold: projection, stats: {totalHolds: holds.length, activeHolds: computedActiveCount, releasedHolds: holds.filter((item) => item.status === "released").length}, holds, events, integrityStatus: projection.activeCount === computedActiveCount && projection.active === (computedActiveCount > 0) ? "verified" : "projection_mismatch", readOnly: true, writesPerformed: 0};
    },
    async start(raw, invocation) {
      const request = startRequest(raw); if (!invocation?.uid) throw new CaseLegalHoldError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); await ownerRequired({db, context}); const recordedAt = nowIso(clock);
      const holdId = sha256(`${context.tenantId}|${request.caseId}|${request.requestId}`); const holdRef = db.collection("case_legal_holds").doc(holdId); const eventId = sha256(`${holdId}|started`); const eventRef = db.collection("case_legal_hold_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const linkedCase = await scopedCase({db, caseId: request.caseId, context, transaction}); const existing = await transaction.get(holdRef);
        if (existing.exists) {
          const hold = existing.data() || {}; return {contractVersion: "case-legal-hold-start-result-v1", ok: true, duplicate: true, holdId, holdNumber: hold.holdNumber, status: hold.status, activeCount: projectionOf(linkedCase.data).activeCount, transactionCommitted: false};
        }
        const holdNumber = `HM-${recordedAt.slice(0, 4)}-${holdId.slice(0, 8).toUpperCase()}`; const current = projectionOf(linkedCase.data); const activeCount = current.activeCount + 1;
        const hold = optional({contractVersion: "case-legal-hold-v1", schemaVersion: "case-legal-hold-schema-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, holdNumber, scope: HOLD_SCOPE, status: "active", reason: request.reason, startedByUid: invocation.uid, startedAt: recordedAt, eventCount: 1, lastEventType: "legal_hold_started", lastEventAt: recordedAt, lastEventId: eventId}, {authorityReference: request.authorityReference});
        const event = optional({contractVersion: "case-legal-hold-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, holdId, sequence: 1, eventType: "legal_hold_started", note: request.reason, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, appendOnly: true}, {authorityReference: request.authorityReference});
        transaction.create(holdRef, hold); transaction.create(eventRef, event);
        transaction.update(linkedCase.ref, {legalHold: {active: true, activeCount, latestHoldId: holdId, startedAt: current.active ? current.startedAt || recordedAt : recordedAt, releasedAt: null, lastChangedAt: recordedAt}, updatedAt: recordedAt});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "legal_hold_started", category: "legal", summary: `${holdNumber} hukuki muhafaza başlatıldı.`, occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "legal_hold.started", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-legal-hold-start-result-v1", ok: true, duplicate: false, holdId, holdNumber, status: "active", activeCount, transactionCommitted: true};
      });
    },
    async release(raw, invocation) {
      const request = releaseRequest(raw); if (!invocation?.uid) throw new CaseLegalHoldError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); await ownerRequired({db, context}); const recordedAt = nowIso(clock);
      const holdRef = db.collection("case_legal_holds").doc(request.holdId); const eventId = sha256(`${context.tenantId}|legal-hold|${request.holdId}|${request.requestId}`); const eventRef = db.collection("case_legal_hold_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const holdSnapshot = await transaction.get(holdRef); const hold = holdSnapshot.data() || {};
        if (!holdSnapshot.exists || hold.tenantId !== context.tenantId || hold.canonicalBrandId !== context.brandId) throw new CaseLegalHoldError("hold.not_found", "hold not found");
        const linkedCase = await scopedCase({db, caseId: hold.caseId, context, transaction}); const existing = await transaction.get(eventRef);
        if (existing.exists) {
          return {contractVersion: "case-legal-hold-release-result-v1", ok: true, duplicate: true, holdId: request.holdId, holdNumber: hold.holdNumber, status: hold.status, activeCount: projectionOf(linkedCase.data).activeCount, transactionCommitted: false};
        }
        if (hold.status !== "active") throw new CaseLegalHoldError("hold.already_released", "hold already released");
        const sequence = Number(hold.eventCount || 0) + 1; const current = projectionOf(linkedCase.data); const activeCount = Math.max(0, current.activeCount - 1); const active = activeCount > 0;
        const event = {contractVersion: "case-legal-hold-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: hold.caseId, holdId: request.holdId, sequence, eventType: "legal_hold_released", note: request.reason, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, appendOnly: true}; if (hold.lastEventId) event.previousEventId = hold.lastEventId;
        transaction.update(holdRef, {status: "released", releasedByUid: invocation.uid, releasedAt: recordedAt, releaseReason: request.reason, eventCount: sequence, lastEventType: "legal_hold_released", lastEventAt: recordedAt, lastEventId: eventId});
        transaction.create(eventRef, event); transaction.update(linkedCase.ref, {legalHold: {active, activeCount, latestHoldId: request.holdId, startedAt: current.startedAt || hold.startedAt || null, releasedAt: active ? null : recordedAt, lastChangedAt: recordedAt}, updatedAt: recordedAt});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: hold.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "legal_hold_released", category: "legal", summary: `${hold.holdNumber} hukuki muhafaza kaldırıldı.`, occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: hold.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "legal_hold.released", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-legal-hold-release-result-v1", ok: true, duplicate: false, holdId: request.holdId, holdNumber: hold.holdNumber, status: "released", activeCount, transactionCommitted: true};
      });
    },
  });
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  if (error.code === "unauthenticated") return new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  if (error.code === "authorization.denied") return new HttpsError("permission-denied", "Bu işlem için marka sahibi yetkisi gerekir.");
  if (["case.not_found", "hold.not_found"].includes(error.code)) return new HttpsError("not-found", "Hukuki muhafaza kaydı bulunamadı.");
  if (error.code === "hold.already_released") return new HttpsError("failed-precondition", "Hukuki muhafaza daha önce kaldırılmış.");
  if (error.code === "scope.too_large") return new HttpsError("resource-exhausted", "Hukuki muhafaza kapsamı güvenli sınırı aşıyor.");
  if (error.code === "internal") return new HttpsError("internal", "Hukuki muhafaza işlemi tamamlanamadı.");
  return new HttpsError("invalid-argument", "Geçersiz hukuki muhafaza isteği.");
}
function createLegalHoldHandler(method, {db, clock, resolveContext, appCheck = true, log = logger}) {
  const service = createLegalHoldService({db, clock, resolveContext});
  return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    if (appCheck && !invocation.app) throw new HttpsError("failed-precondition", "Uygulama doğrulaması gerekir.");
    try {
      return await service[method](invocation.data || {}, {uid: invocation.auth.uid});
    } catch (error) {
      log.error("case legal hold callable failed", {method, code: error.code || "unknown", message: error.message}); throw mapError(error);
    }
  };
}
function buildGetCaseLegalHoldDetail({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createLegalHoldHandler("detail", {db, appCheck: false}));
}
function buildStartCaseLegalHold({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createLegalHoldHandler("start", {db}));
}
function buildReleaseCaseLegalHold({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createLegalHoldHandler("release", {db}));
}

module.exports = {CaseLegalHoldError, buildGetCaseLegalHoldDetail, buildReleaseCaseLegalHold, buildStartCaseLegalHold, createLegalHoldHandler, createLegalHoldService, detailRequest, releaseRequest, startRequest};
