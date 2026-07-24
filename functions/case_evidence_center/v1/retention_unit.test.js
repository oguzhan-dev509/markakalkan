/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {assessRequest, createRetentionHandler, createRetentionService, detailRequest, setPolicyRequest} = require("./retention");

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
    const next = structuredClone(this.store.collections);
    for (const entry of this.pending) {
      const parts = entry.path.split("/"); const id = parts.pop(); const name = parts.join("/"); next[name] ||= [];
      if (entry.type === "create") {
        if (next[name].some((item) => item.id === id)) throw new Error("document already exists");
        next[name].push({id, data: structuredClone(entry.data)});
      } else {
        const current = next[name].find((item) => item.id === id); if (!current) throw new Error("document missing");
        current.data = {...current.data, ...structuredClone(entry.data)};
      }
    }
    this.store.collections = next; this.store.writes += this.pending.length;
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
  case_files: [{id: "case-1", data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseNumber: "VK-2026-EA953C48", title: "Dejure Spor Ayakkabı", status: "open", openedAt: "2026-01-01T00:00:00.000Z", closedAt: null, legalHold: {active: false, activeCount: 0}, retention: {active: false}, updatedAt: "2026-07-23T10:00:00.000Z"}}],
  case_retention_records: [], case_retention_events: [], case_events: [], case_audit_events: [],
});
const resolveContext = async ({uid}) => ({uid, tenantId: "tenant-1", brandId: "brand-1", membershipId: "membership-1"});
const clock = (...values) => {
  let index = 0; return {now: () => values[Math.min(index++, values.length - 1)]};
};
const detailPayload = () => ({contractVersion: "case-retention-detail-request-v1", caseId: "case-1"});
const policyPayload = (requestId = "123e4567-e89b-42d3-a456-426614174301", overrides = {}) => ({contractVersion: "case-retention-policy-set-request-v1", caseId: "case-1", policyCode: "CASE-365", policyName: "Vaka kayıtları 365 gün saklama", anchorType: "case_opened_at", anchorDate: null, retentionPeriodDays: 365, reason: "Kurumsal kayıt saklama politikası vakaya uygulanmaktadır.", authorityReference: "İç Politika HMS-01", requestId, ...overrides});
const assessPayload = (requestId = "123e4567-e89b-42d3-a456-426614174302") => ({contractVersion: "case-retention-disposition-assess-request-v1", caseId: "case-1", note: "Saklama süresi ve engelleyici koşullar yetkili kullanıcı tarafından değerlendirildi.", requestId});

test("retention request contracts are strict", () => {
  assert.equal(detailRequest(detailPayload()).caseId, "case-1"); assert.equal(setPolicyRequest(policyPayload()).retentionPeriodDays, 365); assert.equal(assessRequest(assessPayload()).caseId, "case-1");
  assert.throws(() => detailRequest({...detailPayload(), extra: true}), /contract/); assert.throws(() => setPolicyRequest({...policyPayload(), retentionPeriodDays: 0}), /retentionPeriodDays/); assert.throws(() => setPolicyRequest({...policyPayload(), anchorType: "manual_date", anchorDate: null}), /anchorDate/); assert.throws(() => setPolicyRequest({...policyPayload(), anchorDate: "2026-01-01T00:00:00.000Z"}), /anchorDate/); assert.throws(() => assessRequest({...assessPayload(), requestId: "bad"}), /requestId/);
});

test("retention detail is scoped read-only and verifies empty projection", async () => {
  const db = new FakeDb(baseCollections()); const result = await createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z"), resolveContext}).detail(detailPayload(), {uid: "user-1"});
  assert.equal(result.record, null); assert.equal(result.events.length, 0); assert.equal(result.integrityStatus, "verified"); assert.equal(result.readOnly, true); assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0); assert.equal(JSON.stringify(result).includes("tenantId"), false);
});

test("closed-date retention anchor fails closed until the case has a closedAt value", async () => {
  const db = new FakeDb(baseCollections()); const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z"), resolveContext}); const request = policyPayload("123e4567-e89b-42d3-a456-426614174309", {anchorType: "case_closed_at"});
  await assert.rejects(() => service.setPolicy(request, {uid: "user-1"}), (error) => error.code === "retention.anchor_unavailable"); assert.equal(db.writes, 0); assert.equal(db.collections.case_retention_records.length, 0);
});

test("retention policy set is atomic idempotent auditable and projected", async () => {
  const db = new FakeDb(baseCollections()); const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z", "2026-07-24T12:01:00.000Z"), resolveContext});
  const first = await service.setPolicy(policyPayload(), {uid: "user-1"}); const writes = db.writes; const duplicate = await service.setPolicy(policyPayload(), {uid: "user-1"}); const record = db.collections.case_retention_records[0].data; const caseData = db.collections.case_files[0].data;
  const event = db.collections.case_retention_events[0].data;
  assert.equal(first.policyVersion, 1); assert.equal(first.retainUntil, "2027-01-01T00:00:00.000Z"); assert.equal(first.dispositionStatus, "not_due"); assert.equal(duplicate.duplicate, true); assert.equal(duplicate.policyVersion, first.policyVersion); assert.equal(duplicate.retainUntil, first.retainUntil); assert.equal(duplicate.dispositionStatus, first.dispositionStatus); assert.equal(db.writes, writes); assert.equal(db.collections.case_retention_records.length, 1); assert.equal(db.collections.case_retention_events.length, 1); assert.equal(db.collections.case_events.length, 1); assert.equal(db.collections.case_audit_events.length, 1); assert.equal(record.lastEventId, db.collections.case_retention_events[0].id); assert.equal(caseData.retention.recordId, first.recordId); assert.equal(caseData.retention.policyVersion, 1); assert.equal(event.policyCode, "CASE-365"); assert.equal(event.anchorType, "case_opened_at"); assert.equal(event.anchorAt, "2026-01-01T00:00:00.000Z"); assert.equal(event.retentionPeriodDays, 365); assert.equal(event.retainUntil, first.retainUntil); assert.equal(event.dispositionEligible, false); assert.equal(db.collections.case_audit_events[0].data.action, "retention.policy_set");
});

test("retention policy update increments snapshot version and preserves creation metadata", async () => {
  const db = new FakeDb(baseCollections()); db.collections.case_files[0].data.closedAt = "2026-06-01T00:00:00.000Z"; const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z", "2026-07-24T12:10:00.000Z"), resolveContext});
  await service.setPolicy(policyPayload(), {uid: "user-1"}); const createdAt = db.collections.case_retention_records[0].data.createdAt; const updated = await service.setPolicy(policyPayload("123e4567-e89b-42d3-a456-426614174303", {policyCode: "CASE-730", policyName: "Kapalı vaka kayıtları 730 gün saklama", anchorType: "case_closed_at", retentionPeriodDays: 730}), {uid: "user-1"}); const record = db.collections.case_retention_records[0].data; const event = db.collections.case_retention_events[1].data;
  const firstEvent = db.collections.case_retention_events[0].data;
  assert.equal(updated.policyVersion, 2); assert.equal(record.anchorAt, "2026-06-01T00:00:00.000Z"); assert.equal(record.createdAt, createdAt); assert.equal(record.eventCount, 2); assert.equal(firstEvent.policyCode, "CASE-365"); assert.equal(firstEvent.retentionPeriodDays, 365); assert.equal(event.policyCode, "CASE-730"); assert.equal(event.policyName, "Kapalı vaka kayıtları 730 gün saklama"); assert.equal(event.anchorType, "case_closed_at"); assert.equal(event.anchorAt, "2026-06-01T00:00:00.000Z"); assert.equal(event.retentionPeriodDays, 730); assert.equal(event.retainUntil, updated.retainUntil); assert.equal(event.previousEventId, db.collections.case_retention_events[0].id); assert.equal(db.collections.case_audit_events[1].data.action, "retention.policy_updated");
});

test("idempotent retries preserve their original policy and assessment results after later changes", async () => {
  const db = new FakeDb(baseCollections()); const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z", "2026-07-24T12:01:00.000Z", "2026-07-24T12:02:00.000Z", "2026-07-24T12:03:00.000Z", "2026-07-24T12:04:00.000Z", "2026-07-24T12:05:00.000Z"), resolveContext});
  const firstRequest = policyPayload("123e4567-e89b-42d3-a456-426614174310", {anchorType: "manual_date", anchorDate: "2026-07-20T00:00:00.000Z", retentionPeriodDays: 1}); const first = await service.setPolicy(firstRequest, {uid: "user-1"});
  await service.setPolicy(policyPayload("123e4567-e89b-42d3-a456-426614174311", {policyCode: "CASE-730", policyName: "Vaka kayıtları 730 gün saklama", retentionPeriodDays: 730}), {uid: "user-1"}); const firstRetry = await service.setPolicy(firstRequest, {uid: "user-1"});
  const firstAssessmentRequest = assessPayload("123e4567-e89b-42d3-a456-426614174312"); const firstAssessment = await service.assessDisposition(firstAssessmentRequest, {uid: "user-1"}); db.collections.case_files[0].data.status = "closed"; db.collections.case_files[0].data.closedAt = "2026-07-21T00:00:00.000Z"; const secondAssessment = await service.assessDisposition(assessPayload("123e4567-e89b-42d3-a456-426614174313"), {uid: "user-1"}); const firstAssessmentRetry = await service.assessDisposition(firstAssessmentRequest, {uid: "user-1"});
  assert.equal(firstRetry.duplicate, true); assert.equal(firstRetry.policyVersion, first.policyVersion); assert.equal(firstRetry.retainUntil, first.retainUntil); assert.equal(firstAssessment.dispositionStatus, "not_due"); assert.equal(secondAssessment.dispositionStatus, "not_due"); assert.equal(firstAssessmentRetry.duplicate, true); assert.equal(firstAssessmentRetry.dispositionStatus, firstAssessment.dispositionStatus); assert.equal(firstAssessmentRetry.dispositionEligible, firstAssessment.dispositionEligible);
});

test("retention detail detects stale derived projection fields", async () => {
  const db = new FakeDb(baseCollections()); const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z", "2026-07-24T12:01:00.000Z"), resolveContext}); await service.setPolicy(policyPayload(), {uid: "user-1"}); db.collections.case_files[0].data.retention.blockedReason = "stale_projection";
  const detail = await service.detail(detailPayload(), {uid: "user-1"});
  assert.equal(detail.integrityStatus, "projection_mismatch"); assert.equal(detail.events[0].policyCode, "CASE-365"); assert.equal(detail.events[0].retainUntil, "2027-01-01T00:00:00.000Z");
});

test("disposition assessment blocks lifecycle and legal hold before becoming eligible without changing retention", async () => {
  const values = baseCollections(); const db = new FakeDb(values); const service = createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z", "2026-07-24T12:01:00.000Z", "2026-07-24T12:02:00.000Z", "2026-07-24T12:03:00.000Z"), resolveContext});
  await service.setPolicy(policyPayload("123e4567-e89b-42d3-a456-426614174304", {anchorType: "manual_date", anchorDate: "2026-07-20T00:00:00.000Z", retentionPeriodDays: 1}), {uid: "user-1"}); const retainUntil = db.collections.case_retention_records[0].data.retainUntil;
  const open = await service.assessDisposition(assessPayload("123e4567-e89b-42d3-a456-426614174305"), {uid: "user-1"}); db.collections.case_files[0].data.status = "closed"; db.collections.case_files[0].data.closedAt = "2026-07-21T00:00:00.000Z"; db.collections.case_files[0].data.legalHold = {active: true, activeCount: 1}; const held = await service.assessDisposition(assessPayload("123e4567-e89b-42d3-a456-426614174306"), {uid: "user-1"}); db.collections.case_files[0].data.legalHold = {active: false, activeCount: 0}; const eligible = await service.assessDisposition(assessPayload("123e4567-e89b-42d3-a456-426614174307"), {uid: "user-1"});
  assert.equal(open.dispositionStatus, "blocked_by_case_lifecycle"); assert.equal(held.dispositionStatus, "blocked_by_legal_hold"); assert.equal(eligible.dispositionStatus, "eligible_for_disposition"); assert.equal(eligible.dispositionEligible, true); assert.equal(db.collections.case_retention_records[0].data.retainUntil, retainUntil); assert.equal(db.collections.case_retention_records[0].data.blockedReason, null); assert.equal(db.collections.case_files.length, 1); assert.equal(db.collections.case_retention_records.length, 1);
});

test("legacy retention assessment omits undefined previousEventId", async () => {
  const values = baseCollections(); const serviceClock = clock("2026-07-24T12:00:00.000Z"); const db = new FakeDb(values); const service = createRetentionService({db, clock: serviceClock, resolveContext}); await service.setPolicy(policyPayload(), {uid: "user-1"}); delete db.collections.case_retention_records[0].data.lastEventId; db.collections.case_files[0].data.status = "closed"; db.collections.case_retention_records[0].data.retainUntil = "2026-01-01T00:00:00.000Z"; const before = db.collections.case_retention_events.length; await service.assessDisposition(assessPayload(), {uid: "user-1"}); const event = db.collections.case_retention_events[before].data;
  assert.equal("previousEventId" in event, false); assert.equal(db.collections.case_retention_records[0].data.lastEventId, db.collections.case_retention_events[before].id);
});

test("retention writes require owner auth and App Check", async () => {
  const db = new FakeDb(baseCollections()); const handler = createRetentionHandler("setPolicy", {db, clock: clock("2026-07-24T12:00:00.000Z"), resolveContext, appCheck: true, log: {error: () => {}}});
  await assert.rejects(() => handler({data: policyPayload()}), (error) => error instanceof HttpsError && error.code === "unauthenticated"); await assert.rejects(() => handler({auth: {uid: "user-1"}, data: policyPayload()}), (error) => error instanceof HttpsError && error.code === "failed-precondition"); db.collections.tenant_memberships[0].data.role = "member"; await assert.rejects(() => handler({auth: {uid: "user-1"}, app: {appId: "app-1"}, data: policyPayload()}), (error) => error instanceof HttpsError && error.code === "permission-denied");
});

test("transaction failure leaves no partial retention writes", async () => {
  const db = new FakeDb(baseCollections(), {transactionFailure: true}); const before = structuredClone(db.collections); await assert.rejects(() => createRetentionService({db, clock: clock("2026-07-24T12:00:00.000Z"), resolveContext}).setPolicy(policyPayload(), {uid: "user-1"}), /simulated transaction failure/); assert.deepEqual(db.collections, before); assert.equal(db.writes, 0);
});
