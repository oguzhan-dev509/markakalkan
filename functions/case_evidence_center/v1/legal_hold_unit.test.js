/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {createLegalHoldHandler, createLegalHoldService, detailRequest, releaseRequest, startRequest} = require("./legal_hold");

function assertNoUndefined(value, path = "root") {
  if (value === undefined) throw new Error(`undefined firestore value at ${path}`);
  if (Array.isArray(value)) value.forEach((item, index) => assertNoUndefined(item, `${path}[${index}]`));
  else if (value && typeof value === "object" && !(value instanceof Date)) for (const [key, item] of Object.entries(value)) assertNoUndefined(item, `${path}.${key}`);
}
class Snapshot {
  constructor(id, data, path, exists = true) {
    this.id = id; this._data = data; this.exists = exists; this.ref = {path};
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
    return {docs: (this.store.collections[this.name] || []).filter((item) => this.filters.every(([field, value]) => item.data[field] === value)).slice(0, this.maximum).map((item) => new Snapshot(item.id, item.data, `${this.name}/${item.id}`))};
  }
}
class Ref {
  constructor(store, path) {
    this.store = store; this.path = path; this.id = path.split("/").at(-1);
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
  async get(reference) {
    if (reference instanceof Query) return reference.get();
    return this.store.snapshot(reference.path);
  }
  create(reference, data) {
    assertNoUndefined(data); this.pending.push({type: "create", path: reference.path, data});
  }
  update(reference, data) {
    assertNoUndefined(data); this.pending.push({type: "update", path: reference.path, data});
  }
  commit() {
    const nextCollections = structuredClone(this.store.collections);
    for (const entry of this.pending) {
      const parts = entry.path.split("/"); const id = parts.pop(); const name = parts.join("/"); nextCollections[name] ||= [];
      if (entry.type === "create") {
        if (nextCollections[name].some((item) => item.id === id)) throw new Error("document already exists");
        nextCollections[name].push({id, data: structuredClone(entry.data)});
      } else {
        const current = nextCollections[name].find((item) => item.id === id); if (!current) throw new Error("document missing");
        current.data = {...current.data, ...structuredClone(entry.data)};
      }
    }
    this.store.collections = nextCollections; this.store.writes += this.pending.length;
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
    return item ? new Snapshot(id, item.data, path, true) : new Snapshot(id, {}, path, false);
  }
  async runTransaction(callback) {
    const transaction = new Transaction(this); const result = await callback(transaction); if (this.transactionFailure) throw new Error("simulated transaction failure"); if (result.transactionCommitted !== false) transaction.commit(); return result;
  }
}
const baseCollections = () => ({
  tenant_memberships: [{id: "membership-1", data: {uid: "user-1", tenantId: "tenant-1", status: "active", role: "owner"}}],
  case_files: [{id: "case-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseNumber: "VK-2026-EA953C48", title: "Dejure Spor Ayakkabı", status: "open", legalHold: {active: false, startedAt: null, releasedAt: null}, updatedAt: "2026-07-23T10:00:00.000Z"}}],
  case_legal_holds: [], case_legal_hold_events: [], case_events: [], case_audit_events: [],
});
const times = [
  "2026-07-24T11:00:00.000Z",
  "2026-07-24T11:01:00.000Z",
  "2026-07-24T11:02:00.000Z",
  "2026-07-24T11:03:00.000Z",
];
function clock() {
  let index = 0; return {now: () => times[Math.min(index++, times.length - 1)]};
}
const resolveContext = async ({uid}) => ({uid, tenantId: "tenant-1", brandId: "brand-1", membershipId: "membership-1"});
const startPayload = (requestId = "123e4567-e89b-42d3-a456-426614174201") => ({contractVersion: "case-legal-hold-start-request-v1", caseId: "case-1", reason: "Muhtemel hukuki süreç nedeniyle vaka ve tüm bağlı kayıtlar korunmalıdır.", authorityReference: "İç hukuk değerlendirmesi 2026/01", requestId});
const releasePayload = (holdId, requestId = "123e4567-e89b-42d3-a456-426614174202") => ({contractVersion: "case-legal-hold-release-request-v1", holdId, reason: "Hukuki muhafaza ihtiyacının sona erdiği yetkili değerlendirmeyle doğrulandı.", requestId});

test("legal hold request contracts are strict", () => {
  assert.equal(detailRequest({contractVersion: "case-legal-hold-detail-request-v1", caseId: "case-1"}).caseId, "case-1");
  assert.equal(startRequest(startPayload()).authorityReference, "İç hukuk değerlendirmesi 2026/01");
  assert.equal(releaseRequest(releasePayload("hold-1")).holdId, "hold-1");
  assert.throws(() => detailRequest({contractVersion: "wrong", caseId: "case-1"}), /contract/);
  assert.throws(() => startRequest({...startPayload(), unknown: true}), /contract/);
  assert.throws(() => startRequest({...startPayload(), requestId: "bad"}), /requestId/);
  assert.throws(() => releaseRequest({...releasePayload("hold-1"), reason: "kısa"}), /reason/);
});

test("legal hold detail is scoped read-only and verifies projection", async () => {
  const values = baseCollections(); values.case_legal_holds.push({id: "hold-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", holdNumber: "HM-2026-AAAA1111", scope: "case_and_descendants", status: "active", reason: "Geçerli hukuki gerekçe metni.", startedAt: "2026-07-24T10:00:00.000Z", eventCount: 1}}, {id: "foreign", data: {tenantId: "tenant-1", canonicalBrandId: "brand-other", caseId: "case-1", holdNumber: "GİZLİ", status: "active", startedAt: "2026-07-24T09:00:00.000Z"}});
  values.case_files[0].data.legalHold = {active: true, activeCount: 1, latestHoldId: "hold-1", startedAt: "2026-07-24T10:00:00.000Z", releasedAt: null, lastChangedAt: "2026-07-24T10:00:00.000Z"};
  values.case_legal_hold_events.push({id: "event-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", holdId: "hold-1", sequence: 1, eventType: "legal_hold_started", note: "Geçerli hukuki gerekçe metni.", recordedAt: "2026-07-24T10:00:00.000Z"}});
  const db = new FakeDb(values); const result = await createLegalHoldService({db, clock: clock(), resolveContext}).detail({contractVersion: "case-legal-hold-detail-request-v1", caseId: "case-1"}, {uid: "user-1"});
  assert.equal(result.holds.length, 1); assert.equal(result.stats.activeHolds, 1); assert.equal(result.integrityStatus, "verified"); assert.equal(result.readOnly, true); assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0); assert.equal(JSON.stringify(result).includes("GİZLİ"), false); assert.equal(JSON.stringify(result).includes("tenantId"), false);
});

test("legal hold start is atomic idempotent auditable and projects active state", async () => {
  const db = new FakeDb(baseCollections()); const service = createLegalHoldService({db, clock: clock(), resolveContext});
  const first = await service.start(startPayload(), {uid: "user-1"}); const duplicate = await service.start(startPayload(), {uid: "user-1"}); const record = db.collections.case_files[0].data;
  assert.match(first.holdNumber, /^HM-2026-[A-F0-9]{8}$/); assert.equal(first.status, "active"); assert.equal(first.activeCount, 1); assert.equal(duplicate.duplicate, true); assert.equal(db.collections.case_legal_holds.length, 1); assert.equal(db.collections.case_legal_hold_events.length, 1); assert.equal(db.collections.case_events.length, 1); assert.equal(db.collections.case_audit_events.length, 1); assert.equal(record.legalHold.active, true); assert.equal(record.legalHold.activeCount, 1); assert.equal(record.legalHold.latestHoldId, first.holdId); assert.equal(db.collections.case_legal_holds[0].data.lastEventId, db.collections.case_legal_hold_events[0].id); assert.equal(db.collections.case_events[0].data.eventType, "legal_hold_started"); assert.equal(db.collections.case_audit_events[0].data.action, "legal_hold.started");
});

test("multiple holds preserve protection until the final idempotent release", async () => {
  const db = new FakeDb(baseCollections()); const service = createLegalHoldService({db, clock: clock(), resolveContext});
  const first = await service.start(startPayload("123e4567-e89b-42d3-a456-426614174203"), {uid: "user-1"}); const second = await service.start(startPayload("123e4567-e89b-42d3-a456-426614174204"), {uid: "user-1"});
  const partial = await service.release(releasePayload(first.holdId, "123e4567-e89b-42d3-a456-426614174205"), {uid: "user-1"}); assert.equal(partial.activeCount, 1); assert.equal(db.collections.case_files[0].data.legalHold.active, true);
  const finalRequest = releasePayload(second.holdId, "123e4567-e89b-42d3-a456-426614174206"); const final = await service.release(finalRequest, {uid: "user-1"}); const writes = db.writes; const duplicate = await service.release(finalRequest, {uid: "user-1"});
  assert.equal(final.activeCount, 0); assert.equal(duplicate.duplicate, true); assert.equal(db.writes, writes); assert.equal(db.collections.case_files[0].data.legalHold.active, false); assert.equal(db.collections.case_files[0].data.legalHold.activeCount, 0); assert.equal(db.collections.case_legal_holds.filter((item) => item.data.status === "released").length, 2); assert.equal(db.collections.case_legal_hold_events.length, 4); assert.equal(db.collections.case_events.length, 4); assert.equal(db.collections.case_audit_events.length, 4);
});

test("legacy hold release omits undefined previousEventId", async () => {
  const values = baseCollections(); values.case_files[0].data.legalHold = {active: true, activeCount: 1, latestHoldId: "legacy-hold", startedAt: "2026-07-24T10:00:00.000Z", releasedAt: null};
  values.case_legal_holds.push({id: "legacy-hold", data: {contractVersion: "case-legal-hold-v1", tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", holdNumber: "HM-2026-LEGACY01", scope: "case_and_descendants", status: "active", reason: "Geçerli eski hukuki muhafaza gerekçesi.", startedAt: "2026-07-24T10:00:00.000Z", eventCount: 1}});
  const db = new FakeDb(values); const result = await createLegalHoldService({db, clock: clock(), resolveContext}).release(releasePayload("legacy-hold"), {uid: "user-1"}); const event = db.collections.case_legal_hold_events[0].data;
  assert.equal(result.activeCount, 0); assert.equal("previousEventId" in event, false); assert.equal(db.collections.case_legal_holds[0].data.lastEventId, db.collections.case_legal_hold_events[0].id);
});

test("writes require owner auth and App Check", async () => {
  const db = new FakeDb(baseCollections()); const handler = createLegalHoldHandler("start", {db, clock: clock(), resolveContext, appCheck: true, log: {error: () => {}}});
  await assert.rejects(() => handler({data: startPayload()}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  await assert.rejects(() => handler({auth: {uid: "user-1"}, data: startPayload()}), (error) => error instanceof HttpsError && error.code === "failed-precondition");
  db.collections.tenant_memberships[0].data.role = "member";
  await assert.rejects(() => handler({auth: {uid: "user-1"}, app: {appId: "app-1"}, data: startPayload()}), (error) => error instanceof HttpsError && error.code === "permission-denied");
});

test("transaction failure leaves no partial legal hold writes", async () => {
  const db = new FakeDb(baseCollections(), {transactionFailure: true}); const before = structuredClone(db.collections);
  await assert.rejects(() => createLegalHoldService({db, clock: clock(), resolveContext}).start(startPayload(), {uid: "user-1"}), /simulated transaction failure/);
  assert.deepEqual(db.collections, before); assert.equal(db.writes, 0);
});
