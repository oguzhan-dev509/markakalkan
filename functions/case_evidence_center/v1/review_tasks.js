/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const TASK_TYPES = Object.freeze(["evidence_review", "source_verification", "marketplace_check", "technical_analysis", "laboratory_analysis", "legal_assessment", "field_investigation", "other"]);
const PRIORITIES = Object.freeze(["low", "medium", "high", "critical"]);
const ASSIGNEE_TYPES = Object.freeze(["unassigned", "internal_member", "external_expert", "laboratory"]);
const OUTCOMES = Object.freeze(["confirmed", "inconclusive", "not_confirmed", "action_required", "not_applicable"]);
const EVENTS = Object.freeze(["assignment_set", "assignment_changed", "review_started", "note_added", "due_date_changed", "review_completed", "task_cancelled"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class ReviewTaskError extends Error {
  constructor(code, message) {
    super(message); this.name = "ReviewTaskError"; this.code = code;
  }
}
const fail = (message, code = "invalid-argument") => {
  throw new ReviewTaskError(code, message);
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
function requestId(value) {
  const clean = text(value, "requestId", 36, 64); if (!UUID.test(clean)) fail("requestId invalid"); return clean.toLowerCase();
}
function canonical(value, values, name) {
  if (!values.includes(value)) fail(`${name} invalid`); return value;
}
function instant(value) {
  if (value == null) return null;
  const clean = text(value, "dueAt", 1, 80); const milliseconds = Date.parse(clean);
  if (!Number.isFinite(milliseconds)) fail("dueAt invalid");
  return new Date(milliseconds);
}
function dueDate(value, now) {
  const date = instant(value); if (!date) return null;
  if (date.getTime() < now.getTime() - 300000 || date.getTime() > now.getTime() + 2 * 366 * 86400000) fail("dueAt out of range");
  return date;
}
function assignment(raw) {
  const value = object(raw, "assignee"); const type = canonical(value.type, ASSIGNEE_TYPES, "assignee.type");
  const allowed = ["type", "uid", "displayLabel", "organization", "expertiseArea"];
  if (Object.keys(value).some((key) => !allowed.includes(key))) fail("assignee contract invalid");
  const uid = text(value.uid, "assignee.uid", 1, 128, true);
  const displayLabel = text(value.displayLabel, "assignee.displayLabel", 1, 160, true);
  const organization = text(value.organization, "assignee.organization", 1, 160, true);
  const expertiseArea = text(value.expertiseArea, "assignee.expertiseArea", 1, 160, true);
  if (type === "unassigned" && (uid || displayLabel || organization || expertiseArea)) fail("unassigned fields invalid");
  if (type === "internal_member" && !uid) fail("internal member uid required");
  if (type === "external_expert" && (!displayLabel || !expertiseArea || uid)) fail("external expert fields invalid");
  if (type === "laboratory" && (!(displayLabel || organization) || !expertiseArea || uid)) fail("laboratory fields invalid");
  return {type, uid, displayLabel, organization, expertiseArea};
}
function createRequest(raw, now) {
  strict(raw, "case-review-task-create-request-v1", ["caseId", "evidenceRefId", "title", "description", "taskType", "priority", "assignee", "dueAt", "requestId"]);
  return {caseId: text(raw.caseId, "caseId", 1, 128), evidenceRefId: text(raw.evidenceRefId, "evidenceRefId", 1, 128, true), title: text(raw.title, "title", 5, 160), description: text(raw.description, "description", 10, 3000), taskType: canonical(raw.taskType, TASK_TYPES, "taskType"), priority: canonical(raw.priority, PRIORITIES, "priority"), assignee: assignment(raw.assignee), dueAt: dueDate(raw.dueAt, now), requestId: requestId(raw.requestId)};
}
function eventRequest(raw, now) {
  object(raw); const eventType = canonical(raw.eventType, EVENTS, "eventType");
  const fields = ["taskId", "eventType", "note", "requestId"];
  if (["assignment_set", "assignment_changed"].includes(eventType)) fields.push("assignee");
  if (eventType === "due_date_changed") fields.push("dueAt");
  if (eventType === "review_completed") fields.push("resultOutcome", "resultSummary");
  strict(raw, "case-review-task-event-request-v1", fields);
  const result = {taskId: text(raw.taskId, "taskId", 1, 128), eventType, note: text(raw.note, "note", 3, 1000), requestId: requestId(raw.requestId)};
  if (fields.includes("assignee")) {
    result.assignee = assignment(raw.assignee);
    if (result.assignee.type === "unassigned") fail("assignment target required");
  }
  if (fields.includes("dueAt")) result.dueAt = dueDate(raw.dueAt, now);
  if (eventType === "review_completed") {
    result.resultOutcome = canonical(raw.resultOutcome, OUTCOMES, "resultOutcome");
    result.resultSummary = text(raw.resultSummary, "resultSummary", 10, 3000);
  }
  return result;
}
const iso = (value) => value == null ? null : (typeof value.toDate === "function" ? value.toDate().toISOString() : new Date(value).toISOString());
const eventLabel = (value) => ({task_created: "Görev oluşturuldu", assignment_set: "Görev atandı", assignment_changed: "Görev ataması değiştirildi", review_started: "İnceleme başlatıldı", note_added: "İnceleme notu eklendi", due_date_changed: "Son tarih değiştirildi", review_completed: "İnceleme tamamlandı", task_cancelled: "Görev iptal edildi"})[value] || "Görev işlemi";
const allowedActions = (status) => ({open: ["assign", "change_due_date", "cancel_task"], assigned: ["change_assignment", "start_review", "add_note", "change_due_date", "cancel_task"], in_review: ["add_note", "change_due_date", "complete_review", "cancel_task"]})[status] || [];
const taskStatus = (assigneeType) => assigneeType === "unassigned" ? "open" : "assigned";
const closed = (status) => ["closed", "archived"].includes(status);
const overdue = (task, now) => Boolean(task.dueAt && !["completed", "cancelled"].includes(task.status) && new Date(iso(task.dueAt)).getTime() < now.getTime());
function assignmentFields(value, label) {
  const fields = {assigneeType: value.type};
  if (value.uid) fields.assigneeUid = value.uid;
  if (label || value.displayLabel) fields.assigneeDisplayLabel = label || value.displayLabel;
  if (value.organization) fields.assigneeOrganization = value.organization;
  if (value.expertiseArea) fields.expertiseArea = value.expertiseArea;
  return fields;
}
function assignmentUpdateFields(value, label, deleteValue) {
  return {
    assigneeType: value.type,
    assigneeUid: value.uid || deleteValue,
    assigneeDisplayLabel: label || value.displayLabel || deleteValue,
    assigneeOrganization: value.organization || deleteValue,
    expertiseArea: value.expertiseArea || deleteValue,
  };
}
async function activeInternalMember(db, transaction, tenantId, uid) {
  const query = db.collection("tenant_memberships").where("tenantId", "==", tenantId).where("uid", "==", uid).limit(2);
  const snapshot = transaction ? await transaction.get(query) : await query.get();
  const member = snapshot.docs.find((doc) => (doc.data() || {}).status === "active");
  if (!member) fail("assignee not found", "not-found");
  const data = member.data() || {};
  return data.displayName || data.displayLabel || (data.role === "owner" ? "Marka yöneticisi" : "İç kullanıcı");
}
async function linked(db, caseId, evidenceRefId) {
  const caseSnapshot = await db.collection("case_files").doc(caseId).get();
  const evidenceSnapshot = evidenceRefId ? await db.collection("case_evidence_refs").doc(evidenceRefId).get() : null;
  return {caseSnapshot, evidenceSnapshot};
}
function safeTask(id, task, caseData, evidenceData, now) {
  return {taskId: id, taskNumber: task.taskNumber, caseId: task.caseId, caseNumber: caseData.caseNumber, caseTitle: caseData.title, evidenceRefId: task.evidenceRefId || null, evidenceLabel: evidenceData?.title || null, title: task.title, description: task.description, taskType: task.taskType, priority: task.priority, status: task.status, assigneeType: task.assigneeType, assigneeLabel: task.assigneeDisplayLabel || null, assigneeOrganization: task.assigneeOrganization || null, expertiseArea: task.expertiseArea || null, dueAt: iso(task.dueAt), isOverdue: overdue(task, now), resultOutcome: task.resultOutcome || null, resultSummary: task.resultSummary || null, createdAt: iso(task.createdAt), updatedAt: iso(task.updatedAt), startedAt: iso(task.startedAt), completedAt: iso(task.completedAt), cancelledAt: iso(task.cancelledAt), lastEventAt: iso(task.lastEventAt), eventCount: Number(task.eventCount || 0)};
}
function createReviewTaskService({db, clock = {now: () => new Date(), timestamp: (date) => date.toISOString()}}) {
  const nowDate = () => {
    const value = clock.now(); return value instanceof Date ? value : new Date(value);
  };
  const stamp = (date) => clock.timestamp ? clock.timestamp(date) : date.toISOString();
  return Object.freeze({
    async list(raw, invocation) {
      strict(raw, "case-review-task-list-request-v1", []); if (!invocation?.uid) fail("authentication required", "unauthenticated");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const now = nowDate();
      const snapshot = await db.collection("case_review_tasks").where("tenantId", "==", context.tenantId).limit(100).get(); const items = [];
      for (const doc of snapshot.docs) {
        const task = doc.data() || {}; if (task.canonicalBrandId !== context.brandId) continue;
        const {caseSnapshot, evidenceSnapshot} = await linked(db, task.caseId, task.evidenceRefId);
        if (!caseSnapshot.exists) continue; const caseData = caseSnapshot.data() || {};
        if (caseData.tenantId !== context.tenantId || caseData.canonicalBrandId !== context.brandId) continue;
        const evidenceData = evidenceSnapshot?.exists ? evidenceSnapshot.data() || {} : null;
        if (task.evidenceRefId && (!evidenceData || evidenceData.caseId !== task.caseId || evidenceData.tenantId !== context.tenantId || evidenceData.canonicalBrandId !== context.brandId)) continue;
        items.push(safeTask(doc.id, task, caseData, evidenceData, now));
      }
      items.sort((a, b) => String(b.updatedAt || b.createdAt).localeCompare(String(a.updatedAt || a.createdAt)));
      return {contractVersion: "case-review-task-list-v1", stats: {totalTasks: items.length, openTasks: items.filter((item) => item.status === "open").length, assignedTasks: items.filter((item) => item.status === "assigned").length, inReviewTasks: items.filter((item) => item.status === "in_review").length, overdueTasks: items.filter((item) => item.isOverdue).length, completedTasks: items.filter((item) => item.status === "completed").length}, items, readOnly: true, writesPerformed: 0};
    },
    async detail(raw, invocation) {
      strict(raw, "case-review-task-detail-request-v1", ["taskId"]); const taskId = text(raw.taskId, "taskId", 1, 128); if (!invocation?.uid) fail("authentication required", "unauthenticated");
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const taskSnapshot = await db.collection("case_review_tasks").doc(taskId).get();
      if (!taskSnapshot.exists) fail("task not found", "not-found"); const task = taskSnapshot.data() || {};
      if (task.tenantId !== context.tenantId || task.canonicalBrandId !== context.brandId) fail("task not found", "not-found");
      const {caseSnapshot, evidenceSnapshot} = await linked(db, task.caseId, task.evidenceRefId); const caseData = caseSnapshot.data() || {}; const evidenceData = evidenceSnapshot?.exists ? evidenceSnapshot.data() || {} : null;
      if (!caseSnapshot.exists || caseData.tenantId !== context.tenantId || caseData.canonicalBrandId !== context.brandId || (task.evidenceRefId && (!evidenceData || evidenceData.caseId !== task.caseId))) fail("task not found", "not-found");
      const events = await db.collection("case_review_task_events").where("taskId", "==", taskId).limit(100).get();
      return {contractVersion: "case-review-task-detail-v1", task: safeTask(taskSnapshot.id, task, caseData, evidenceData, nowDate()), timelineEvents: events.docs.map((doc) => doc.data() || {}).sort((a, b) => Number(a.sequence) - Number(b.sequence)).map((event) => ({sequence: event.sequence, eventType: event.eventType, eventLabel: eventLabel(event.eventType), note: event.note, actorLabel: event.actorLabel || "Yetkili kullanıcı", recordedAt: iso(event.recordedAt)})), allowedActions: allowedActions(task.status), readOnly: true, writesPerformed: 0};
    },
    async create(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const now = nowDate(); const request = createRequest(raw, now);
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const taskId = sha256(`${context.tenantId}|${request.caseId}|${request.requestId}`); const taskRef = db.collection("case_review_tasks").doc(taskId);
      return db.runTransaction(async (transaction) => {
        const caseRef = db.collection("case_files").doc(request.caseId); const caseSnapshot = await transaction.get(caseRef); const caseData = caseSnapshot.data() || {};
        if (!caseSnapshot.exists || caseData.tenantId !== context.tenantId || caseData.canonicalBrandId !== context.brandId) fail("case not found", "not-found"); if (closed(caseData.status)) fail("case closed", "failed-precondition");
        let evidenceData = null;
        if (request.evidenceRefId) {
          const evidenceSnapshot = await transaction.get(db.collection("case_evidence_refs").doc(request.evidenceRefId)); evidenceData = evidenceSnapshot.data() || {};
          if (!evidenceSnapshot.exists || evidenceData.caseId !== request.caseId || evidenceData.tenantId !== context.tenantId || evidenceData.canonicalBrandId !== context.brandId) fail("evidence not found", "not-found");
        }
        const existing = await transaction.get(taskRef);
        if (existing.exists) {
          const task = existing.data() || {}; return {contractVersion: "case-review-task-create-result-v1", ok: true, duplicate: true, taskId, taskNumber: task.taskNumber, status: task.status, eventCount: task.eventCount};
        }
        let memberLabel = null; if (request.assignee.type === "internal_member") memberLabel = await activeInternalMember(db, transaction, context.tenantId, request.assignee.uid);
        const recordedAt = stamp(now); const status = taskStatus(request.assignee.type); const taskNumber = `GV-${now.getUTCFullYear()}-${taskId.slice(0, 8).toUpperCase()}`;
        const collision = await transaction.get(db.collection("case_review_tasks").where("taskNumber", "==", taskNumber).limit(1));
        if (collision.docs.length) fail("task number collision", "failed-precondition");
        const createdEventId = sha256(`${taskId}|created`);
        const task = {contractVersion: "case-review-task-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, taskNumber, caseId: request.caseId, title: request.title, description: request.description, taskType: request.taskType, priority: request.priority, status, ...assignmentFields(request.assignee, memberLabel), createdByUid: invocation.uid, createdAt: recordedAt, updatedAt: recordedAt, lastEventType: "task_created", lastEventAt: recordedAt, lastEventId: createdEventId, eventCount: 1};
        if (request.evidenceRefId) task.evidenceRefId = request.evidenceRefId; if (request.dueAt) task.dueAt = stamp(request.dueAt);
        const eventRef = db.collection("case_review_task_events").doc(createdEventId); const base = {tenantId: context.tenantId, canonicalBrandId: context.brandId, taskId, caseId: request.caseId};
        transaction.create(taskRef, task); transaction.create(eventRef, {contractVersion: "case-review-task-event-v1", ...base, ...(request.evidenceRefId ? {evidenceRefId: request.evidenceRefId} : {}), sequence: 1, eventType: "task_created", note: "İnceleme görevi oluşturuldu.", actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, payloadSummary: eventLabel("task_created")});
        transaction.create(db.collection("case_events").doc(sha256(`${taskId}|case`)), {contractVersion: "case-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: "review_task_created", summary: `${taskNumber} inceleme görevi oluşturuldu.`, occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${taskId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: request.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: "review_task.created", actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        return {contractVersion: "case-review-task-create-result-v1", ok: true, duplicate: false, taskId, taskNumber, status, eventCount: 1};
      });
    },
    async append(raw, invocation) {
      if (!invocation?.uid) fail("authentication required", "unauthenticated"); const now = nowDate(); const request = eventRequest(raw, now);
      const context = await resolveTenantContextV1({db, uid: invocation.uid, request: {}}); const taskRef = db.collection("case_review_tasks").doc(request.taskId); const eventId = sha256(`${context.tenantId}|${request.taskId}|${request.requestId}`); const eventRef = db.collection("case_review_task_events").doc(eventId);
      return db.runTransaction(async (transaction) => {
        const taskSnapshot = await transaction.get(taskRef); const task = taskSnapshot.data() || {};
        if (!taskSnapshot.exists || task.tenantId !== context.tenantId || task.canonicalBrandId !== context.brandId) fail("task not found", "not-found");
        const caseSnapshot = await transaction.get(db.collection("case_files").doc(task.caseId)); const caseData = caseSnapshot.data() || {};
        if (!caseSnapshot.exists || caseData.tenantId !== context.tenantId || caseData.canonicalBrandId !== context.brandId) fail("task not found", "not-found"); if (closed(caseData.status)) fail("case closed", "failed-precondition");
        if (task.evidenceRefId) {
          const evidenceSnapshot = await transaction.get(db.collection("case_evidence_refs").doc(task.evidenceRefId)); const evidence = evidenceSnapshot.data() || {};
          if (!evidenceSnapshot.exists || evidence.caseId !== task.caseId || evidence.tenantId !== context.tenantId || evidence.canonicalBrandId !== context.brandId) fail("task not found", "not-found");
        }
        const existing = await transaction.get(eventRef);
        if (existing.exists) {
          const event = existing.data() || {}; return {contractVersion: "case-review-task-event-result-v1", ok: true, duplicate: true, taskId: request.taskId, taskNumber: task.taskNumber, sequence: event.sequence, eventType: event.eventType, eventLabel: eventLabel(event.eventType), status: task.status, assigneeLabel: task.assigneeDisplayLabel || null, dueAt: iso(task.dueAt), resultOutcome: task.resultOutcome || null, eventCount: task.eventCount};
        }
        if (["completed", "cancelled"].includes(task.status)) fail("task terminal", "failed-precondition");
        const expected = {assignment_set: ["open"], assignment_changed: ["assigned"], review_started: ["assigned"], note_added: ["assigned", "in_review"], due_date_changed: ["open", "assigned", "in_review"], review_completed: ["in_review"], task_cancelled: ["open", "assigned", "in_review"]}[request.eventType];
        if (!expected.includes(task.status)) fail("transition denied", "failed-precondition");
        let memberLabel = null; if (request.assignee?.type === "internal_member") memberLabel = await activeInternalMember(db, transaction, context.tenantId, request.assignee.uid);
        const sequence = Number(task.eventCount || 0) + 1; const recordedAt = stamp(now); const update = {updatedAt: recordedAt, lastEventType: request.eventType, lastEventAt: recordedAt, eventCount: sequence};
        if (request.eventType === "assignment_set" || request.eventType === "assignment_changed") Object.assign(update, assignmentUpdateFields(request.assignee, memberLabel, clock.deleteValue ? clock.deleteValue() : undefined), {status: "assigned"});
        if (request.eventType === "review_started") Object.assign(update, {status: "in_review", startedAt: recordedAt});
        if (request.eventType === "due_date_changed") update.dueAt = stamp(request.dueAt);
        if (request.eventType === "review_completed") Object.assign(update, {status: "completed", completedAt: recordedAt, resultOutcome: request.resultOutcome, resultSummary: request.resultSummary});
        if (request.eventType === "task_cancelled") Object.assign(update, {status: "cancelled", cancelledAt: recordedAt});
        const event = {contractVersion: "case-review-task-event-v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, taskId: request.taskId, caseId: task.caseId, ...(task.evidenceRefId ? {evidenceRefId: task.evidenceRefId} : {}), sequence, eventType: request.eventType, note: request.note, actorUid: invocation.uid, actorLabel: "Yetkili kullanıcı", recordedAt, previousEventId: task.lastEventId, payloadSummary: eventLabel(request.eventType)};
        update.lastEventId = eventId; transaction.create(eventRef, event); transaction.update(taskRef, update);
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {contractVersion: "case-event-v1", caseId: task.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, eventType: `review_task_${request.eventType}`, summary: eventLabel(request.eventType), occurredAt: recordedAt, actorUid: invocation.uid, appendOnly: true});
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {contractVersion: "case-audit-event-v1", caseId: task.caseId, tenantId: context.tenantId, canonicalBrandId: context.brandId, action: `review_task.${request.eventType}`, actorUid: invocation.uid, occurredAt: recordedAt, appendOnly: true});
        const next = {...task, ...update}; return {contractVersion: "case-review-task-event-result-v1", ok: true, duplicate: false, taskId: request.taskId, taskNumber: task.taskNumber, sequence, eventType: request.eventType, eventLabel: eventLabel(request.eventType), status: next.status, assigneeLabel: next.assigneeDisplayLabel || null, dueAt: iso(next.dueAt), resultOutcome: next.resultOutcome || null, eventCount: sequence};
      });
    },
  });
}
function mapError(error) {
  const code = error.code === "unauthenticated" ? "unauthenticated" : error.code === "not-found" ? "not-found" : error.code === "failed-precondition" ? "failed-precondition" : error.code === "invalid-argument" ? "invalid-argument" : "permission-denied";
  return new HttpsError(code, code === "not-found" ? "İnceleme görevi bulunamadı." : code === "failed-precondition" ? "Görev işlemi mevcut durumda gerçekleştirilemiyor." : code === "invalid-argument" ? "Görev isteği geçersiz." : code === "unauthenticated" ? "Oturum açmanız gerekir." : "Bu işlem için yetkiniz bulunmuyor.");
}
function handler(method, {db, clock, appCheck = false, log = logger}) {
  const service = createReviewTaskService({db, clock}); return async (invocation) => {
    if (!invocation.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    if (appCheck && !invocation.app?.appId) throw new HttpsError("failed-precondition", "Görev işlemi için uygulama doğrulaması gereklidir.");
    try {
      const result = await service[method](invocation.data || {}, {uid: invocation.auth.uid});
      log.info("Case review task callable completed", {event: `case_review_task_${method}_completed`, duplicate: result.duplicate === true, transactionCommitted: ["create", "append"].includes(method) && result.duplicate !== true, writeAttempted: ["create", "append"].includes(method) && result.duplicate !== true}); return result;
    } catch (error) {
      if (error instanceof ReviewTaskError) throw mapError(error); throw new HttpsError("internal", "Görev işlemi güvenli biçimde tamamlanamadı.");
    }
  };
}
const productionClock = (admin) => ({now: () => new Date(), timestamp: (date) => admin.firestore.Timestamp.fromDate(date), deleteValue: () => admin.firestore.FieldValue.delete()});
const buildListCaseReviewTasks = ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, handler("list", {db, clock: productionClock(admin)}));
const buildGetCaseReviewTaskDetail = ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, handler("detail", {db, clock: productionClock(admin)}));
const buildCreateCaseReviewTask = ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, handler("create", {db, clock: productionClock(admin), appCheck: true}));
const buildAppendCaseReviewTaskEvent = ({db, admin}) => onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, handler("append", {db, clock: productionClock(admin), appCheck: true}));

module.exports = {ReviewTaskError, allowedActions, buildAppendCaseReviewTaskEvent, buildCreateCaseReviewTask, buildGetCaseReviewTaskDetail, buildListCaseReviewTasks, createRequest, createReviewTaskService, eventRequest, handler};
