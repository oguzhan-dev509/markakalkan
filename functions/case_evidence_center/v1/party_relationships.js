/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PARTY_TYPES = Object.freeze(["person", "organization", "seller_account", "marketplace_store", "marketplace_operator", "website", "social_media_account", "manufacturer", "supplier", "logistics_provider", "payment_intermediary", "laboratory", "expert", "public_authority", "legal_representative", "address", "other"]);
const PARTY_ROLES = Object.freeze(["suspected_seller", "suspected_operator", "manufacturer", "supplier", "marketplace", "payment_recipient", "logistics_provider", "complainant", "reporter", "witness", "expert", "laboratory", "authority", "legal_representative", "related_party", "other"]);
const RELATIONSHIP_TYPES = Object.freeze(["owns", "operates", "manages", "sells_for", "supplies", "manufactures_for", "ships_for", "receives_payment_for", "represents", "uses_same_identity", "uses_same_contact_point", "uses_same_address", "appears_in_evidence", "assigned_to_task", "reported_by", "investigated_by", "verified_by", "linked_to", "other"]);
const CONFIDENCE = Object.freeze(["low", "medium", "high", "confirmed"]);
const ENDPOINT_TYPES = Object.freeze(["party", "case", "evidence", "task"]);
const PARTY_EVENTS = Object.freeze(["party_review_started", "party_verified", "party_disputed", "party_note_added", "party_deactivated"]);
const RELATIONSHIP_EVENTS = Object.freeze(["relationship_review_started", "relationship_confirmed", "relationship_disputed", "relationship_note_added", "relationship_deactivated"]);
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class CaseGraphError extends Error {
  constructor(code, message) {
    super(message); this.name = "CaseGraphError"; this.code = code;
  }
}
const fail = (message, code = "invalid-argument") => {
  throw new CaseGraphError(code, message);
};
function object(value, name = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail(`${name} invalid`);
  return value;
}
function text(value, name, min, max, optional = false) {
  if (optional && value == null) return null;
  if (typeof value !== "string") fail(`${name} invalid`);
  const clean = value.trim();
  if (clean.length < min || clean.length > max || [...clean].some((character) => {
    const code = character.charCodeAt(0); return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  })) fail(`${name} invalid`);
  return clean;
}
function strict(raw, version, fields) {
  object(raw); const allowed = ["contractVersion", ...fields];
  if (raw.contractVersion !== version || Object.keys(raw).some((key) => !allowed.includes(key))) fail("request contract invalid");
}
function canonical(value, values, name) {
  if (!values.includes(value)) fail(`${name} invalid`); return value;
}
function requestId(value) {
  const clean = text(value, "requestId", 36, 64); if (!UUID.test(clean)) fail("requestId invalid"); return clean.toLowerCase();
}
function iso(value) {
  if (value == null) return null;
  if (typeof value === "string") return value.trim() && !Number.isNaN(Date.parse(value)) ? value : null;
  try {
    const date = value instanceof Date ? value : value.toDate?.();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date.toISOString() : null;
  } catch {
    return null;
  }
}
function optionalFields(target, values) {
  for (const [key, value] of Object.entries(values)) if (value != null) target[key] = value;
  return target;
}
function partyCreateRequest(raw) {
  strict(raw, "case-party-create-request-v1", ["caseId", "displayName", "partyType", "caseRoles", "publicAlias", "organizationName", "countryCode", "city", "description", "requestId"]);
  if (!Array.isArray(raw.caseRoles)) fail("caseRoles invalid");
  const caseRoles = [...new Set(raw.caseRoles.map((value) => canonical(value, PARTY_ROLES, "caseRoles")))];
  if (caseRoles.length < 1 || caseRoles.length > 5) fail("caseRoles invalid");
  const countryCode = text(raw.countryCode, "countryCode", 2, 2, true);
  if (countryCode && !/^[A-Z]{2}$/.test(countryCode)) fail("countryCode invalid");
  return {caseId: text(raw.caseId, "caseId", 1, 128), displayName: text(raw.displayName, "displayName", 3, 160), partyType: canonical(raw.partyType, PARTY_TYPES, "partyType"), caseRoles, publicAlias: text(raw.publicAlias, "publicAlias", 1, 160, true), organizationName: text(raw.organizationName, "organizationName", 1, 160, true), countryCode, city: text(raw.city, "city", 1, 120, true), description: text(raw.description, "description", 10, 3000), requestId: requestId(raw.requestId)};
}
function partyProfileUpdateRequest(raw) {
  strict(raw, "case-party-profile-update-request-v1", ["partyId", "displayName", "partyType", "caseRoles", "publicAlias", "organizationName", "countryCode", "city", "description", "note", "requestId"]);
  if (!Array.isArray(raw.caseRoles)) fail("caseRoles invalid");
  const caseRoles = [...new Set(raw.caseRoles.map((value) => canonical(value, PARTY_ROLES, "caseRoles")))];
  if (caseRoles.length < 1 || caseRoles.length > 5) fail("caseRoles invalid");
  const countryCode = text(raw.countryCode, "countryCode", 2, 2, true)?.toUpperCase() || null;
  if (countryCode && !/^[A-Z]{2}$/.test(countryCode)) fail("countryCode invalid");
  return {partyId: text(raw.partyId, "partyId", 1, 128), displayName: text(raw.displayName, "displayName", 3, 160), partyType: canonical(raw.partyType, PARTY_TYPES, "partyType"), caseRoles, publicAlias: text(raw.publicAlias, "publicAlias", 1, 160, true), organizationName: text(raw.organizationName, "organizationName", 1, 160, true), countryCode, city: text(raw.city, "city", 1, 120, true), description: text(raw.description, "description", 10, 3000), note: text(raw.note, "note", 3, 1000), requestId: requestId(raw.requestId)};
}
function endpoint(raw, name) {
  object(raw, name); if (Object.keys(raw).some((key) => !["entityType", "entityId"].includes(key))) fail(`${name} invalid`);
  return {entityType: canonical(raw.entityType, ENDPOINT_TYPES, `${name}.entityType`), entityId: text(raw.entityId, `${name}.entityId`, 1, 128)};
}
function relationshipCreateRequest(raw) {
  strict(raw, "case-relationship-create-request-v1", ["caseId", "source", "target", "relationshipType", "confidence", "summary", "supportingEvidenceRefId", "requestId"]);
  const source = endpoint(raw.source, "source"); const target = endpoint(raw.target, "target");
  if (source.entityType !== "party" && target.entityType !== "party") fail("party endpoint required");
  if (source.entityType === target.entityType && source.entityId === target.entityId) fail("endpoints must differ");
  return {caseId: text(raw.caseId, "caseId", 1, 128), source, target, relationshipType: canonical(raw.relationshipType, RELATIONSHIP_TYPES, "relationshipType"), confidence: canonical(raw.confidence, CONFIDENCE.filter((item) => item !== "confirmed"), "confidence"), summary: text(raw.summary, "summary", 10, 2000), supportingEvidenceRefId: text(raw.supportingEvidenceRefId, "supportingEvidenceRefId", 1, 128, true), requestId: requestId(raw.requestId)};
}
function graphEventRequest(raw) {
  strict(raw, "case-graph-event-request-v1", ["targetType", "targetId", "eventType", "note", "requestId"]);
  const targetType = canonical(raw.targetType, ["party", "relationship"], "targetType");
  const eventType = canonical(raw.eventType, targetType === "party" ? PARTY_EVENTS : RELATIONSHIP_EVENTS, "eventType");
  return {targetType, targetId: text(raw.targetId, "targetId", 1, 128), eventType, note: text(raw.note, "note", 3, 1000), requestId: requestId(raw.requestId)};
}
const eventLabel = (value) => ({party_created: "Taraf kaydı oluşturuldu", party_review_started: "Taraf incelemesi başlatıldı", party_verified: "Taraf doğrulandı", party_disputed: "Taraf ihtilaflı olarak işaretlendi", party_note_added: "Taraf notu eklendi", party_profile_updated: "Taraf bilgileri güncellendi", party_deactivated: "Taraf pasife alındı", relationship_created: "İlişki kaydı oluşturuldu", relationship_review_started: "İlişki incelemesi başlatıldı", relationship_confirmed: "İlişki doğrulandı", relationship_disputed: "İlişki ihtilaflı olarak işaretlendi", relationship_note_added: "İlişki notu eklendi", relationship_deactivated: "İlişki pasife alındı"})[value] || "Vaka bağlantısı işlemi";
const timelineEventLabel = (value) => ({
  case_opened_from_risk: "Vaka dosyası açıldı",
  evidence_chain_started: "Delil zinciri başlatıldı",
  review_task_created: "İnceleme görevi oluşturuldu",
  review_task_due_date_changed: "Görev son tarihi değiştirildi",
  party_created: "Taraf kaydı oluşturuldu",
  party_profile_updated: "Taraf bilgileri güncellendi",
  relationship_created: "İlişki kaydı oluşturuldu",
  ...Object.fromEntries([...PARTY_EVENTS, ...RELATIONSHIP_EVENTS].map((item) => [item, eventLabel(item)])),
})[value] || "Vaka olayı";
const allowedActions = (type, status) => {
  const shared = status === "inactive" ? [] : ["add_note", "deactivate"];
  const edit = type === "party" && status !== "inactive" ? ["edit_profile"] : [];
  if (status === "observed") return ["start_review", type === "party" ? "verify" : "confirm", "dispute", ...edit, ...shared];
  if (status === "under_review") return [type === "party" ? "verify" : "confirm", "dispute", ...edit, ...shared];
  if (status === (type === "party" ? "verified" : "confirmed")) return ["dispute", ...edit, ...shared];
  if (status === "disputed") return ["start_review", ...edit, ...shared];
  return [];
};
const eventAction = (type, value) => ({
  [`${type}_review_started`]: "start_review",
  [`${type}_${type === "party" ? "verified" : "confirmed"}`]: type === "party" ? "verify" : "confirm",
  [`${type}_disputed`]: "dispute",
  [`${type}_note_added`]: "add_note",
  [`${type}_deactivated`]: "deactivate",
})[value];
const nextStatus = (type, current, eventType) => {
  const action = eventAction(type, eventType);
  if (!allowedActions(type, current).includes(action)) fail("transition denied", "failed-precondition");
  return ({start_review: "under_review", verify: "verified", confirm: "confirmed", dispute: "disputed", deactivate: "inactive", add_note: current})[action];
};
const category = (eventType, explicit) => {
  if (["case", "evidence", "task", "party", "relationship"].includes(explicit)) return explicit;
  if (/^(evidence_|chain_)/.test(eventType)) return "evidence";
  if (/^(review_task_|task_)/.test(eventType)) return "task";
  if (/^party_/.test(eventType)) return "party";
  if (/^relationship_/.test(eventType)) return "relationship";
  return "case";
};
const categoryLabel = (value) => ({case: "Vaka", evidence: "Delil", task: "Görev", party: "Taraf", relationship: "İlişki"})[value] || "Vaka";
const closed = (status) => ["closed", "archived"].includes(status);

async function scopedCase(db, transaction, caseId, context) {
  const snapshot = await (transaction ? transaction.get(db.collection("case_files").doc(caseId)) : db.collection("case_files").doc(caseId).get());
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) fail("case not found", "not-found");
  return {snapshot, data};
}
async function resolveEndpoint(db, transaction, endpointValue, caseId, context, caseData) {
  if (endpointValue.entityType === "case") {
    if (endpointValue.entityId !== caseId) fail("endpoint not found", "not-found");
    return {label: `${caseData.caseNumber} · ${caseData.title}`};
  }
  const collection = {party: "case_parties", evidence: "case_evidence_refs", task: "case_review_tasks"}[endpointValue.entityType];
  const snapshot = await transaction.get(db.collection(collection).doc(endpointValue.entityId)); const data = snapshot.data() || {};
  if (!snapshot.exists || data.caseId !== caseId || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) fail("endpoint not found", "not-found");
  return {data, label: data.displayName || data.title || data.partyNumber || data.taskNumber || "Bağlı kayıt"};
}
function safeParty(id, item, caseData, relationshipCount = 0) {
  return optionalFields({partyId: id, partyNumber: item.partyNumber, caseId: item.caseId, caseNumber: caseData.caseNumber, caseTitle: caseData.title, displayName: item.displayName, partyType: item.partyType, caseRoles: item.caseRoles, status: item.status, relationshipCount, createdAt: iso(item.createdAt), updatedAt: iso(item.updatedAt), lastEventAt: iso(item.lastEventAt)}, {publicAlias: item.publicAlias, organizationName: item.organizationName, countryCode: item.countryCode, city: item.city, description: item.description, eventCount: Number(item.eventCount || 0)});
}
function safeRelationship(id, item, caseData, evidenceLabel = null) {
  return optionalFields({relationshipId: id, relationshipNumber: item.relationshipNumber, caseId: item.caseId, caseNumber: caseData.caseNumber, sourceEntityType: item.sourceEntityType, sourceEntityId: item.sourceEntityId, sourceLabel: item.sourceLabelSnapshot, targetEntityType: item.targetEntityType, targetEntityId: item.targetEntityId, targetLabel: item.targetLabelSnapshot, relationshipType: item.relationshipType, status: item.status, confidence: item.confidence, summary: item.summary, createdAt: iso(item.createdAt), updatedAt: iso(item.updatedAt), lastEventAt: iso(item.lastEventAt)}, {supportingEvidenceRefId: item.supportingEvidenceRefId, supportingEvidenceLabel: evidenceLabel});
}
const PROFILE_FIELDS = Object.freeze(["displayName", "partyType", "caseRoles", "publicAlias", "organizationName", "countryCode", "city", "description"]);
function profileOf(value) {
  return Object.fromEntries(PROFILE_FIELDS.map((field) => [field, field === "caseRoles" ? [...(value[field] || [])] : (value[field] ?? null)]));
}
function sameProfile(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function createCaseGraphService({db, clock = {now: () => new Date(), timestamp: (date) => date.toISOString()}}) {
  const nowDate = () => {
    const value = clock.now(); return value instanceof Date ? value : new Date(value);
  };
  const stamp = (date) => clock.timestamp ? clock.timestamp(date) : date.toISOString();
  return Object.freeze({
    async workspace(raw, invocation) {
      strict(raw, "case-party-workspace-list-request-v1", []); if (!invocation?.uid) fail("authentication required", "unauthenticated");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}});
      const [caseSnapshot, partySnapshot, relationshipSnapshot] = await Promise.all([db.collection("case_files").where("tenantId", "==", context.tenantId).limit(100).get(), db.collection("case_parties").where("tenantId", "==", context.tenantId).limit(200).get(), db.collection("case_relationships").where("tenantId", "==", context.tenantId).limit(300).get()]);
      const cases = caseSnapshot.docs.map((doc) => ({id: doc.id, data: doc.data() || {}})).filter((item) => item.data.canonicalBrandId === context.brandId);
      const byCase = new Map(cases.map((item) => [item.id, item.data]));
      const relationships = relationshipSnapshot.docs.map((doc) => ({id: doc.id, data: doc.data() || {}})).filter((item) => item.data.canonicalBrandId === context.brandId && byCase.has(item.data.caseId));
      const counts = new Map(); for (const item of relationships) for (const endpointId of [item.data.sourceEntityId, item.data.targetEntityId]) counts.set(endpointId, (counts.get(endpointId) || 0) + 1);
      const parties = partySnapshot.docs.map((doc) => ({id: doc.id, data: doc.data() || {}})).filter((item) => item.data.canonicalBrandId === context.brandId && byCase.has(item.data.caseId)).map((item) => safeParty(item.id, item.data, byCase.get(item.data.caseId), counts.get(item.id) || 0)).sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
      const safeRelationships = relationships.map((item) => safeRelationship(item.id, item.data, byCase.get(item.data.caseId))).sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
      return {contractVersion: "case-party-workspace-list-v1", stats: {totalParties: parties.length, observedParties: parties.filter((item) => item.status === "observed").length, underReviewParties: parties.filter((item) => item.status === "under_review").length, verifiedParties: parties.filter((item) => item.status === "verified").length, disputedParties: parties.filter((item) => item.status === "disputed").length, activeRelationships: safeRelationships.filter((item) => item.status !== "inactive").length}, cases: cases.map((item) => ({caseId: item.id, caseNumber: item.data.caseNumber, caseTitle: item.data.title, status: item.data.status})), parties, relationships: safeRelationships, readOnly: true, writesPerformed: 0};
    },
    async partyDetail(raw, invocation) {
      strict(raw, "case-party-detail-request-v1", ["partyId"]); const partyId = text(raw.partyId, "partyId", 1, 128); if (!invocation?.uid) fail("authentication required", "unauthenticated");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const snapshot = await db.collection("case_parties").doc(partyId).get(); const party = snapshot.data() || {};
      if (!snapshot.exists || party.tenantId !== context.tenantId || party.canonicalBrandId !== context.brandId) fail("party not found", "not-found");
      const linkedCase = await scopedCase(db, null, party.caseId, context);
      const [relationshipsSnapshot, eventSnapshot] = await Promise.all([db.collection("case_relationships").where("tenantId", "==", context.tenantId).limit(300).get(), db.collection("case_graph_events").where("targetKey", "==", `party:${partyId}`).limit(200).get()]);
      const relationships = relationshipsSnapshot.docs.map((doc) => ({id: doc.id, data: doc.data() || {}})).filter((item) => item.data.canonicalBrandId === context.brandId && item.data.caseId === party.caseId && [item.data.sourceEntityId, item.data.targetEntityId].includes(partyId)).map((item) => safeRelationship(item.id, item.data, linkedCase.data));
      const timelineEvents = eventSnapshot.docs.map((doc) => doc.data() || {}).filter((item) => item.tenantId === context.tenantId && item.canonicalBrandId === context.brandId).sort((a, b) => Number(a.sequence) - Number(b.sequence)).map((item) => ({sequence: item.sequence, eventType: item.eventType, eventLabel: eventLabel(item.eventType), note: item.note, actorLabel: item.actorLabel || "Yetkili kullanıcı", recordedAt: iso(item.recordedAt)}));
      return {contractVersion: "case-party-detail-v1", party: safeParty(partyId, party, linkedCase.data, relationships.length), relationships, timelineEvents, allowedActions: allowedActions("party", party.status), readOnly: true, writesPerformed: 0};
    },
    async timeline(raw, invocation) {
      strict(raw, "case-unified-timeline-request-v1", ["caseId"]); const caseId = text(raw.caseId, "caseId", 1, 128); if (!invocation?.uid) fail("authentication required", "unauthenticated");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const linkedCase = await scopedCase(db, null, caseId, context);
      const snapshot = await db.collection("case_events").where("caseId", "==", caseId).limit(500).get();
      const events = snapshot.docs.map((doc) => doc.data() || {}).filter((item) => item.tenantId === context.tenantId && item.canonicalBrandId === context.brandId).map((item) => {
        const eventCategory = category(item.eventType || "", item.category); return {eventType: item.eventType, eventLabel: timelineEventLabel(item.eventType), category: eventCategory, categoryLabel: categoryLabel(eventCategory), summary: item.summary || "Vaka olayı", occurredAt: iso(item.occurredAt)};
      }).sort((a, b) => String(b.occurredAt || "").localeCompare(String(a.occurredAt || "")));
      const count = (value) => events.filter((item) => item.category === value).length;
      return {contractVersion: "case-unified-timeline-v1", case: {caseId, caseNumber: linkedCase.data.caseNumber, caseTitle: linkedCase.data.title, status: linkedCase.data.status}, stats: {totalEvents: events.length, caseEvents: count("case"), evidenceEvents: count("evidence"), taskEvents: count("task"), partyEvents: count("party"), relationshipEvents: count("relationship")}, events, readOnly: true, writesPerformed: 0};
    },
    async createParty(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const request = partyCreateRequest(raw); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const now = nowDate(); const recordedAt = stamp(now); const partyId = sha256(`${context.tenantId}|${request.caseId}|${request.requestId}`); const partyRef = db.collection("case_parties").doc(partyId);
      return db.runTransaction(async (transaction) => {
        const linkedCase = await scopedCase(db, transaction, request.caseId, context); if (closed(linkedCase.data.status)) fail("case closed", "failed-precondition");
        const existing = await transaction.get(partyRef); if (existing.exists) return {contractVersion: "case-party-create-result-v1", ok: true, duplicate: true, partyId, partyNumber: existing.data().partyNumber, status: existing.data().status, eventCount: existing.data().eventCount};
        const partyNumber = `TRF-${now.getUTCFullYear()}-${partyId.slice(0, 8).toUpperCase()}`; const collision = await transaction.get(db.collection("case_parties").where("partyNumber", "==", partyNumber).limit(1)); if (collision.docs.length) fail("party number collision", "failed-precondition");
        const eventId = sha256(`${context.tenantId}|party|${partyId}|${request.requestId}`); const party = optionalFields({contractVersion: "case-party-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, partyNumber, caseId: request.caseId, displayName: request.displayName, partyType: request.partyType, caseRoles: request.caseRoles, status: "observed", description: request.description, createdByUid: invocation.uid, createdAt: recordedAt, updatedAt: recordedAt, lastEventType: "party_created", lastEventAt: recordedAt, lastEventId: eventId, eventCount: 1}, {publicAlias: request.publicAlias, organizationName: request.organizationName, countryCode: request.countryCode, city: request.city});
        transaction.create(partyRef, party); transaction.create(db.collection("case_graph_events").doc(eventId), {contractVersion: "case-graph-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, targetType: "party", targetId: partyId, targetKey: `party:${partyId}`, sequence: 1, eventType: "party_created", note: "Taraf kaydı oluşturuldu.", actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, payloadSummary: eventLabel("party_created")});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "party_created", category: "party", summary: `${partyNumber} taraf kaydı oluşturuldu.`, occurredAt: now.toISOString(), actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "party.created", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-party-create-result-v1", ok: true, duplicate: false, partyId, partyNumber, status: "observed", eventCount: 1};
      });
    },
    async createRelationship(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const request = relationshipCreateRequest(raw); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const now = nowDate(); const recordedAt = stamp(now); const relationshipId = sha256(`${context.tenantId}|${request.caseId}|${request.requestId}`); const relationshipRef = db.collection("case_relationships").doc(relationshipId);
      return db.runTransaction(async (transaction) => {
        const linkedCase = await scopedCase(db, transaction, request.caseId, context); if (closed(linkedCase.data.status)) fail("case closed", "failed-precondition");
        const existing = await transaction.get(relationshipRef); if (existing.exists) {
          const item = existing.data() || {}; return {contractVersion: "case-relationship-create-result-v1", ok: true, duplicate: true, relationshipId, relationshipNumber: item.relationshipNumber, status: item.status, confidence: item.confidence, eventCount: item.eventCount};
        }
        const source = await resolveEndpoint(db, transaction, request.source, request.caseId, context, linkedCase.data); const target = await resolveEndpoint(db, transaction, request.target, request.caseId, context, linkedCase.data);
        let supportingEvidenceLabel = null; if (request.supportingEvidenceRefId) supportingEvidenceLabel = (await resolveEndpoint(db, transaction, {entityType: "evidence", entityId: request.supportingEvidenceRefId}, request.caseId, context, linkedCase.data)).label;
        const relationshipNumber = `IL-${now.getUTCFullYear()}-${relationshipId.slice(0, 8).toUpperCase()}`; const collision = await transaction.get(db.collection("case_relationships").where("relationshipNumber", "==", relationshipNumber).limit(1)); if (collision.docs.length) fail("relationship number collision", "failed-precondition");
        const eventId = sha256(`${context.tenantId}|relationship|${relationshipId}|${request.requestId}`); const relationship = optionalFields({contractVersion: "case-relationship-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, relationshipNumber, caseId: request.caseId, sourceEntityType: request.source.entityType, sourceEntityId: request.source.entityId, sourceLabelSnapshot: source.label, targetEntityType: request.target.entityType, targetEntityId: request.target.entityId, targetLabelSnapshot: target.label, relationshipType: request.relationshipType, status: "observed", confidence: request.confidence, summary: request.summary, createdByUid: invocation.uid, createdAt: recordedAt, updatedAt: recordedAt, lastEventType: "relationship_created", lastEventAt: recordedAt, lastEventId: eventId, eventCount: 1}, {supportingEvidenceRefId: request.supportingEvidenceRefId, supportingEvidenceLabel});
        transaction.create(relationshipRef, relationship); transaction.create(db.collection("case_graph_events").doc(eventId), {contractVersion: "case-graph-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: request.caseId, targetType: "relationship", targetId: relationshipId, targetKey: `relationship:${relationshipId}`, sequence: 1, eventType: "relationship_created", note: "İlişki kaydı oluşturuldu.", actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, payloadSummary: eventLabel("relationship_created")});
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "relationship_created", category: "relationship", summary: `${relationshipNumber} ilişki kaydı oluşturuldu.`, occurredAt: now.toISOString(), actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "relationship.created", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-relationship-create-result-v1", ok: true, duplicate: false, relationshipId, relationshipNumber, status: "observed", confidence: request.confidence, eventCount: 1};
      });
    },
    async updatePartyProfile(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const request = partyProfileUpdateRequest(raw); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const now = nowDate(); const recordedAt = stamp(now); const partyRef = db.collection("case_parties").doc(request.partyId); const eventId = sha256(`${context.tenantId}|party|${request.partyId}|${request.requestId}`); const eventRef = db.collection("case_graph_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const partySnapshot = await transaction.get(partyRef); const party = partySnapshot.data() || {};
        if (!partySnapshot.exists || party.tenantId !== context.tenantId || party.canonicalBrandId !== context.brandId) fail("party not found", "not-found");
        const linkedCase = await scopedCase(db, transaction, party.caseId, context); if (closed(linkedCase.data.status)) fail("case closed", "failed-precondition"); if (party.status === "inactive") fail("party inactive", "failed-precondition");
        const existing = await transaction.get(eventRef); if (existing.exists) return {contractVersion: "case-party-profile-update-result-v1", ok: true, duplicate: true, noChange: false, partyId: request.partyId, partyNumber: party.partyNumber, status: party.status, eventCount: party.eventCount, changedFields: existing.data().payloadSummary?.changedFields || []};
        const beforeSnapshot = profileOf(party); const afterSnapshot = profileOf(request); const changedFields = PROFILE_FIELDS.filter((field) => !sameProfile(beforeSnapshot[field], afterSnapshot[field]));
        if (!changedFields.length) return {contractVersion: "case-party-profile-update-result-v1", ok: true, duplicate: false, noChange: true, partyId: request.partyId, partyNumber: party.partyNumber, status: party.status, eventCount: party.eventCount, changedFields: [], transactionCommitted: false};
        const sequence = Number(party.eventCount || 0) + 1; const update = {displayName: request.displayName, partyType: request.partyType, caseRoles: request.caseRoles, description: request.description, updatedAt: recordedAt, lastEventType: "party_profile_updated", lastEventAt: recordedAt, lastEventId: eventId, eventCount: sequence};
        for (const field of ["publicAlias", "organizationName", "countryCode", "city"]) {
          if (request[field] != null) update[field] = request[field];
          else if (party[field] != null) update[field] = clock.deleteValue ? clock.deleteValue() : null;
        }
        transaction.update(partyRef, update);
        const graphEvent = {contractVersion: "case-graph-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: party.caseId, targetType: "party", targetId: request.partyId, targetKey: `party:${request.partyId}`, sequence, eventType: "party_profile_updated", note: request.note, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, payloadSummary: {changedFields, beforeSnapshot, afterSnapshot}}; if (party.lastEventId) graphEvent.previousEventId = party.lastEventId; transaction.create(eventRef, graphEvent);
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: party.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "party_profile_updated", category: "party", summary: `${party.partyNumber} taraf bilgileri güncellendi.`, occurredAt: now.toISOString(), actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: party.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "party.profile_updated", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-party-profile-update-result-v1", ok: true, duplicate: false, noChange: false, partyId: request.partyId, partyNumber: party.partyNumber, status: party.status, eventCount: sequence, changedFields};
      });
    },
    async append(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const request = graphEventRequest(raw); const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const now = nowDate(); const recordedAt = stamp(now); const collection = request.targetType === "party" ? "case_parties" : "case_relationships"; const targetRef = db.collection(collection).doc(request.targetId); const eventId = sha256(`${context.tenantId}|${request.targetType}|${request.targetId}|${request.requestId}`); const eventRef = db.collection("case_graph_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const targetSnapshot = await transaction.get(targetRef); const target = targetSnapshot.data() || {};
        if (!targetSnapshot.exists || target.tenantId !== context.tenantId || target.canonicalBrandId !== context.brandId) fail("target not found", "not-found");
        const linkedCase = await scopedCase(db, transaction, target.caseId, context); if (closed(linkedCase.data.status)) fail("case closed", "failed-precondition");
        const existing = await transaction.get(eventRef); if (existing.exists) return {contractVersion: "case-graph-event-result-v1", ok: true, duplicate: true, targetType: request.targetType, sequence: existing.data().sequence, eventType: existing.data().eventType, eventLabel: eventLabel(existing.data().eventType), status: target.status, eventCount: target.eventCount};
        const status = nextStatus(request.targetType, target.status, request.eventType); const sequence = Number(target.eventCount || 0) + 1;
        const event = {contractVersion: "case-graph-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, caseId: target.caseId, targetType: request.targetType, targetId: request.targetId, targetKey: `${request.targetType}:${request.targetId}`, sequence, eventType: request.eventType, note: request.note, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, payloadSummary: eventLabel(request.eventType)}; if (target.lastEventId) event.previousEventId = target.lastEventId;
        const update = {status, updatedAt: recordedAt, lastEventType: request.eventType, lastEventAt: recordedAt, lastEventId: eventId, eventCount: sequence}; if (request.eventType === "relationship_confirmed" && !["high", "confirmed"].includes(target.confidence)) update.confidence = "high";
        transaction.create(eventRef, event); transaction.update(targetRef, update);
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: target.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: request.eventType, category: request.targetType, summary: eventLabel(request.eventType), occurredAt: now.toISOString(), actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: target.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: request.eventType.replace("_", "."), actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-graph-event-result-v1", ok: true, duplicate: false, targetType: request.targetType, sequence, eventType: request.eventType, eventLabel: eventLabel(request.eventType), status, eventCount: sequence};
      });
    },
  });
}

function mapError(error) {
  const code = ["unauthenticated", "not-found", "failed-precondition", "invalid-argument"].includes(error.code) ? error.code : "permission-denied";
  return new HttpsError(code, code === "not-found" ? "Vaka bağlantısı kaydı bulunamadı." : code === "failed-precondition" ? "İşlem mevcut durumda gerçekleştirilemiyor." : code === "invalid-argument" ? "Vaka bağlantısı isteği geçersiz." : code === "unauthenticated" ? "Oturum açmanız gerekir." : "Bu işlem için yetkiniz bulunmuyor.");
}
function handler(method, {db, clock, appCheck = false, log = logger}) {
  const service = createCaseGraphService({db, clock}); return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    if (appCheck && !invocation.app?.appId) throw new HttpsError("failed-precondition", "İşlem için uygulama doğrulaması gereklidir.");
    try {
      const result = await service[method](invocation.data || {}, {uid: invocation.auth.uid}); log.info("Case party graph callable completed", {event: `case_party_graph_${method}_completed`, duplicate: result.duplicate === true, transactionCommitted: ["createParty", "createRelationship", "append"].includes(method) && result.duplicate !== true, writeAttempted: ["createParty", "createRelationship", "append"].includes(method) && result.duplicate !== true}); return result;
    } catch (error) {
      if (error instanceof CaseGraphError) throw mapError(error); throw new HttpsError("internal", "Vaka bağlantısı işlemi güvenli biçimde tamamlanamadı.");
    }
  };
}
const productionClock = (admin) => ({now: () => new Date(), timestamp: (date) => admin.firestore.Timestamp.fromDate(date), deleteValue: () => admin.firestore.FieldValue.delete()});
const read = (method) => ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, handler(method, {db, clock: productionClock(admin)}));
const write = (method) => ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, handler(method, {db, clock: productionClock(admin), appCheck: true}));

module.exports = {
  CaseGraphError,
  allowedActions,
  buildAppendCaseGraphEvent: write("append"),
  buildCreateCaseParty: write("createParty"),
  buildCreateCaseRelationship: write("createRelationship"),
  buildGetCasePartyDetail: read("partyDetail"),
  buildGetCaseUnifiedTimeline: read("timeline"),
  buildListCasePartyWorkspace: read("workspace"),
  buildUpdateCasePartyProfile: write("updatePartyProfile"),
  createCaseGraphService,
  graphEventRequest,
  handler,
  partyCreateRequest,
  partyProfileUpdateRequest,
  relationshipCreateRequest,
};
