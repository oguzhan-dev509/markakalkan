/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {createListHandler, createService, createWriteHandler, listRequest} = require("./index");

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
