/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {createDetailHandler, createListHandler, createService, createWriteHandler, detailRequest, listRequest} = require("./index");

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
    return this.store.snapshot(ref.path);
  }
  create(ref, data) {
    this.pending.push({path: ref.path, data});
  }
  commit() {
    for (const entry of this.pending) {
      const parts = entry.path.split("/"); const id = parts.pop(); const name = parts.join("/");
      this.store.collections[name] ||= []; this.store.collections[name].push({id, data: entry.data, version: entry.data.updatedAt || entry.data.occurredAt}); this.store.writes++;
    }
  }
}
class FakeDb {
  constructor(collections) {
    this.collections = structuredClone(collections); this.writes = 0;
  }
  collection(name) {
    return new Collection(this, name);
  }
  snapshot(path) {
    const parts = path.split("/"); const id = parts.pop(); const name = parts.join("/"); const item = (this.collections[name] || []).find((entry) => entry.id === id);
    return item ? new Snapshot(id, item.data, path, true, item.version) : new Snapshot(id, {}, path, false);
  }
  async runTransaction(callback) {
    const transaction = new Transaction(this); const result = await callback(transaction); if (result.transactionCommitted !== false) transaction.commit(); return result;
  }
}

const collections = {
  "tenant_memberships": [{id: "membership-1", data: {uid: "user-1", tenantId: "tenant-1", status: "active", role: "owner"}}],
  "canonical_brands": [{id: "brand-1", data: {tenantId: "tenant-1", status: "active"}}],
  "monitoring_signals": [{id: "monitoring-1", version: "2026-07-22T10:00:00.000Z", data: {tenantId: "tenant-1", brandId: "brand-1", pageId: "page-1", signalLevel: "critical", status: "new", title: "Şüpheli pazar yeri ilanı", summary: "Birden fazla kaynakla desteklenen risk.", detectedAt: "2026-07-22T09:00:00.000Z", createdAt: "2026-07-22T09:00:00.000Z", evidenceVerified: true, confidence: .95}}],
  "verificationScans": [], "shared_risk_signals": [], "brands/user-1/digitalDetectiveTasks": [], "case_files": [], "case_events": [], "case_evidence_refs": [], "case_audit_events": [],
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
    "case_audit_events": [{id: "audit-1", data: {caseId: "case-1", tenantId: "tenant-1", canonicalBrandId: "brand-1", action: "case.created_from_risk", occurredAt: "2026-07-22T10:05:00.000Z", correlationHash: "secret"}}],
  };
}

test("detail request contract is strict", () => {
  assert.equal(detailRequest({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1"}).caseId, "case-1");
  assert.throws(() => detailRequest({caseId: "case-1"}), /detail request/);
  assert.throws(() => detailRequest({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1", extra: true}), /detail request/);
});

test("detail reads tenant and brand scoped records in safe chronological contract with zero writes", async () => {
  const db = new FakeDb(detailCollections());
  const result = await createService({db, clock}).detail({contractVersion: "case-evidence-detail-request-v1", caseId: "case-1"}, {uid: "user-1"});
  assert.equal(result.contractVersion, "case-evidence-detail-v1");
  assert.equal(result.case.caseCode, "VK-2026-ABC12345");
  assert.deepEqual(result.evidenceReferences.map((item) => item.title), ["İlk delil", "İkinci delil"]);
  assert.deepEqual(result.timelineEvents.map((item) => item.summary), ["İlk olay", "İkinci olay"]);
  assert.equal(result.auditSummary.length, 1);
  assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0);
  const serialized = JSON.stringify(result);
  for (const forbidden of ["secret-source", "secret-fingerprint", "secret-key", "correlationHash", "sourceRecordPath", "projectionFingerprint"]) assert.equal(serialized.includes(forbidden), false);
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
