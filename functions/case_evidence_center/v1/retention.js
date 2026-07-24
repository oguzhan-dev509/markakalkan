/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const ANCHOR_TYPES = new Set(["case_opened_at", "case_closed_at", "manual_date"]);
const CLOSED_CASE_STATUSES = new Set(["closed", "archived"]);
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class CaseRetentionError extends Error {
  constructor(code, message) {
    super(message); this.name = "CaseRetentionError"; this.code = code;
  }
}

function objectRequired(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new CaseRetentionError("invalid-argument", "request object required");
}
function text(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== "string") throw new CaseRetentionError("invalid-argument", `${field} invalid`);
  const clean = value.trim(); const forbidden = [...clean].some((character) => {
    const code = character.charCodeAt(0); return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  });
  if (clean.length < minimum || clean.length > maximum || forbidden) throw new CaseRetentionError("invalid-argument", `${field} invalid`);
  return clean;
}
function integer(value, field, minimum, maximum) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) throw new CaseRetentionError("invalid-argument", `${field} invalid`);
  return value;
}
function uuid(value) {
  const clean = text(value, "requestId", 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clean)) throw new CaseRetentionError("invalid-argument", "requestId invalid");
  return clean.toLowerCase();
}
function strict(raw, version, fields) {
  objectRequired(raw); const allowed = ["contractVersion", ...fields];
  if (Object.keys(raw).some((key) => !allowed.includes(key)) || raw.contractVersion !== version) throw new CaseRetentionError("invalid-argument", "request contract invalid");
}
function isoInput(value, field, optional = false) {
  if (value == null && optional) return null;
  const clean = text(value, field, 20, 40); const date = new Date(clean);
  if (Number.isNaN(date.getTime()) || date.toISOString() !== clean) throw new CaseRetentionError("invalid-argument", `${field} invalid`);
  return clean;
}
function detailRequest(raw) {
  strict(raw, "case-retention-detail-request-v1", ["caseId"]);
  return Object.freeze({contractVersion: raw.contractVersion, caseId: text(raw.caseId, "caseId", 1, 128)});
}
function setPolicyRequest(raw) {
  strict(raw, "case-retention-policy-set-request-v1", ["caseId", "policyCode", "policyName", "anchorType", "anchorDate", "retentionPeriodDays", "reason", "authorityReference", "requestId"]);
  const anchorType = text(raw.anchorType, "anchorType", 1, 40); if (!ANCHOR_TYPES.has(anchorType)) throw new CaseRetentionError("invalid-argument", "anchorType invalid");
  const anchorDate = isoInput(raw.anchorDate, "anchorDate", true);
  if ((anchorType === "manual_date") !== (anchorDate != null)) throw new CaseRetentionError("invalid-argument", "anchorDate contract invalid");
  return Object.freeze({contractVersion: raw.contractVersion, caseId: text(raw.caseId, "caseId", 1, 128), policyCode: text(raw.policyCode, "policyCode", 2, 80), policyName: text(raw.policyName, "policyName", 3, 200), anchorType, anchorDate, retentionPeriodDays: integer(raw.retentionPeriodDays, "retentionPeriodDays", 1, 36500), reason: text(raw.reason, "reason", 10, 2000), authorityReference: text(raw.authorityReference, "authorityReference", 1, 500, true), requestId: uuid(raw.requestId)});
}
function assessRequest(raw) {
  strict(raw, "case-retention-disposition-assess-request-v1", ["caseId", "note", "requestId"]);
  return Object.freeze({contractVersion: raw.contractVersion, caseId: text(raw.caseId, "caseId", 1, 128), note: text(raw.note, "note", 10, 1000), requestId: uuid(raw.requestId)});
}
function dateValue(value, field, code = "retention.anchor_unavailable") {
  if (value == null || value === "") throw new CaseRetentionError(code, `${field} unavailable`);
  let candidate;
  if (value instanceof Date) candidate = value;
  else if (value && typeof value.toDate === "function") candidate = value.toDate();
  else candidate = new Date(value);
  if (!(candidate instanceof Date) || Number.isNaN(candidate.getTime())) throw new CaseRetentionError(code, `${field} unavailable`);
  return candidate;
}
function nowIso(clock) {
  return dateValue(clock.now(), "clock", "internal").toISOString();
}
function addDaysIso(anchorAt, days) {
  return new Date(dateValue(anchorAt, "anchorAt").getTime() + days * 86400000).toISOString();
}
function resolveAnchor(caseData, request) {
  if (request.anchorType === "manual_date") return request.anchorDate;
  if (request.anchorType === "case_opened_at") return dateValue(caseData.openedAt, "case.openedAt").toISOString();
  return dateValue(caseData.closedAt, "case.closedAt").toISOString();
}
async function ownerRequired({db, context}) {
  const snapshot = await db.collection("tenant_memberships").doc(context.membershipId).get(); const data = snapshot.data() || {};
  if (!snapshot.exists || data.status !== "active" || data.role !== "owner") throw new CaseRetentionError("authorization.denied", "owner required");
}
async function scopedCase({db, caseId, context, transaction = null}) {
  const ref = db.collection("case_files").doc(caseId); const snapshot = transaction ? await transaction.get(ref) : await ref.get(); const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseRetentionError("case.not_found", "case not found");
  return {ref, data};
}
function retentionRecordId(context, caseId) {
  return sha256(`${context.tenantId}|case-retention|${caseId}`);
}
function projectionOf(caseData) {
  const value = caseData?.retention && typeof caseData.retention === "object" ? caseData.retention : {};
  return {active: value.active === true, recordId: value.recordId || null, policyCode: value.policyCode || null, policyVersion: Math.max(0, Number(value.policyVersion || 0)), retainUntil: value.retainUntil || null, dispositionStatus: value.dispositionStatus || null, dispositionEligible: value.dispositionEligible === true, blockedReason: value.blockedReason || null, lastAssessedAt: value.lastAssessedAt || null, lastChangedAt: value.lastChangedAt || null};
}
function dispositionOf(record, caseData, assessedAt) {
  const retainUntil = dateValue(record.retainUntil, "retainUntil", "internal").getTime(); const assessed = dateValue(assessedAt, "assessedAt", "internal").getTime();
  if (assessed < retainUntil) return {status: "not_due", eligible: false, blockedReason: "retention_period_active"};
  if (!CLOSED_CASE_STATUSES.has(caseData.status)) return {status: "blocked_by_case_lifecycle", eligible: false, blockedReason: "case_not_closed"};
  if (caseData?.legalHold?.active === true) return {status: "blocked_by_legal_hold", eligible: false, blockedReason: "active_legal_hold"};
  return {status: "eligible_for_disposition", eligible: true, blockedReason: null};
}
function safeRecord(id, data) {
  return {recordId: id, status: data.status || "active", caseId: data.caseId, policyCode: data.policyCode, policyName: data.policyName, policyVersion: Number(data.policyVersion || 0), anchorType: data.anchorType, anchorAt: data.anchorAt, retentionPeriodDays: Number(data.retentionPeriodDays || 0), retainUntil: data.retainUntil, reason: data.reason, authorityReference: data.authorityReference || null, dispositionStatus: data.dispositionStatus, dispositionEligible: data.dispositionEligible === true, blockedReason: data.blockedReason || null, lastAssessedAt: data.lastAssessedAt || null, eventCount: Number(data.eventCount || 0), lastEventType: data.lastEventType || null, lastEventAt: data.lastEventAt || null, createdAt: data.createdAt, updatedAt: data.updatedAt};
}
function safeEvent(data) {
  return {recordId: data.recordId, sequence: Number(data.sequence || 0), eventType: data.eventType, note: data.note, policyCode: data.policyCode || null, policyName: data.policyName || null, policyVersion: Number(data.policyVersion || 0), anchorType: data.anchorType || null, anchorAt: data.anchorAt || null, retentionPeriodDays: Number(data.retentionPeriodDays || 0), retainUntil: data.retainUntil || null, dispositionStatus: data.dispositionStatus || null, dispositionEligible: data.dispositionEligible === true, blockedReason: data.blockedReason || null, actorLabel: data.actorLabel || "Yetkili kullanıcı", recordedAt: data.recordedAt};
}
function optional(target, values) {
  for (const [key, value] of Object.entries(values)) if (value != null) target[key] = value;
  return target;
}
function projectionMatches(projection, recordId, record) {
  if (!record) return projection.active === false && projection.recordId == null && projection.policyCode == null && projection.policyVersion === 0 && projection.retainUntil == null && projection.dispositionStatus == null && projection.dispositionEligible === false && projection.blockedReason == null && projection.lastAssessedAt == null && projection.lastChangedAt == null;
  return projection.active === true && projection.recordId === recordId && projection.policyCode === record.policyCode && projection.policyVersion === Number(record.policyVersion || 0) && projection.retainUntil === record.retainUntil && projection.dispositionStatus === record.dispositionStatus && projection.dispositionEligible === (record.dispositionEligible === true) && projection.blockedReason === (record.blockedReason || null) && projection.lastAssessedAt === (record.lastAssessedAt || null) && projection.lastChangedAt === (record.updatedAt || null);
}

function createRetentionService({db, clock = {now: () => new Date()}, resolveContext = resolveTenantContextV1}) {
  return Object.freeze({
    async detail(raw, invocation) {
      const request = detailRequest(raw); if (!invocation?.uid) throw new CaseRetentionError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); const linkedCase = await scopedCase({db, caseId: request.caseId, context}); const recordId = retentionRecordId(context, request.caseId);
      const [recordSnapshot, eventSnapshot] = await Promise.all([db.collection("case_retention_records").doc(recordId).get(), db.collection("case_retention_events").where("caseId", "==", request.caseId).limit(201).get()]);
      const rawRecord = recordSnapshot.exists ? recordSnapshot.data() || {} : null;
      if (rawRecord && (rawRecord.tenantId !== context.tenantId || rawRecord.canonicalBrandId !== context.brandId || rawRecord.caseId !== request.caseId)) throw new CaseRetentionError("retention.not_found", "retention not found");
      if (eventSnapshot.docs.length > 200) throw new CaseRetentionError("scope.too_large", "retention event scope too large");
      const events = eventSnapshot.docs.map((snapshot) => ({id: snapshot.id, data: snapshot.data() || {}})).filter((item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId).map((item) => safeEvent(item.data)).sort((a, b) => String(a.recordedAt || "").localeCompare(String(b.recordedAt || "")) || a.sequence - b.sequence);
      const projection = projectionOf(linkedCase.data); const record = rawRecord ? safeRecord(recordId, rawRecord) : null; const currentEvaluation = rawRecord ? dispositionOf(rawRecord, linkedCase.data, nowIso(clock)) : null;
      return {contractVersion: "case-retention-detail-v1", case: {caseId: request.caseId, caseNumber: linkedCase.data.caseNumber, title: linkedCase.data.title, status: linkedCase.data.status}, retention: projection, record, currentEvaluation, events, stats: {eventCount: events.length, policyVersion: record?.policyVersion || 0}, integrityStatus: projectionMatches(projection, recordId, rawRecord) ? "verified" : "projection_mismatch", readOnly: true, writesPerformed: 0};
    },
    async setPolicy(raw, invocation) {
      const request = setPolicyRequest(raw); if (!invocation?.uid) throw new CaseRetentionError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); await ownerRequired({db, context}); const recordedAt = nowIso(clock); const recordId = retentionRecordId(context, request.caseId); const recordRef = db.collection("case_retention_records").doc(recordId); const eventId = sha256(`${recordId}|policy|${request.requestId}`); const eventRef = db.collection("case_retention_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const linkedCase = await scopedCase({db, caseId: request.caseId, context, transaction}); const recordSnapshot = await transaction.get(recordRef); const existing = recordSnapshot.data() || {}; const duplicateSnapshot = await transaction.get(eventRef);
        if (duplicateSnapshot.exists) {
          const duplicate = duplicateSnapshot.data() || {};
          return {contractVersion: "case-retention-policy-set-result-v1", ok: true, duplicate: true, recordId, policyVersion: Number(duplicate.policyVersion || existing.policyVersion || 0), retainUntil: duplicate.retainUntil || existing.retainUntil, dispositionStatus: duplicate.dispositionStatus || existing.dispositionStatus, transactionCommitted: false};
        }
        const anchorAt = resolveAnchor(linkedCase.data, request); const retainUntil = addDaysIso(anchorAt, request.retentionPeriodDays); const policyVersion = Number(existing.policyVersion || 0) + 1; const sequence = Number(existing.eventCount || 0) + 1; const eventType = recordSnapshot.exists ? "retention_policy_updated" : "retention_policy_set";
        const draft = {retainUntil}; const evaluation = dispositionOf(draft, linkedCase.data, recordedAt);
        const record = {contractVersion: "case-retention-record-v1", schemaVersion: "case-retention-record-schema-v1", status: "active", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, policyCode: request.policyCode, policyName: request.policyName, policyVersion, anchorType: request.anchorType, anchorAt, retentionPeriodDays: request.retentionPeriodDays, retainUntil, reason: request.reason, authorityReference: request.authorityReference, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, blockedReason: evaluation.blockedReason, lastAssessedAt: recordedAt, eventCount: sequence, lastEventType: eventType, lastEventAt: recordedAt, lastEventId: eventId, createdAt: existing.createdAt || recordedAt, createdByUid: existing.createdByUid || invocation.uid, updatedAt: recordedAt, updatedByUid: invocation.uid};
        const event = optional({contractVersion: "case-retention-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, recordId, sequence, eventType, note: request.reason, policyCode: request.policyCode, policyName: request.policyName, policyVersion, anchorType: request.anchorType, anchorAt, retentionPeriodDays: request.retentionPeriodDays, retainUntil, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, appendOnly: true}, {previousEventId: existing.lastEventId, authorityReference: request.authorityReference, blockedReason: evaluation.blockedReason});
        if (recordSnapshot.exists) transaction.update(recordRef, record); else transaction.create(recordRef, record);
        transaction.create(eventRef, event); transaction.update(linkedCase.ref, {retention: {active: true, recordId, policyCode: request.policyCode, policyVersion, retainUntil, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, blockedReason: evaluation.blockedReason, lastAssessedAt: recordedAt, lastChangedAt: recordedAt}, updatedAt: recordedAt});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType, category: "retention", summary: `${request.policyName} saklama politikası kaydedildi.`, occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: recordSnapshot.exists ? "retention.policy_updated" : "retention.policy_set", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-retention-policy-set-result-v1", ok: true, duplicate: false, recordId, policyVersion, retainUntil, dispositionStatus: evaluation.status, transactionCommitted: true};
      });
    },
    async assessDisposition(raw, invocation) {
      const request = assessRequest(raw); if (!invocation?.uid) throw new CaseRetentionError("unauthenticated", "authentication required");
      const context = await resolveContext({db, uid: invocation.uid, request: {}}); await ownerRequired({db, context}); const recordedAt = nowIso(clock); const recordId = retentionRecordId(context, request.caseId); const recordRef = db.collection("case_retention_records").doc(recordId); const eventId = sha256(`${recordId}|assessment|${request.requestId}`); const eventRef = db.collection("case_retention_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const linkedCase = await scopedCase({db, caseId: request.caseId, context, transaction}); const recordSnapshot = await transaction.get(recordRef); const record = recordSnapshot.data() || {}; if (!recordSnapshot.exists || record.tenantId !== context.tenantId || record.canonicalBrandId !== context.brandId) throw new CaseRetentionError("retention.not_found", "retention not found"); const duplicateSnapshot = await transaction.get(eventRef);
        if (duplicateSnapshot.exists) {
          const duplicate = duplicateSnapshot.data() || {};
          return {contractVersion: "case-retention-disposition-assess-result-v1", ok: true, duplicate: true, recordId, dispositionStatus: duplicate.dispositionStatus || record.dispositionStatus, dispositionEligible: duplicate.dispositionEligible === true, blockedReason: duplicate.blockedReason || null, transactionCommitted: false};
        }
        const evaluation = dispositionOf(record, linkedCase.data, recordedAt); const sequence = Number(record.eventCount || 0) + 1;
        const event = optional({contractVersion: "case-retention-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, recordId, sequence, eventType: "retention_disposition_assessed", note: request.note, policyCode: record.policyCode, policyName: record.policyName, policyVersion: Number(record.policyVersion || 0), anchorType: record.anchorType, anchorAt: record.anchorAt, retentionPeriodDays: Number(record.retentionPeriodDays || 0), retainUntil: record.retainUntil, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, appendOnly: true}, {previousEventId: record.lastEventId, blockedReason: evaluation.blockedReason});
        transaction.update(recordRef, {dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, blockedReason: evaluation.blockedReason, lastAssessedAt: recordedAt, eventCount: sequence, lastEventType: "retention_disposition_assessed", lastEventAt: recordedAt, lastEventId: eventId, updatedAt: recordedAt, updatedByUid: invocation.uid});
        transaction.create(eventRef, event); transaction.update(linkedCase.ref, {retention: {active: true, recordId, policyCode: record.policyCode, policyVersion: Number(record.policyVersion || 0), retainUntil: record.retainUntil, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, blockedReason: evaluation.blockedReason, lastAssessedAt: recordedAt, lastChangedAt: recordedAt}, updatedAt: recordedAt});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "retention_disposition_assessed", category: "retention", summary: `Saklama tasfiye değerlendirmesi: ${evaluation.status}.`, occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "retention.disposition_assessed", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-retention-disposition-assess-result-v1", ok: true, duplicate: false, recordId, dispositionStatus: evaluation.status, dispositionEligible: evaluation.eligible, blockedReason: evaluation.blockedReason, transactionCommitted: true};
      });
    },
  });
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  if (error.code === "unauthenticated") return new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  if (error.code === "authorization.denied") return new HttpsError("permission-denied", "Bu işlem için marka sahibi yetkisi gerekir.");
  if (error.code === "case.not_found") return new HttpsError("not-found", "Vaka bulunamadı.");
  if (error.code === "retention.not_found") return new HttpsError("not-found", "Saklama kaydı bulunamadı.");
  if (error.code === "retention.anchor_unavailable") return new HttpsError("failed-precondition", "Saklama başlangıç tarihi henüz kullanılamıyor.");
  if (error.code === "scope.too_large") return new HttpsError("resource-exhausted", "Saklama olay kapsamı güvenli sınırı aşıyor.");
  if (error.code === "invalid-argument") return new HttpsError("invalid-argument", "Geçersiz saklama isteği.");
  return new HttpsError("internal", "Saklama işlemi tamamlanamadı.");
}
function createRetentionHandler(method, {db, clock, resolveContext, appCheck = true, log = logger}) {
  const service = createRetentionService({db, clock, resolveContext});
  return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    if (appCheck && !invocation.app) throw new HttpsError("failed-precondition", "Uygulama doğrulaması gerekir.");
    try {
      return await service[method](invocation.data || {}, {uid: invocation.auth.uid});
    } catch (error) {
      log.error("case retention callable failed", {method, code: error.code || "unknown", message: error.message}); throw mapError(error);
    }
  };
}
function buildGetCaseRetentionDetail({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createRetentionHandler("detail", {db, appCheck: false}));
}
function buildSetCaseRetentionPolicy({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createRetentionHandler("setPolicy", {db}));
}
function buildAssessCaseRetentionDisposition({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createRetentionHandler("assessDisposition", {db}));
}

module.exports = {CaseRetentionError, assessRequest, buildAssessCaseRetentionDisposition, buildGetCaseRetentionDetail, buildSetCaseRetentionPolicy, createRetentionHandler, createRetentionService, detailRequest, setPolicyRequest};
