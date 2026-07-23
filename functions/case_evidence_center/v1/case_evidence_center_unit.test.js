/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {createAppendChainEventHandler, createDetailHandler, createListHandler, createService, createWriteHandler, detailRequest, listRequest} = require("./index");
const {createRequest: createReviewTaskRequest, createReviewTaskService, eventRequest: reviewTaskEventRequest, handler: reviewTaskHandler} = require("./review_tasks");

class Snapshot {
  constructor(id, data, path, exists = true, version = "2026-07-22T10:00:00.000Z") {
    this.id = id; this._data = data; this.exists = exists; this.ref = {path}; this.updateTime = {toDate: () => new Date(version)};
  }
  data() {
    return this._data;
  }
}
class Query {
  constructor(store, name, filters = [], maximum = 1000) {
    this.store = store; this.name = name; this.filters = filters; this.maximum = maximum;
  }
  where(field, op, value) {
    assert.equal(op, "=="); return new Query(this.store, this.name, [...this.filters, [field, value]], this.maximum);
  }
  limit(value) {
    return new Query(this.store, this.name, this.filters, value);
  }
  async get() {
    return {docs: (this.store.collections[this.name] || []).filter((item) => this.filters.every(([field, value]) => item.data[field] === value)).slice(0, this.maximum).map((item) => new Snapshot(item.id, item.data, `${this.name}/${item.id}`, true, item.version))};
  }
}
class Ref {
  constructor(store, path) {
    this.store = store; this.path = path; this.id = path.split("/").at(-1);
  }
  collection(name) {
    return new Query(this.store, `${this.path}/${name}`);
  }
  async get() {
    return this.store.snapshot(this.path);
  }
}
class Collection extends Query {
  doc(id) {
    return new Ref(this.store, `${this.name}/${id}`);
  }
}
class Transaction {
  constructor(store) {
    this.store = store; this.pending = [];
  }
  async get(ref) {
    if (ref instanceof Query) return ref.get();
    return this.store.snapshot(ref.path);
  }
  create(ref, data) {
    this.pending.push({type: "create", path: ref.path, data});
  }
  update(ref, data) {
    this.pending.push({type: "update", path: ref.path, data});
  }
  commit() {
    for (const entry of this.pending) {
      const parts = entry.path.split("/"); const id = parts.pop(); const name = parts.join("/");
      this.store.collections[name] ||= [];
      if (entry.type === "update") {
        const current = this.store.collections[name].find((item) => item.id === id); current.data = {...current.data, ...entry.data}; current.version = entry.data.updatedAt || current.version;
      } else this.store.collections[name].push({id, data: entry.data, version: entry.data.updatedAt || entry.data.occurredAt});
      this.store.writes++;
    }
  }
}
class FakeDb {
  constructor(collections, {transactionFailure = false} = {}) {
    this.collections = structuredClone(collections); this.writes = 0; this.transactionFailure = transactionFailure;
  }
  collection(name) {
    return new Collection(this, name);
  }
  snapshot(path) {
    const parts = path.split("/"); const id = parts.pop(); const name = parts.join("/"); const item = (this.collections[name] || []).find((entry) => entry.id === id);
    return item ? new Snapshot(id, item.data, path, true, item.version) : new Snapshot(id, {}, path, false);
  }
  async runTransaction(callback) {
    const transaction = new Transaction(this); const result = await callback(transaction); if (this.transactionFailure) throw new Error("simulated transaction failure"); if (result.transactionCommitted !== false) transaction.commit(); return result;
  }
}

const collections = {
  "tenant_memberships": [{id: "membership-1", data: {uid: "user-1", tenantId: "tenant-1", status: "active", role: "owner"}}],
  "canonical_brands": [{id: "brand-1", data: {tenantId: "tenant-1", status: "active"}}],
  "monitoring_signals": [{id: "monitoring-1", version: "2026-07-22T10:00:00.000Z", data: {tenantId: "tenant-1", brandId: "brand-1", pageId: "page-1", signalLevel: "critical", status: "new", title: "Şüpheli pazar yeri ilanı", summary: "Birden fazla kaynakla desteklenen risk.", detectedAt: "2026-07-22T09:00:00.000Z", createdAt: "2026-07-22T09:00:00.000Z", evidenceVerified: true, confidence: .95}}],
  "verificationScans": [], "shared_risk_signals": [], "brands/user-1/digitalDetectiveTasks": [], "case_files": [], "case_events": [], "case_evidence_refs": [], "case_audit_events": [], "case_review_tasks": [], "case_review_task_events": [],
};
const clock = {now: () => "2026-07-22T11:00:00.000Z"};

async function candidate(service) {
  return (await service.list({}, {uid: "user-1"})).caseCandidates[0];
}

test("list contract is strict", () => {
  assert.equal(listRequest({pageSize: 50}).pageSize, 50);
  assert.throws(() => listRequest({pageSize: 51}), /pageSize/);
  assert.throws(() => listRequest({unknown: true}), /unsupported/);
});

test("read model returns review candidate with zero writes", async () => {
  const db = new FakeDb(collections); const result = await createService({db, clock}).list({}, {uid: "user-1"});
  assert.equal(result.contractVersion, "case-evidence-center-read-v1"); assert.equal(result.caseCandidates.length, 1); assert.equal(result.cases.length, 0); assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0);
});

test("list returns internal case id and user case number together", async () => {
  const withCase = structuredClone(collections);
  withCase.case_files = [{
    id: "internal-case-123",
    data: {
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      caseNumber: "VK-2026-EA953C48",
      title: "Şüpheli pazar yeri ilanı",
      summary: "Güvenli vaka özeti.",
      status: "open",
      stage: "initial_review",
      priority: "high",
      updatedAt: "2026-07-22T11:00:00.000Z",
      sourceBinding: {sourceSystem: "monitoring", sourceRecordId: "monitoring-1"},
    },
  }];
  const db = new FakeDb(withCase);
  const result = await createService({db, clock}).list({}, {uid: "user-1"});
  assert.equal(result.cases[0].caseId, "internal-case-123");
  assert.equal(result.cases[0].caseNumber, "VK-2026-EA953C48");
  assert.notEqual(result.cases[0].caseId, result.cases[0].caseNumber);
  assert.notEqual(result.cases[0].caseId, "monitoring-1");
  assert.equal(result.caseCandidates[0].existingCaseId, "internal-case-123");
  assert.equal(result.caseCandidates[0].existingCaseNumber, "VK-2026-EA953C48");
  assert.equal(result.writesPerformed, 0);
  assert.equal(db.writes, 0);
});

test("dry-run validates source and writes nothing", async () => {
  const db = new FakeDb(collections); const service = createService({db, clock}); const item = await candidate(service);
  const result = await service.create({sourceSystem: item.sourceSystem, sourceRecordId: item.sourceRecordId, expectedSourceRecordVersion: item.sourceRecordVersion, expectedProjectionFingerprint: item.projectionFingerprint, correlationId: "correlation-0001", dryRun: true}, {uid: "user-1"});
  assert.equal(result.outcome, "dry_run_ready"); assert.equal(result.transactionCommitted, false); assert.equal(db.writes, 0);
});

test("real creation is atomic and idempotent", async () => {
  const db = new FakeDb(collections); const service = createService({db, clock}); const item = await candidate(service);
  const request = {sourceSystem: item.sourceSystem, sourceRecordId: item.sourceRecordId, expectedSourceRecordVersion: item.sourceRecordVersion, expectedProjectionFingerprint: item.projectionFingerprint, correlationId: "correlation-0002", dryRun: false};
  const first = await service.create(request, {uid: "user-1"}); assert.equal(first.outcome, "created"); assert.equal(db.writes, 4);
  const second = await service.create(request, {uid: "user-1"}); assert.equal(second.outcome, "already_exists"); assert.equal(db.writes, 4);
});

test("callables require auth and App Check for real write", async () => {
  const db = new FakeDb(collections); const log = {info: () => {}}; const list = createListHandler({db, clock, log});
  await assert.rejects(() => list({data: {}}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  const item = (await list({auth: {uid: "user-1"}, data: {}})).caseCandidates[0];
  const write = createWriteHandler({db, clock, log}); const request = {sourceSystem: item.sourceSystem, sourceRecordId: item.sourceRecordId, expectedSourceRecordVersion: item.sourceRecordVersion, expectedProjectionFingerprint: item.projectionFingerprint, correlationId: "correlation-0003", dryRun: false};
  await assert.rejects(() => write({auth: {uid: "user-1"}, data: request}), (error) => error instanceof HttpsError && error.code === "failed-precondition");
  assert.equal((await write({auth: {uid: "user-1"}, app: {appId: "verified"}, data: request})).outcome, "created");
});

function detailCollections() {
  return {
    ...collections,
    "case_files": [{id: "case-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseNumber: "VK-2026-ABC12345", title: "Şüpheli ilan", summary: "Güvenli vaka özeti.", status: "open", priority: "high", sourceBinding: {sourceSystem: "monitoring", sourceRecordId: "secret-source", sourceRecordPath: "monitoring_signals/secret-source", projectionFingerprint: "secret-fingerprint"}, openedAt: "2026-07-22T10:00:00.000Z", updatedAt: "2026-07-22T11:00:00.000Z", idempotencyKey: "secret-key"}}],
    "case_evidence_refs": [
      {id: "evidence-2", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", title: "İkinci delil", sourceSystem: "monitoring", reviewStatus: "pending", integrityStatus: "reference_only", createdAt: "2026-07-22T10:02:00.000Z", projectionFingerprint: "secret"}},
      {id: "evidence-1", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", title: "İlk delil", sourceSystem: "monitoring", reviewStatus: "pending", integrityStatus: "reference_only", createdAt: "2026-07-22T10:01:00.000Z"}},
      {id: "other", data: {caseId: "case-other", tenantId: "tenant-1", canonicalBrandId: "brand-1", title: "Başka vaka"}},
    ],
    "case_events": [
      {id: "event-2", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", eventType: "reviewed", summary: "İkinci olay", occurredAt: "2026-07-22T10:04:00.000Z"}},
      {id: "event-1", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", eventType: "opened", summary: "İlk olay", occurredAt: "2026-07-22T10:03:00.000Z"}},
    ],
    "case_audit_events": [
      {id: "audit-invalid", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.invalid", occurredAt: "not-a-date", actorUid: "secret-actor"}},
      {id: "audit-null", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.null", occurredAt: null}},
      {id: "audit-string", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.created_from_risk", occurredAt: "2026-07-22T10:05:00.000Z", correlationHash: "secret"}},
      {id: "audit-date", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.date", occurredAt: new Date("2026-07-22T10:06:00.000Z")}},
    ],
  };
}

test("detail request contract is strict", () => {
  assert.equal(detailRequest({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1"}).caseId, "case-1");
  assert.throws(() => detailRequest({caseId: "case-1"}), /detail request/);
  assert.throws(() => detailRequest({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1", extra: true}), /detail request/);
});

test("detail reads tenant and brand scoped records in safe chronological contract with zero writes", async () => {
  const db = new FakeDb(detailCollections());
  db.collections.case_audit_events.push({id: "audit-timestamp", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.timestamp", occurredAt: {toDate: () => new Date("2026-07-22T10:07:00.000Z")}}});
  const result = await createService({db, clock}).detail({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1"}, {uid: "user-1"});
  assert.equal(result.contractVersion, "case-evidence-detail-v1");
  assert.equal(result.case.caseCode, "VK-2026-ABC12345");
  assert.deepEqual(result.evidenceReferences.map((item) => item.title), ["İlk delil", "İkinci delil"]);
  assert.deepEqual(result.timelineEvents.map((item) => item.summary), ["İlk olay", "İkinci olay"]);
  assert.deepEqual(result.auditSummary, [
    {action: "case.timestamp", occurredAt: "2026-07-22T10:07:00.000Z"},
    {action: "case.date", occurredAt: "2026-07-22T10:06:00.000Z"},
    {action: "case.created_from_risk", occurredAt: "2026-07-22T10:05:00.000Z"},
    {action: "case.invalid", occurredAt: null},
    {action: "case.null", occurredAt: null},
  ]);
  assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0);
  const serialized = JSON.stringify(result);
  for (const forbidden of ["secret-source", "secret-fingerprint", "secret-key", "secret-actor", "audit-timestamp", "correlationHash", "sourceRecordPath", "projectionFingerprint", "actorUid"]) assert.equal(serialized.includes(forbidden), false);
});

test("detail denies unauthenticated, foreign and missing cases safely", async () => {
  const db = new FakeDb(detailCollections()); const service = createService({db, clock});
  const request = {contractVersion: "case-evidence-detail-request-v1", caseId: "case-1"};
  await assert.rejects(() => service.detail(request, {}), /authentication required/);
  db.collections.case_files[0].data.tenantId = "tenant-other";
  await assert.rejects(() => service.detail(request, {uid: "user-1"}), (error) => error.code === "case.not_found");
  await assert.rejects(() => service.detail({...request, caseId: "missing"}, {uid: "user-1"}), (error) => error.code === "case.not_found");
});

test("detail callable requires auth and maps missing case", async () => {
  const handler = createDetailHandler({db: new FakeDb(detailCollections()), clock, log: {info: () => {}}});
  await assert.rejects(() => handler({data: {}}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  await assert.rejects(() => handler({auth: {uid: "user-1"}, data: {contractVersion: "case-evidence-detail-request-v1", caseId: "missing"}}), (error) => error instanceof HttpsError && error.code === "not-found");
});

function vaultCollections() {
  const value = structuredClone(collections);
  value.case_files = [{id: "case-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseNumber: "VK-2026-EA953C48", title: "Şüpheli tarama", status: "open"}}];
  value.case_evidence_refs = [{id: "evidence-1", data: {contractVersion: "case-evidence-reference-v1", caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", referenceType: "source_record", title: "Kaynak risk kaydı", sourceSystem: "monitoring", reviewStatus: "pending", integrityStatus: "reference_only", createdAt: "2026-07-22T11:00:00.000Z"}}];
  value.case_evidence_chain_events = [];
  return value;
}

test("vault contracts are strict and list is tenant scoped zero-write", async () => {
  const values = vaultCollections();
  values.case_evidence_refs.push(
      {id: "foreign-tenant", data: {...values.case_evidence_refs[0].data, tenantId: "tenant-other"}},
      {id: "foreign-brand", data: {...values.case_evidence_refs[0].data, canonicalBrandId: "brand-other"}},
  );
  const db = new FakeDb(values); const service = createService({db, clock});
  await assert.rejects(() => service.vaultList({}, {uid: "user-1"}), /contract/);
  const result = await service.vaultList({contractVersion: "case-evidence-vault-list-request-v1"}, {uid: "user-1"});
  assert.equal(result.contractVersion, "case-evidence-vault-list-v1"); assert.equal(result.items.length, 1); assert.equal(result.items[0].evidenceRefId, "evidence-1"); assert.equal(result.items[0].integrityStatus, "not_started"); assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0);
});

test("evidence detail is strict, tenant scoped, ordered and hides hashes", async () => {
  const db = new FakeDb(vaultCollections()); const service = createService({db, clock});
  await assert.rejects(() => service.evidenceDetail({contractVersion: "wrong", evidenceRefId: "evidence-1"}, {uid: "user-1"}), /contract/);
  const result = await service.evidenceDetail({contractVersion: "case-evidence-item-detail-request-v1", evidenceRefId: "evidence-1"}, {uid: "user-1"});
  assert.equal(result.evidence.caseNumber, "VK-2026-EA953C48"); assert.deepEqual(result.allowedActions, ["chain_started"]); assert.equal(result.writesPerformed, 0); assert.equal(JSON.stringify(result).includes("chainHash"), false);
  db.collections.case_evidence_refs[0].data.tenantId = "other"; await assert.rejects(() => service.evidenceDetail({contractVersion: "case-evidence-item-detail-request-v1", evidenceRefId: "evidence-1"}, {uid: "user-1"}), (error) => error.code === "evidence.not_found");
});

test("chain append is atomic, idempotent and hash continuity verifies", async () => {
  const db = new FakeDb(vaultCollections()); const service = createService({db, clock}); const request = {contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", eventType: "chain_started", note: "Zincir kontrollü biçimde başlatıldı.", requestId: "request-1"};
  const first = await service.appendChainEvent(request, {uid: "user-1"}); assert.equal(first.sequence, 1); assert.equal(first.duplicate, false); assert.equal(db.writes, 4);
  const duplicate = await service.appendChainEvent(request, {uid: "user-1"}); assert.equal(duplicate.duplicate, true); assert.equal(db.writes, 4);
  const second = await service.appendChainEvent({...request, eventType: "review_started", note: "İnceleme yetkili tarafından başlatıldı.", requestId: "request-2"}, {uid: "user-1"}); assert.equal(second.sequence, 2); assert.equal(second.reviewStatus, "under_review"); assert.equal(db.writes, 8);
  db.collections.case_evidence_chain_events.reverse();
  const detail = await service.evidenceDetail({contractVersion: "case-evidence-item-detail-request-v1", evidenceRefId: "evidence-1"}, {uid: "user-1"}); assert.equal(detail.evidence.integrityStatus, "verified"); assert.deepEqual(detail.chainEvents.map((item) => item.sequence), [1, 2]); assert.equal(JSON.stringify(detail).includes("previousHash"), false);
  assert.equal(db.collections.case_events.length, 2); assert.equal(db.collections.case_audit_events.length, 2);
  db.collections.case_evidence_chain_events[0].data.note = "Değiştirilmiş not";
  const broken = await service.evidenceDetail({contractVersion: "case-evidence-item-detail-request-v1", evidenceRefId: "evidence-1"}, {uid: "user-1"}); assert.equal(broken.evidence.integrityStatus, "broken");
});

test("chain append rejects auth, invalid note, invalid transitions and closed cases", async () => {
  const db = new FakeDb(vaultCollections()); const service = createService({db, clock}); const base = {contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", eventType: "chain_started", note: "Başlatıldı", requestId: "request-x"};
  await assert.rejects(() => service.appendChainEvent(base, {}), /authentication/); await assert.rejects(() => service.appendChainEvent({...base, note: "x"}, {uid: "user-1"}), /note/); await assert.rejects(() => service.appendChainEvent({...base, eventType: "review_started"}, {uid: "user-1"}), (error) => error.code === "transition.denied"); assert.equal(db.writes, 0);
  for (const status of ["closed", "archived"]) {
    db.collections.case_files[0].data.status = status; await assert.rejects(() => service.appendChainEvent(base, {uid: "user-1"}), (error) => error.code === "transition.denied"); assert.equal(db.writes, 0);
  }
});

test("chain append rejects a repeated custody transition", async () => {
  const db = new FakeDb(vaultCollections()); const service = createService({db, clock}); const base = {contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", note: "Kontrollü teslim kaydı"};
  await service.appendChainEvent({...base, eventType: "chain_started", requestId: "repeat-1"}, {uid: "user-1"});
  await service.appendChainEvent({...base, eventType: "custody_received", requestId: "repeat-2"}, {uid: "user-1"});
  await assert.rejects(() => service.appendChainEvent({...base, eventType: "custody_received", requestId: "repeat-3"}, {uid: "user-1"}), (error) => error.code === "transition.denied");
  assert.equal(db.collections.case_evidence_chain_events.length, 2);
});

test("chain append handler requires auth and App Check", async () => {
  const handler = createAppendChainEventHandler({db: new FakeDb(vaultCollections()), clock, log: {info: () => {}}});
  const data = {contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", eventType: "chain_started", note: "Zincir başlatıldı", requestId: "request-handler"};
  await assert.rejects(() => handler({data}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  await assert.rejects(() => handler({auth: {uid: "user-1"}, data}), (error) => error instanceof HttpsError && error.code === "failed-precondition");
  assert.equal((await handler({auth: {uid: "user-1"}, app: {appId: "verified"}, data})).duplicate, false);
});

test("chain append hides foreign tenant and brand and leaves zero writes", async () => {
  for (const field of ["tenantId", "canonicalBrandId"]) {
    const value = vaultCollections(); value.case_evidence_refs[0].data[field] = "foreign";
    const db = new FakeDb(value); const service = createService({db, clock});
    await assert.rejects(() => service.appendChainEvent({contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", eventType: "chain_started", note: "Zincir başlatıldı", requestId: `foreign-${field}`}, {uid: "user-1"}), (error) => error.code === "evidence.not_found");
    assert.equal(db.writes, 0);
  }
});

test("transaction failure leaves no partial chain, case or audit writes", async () => {
  const db = new FakeDb(vaultCollections(), {transactionFailure: true}); const service = createService({db, clock});
  await assert.rejects(() => service.appendChainEvent({contractVersion: "case-evidence-chain-event-request-v1", evidenceRefId: "evidence-1", eventType: "chain_started", note: "Zincir başlatıldı", requestId: "request-failure"}, {uid: "user-1"}), /simulated transaction failure/);
  assert.equal(db.writes, 0); assert.equal(db.collections.case_evidence_chain_events.length, 0); assert.equal(db.collections.case_events.length, 0); assert.equal(db.collections.case_audit_events.length, 0);
});

const reviewClock = {now: () => new Date("2026-07-23T05:00:00.000Z"), timestamp: (date) => date.toISOString()};
const reviewUuid = "123e4567-e89b-42d3-a456-426614174000";
function reviewCollections() {
  const value = vaultCollections();
  value.tenant_memberships[0].data.displayName = "Marka Uzmanı";
  value.case_evidence_refs[0].data.reviewStatus = "awaiting_review";
  value.case_evidence_refs[0].data.integrityStatus = "verified";
  value.case_evidence_refs[0].data.custodyStatus = "registered";
  value.case_evidence_refs[0].data.chainEventCount = 1;
  value.case_review_tasks = [];
  value.case_review_task_events = [];
  return value;
}
const unassignedReviewRequest = (overrides = {}) => ({
  contractVersion: "case-review-task-create-request-v1",
  caseId: "case-1",
  evidenceRefId: "evidence-1",
  title: "Kaynak risk kaydı incelemesi",
  description: "Kaynak risk kaydı uzman tarafından incelenecek.",
  taskType: "evidence_review",
  priority: "high",
  assignee: {type: "unassigned"},
  dueAt: "2026-07-24T05:00:00.000Z",
  requestId: reviewUuid,
  ...overrides,
});

test("review task contracts reject unknown fields, invalid UUID, text and due date", () => {
  assert.equal(createReviewTaskRequest(unassignedReviewRequest(), reviewClock.now()).caseId, "case-1");
  assert.throws(() => createReviewTaskRequest({...unassignedReviewRequest(), extra: true}, reviewClock.now()), /contract/);
  assert.throws(() => createReviewTaskRequest(unassignedReviewRequest({requestId: "not-uuid"}), reviewClock.now()), /requestId/);
  assert.throws(() => createReviewTaskRequest(unassignedReviewRequest({title: "x"}), reviewClock.now()), /title/);
  assert.throws(() => createReviewTaskRequest(unassignedReviewRequest({dueAt: "2020-01-01T00:00:00Z"}), reviewClock.now()), /dueAt/);
  assert.throws(() => reviewTaskEventRequest({contractVersion: "case-review-task-event-request-v1", taskId: "task-1", eventType: "note_added", note: "Not eklendi", requestId: reviewUuid, dueAt: "2026-07-24T00:00:00Z"}, reviewClock.now()), /contract/);
});

test("review task create is atomic, assigned or open, and deterministic idempotent", async () => {
  const db = new FakeDb(reviewCollections()); const service = createReviewTaskService({db, clock: reviewClock});
  const first = await service.create(unassignedReviewRequest(), {uid: "user-1"});
  assert.equal(first.status, "open"); assert.equal(first.duplicate, false); assert.match(first.taskNumber, /^GV-2026-[A-F0-9]{8}$/); assert.notEqual(first.taskNumber, first.taskId); assert.equal(db.writes, 4);
  const duplicate = await service.create(unassignedReviewRequest(), {uid: "user-1"});
  assert.equal(duplicate.duplicate, true); assert.equal(db.writes, 4);
  assert.equal(db.collections.case_review_tasks.length, 1); assert.equal(db.collections.case_review_task_events.length, 1); assert.equal(db.collections.case_events.length, 1); assert.equal(db.collections.case_audit_events.length, 1);
  const assignedDb = new FakeDb(reviewCollections()); const assigned = await createReviewTaskService({db: assignedDb, clock: reviewClock}).create(unassignedReviewRequest({requestId: "223e4567-e89b-42d3-a456-426614174001", assignee: {type: "external_expert", displayLabel: "Ayşe Uzman", expertiseArea: "Ayakkabı analizi"}}), {uid: "user-1"});
  assert.equal(assigned.status, "assigned"); assert.equal(assignedDb.collections.case_review_tasks[0].data.assigneeDisplayLabel, "Ayşe Uzman");
});

test("review task create validates auth App Check assignment evidence and case lifecycle", async () => {
  const db = new FakeDb(reviewCollections()); const service = createReviewTaskService({db, clock: reviewClock});
  await assert.rejects(() => service.create(unassignedReviewRequest(), {}), /authentication/);
  const createHandler = reviewTaskHandler("create", {db, clock: reviewClock, appCheck: true, log: {info: () => {}}});
  await assert.rejects(() => createHandler({auth: {uid: "user-1"}, data: unassignedReviewRequest()}), (error) => error instanceof HttpsError && error.code === "failed-precondition");
  const mismatch = reviewCollections(); mismatch.case_evidence_refs[0].data.caseId = "other";
  await assert.rejects(() => createReviewTaskService({db: new FakeDb(mismatch), clock: reviewClock}).create(unassignedReviewRequest(), {uid: "user-1"}), (error) => error.code === "not-found");
  for (const status of ["closed", "archived"]) {
    const closedValues = reviewCollections(); closedValues.case_files[0].data.status = status;
    await assert.rejects(() => createReviewTaskService({db: new FakeDb(closedValues), clock: reviewClock}).create(unassignedReviewRequest(), {uid: "user-1"}), (error) => error.code === "failed-precondition");
  }
  const badMember = reviewCollections();
  await assert.rejects(() => createReviewTaskService({db: new FakeDb(badMember), clock: reviewClock}).create(unassignedReviewRequest({requestId: "323e4567-e89b-42d3-a456-426614174002", assignee: {type: "internal_member", uid: "foreign-user"}}), {uid: "user-1"}), (error) => error.code === "not-found");
  assert.throws(() => createReviewTaskRequest(unassignedReviewRequest({assignee: {type: "external_expert", displayLabel: "Uzman"}}), reviewClock.now()), /external expert/);
  assert.throws(() => createReviewTaskRequest(unassignedReviewRequest({assignee: {type: "laboratory", displayLabel: "Lab"}}), reviewClock.now()), /laboratory/);
});

test("review task list/detail are scoped, sorted, overdue, safe and zero-write", async () => {
  const db = new FakeDb(reviewCollections()); const service = createReviewTaskService({db, clock: reviewClock});
  const created = await service.create(unassignedReviewRequest({dueAt: "2026-07-23T04:59:00.000Z"}), {uid: "user-1"}); const writes = db.writes;
  db.collections.case_review_tasks.push({id: "foreign-brand", data: {...db.collections.case_review_tasks[0].data, canonicalBrandId: "foreign"}});
  const list = await service.list({contractVersion: "case-review-task-list-request-v1"}, {uid: "user-1"});
  assert.equal(list.items.length, 1); assert.equal(list.items[0].taskId, created.taskId); assert.equal(list.items[0].isOverdue, true); assert.equal(list.writesPerformed, 0); assert.equal(db.writes, writes);
  const detail = await service.detail({contractVersion: "case-review-task-detail-request-v1", taskId: created.taskId}, {uid: "user-1"});
  assert.deepEqual(detail.allowedActions, ["assign", "change_due_date", "cancel_task"]); assert.deepEqual(detail.timelineEvents.map((item) => item.sequence), [1]); assert.equal(detail.writesPerformed, 0);
  const serialized = JSON.stringify(detail); for (const forbidden of ["tenantId", "canonicalBrandId", "actorUid", "previousEventId", "payloadSummary"]) assert.equal(serialized.includes(forbidden), false);
  db.collections.case_review_tasks[0].data.tenantId = "foreign";
  await assert.rejects(() => service.detail({contractVersion: "case-review-task-detail-request-v1", taskId: created.taskId}, {uid: "user-1"}), (error) => error.code === "not-found");
});

test("review task lifecycle, idempotency and terminal rules preserve evidence review state", async () => {
  const db = new FakeDb(reviewCollections()); const service = createReviewTaskService({db, clock: reviewClock});
  const created = await service.create(unassignedReviewRequest(), {uid: "user-1"}); const taskId = created.taskId; const base = {contractVersion: "case-review-task-event-request-v1", taskId, note: "Kontrollü görev işlemi"};
  const assigned = await service.append({...base, eventType: "assignment_set", assignee: {type: "external_expert", displayLabel: "Ayşe Uzman", expertiseArea: "Ayakkabı analizi"}, requestId: "423e4567-e89b-42d3-a456-426614174003"}, {uid: "user-1"}); assert.equal(assigned.status, "assigned"); assert.equal(assigned.sequence, 2);
  const startedRequest = {...base, eventType: "review_started", requestId: "523e4567-e89b-42d3-a456-426614174004"};
  assert.equal((await service.append(startedRequest, {uid: "user-1"})).status, "in_review");
  assert.equal((await service.append(startedRequest, {uid: "user-1"})).duplicate, true);
  await assert.rejects(() => service.append({...base, eventType: "assignment_changed", assignee: {type: "external_expert", displayLabel: "Başka Uzman", expertiseArea: "Analiz"}, requestId: "623e4567-e89b-42d3-a456-426614174005"}, {uid: "user-1"}), (error) => error.code === "failed-precondition");
  const reviewBefore = db.collections.case_evidence_refs[0].data.reviewStatus;
  const completed = await service.append({...base, eventType: "review_completed", resultOutcome: "confirmed", resultSummary: "İnceleme bulguları güvenli biçimde doğrulandı.", requestId: "723e4567-e89b-42d3-a456-426614174006"}, {uid: "user-1"});
  assert.equal(completed.status, "completed"); assert.equal(completed.eventCount, 4); assert.equal(db.collections.case_evidence_refs[0].data.reviewStatus, reviewBefore);
  await assert.rejects(() => service.append({...base, eventType: "note_added", requestId: "823e4567-e89b-42d3-a456-426614174007"}, {uid: "user-1"}), (error) => error.code === "failed-precondition");
  assert.equal(db.collections.case_review_task_events.length, 4); assert.equal(db.collections.case_events.length, 4); assert.equal(db.collections.case_audit_events.length, 4);
});

test("review task transaction failure leaves no partial writes", async () => {
  const db = new FakeDb(reviewCollections(), {transactionFailure: true});
  await assert.rejects(() => createReviewTaskService({db, clock: reviewClock}).create(unassignedReviewRequest(), {uid: "user-1"}), /simulated transaction failure/);
  assert.equal(db.writes, 0); assert.equal(db.collections.case_review_tasks.length, 0); assert.equal(db.collections.case_review_task_events.length, 0);
});

test("review task case events expose server ISO occurredAt while task and audit timestamps stay server timestamps", async () => {
  const serverTimestamp = (date) => ({kind: "server-timestamp", value: date.toISOString(), toDate: () => date});
  const timestampClock = {now: reviewClock.now, timestamp: serverTimestamp};
  const db = new FakeDb(reviewCollections()); const service = createReviewTaskService({db, clock: timestampClock});
  const created = await service.create(unassignedReviewRequest(), {uid: "user-1"});
  assert.equal(db.collections.case_events[0].data.occurredAt, "2026-07-23T05:00:00.000Z");
  assert.equal(db.collections.case_review_task_events[0].data.recordedAt.kind, "server-timestamp");
  assert.equal(db.collections.case_audit_events[0].data.occurredAt.kind, "server-timestamp");
  const duplicate = await service.create(unassignedReviewRequest(), {uid: "user-1"});
  assert.equal(duplicate.duplicate, true); assert.equal(db.collections.case_events.length, 1);
  await service.append({contractVersion: "case-review-task-event-request-v1", taskId: created.taskId, eventType: "assignment_set", note: "Uzman güvenli biçimde atandı.", assignee: {type: "external_expert", displayLabel: "Ayşe Uzman", expertiseArea: "Ayakkabı analizi"}, requestId: "923e4567-e89b-42d3-a456-426614174008"}, {uid: "user-1"});
  assert.equal(db.collections.case_events[1].data.occurredAt, "2026-07-23T05:00:00.000Z");
  assert.equal(db.collections.case_review_task_events[1].data.recordedAt.kind, "server-timestamp");
  assert.equal(db.collections.case_audit_events[1].data.occurredAt.kind, "server-timestamp");
});
