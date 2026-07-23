/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {monitoringProjection, traceabilityProjection} = require("../../risk_operations/v1/projection");
const {resolveTenantContextV1, sharedRiskProjection} = require("../../risk_operations/v1/service");

const SOURCES = Object.freeze(["monitoring", "traceability", "digital_detective", "shared_risk"]);
const CANDIDACY = Object.freeze(["review_candidate", "strong_candidate"]);
const CHAIN_EVENTS = Object.freeze(["chain_started", "custody_received", "custody_transferred", "review_started", "review_completed", "sealed", "unsealed"]);
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
function strictVersionRequest(raw, version, extra = []) {
  objectRequired(raw); const allowed = ["contractVersion", ...extra];
  if (Object.keys(raw).some((key) => !allowed.includes(key)) || raw.contractVersion !== version) throw new CaseEvidenceCenterError("invalid-argument", "request contract invalid");
  return raw;
}
function vaultListRequest(raw) {
  strictVersionRequest(raw, "case-evidence-vault-list-request-v1"); return Object.freeze({contractVersion: raw.contractVersion});
}
function evidenceDetailRequest(raw) {
  strictVersionRequest(raw, "case-evidence-item-detail-request-v1", ["evidenceRefId"]);
  return Object.freeze({contractVersion: raw.contractVersion, evidenceRefId: requiredString(raw.evidenceRefId, "evidenceRefId", 128)});
}
function chainEventRequest(raw) {
  strictVersionRequest(raw, "case-evidence-chain-event-request-v1", ["evidenceRefId", "eventType", "note", "requestId"]);
  const eventType = requiredString(raw.eventType, "eventType", 40); if (!CHAIN_EVENTS.includes(eventType)) throw new CaseEvidenceCenterError("invalid-argument", "eventType invalid");
  const note = requiredString(raw.note, "note", 500); const forbiddenControl = [...note].some((character) => {
    const code = character.charCodeAt(0); return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  }); if (note.length < 3 || forbiddenControl) throw new CaseEvidenceCenterError("invalid-argument", "note invalid");
  return Object.freeze({contractVersion: raw.contractVersion, evidenceRefId: requiredString(raw.evidenceRefId, "evidenceRefId", 128), eventType, note, requestId: requiredString(raw.requestId, "requestId", 128)});
}
const eventLabel = (value) => ({chain_started: "Delil zinciri başlatıldı", custody_received: "Delil teslim alındı", custody_transferred: "Delil teslim edildi", review_started: "İnceleme başlatıldı", review_completed: "İnceleme tamamlandı", sealed: "Delil mühürlendi", unsealed: "Delil mührü açıldı"})[value] || "Delil zinciri işlemi";
const evidenceReview = (data) => data.reviewStatus === "pending" ? "awaiting_review" : (data.reviewStatus || "awaiting_review");
const evidenceCustody = (data) => data.custodyStatus || (Number(data.chainEventCount || 0) > 0 ? "registered" : "not_started");
function genesisHash(id, data) {
  return sha256(JSON.stringify(["case-evidence-genesis-v1", id, data.tenantId || "", data.canonicalBrandId || "", data.caseId || "", data.referenceType || "", data.title || "", data.createdAt || ""]));
}
function chainHash(previousHash, payload) {
  return sha256(previousHash + JSON.stringify([payload.sequence, payload.eventType, payload.note, payload.actorUid, payload.recordedAt]));
}
function allowedActions(data) {
  const count = Number(data.chainEventCount || 0); if (count === 0) return ["chain_started"];
  const review = evidenceReview(data); const custody = evidenceCustody(data); const actions = ["custody_received", "custody_transferred"];
  if (review === "awaiting_review") actions.push("review_started");
  if (review === "under_review") actions.push("review_completed");
  if (custody === "sealed") actions.push("unsealed"); else actions.push("sealed");
  return actions.filter((action) => action !== data.lastChainEventType);
}
function transition(data, type) {
  if (!allowedActions(data).includes(type)) throw new CaseEvidenceCenterError("transition.denied", "transition denied");
  let reviewStatus = evidenceReview(data); let custodyStatus = evidenceCustody(data);
  if (type === "chain_started") {
    reviewStatus = "awaiting_review"; custodyStatus = "registered";
  }
  if (type === "review_started") reviewStatus = "under_review";
  if (type === "review_completed") reviewStatus = "verified";
  if (type === "sealed") custodyStatus = "sealed";
  if (type === "unsealed") custodyStatus = "registered";
  return {reviewStatus, custodyStatus};
}
async function caseForEvidence(db, evidence) {
  const snapshot = await db.collection("case_files").doc(evidence.caseId).get(); return snapshot.exists ? {id: snapshot.id, data: snapshot.data() || {}} : null;
}
function safeEvidence(id, data, caseData, integrityStatus) {
  return {evidenceRefId: id, caseId: data.caseId, caseNumber: caseData.caseNumber, caseTitle: caseData.title, evidenceLabel: data.title || "Delil kaydı", evidenceType: data.referenceType || "evidence_record", sourceLabel: data.sourceSystem || "other", reviewStatus: evidenceReview(data), custodyStatus: evidenceCustody(data), integrityStatus, chainEventCount: Number(data.chainEventCount || 0), createdAt: data.createdAt || data.capturedAt || null, lastChainEventAt: data.lastChainEventAt || null};
}
function verifyChain(id, evidence, events) {
  if (!events.length) return {status: "not_started", events: []}; let previous = genesisHash(id, evidence);
  const sorted = [...events].sort((a, b) => Number(a.data.sequence) - Number(b.data.sequence));
  for (let index = 0; index < sorted.length; index++) {
    const item = sorted[index]; const expected = chainHash(previous, item.data); if (item.data.sequence !== index + 1 || item.data.previousHash !== previous || item.data.chainHash !== expected) return {status: "broken", events: sorted}; previous = item.data.chainHash;
  }
  if (evidence.chainHeadHash !== previous || Number(evidence.chainEventCount || 0) !== sorted.length) return {status: "broken", events: sorted}; return {status: "verified", events: sorted};
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
    async vaultList(raw, invocation) {
      vaultListRequest(raw); if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const snapshot = await db.collection("case_evidence_refs").where("tenantId", "==", context.tenantId).limit(100).get(); const items = [];
      for (const doc of snapshot.docs.map(dataOf)) {
        if (doc.data.canonicalBrandId !== context.brandId) continue; const linkedCase = await caseForEvidence(db, doc.data); if (!linkedCase || linkedCase.data.tenantId !== context.tenantId || linkedCase.data.canonicalBrandId !== context.brandId) continue; const events = await query(db, "case_evidence_chain_events", "evidenceRefId", doc.id, 100); items.push(safeEvidence(doc.id, doc.data, linkedCase.data, verifyChain(doc.id, doc.data, events).status));
      }
      return {contractVersion: "case-evidence-vault-list-v1", stats: {totalEvidence: items.length, awaitingReview: items.filter((i) => i.reviewStatus === "awaiting_review").length, underReview: items.filter((i) => i.reviewStatus === "under_review").length, verified: items.filter((i) => i.reviewStatus === "verified").length, sealed: items.filter((i) => i.custodyStatus === "sealed").length, chainNotStarted: items.filter((i) => i.integrityStatus === "not_started").length}, items, readOnly: true, writesPerformed: 0};
    },
    async evidenceDetail(raw, invocation) {
      const request = evidenceDetailRequest(raw); if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required"); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const snapshot = await db.collection("case_evidence_refs").doc(request.evidenceRefId).get(); if (!snapshot.exists) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); const data = snapshot.data() || {}; if (data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); const linkedCase = await caseForEvidence(db, data); if (!linkedCase || linkedCase.data.tenantId !== context.tenantId || linkedCase.data.canonicalBrandId !== context.brandId) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); const events = await query(db, "case_evidence_chain_events", "evidenceRefId", snapshot.id, 100); const verified = verifyChain(snapshot.id, data, events);
      return {contractVersion: "case-evidence-item-detail-v1", evidence: safeEvidence(snapshot.id, data, linkedCase.data, verified.status), chainEvents: verified.events.map((item) => ({sequence: item.data.sequence, eventType: item.data.eventType, eventLabel: eventLabel(item.data.eventType), note: item.data.note, actorLabel: item.data.actorDisplayLabel || "Yetkili kullanıcı", recordedAt: item.data.recordedAt})), allowedActions: allowedActions(data), readOnly: true, writesPerformed: 0};
    },
    async appendChainEvent(raw, invocation) {
      const request = chainEventRequest(raw); if (!invocation?.uid) throw new CaseEvidenceCenterError("unauthenticated", "authentication required"); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const recordedAt = clock.now(); const evidenceRef = db.collection("case_evidence_refs").doc(request.evidenceRefId); const eventId = sha256([context.tenantId, request.evidenceRefId, request.requestId].join("|")); const eventRef = db.collection("case_evidence_chain_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const evidenceSnapshot = await transaction.get(evidenceRef); if (!evidenceSnapshot.exists) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); const data = evidenceSnapshot.data() || {}; if (data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); const caseRef = db.collection("case_files").doc(data.caseId); const caseSnapshot = await transaction.get(caseRef); const caseData = caseSnapshot.data() || {}; if (!caseSnapshot.exists || caseData.tenantId !== context.tenantId || caseData.canonicalBrandId !== context.brandId) throw new CaseEvidenceCenterError("evidence.not_found", "evidence not found"); if (["closed", "archived"].includes(caseData.status)) throw new CaseEvidenceCenterError("transition.denied", "case closed"); const existing = await transaction.get(eventRef); if (existing.exists) {
          const prior = existing.data() || {}; return {contractVersion: "case-evidence-chain-event-result-v1", ok: true, duplicate: true, evidenceRefId: request.evidenceRefId, sequence: prior.sequence, eventType: prior.eventType, eventLabel: eventLabel(prior.eventType), reviewStatus: evidenceReview(data), custodyStatus: evidenceCustody(data), integrityStatus: "verified", chainEventCount: Number(data.chainEventCount || 0)};
        }
        const state = transition(data, request.eventType); const sequence = Number(data.chainEventCount || 0) + 1; const previousHash = sequence === 1 ? genesisHash(evidenceSnapshot.id, data) : data.chainHeadHash; if (!previousHash) throw new CaseEvidenceCenterError("transition.denied", "chain head missing"); const payload = {sequence, eventType: request.eventType, note: request.note, actorUid: invocation.uid, recordedAt}; const nextHash = chainHash(previousHash, payload); const event = {contractVersion: "case-evidence-chain-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: data.caseId, evidenceRefId: request.evidenceRefId, ...payload, actorDisplayLabel: "Yetkili kullanıcı", previousHash, chainHash: nextHash}; transaction.create(eventRef, event); transaction.update(evidenceRef, {chainInitializedAt: data.chainInitializedAt || recordedAt, chainHeadHash: nextHash, chainEventCount: sequence, lastChainEventAt: recordedAt, lastChainEventType: request.eventType, reviewStatus: state.reviewStatus, custodyStatus: state.custodyStatus, updatedAt: recordedAt}); transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: data.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: `evidence_${request.eventType}`, summary: eventLabel(request.eventType), occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true}); transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: data.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: `evidence.${request.eventType}`, actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true}); return {contractVersion: "case-evidence-chain-event-result-v1", ok: true, duplicate: false, evidenceRefId: request.evidenceRefId, sequence, eventType: request.eventType, eventLabel: eventLabel(request.eventType), reviewStatus: state.reviewStatus, custodyStatus: state.custodyStatus, integrityStatus: "verified", chainEventCount: sequence};
      });
    },
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
        evidenceReferences: evidence.filter(belongs).map((item) => ({evidenceRefId: item.id, title: item.data.title, sourceType: item.data.sourceSystem, reviewStatus: item.data.reviewStatus, integrityStatus: item.data.integrityStatus, capturedAt: item.data.capturedAt, createdAt: item.data.createdAt})).sort((a, b) => String(a.createdAt || "").localeCompare(String(b.createdAt || ""))),
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
  if (error.code === "evidence.not_found") return new HttpsError("not-found", "Delil kaydı bulunamadı.");
  if (error.code === "transition.denied") return new HttpsError("failed-precondition", "Bu delil zinciri işlemi mevcut durumda uygulanamaz.");
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
function createVaultListHandler({db, clock, log = logger}) {
  const service = createService({db, clock}); return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir."); try {
      const result = await service.vaultList(invocation.data || {}, {uid: invocation.auth.uid}); log.info("Evidence vault read completed", {event: "case_evidence_vault_read_completed", itemCount: result.items.length, transactionCommitted: false, writeAttempted: false}); return result;
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error); throw new HttpsError("internal", "Delil kasası güvenli biçimde hazırlanamadı.");
    }
  };
}
function createEvidenceItemDetailHandler({db, clock, log = logger}) {
  const service = createService({db, clock}); return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir."); try {
      return await service.evidenceDetail(invocation.data || {}, {uid: invocation.auth.uid});
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error); log.error("Evidence detail failed", {event: "case_evidence_item_detail_failed"}); throw new HttpsError("internal", "Delil ayrıntısı güvenli biçimde hazırlanamadı.");
    }
  };
}
function createAppendChainEventHandler({db, clock, log = logger}) {
  const service = createService({db, clock}); return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir."); if (!invocation.app?.appId) throw new HttpsError("failed-precondition", "Delil zinciri işlemi için uygulama doğrulaması gereklidir."); try {
      const result = await service.appendChainEvent(invocation.data || {}, {uid: invocation.auth.uid}); log.info("Evidence chain event completed", {event: "case_evidence_chain_event_completed", eventType: result.eventType, sequence: result.sequence, duplicate: result.duplicate, transactionCommitted: !result.duplicate, writeAttempted: !result.duplicate}); return result;
    } catch (error) {
      if (error instanceof CaseEvidenceCenterError) throw mapError(error); throw new HttpsError("internal", "Delil zinciri işlemi tamamlanamadı.");
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
function buildListCaseEvidenceVault({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createVaultListHandler({db, clock: {now: () => new Date().toISOString()}}));
}
function buildGetCaseEvidenceItemDetail({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createEvidenceItemDetailHandler({db, clock: {now: () => new Date().toISOString()}}));
}
function buildAppendCaseEvidenceChainEvent({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createAppendChainEventHandler({db, clock: {now: () => new Date().toISOString()}}));
}

module.exports = {CaseEvidenceCenterError, buildAppendCaseEvidenceChainEvent, buildCreateCaseFromRiskOperation, buildGetCaseEvidenceDetail, buildGetCaseEvidenceItemDetail, buildListCaseEvidenceCenter, buildListCaseEvidenceVault, chainEventRequest, createAppendChainEventHandler, createDetailHandler, createEvidenceItemDetailHandler, createListHandler, createRequest, createService, createVaultListHandler, createWriteHandler, detailRequest, evidenceDetailRequest, listRequest, priority, vaultListRequest};
