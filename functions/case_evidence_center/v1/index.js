/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {monitoringProjection, traceabilityProjection} = require("../../risk_operations/v1/projection");
const {resolveTenantContextV1, sharedRiskProjection} = require("../../risk_operations/v1/service");

const SOURCES = Object.freeze(["monitoring", "traceability", "digital_detective", "shared_risk"]);
const CANDIDACY = Object.freeze(["review_candidate", "strong_candidate"]);
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class CaseEvidenceCenterError extends Error {
  constructor(code, message) {
    super(message); this.name = "CaseEvidenceCenterError"; this.code = code;
  }
}

function objectRequired(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CaseEvidenceCenterError("invalid-argument", "request object required");
  }
}
function optionalString(value, field, max = 160) {
  if (value == null) return null;
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new CaseEvidenceCenterError("invalid-argument", `${field} invalid`);
  }
  return value.trim();
}
function requiredString(value, field, max = 200) {
  const clean = optionalString(value, field, max);
  if (clean == null) throw new CaseEvidenceCenterError("invalid-argument", `${field} required`);
  return clean;
}
function listRequest(raw) {
  objectRequired(raw);
  const allowed = ["tenantId", "canonicalBrandId", "pageSize"];
  if (Object.keys(raw).some((key) => !allowed.includes(key))) {
    throw new CaseEvidenceCenterError("invalid-argument", "unsupported request fields");
  }
  const pageSize = raw.pageSize == null ? 25 : raw.pageSize;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) {
    throw new CaseEvidenceCenterError("invalid-argument", "pageSize invalid");
  }
  return Object.freeze({
    tenantId: optionalString(raw.tenantId, "tenantId"),
    canonicalBrandId: optionalString(raw.canonicalBrandId, "canonicalBrandId"),
    pageSize,
  });
}
function createRequest(raw) {
  objectRequired(raw);
  const allowed = ["tenantId", "canonicalBrandId", "sourceSystem", "sourceRecordId", "expectedSourceRecordVersion", "expectedProjectionFingerprint", "correlationId", "dryRun"];
  if (Object.keys(raw).some((key) => !allowed.includes(key))) {
    throw new CaseEvidenceCenterError("invalid-argument", "unsupported request fields");
  }
  const sourceSystem = requiredString(raw.sourceSystem, "sourceSystem", 40);
  if (!SOURCES.includes(sourceSystem)) {
    throw new CaseEvidenceCenterError("invalid-argument", "sourceSystem unsupported");
  }
  const fingerprint = requiredString(raw.expectedProjectionFingerprint, "expectedProjectionFingerprint", 64);
  if (!/^[a-f0-9]{64}$/.test(fingerprint)) {
    throw new CaseEvidenceCenterError("invalid-argument", "expectedProjectionFingerprint invalid");
  }
  if (typeof raw.dryRun !== "boolean") {
    throw new CaseEvidenceCenterError("invalid-argument", "dryRun invalid");
  }
  return Object.freeze({
    tenantId: optionalString(raw.tenantId, "tenantId"),
    canonicalBrandId: optionalString(raw.canonicalBrandId, "canonicalBrandId"),
    sourceSystem,
    sourceRecordId: requiredString(raw.sourceRecordId, "sourceRecordId", 240),
    expectedSourceRecordVersion: requiredString(raw.expectedSourceRecordVersion, "expectedSourceRecordVersion", 120),
    expectedProjectionFingerprint: fingerprint,
    correlationId: requiredString(raw.correlationId, "correlationId", 128),
    dryRun: raw.dryRun,
  });
}
function detailRequest(raw) {
  objectRequired(raw);
  const allowed = ["contractVersion", "caseId"];
  if (Object.keys(raw).some((key) => !allowed.includes(key)) || raw.contractVersion !== "case-evidence-detail-request-v1") {
    throw new CaseEvidenceCenterError("invalid-argument", "detail request invalid");
  }
  return Object.freeze({contractVersion: raw.contractVersion, caseId: requiredString(raw.caseId, "caseId", 128)});
}

const versionOf = (snapshot) => snapshot.updateTime && snapshot.updateTime.toDate ?
  snapshot.updateTime.toDate().toISOString() :
  ((snapshot.data() || {}).sourceRecordVersion || (snapshot.data() || {}).contractVersion || "v1");
const dataOf = (snapshot) => ({id: snapshot.id, data: snapshot.data() || {}, reference: snapshot.ref, version: versionOf(snapshot)});
async function query(db, name, field, value, limit = 200) {
  return (await db.collection(name).where(field, "==", value).limit(limit).get()).docs.map(dataOf);
}

function project({sourceSystem, item, context, evaluatedAt}) {
  if (sourceSystem === "monitoring") {
    if (item.data.tenantId !== context.tenantId || item.data.brandId !== context.brandId) throw new CaseEvidenceCenterError("source.denied", "source denied");
    return monitoringProjection({id: item.id, data: {...item.data, sourceRecordVersion: item.version}, context, evaluatedAt});
  }
  if (sourceSystem === "traceability") {
    if (item.data.ownerUid !== context.uid) throw new CaseEvidenceCenterError("source.denied", "source denied");
    return traceabilityProjection({id: item.id, data: {...item.data, sourceRecordVersion: item.version}, context, evaluatedAt});
  }
  if (sourceSystem === "digital_detective") {
    if (item.data.status !== "completed") throw new CaseEvidenceCenterError("source.denied", "source denied");
    return sharedRiskProjection({id: item.id, data: {...item.data, contractVersion: item.version, tenantId: context.tenantId, canonicalSubjectId: item.id, subjectType: "source_record", sourceModule: "digital_detective", title: item.data.title || "Dijital Dedektif sonucu", riskClass: item.data.riskClass || "other"}, context, evaluatedAt});
  }
  if (item.data.tenantId !== context.tenantId || (item.data.canonicalBrandId && item.data.canonicalBrandId !== context.brandId)) throw new CaseEvidenceCenterError("source.denied", "source denied");
  return sharedRiskProjection({id: item.id, data: {...item.data, contractVersion: item.version}, context, evaluatedAt});
}

async function readSources({db, context, evaluatedAt}) {
  const definitions = [
    ["monitoring", async () => (await query(db, "monitoring_signals", "tenantId", context.tenantId)).filter((item) => item.data.brandId === context.brandId)],
    ["traceability", async () => query(db, "verificationScans", "ownerUid", context.uid)],
    ["shared_risk", async () => (await query(db, "shared_risk_signals", "tenantId", context.tenantId)).filter((item) => !item.data.canonicalBrandId || item.data.canonicalBrandId === context.brandId)],
    ["digital_detective", async () => (await db.collection("brands").doc(context.uid).collection("digitalDetectiveTasks").limit(200).get()).docs.map(dataOf).filter((item) => item.data.status === "completed")],
  ];
  const settled = await Promise.allSettled(definitions.map((entry) => entry[1]()));
  const items = []; const availability = [];
  settled.forEach((result, index) => {
    const sourceSystem = definitions[index][0];
    if (result.status === "fulfilled") {
      for (const item of result.value) {
        try {
          items.push({sourceSystem, item, projection: project({sourceSystem, item, context, evaluatedAt})});
        } catch (_) {/* fail closed */}
      }
      availability.push({sourceSystem, status: "available"});
    } else {
      availability.push({sourceSystem, status: "unavailable", reasonCode: "source.read_failed"});
    }
  });
  return {items, availability};
}

function bindingKey(sourceSystem, sourceRecordId) {
  return `${sourceSystem}:${sourceRecordId}`;
}
function priority(severity) {
  return severity === "critical" ? "critical" : severity === "high" ? "high" : severity === "medium" ? "medium" : "low";
}
function caseNumber(openedAt, caseId) {
  return `VK-${openedAt.slice(0, 4)}-${caseId.slice(0, 8).toUpperCase()}`;
}

async function ownerRequired({db, context}) {
  const snapshot = await db.collection("tenant_memberships").doc(context.membershipId).get();
  const data = snapshot.data() || {};
  if (data.status !== "active" || data.role !== "owner") throw new CaseEvidenceCenterError("authorization.denied", "owner required");
}

async function exactSource({db, context, request, evaluatedAt}) {
  let reference;
  if (request.sourceSystem === "monitoring") reference = db.collection("monitoring_signals").doc(request.sourceRecordId);
  else if (request.sourceSystem === "traceability") reference = db.collection("verificationScans").doc(request.sourceRecordId);
  else if (request.sourceSystem === "shared_risk") reference = db.collection("shared_risk_signals").doc(request.sourceRecordId);
  else reference = db.collection("brands").doc(context.uid).collection("digitalDetectiveTasks").doc(request.sourceRecordId);
  const snapshot = await reference.get();
  if (!snapshot.exists) throw new CaseEvidenceCenterError("source.not_found", "source not found");
  const item = dataOf(snapshot);
  return {reference, item, projection: project({sourceSystem: request.sourceSystem, item, context, evaluatedAt})};
}

async function readDetails(db, entry) {
  const [events, evidence] = await Promise.all([
    db.collection("case_events").where("caseId", "==", entry.id).limit(100).get(),
    db.collection("case_evidence_refs").where("caseId", "==", entry.id).limit(100).get(),
  ]);
  return {
    caseId: entry.id,
    ...entry.data,
    events: events.docs.map(dataOf).map((item) => ({eventId: item.id, ...item.data})).sort((a, b) => String(b.occurredAt || "").localeCompare(String(a.occurredAt || ""))),
    evidenceRefs: evidence.docs.map(dataOf).map((item) => ({evidenceRefId: item.id, ...item.data})),
  };
}

function createService({db, clock = {now: () => new Date().toISOString()}}) {
  return Object.freeze({
    async detail(raw, invocation) {
      const request = detailRequest(raw);
      if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}});
      const snapshot = await db.collection("case_files").doc(request.caseId).get();
      if (!snapshot.exists) throw new CaseEvidenceCenterError("case.not_found", "case not found");
      const record = snapshot.data() || {};
      if (record.tenantId !== context.tenantId || record.canonicalBrandId !== context.brandId) {
        throw new CaseEvidenceCenterError("case.not_found", "case not found");
      }
      const [evidence, events, audits] = await Promise.all([
        query(db, "case_evidence_refs", "caseId", request.caseId, 100),
        query(db, "case_events", "caseId", request.caseId, 100),
        query(db, "case_audit_events", "caseId", request.caseId, 100),
      ]);
      const belongs = (item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId;
      return Object.freeze({
        contractVersion: "case-evidence-detail-v1",
        case: {
          id: snapshot.id,
          caseCode: record.caseNumber,
          title: record.title,
          summary: record.summary,
          status: record.status,
          priority: record.priority,
          sourceType: record.sourceBinding?.sourceSystem,
          sourceReference: "Kaynak risk kaydı",
          createdAt: record.openedAt,
          updatedAt: record.updatedAt,
        },
        evidenceReferences: evidence.filter(belongs).map((item) => ({title: item.data.title, sourceType: item.data.sourceSystem, reviewStatus: item.data.reviewStatus, integrityStatus: item.data.integrityStatus, capturedAt: item.data.capturedAt, createdAt: item.data.createdAt})).sort((a, b) => String(a.createdAt || "").localeCompare(String(b.createdAt || ""))),
        timelineEvents: events.filter(belongs).map((item) => ({type: item.data.eventType, summary: item.data.summary, occurredAt: item.data.occurredAt})).sort((a, b) => String(a.occurredAt || "").localeCompare(String(b.occurredAt || ""))),
        auditSummary: audits.filter(belongs).map((item) => ({action: item.data.action, occurredAt: item.data.occurredAt})).sort((a, b) => String(b.occurredAt || "").localeCompare(String(a.occurredAt || ""))),
        readOnly: true,
        writesPerformed: 0,
      });
    },
    async list(raw, invocation) {
      const request = listRequest(raw);
      if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request});
      const evaluatedAt = clock.now();
      const [caseSnapshot, sourceResult] = await Promise.all([
        db.collection("case_files").where("tenantId", "==", context.tenantId).limit(100).get(),
        readSources({db, context, evaluatedAt}),
      ]);
      const entries = caseSnapshot.docs.map(dataOf).filter((entry) => entry.data.canonicalBrandId === context.brandId);
      const bySource = new Map(entries.map((entry) => [bindingKey(entry.data.sourceBinding?.sourceSystem, entry.data.sourceBinding?.sourceRecordId), entry]));
      const candidates = sourceResult.items.filter((source) => CANDIDACY.includes(source.projection.caseCandidacy.status)).map((source) => {
        const existing = bySource.get(bindingKey(source.sourceSystem, source.projection.sourceRecordId));
        return {
          signalId: source.projection.signalId,
          sourceSystem: source.sourceSystem,
          sourceRecordId: source.projection.sourceRecordId,
          sourceRecordVersion: source.item.version,
          projectionFingerprint: source.projection.projectionFingerprint,
          title: source.projection.title,
          summary: source.projection.summary,
          occurredAt: source.projection.occurredAt,
          riskClass: source.projection.riskClass,
          severity: source.projection.severity,
          evidenceQuality: source.projection.evidenceQuality,
          caseCandidacy: source.projection.caseCandidacy,
          existingCaseId: existing?.id || null,
          existingCaseNumber: existing?.data.caseNumber || null,
        };
      }).sort((a, b) => String(b.occurredAt || "").localeCompare(String(a.occurredAt || "")));
      const allCases = await Promise.all(entries.map((entry) => readDetails(db, entry)));
      allCases.sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")));
      const cases = allCases.slice(0, request.pageSize);
      return Object.freeze({
        contractVersion: "case-evidence-center-read-v1",
        tenantContext: {tenantId: context.tenantId, canonicalBrandId: context.brandId},
        summary: {
          openCases: allCases.filter((item) => !["closed", "archived"].includes(item.status)).length,
          evidenceAwaitingReview: allCases.reduce((sum, item) => sum + item.evidenceRefs.filter((evidence) => evidence.reviewStatus === "pending").length, 0),
          expertReview: allCases.filter((item) => item.stage === "expert_review").length,
          legalHold: allCases.filter((item) => item.legalHold?.active === true).length,
          reviewCandidates: candidates.filter((item) => !item.existingCaseId).length,
        },
        cases,
        caseCandidates: candidates,
        sourceAvailability: sourceResult.availability,
        readOnly: true,
        writesPerformed: 0,
      });
    },

    async create(raw, invocation) {
      const request = createRequest(raw);
      if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request});
      await ownerRequired({db, context});
      const openedAt = clock.now();
      const source = await exactSource({db, context, request, evaluatedAt: openedAt});
      if (!CANDIDACY.includes(source.projection.caseCandidacy.status)) {
        return {outcome: "blocked", blockerCodes: ["case.human_review_required"], dryRun: request.dryRun, transactionCommitted: false, writeAttempted: false};
      }
      if (source.item.version !== request.expectedSourceRecordVersion || source.projection.projectionFingerprint !== request.expectedProjectionFingerprint) {
        return {outcome: "conflict", blockerCodes: ["source.projection_stale"], dryRun: request.dryRun, transactionCommitted: false, writeAttempted: false};
      }
      const caseId = sha256(["case-file-v1", context.tenantId, context.brandId, request.sourceSystem, request.sourceRecordId].join("|"));
      const number = caseNumber(openedAt, caseId);
      if (request.dryRun) return {outcome: "dry_run_ready", caseNumber: number, blockerCodes: [], dryRun: true, transactionCommitted: false, writeAttempted: false};
      const caseRef = db.collection("case_files").doc(caseId);
      const eventRef = db.collection("case_events").doc(sha256(`${caseId}|opened`));
      const evidenceRef = db.collection("case_evidence_refs").doc(sha256(`${caseId}|source`));
      const auditRef = db.collection("case_audit_events").doc(sha256(`${caseId}|audit`));
      const result = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(caseRef);
        if (existing.exists) return {outcome: "already_exists", caseNumber: (existing.data() || {}).caseNumber || number, transactionCommitted: false, writeAttempted: false};
        const currentSource = await transaction.get(source.reference);
        if (!currentSource.exists || versionOf(currentSource) !== source.item.version) return {outcome: "conflict", blockerCodes: ["source.version_changed"], transactionCommitted: false, writeAttempted: false};
        const sourceBinding = {sourceSystem: request.sourceSystem, sourceRecordId: request.sourceRecordId, sourceRecordVersion: source.item.version, sourceRecordPath: source.reference.path, projectionFingerprint: source.projection.projectionFingerprint};
        transaction.create(caseRef, {contractVersion: "case-file-v1", schemaVersion: "case-file-schema-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseNumber: number, title: source.projection.title, summary: source.projection.summary, status: "open", stage: "initial_review", priority: priority(source.projection.severity), ownerUid: invocation.uid, riskClass: source.projection.riskClass, severity: source.projection.severity, evidenceQuality: source.projection.evidenceQuality, caseCandidacy: source.projection.caseCandidacy, sourceBinding, legalHold: {active: false, startedAt: null, releasedAt: null}, openedAt, updatedAt: openedAt, closedAt: null, archivedAt: null, lifecycleVersion: "v1"});
        transaction.create(eventRef, {contractVersion: "case-event-v1", caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "case_opened_from_risk", summary: "Risk sinyalinden kontrollü vaka dosyası açıldı.", occurredAt: openedAt, actorUid: invocation.uid, sourceBinding, appendOnly: true});
        transaction.create(evidenceRef, {contractVersion: "case-evidence-reference-v1", caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, referenceType: "source_record", title: "Kaynak risk kaydı", sourceSystem: request.sourceSystem, sourceRecordPath: source.reference.path, sourceRecordVersion: source.item.version, projectionFingerprint: source.projection.projectionFingerprint, reviewStatus: "pending", integrityStatus: "reference_only", capturedAt: source.projection.occurredAt || openedAt, createdAt: openedAt, createdBy: invocation.uid, appendOnly: true});
        transaction.create(auditRef, {contractVersion: "case-audit-event-v1", caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "case.created_from_risk", actorUid: invocation.uid, occurredAt: openedAt, correlationHash: sha256(request.correlationId).slice(0, 16), appendOnly: true});
        return {outcome: "created", caseNumber: number, transactionCommitted: true, writeAttempted: true};
      });
      return {...result, dryRun: false, blockerCodes: result.blockerCodes || []};
    },
  });
}

function mapError(error) {
  if (error.code === "unauthenticated") return new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  if (error.code === "source.not_found") return new HttpsError("not-found", "Kaynak risk kaydı bulunamadı.");
  if (error.code === "case.not_found") return new HttpsError("not-found", "Vaka dosyası bulunamadı.");
  if (["authorization.denied", "source.denied"].includes(error.code)) return new HttpsError("permission-denied", "Bu işlem için yeterli yetkiniz bulunmuyor.");
  return new HttpsError("invalid-argument", "Geçersiz vaka isteği.");
}
function createDetailHandler({db, clock, log = logger}) {
  const service = createService({db, clock});
  return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    try {
      const result = await service.detail(invocation.data || {}, {uid: invocation.auth.uid});
      log.info("Case evidence detail read completed", {event: "case_evidence_detail_read_completed", evidenceCount: result.evidenceReferences.length, eventCount: result.timelineEvents.length, auditCount: result.auditSummary.length, transactionCommitted: false, writeAttempted: false});
      return result;
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error);
      throw new HttpsError("internal", "Vaka ayrıntısı güvenli biçimde hazırlanamadı.");
    }
  };
}
function createListHandler({db, clock, log = logger}) {
  const service = createService({db, clock});
  return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    try {
      const result = await service.list(invocation.data || {}, {uid: invocation.auth.uid});
      log.info("Case evidence center read completed", {event: "case_evidence_center_read_completed", caseCount: result.cases.length, candidateCount: result.caseCandidates.length, appCheckPresent: Boolean(invocation.app?.appId), transactionCommitted: false, writeAttempted: false});
      return result;
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error);
      throw new HttpsError("internal", "Vaka ve delil görünümü güvenli biçimde hazırlanamadı.");
    }
  };
}
function createWriteHandler({db, clock, log = logger}) {
  const service = createService({db, clock});
  return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    let request;
    try {
      request = createRequest(invocation.data || {});
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error); throw error;
    }
    const appCheckPresent = Boolean(invocation.app?.appId);
    if (!request.dryRun && !appCheckPresent) throw new HttpsError("failed-precondition", "Gerçek vaka açılışı için uygulama doğrulaması gereklidir.");
    const logBase = {sourceIdentityHash: sha256(`${request.sourceSystem}:${request.sourceRecordId}`).slice(0, 16), correlationHash: sha256(request.correlationId).slice(0, 16), dryRun: request.dryRun, appCheckPresent, appCheckRequired: !request.dryRun};
    log.info("Case from risk started", {event: "case_from_risk_started", ...logBase});
    try {
      const result = await service.create(request, {uid: invocation.auth.uid});
      log.info("Case from risk completed", {event: "case_from_risk_completed", ...logBase, outcome: result.outcome, transactionCommitted: result.transactionCommitted, writeAttempted: result.writeAttempted, blockerCodes: result.blockerCodes});
      return result;
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error);
      throw new HttpsError("internal", "Vaka dosyası güvenli biçimde oluşturulamadı.");
    }
  };
}
function buildListCaseEvidenceCenter({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createListHandler({db, clock: {now: () => new Date().toISOString()}}));
}
function buildCreateCaseFromRiskOperation({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 1}, createWriteHandler({db, clock: {now: () => new Date().toISOString()}}));
}
function buildGetCaseEvidenceDetail({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createDetailHandler({db, clock: {now: () => new Date().toISOString()}}));
}

module.exports = {CaseEvidenceCenterError, buildCreateCaseFromRiskOperation, buildGetCaseEvidenceDetail, buildListCaseEvidenceCenter, createDetailHandler, createListHandler, createRequest, createService, createWriteHandler, detailRequest, listRequest, priority};
