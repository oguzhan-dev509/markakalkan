/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const test = require("node:test");
const {
  MAX_MANIFEST_BYTES,
  MAX_PACKAGES_PER_CASE,
  readinessRequest,
  listRequest,
  createRequest,
  detailRequest,
  canonicalJson,
  createCaseExportService,
  createHandler,
} = require("./export_manifest");

class Snapshot {
  constructor(id, data, exists = true) {
    this.id = id;
    this._data = data;
    this.exists = exists;
  }
  data() {
    return this._data;
  }
}
class Query {
  constructor(store, name, filters = [], maximum = 1000) {
    this.store = store;
    this.name = name;
    this.filters = filters;
    this.maximum = maximum;
  }
  where(field, op, value) {
    assert.equal(op, "==");
    return new Query(this.store, this.name, [...this.filters, [field, value]], this.maximum);
  }
  limit(value) {
    return new Query(this.store, this.name, this.filters, value);
  }
  async get() {
    const items = (this.store.collections[this.name] || [])
        .filter((item) => this.filters.every(([field, value]) => item.data[field] === value))
        .slice(0, this.maximum);
    return {docs: items.map((item) => new Snapshot(item.id, structuredClone(item.data), true))};
  }
}
class Ref {
  constructor(store, name, id) {
    this.store = store;
    this.name = name;
    this.id = id;
    this.path = `${name}/${id}`;
  }
  async get() {
    const item = (this.store.collections[this.name] || []).find((entry) => entry.id === this.id);
    return item ? new Snapshot(item.id, structuredClone(item.data), true) : new Snapshot(this.id, undefined, false);
  }
}
class Collection extends Query {
  doc(id) {
    return new Ref(this.store, this.name, id);
  }
}
class Transaction {
  constructor(store) {
    this.store = store;
    this.pending = [];
  }
  async get(ref) {
    return ref.get();
  }
  create(ref, data) {
    this.pending.push({ref, data: structuredClone(data)});
  }
  commit() {
    for (const {ref, data} of this.pending) {
      const list = this.store.collections[ref.name] ||= [];
      if (list.some((entry) => entry.id === ref.id)) throw new Error("already exists");
      list.push({id: ref.id, data});
      this.store.writes += 1;
    }
  }
}
class FakeDb {
  constructor(collections, {transactionFailure = false} = {}) {
    this.collections = structuredClone(collections);
    this.transactionFailure = transactionFailure;
    this.writes = 0;
  }
  collection(name) {
    return new Collection(this, name);
  }
  async runTransaction(callback) {
    const transaction = new Transaction(this);
    const result = await callback(transaction);
    if (this.transactionFailure) throw new Error("simulated transaction failure");
    transaction.commit();
    return result;
  }
}

const resolveContext = async ({uid}) => ({uid, tenantId: "tenant-1", brandId: "brand-1"});
const clock = {now: () => "2026-07-24T15:30:00.000Z"};

function baseCollections() {
  const base = {
    tenant_memberships: [{id: "membership-1", data: {uid: "user-1", tenantId: "tenant-1", status: "active", role: "owner"}}],
    case_files: [{id: "case-1", data: {
      contractVersion: "case-file-v1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      caseNumber: "VK-2026-EA953C48",
      title: "Dejure Spor Ayakkabı",
      status: "closed",
      stage: "legal_review",
      openedAt: "2026-01-01T00:00:00.000Z",
      closedAt: "2026-07-20T00:00:00.000Z",
      legalHold: {active: true, activeCount: 1, latestHoldId: "hold-1", startedAt: "2026-07-21T00:00:00.000Z"},
      retention: {active: true, recordId: "retention-1", policyCode: "TR-10Y", policyName: "On yıl", policyVersion: 1, anchorType: "case_closed_at", anchorAt: "2026-07-20T00:00:00.000Z", retainUntil: "2036-07-20T00:00:00.000Z", dispositionStatus: "blocked_by_legal_hold", dispositionEligible: false, blockedReason: "active_legal_hold"},
    }}],
  };
  const sections = {
    case_events: {eventType: "case_opened", occurredAt: "2026-01-01T00:00:00.000Z"},
    case_evidence_refs: {title: "Kaynak kayıt", integrityStatus: "verified"},
    case_audit_events: {action: "case.created"},
    case_evidence_chain_events: {evidenceRefId: "evidence-1", sequence: 1, chainHash: "a".repeat(64)},
    case_review_tasks: {taskNumber: "GRV-1", status: "completed"},
    case_review_task_events: {taskId: "task-1", eventType: "completed"},
    case_parties: {partyNumber: "TRF-1", displayName: "Satıcı"},
    case_relationships: {relationshipNumber: "ILSK-1", relationshipType: "seller_of"},
    case_graph_events: {targetType: "party", eventType: "party_created"},
    case_legal_holds: {holdNumber: "HM-1", status: "active"},
    case_legal_hold_events: {holdId: "hold-1", eventType: "started"},
    case_retention_records: {policyCode: "TR-10Y", policyVersion: 1},
    case_retention_events: {eventType: "policy_set", policyCode: "TR-10Y"},
  };
  for (const [collection, data] of Object.entries(sections)) {
    base[collection] = [{id: `${collection}-1`, data: {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", ...data}}];
  }
  base.case_export_packages = [];
  base.case_export_events = [];
  return base;
}

function createPayload(digest, requestId = "123e4567-e89b-42d3-a456-426614174401") {
  return {
    contractVersion: "case-export-package-create-request-v1",
    caseId: "case-1",
    purpose: "legal_review",
    note: "Mahkeme ön incelemesi için.",
    expectedManifestDigestSha256: digest,
    requestId,
  };
}

test("export request contracts are strict", () => {
  assert.deepEqual(readinessRequest({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}), {caseId: "case-1"});
  assert.throws(() => readinessRequest({contractVersion: "case-export-readiness-request-v1", caseId: "case-1", extra: true}), /unsupported/);
  assert.deepEqual(listRequest({contractVersion: "case-export-package-list-request-v1", caseId: "case-1"}), {caseId: "case-1", pageSize: 25});
  assert.throws(() => listRequest({contractVersion: "case-export-package-list-request-v1", caseId: "case-1", pageSize: 51}), /pageSize/);
  assert.equal(createRequest(createPayload("a".repeat(64))).purpose, "legal_review");
  assert.throws(() => createRequest({...createPayload("a".repeat(64)), purpose: "invalid"}), /purpose/);
  assert.deepEqual(detailRequest({contractVersion: "case-export-package-detail-request-v1", packageId: "b".repeat(64)}), {packageId: "b".repeat(64)});
  assert.equal(canonicalJson({b: 2, a: 1}), "{\"a\":1,\"b\":2}");
});

test("readiness is owner scoped deterministic bounded and zero-write", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const request = {contractVersion: "case-export-readiness-request-v1", caseId: "case-1"};
  const first = await service.readiness(request, {uid: "user-1"});
  const second = await service.readiness(request, {uid: "user-1"});
  assert.equal(first.ready, true);
  assert.equal(first.manifestDigestSha256, second.manifestDigestSha256);
  assert.equal(first.totalRecordCount, 14);
  assert.equal(first.sectionCounts.case_evidence_refs, 1);
  assert.equal(first.legalHold.active, true);
  assert.equal(first.retention.dispositionStatus, "blocked_by_legal_hold");
  assert.equal(first.binaryEvidenceIncluded, false);
  assert.ok(first.estimatedManifestBytes < MAX_MANIFEST_BYTES);
  assert.equal(db.writes, 0);

  const foreign = baseCollections();
  foreign.case_files[0].data.canonicalBrandId = "brand-other";
  await assert.rejects(() => createCaseExportService({db: new FakeDb(foreign), clock, resolveContext}).readiness(request, {uid: "user-1"}), (error) => error.code === "not-found");

  const nonOwner = baseCollections();
  nonOwner.tenant_memberships[0].data.role = "member";
  await assert.rejects(() => createCaseExportService({db: new FakeDb(nonOwner), clock, resolveContext}).readiness(request, {uid: "user-1"}), (error) => error.code === "permission-denied");
});

test("package create is atomic immutable idempotent and auditable", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const readiness = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const request = createPayload(readiness.manifestDigestSha256);
  const first = await service.createPackage(request, {uid: "user-1"});
  assert.equal(first.duplicate, false);
  assert.equal(first.totalRecordCount, 14);
  assert.equal(db.collections.case_export_packages.length, 1);
  assert.equal(db.collections.case_export_events.length, 1);
  assert.equal(db.collections.case_events.length, 2);
  assert.equal(db.collections.case_audit_events.length, 2);
  assert.equal(db.writes, 4);
  const stored = db.collections.case_export_packages[0].data;
  assert.equal(stored.binaryEvidenceIncluded, false);
  assert.equal(stored.manifestDigestSha256, readiness.manifestDigestSha256);
  assert.equal(stored.appendOnly, true);
  const manifest = JSON.parse(stored.manifestJson);
  assert.equal(manifest.legalHold.active, true);
  assert.equal(manifest.retention.policyCode, "TR-10Y");
  assert.equal(manifest.sections.find((item) => item.collection === "case_evidence_refs").records[0].data.title, "Kaynak kayıt");

  db.collections.case_evidence_refs[0].data.title = "Daha sonra değişti";
  const duplicate = await service.createPackage(request, {uid: "user-1"});
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.manifestDigestSha256, first.manifestDigestSha256);
  assert.equal(db.writes, 4);

  await assert.rejects(() => service.createPackage({...request, purpose: "other"}, {uid: "user-1"}), (error) => error.code === "already-exists");
});

test("package list is case scoped globally ordered bounded and zero-write", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const ready = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const first = await service.createPackage(createPayload(ready.manifestDigestSha256, "123e4567-e89b-42d3-a456-426614174401"), {uid: "user-1"});
  db.collections.case_export_packages[0].data.createdAt = "2026-07-24T15:30:00.000Z";
  db.collections.case_export_packages.push({id: "f".repeat(64), data: {...db.collections.case_export_packages[0].data, packageId: "f".repeat(64), requestId: "123e4567-e89b-42d3-a456-426614174402", requestFingerprint: "b".repeat(64), createdAt: "2026-07-24T15:31:00.000Z"}});
  const before = db.writes;
  const result = await service.listPackages({contractVersion: "case-export-package-list-request-v1", caseId: "case-1", pageSize: 1}, {uid: "user-1"});
  assert.equal(result.packages.length, 1);
  assert.equal(result.packages[0].packageId, "f".repeat(64));
  assert.equal(result.hasMore, true);
  assert.equal(result.totalPackageCount, 2);
  assert.equal(result.maximumPackagesPerCase, MAX_PACKAGES_PER_CASE);
  assert.equal(result.readOnly, true);
  assert.equal(db.writes, before);
  assert.notEqual(result.packages[0].packageId, first.packageId);
});

test("package creation enforces the per-case immutable package cap with zero writes", async () => {
  const values = baseCollections();
  values.case_export_packages = Array.from({length: MAX_PACKAGES_PER_CASE}, (_, index) => ({
    id: String(index).padStart(64, "0"),
    data: {
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      caseId: "case-1",
      packageId: String(index).padStart(64, "0"),
      createdAt: `2026-07-24T15:${String(index).padStart(2, "0")}:00.000Z`,
    },
  }));
  const db = new FakeDb(values);
  const service = createCaseExportService({db, clock, resolveContext});
  const ready = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  await assert.rejects(() => service.createPackage(createPayload(ready.manifestDigestSha256), {uid: "user-1"}), (error) => error.code === "resource-exhausted");
  assert.equal(db.writes, 0);
  assert.equal(db.collections.case_export_packages.length, MAX_PACKAGES_PER_CASE);
});

test("snapshot drift is rejected with zero writes", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const readiness = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  db.collections.case_parties[0].data.displayName = "Değişen taraf";
  await assert.rejects(() => service.createPackage(createPayload(readiness.manifestDigestSha256), {uid: "user-1"}), (error) => error.code === "failed-precondition");
  assert.equal(db.writes, 0);
  assert.equal(db.collections.case_export_packages.length, 0);
});

test("package detail verifies canonical manifest identity metadata and scope", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const ready = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const created = await service.createPackage(createPayload(ready.manifestDigestSha256), {uid: "user-1"});
  const detail = await service.packageDetail({contractVersion: "case-export-package-detail-request-v1", packageId: created.packageId}, {uid: "user-1"});
  assert.equal(detail.integrityStatus, "verified");
  assert.equal(detail.manifest.contractVersion, "case-export-manifest-v1");
  assert.equal(detail.readOnly, true);
  assert.equal(detail.writesPerformed, 0);

  db.collections.case_export_packages[0].data.packageId = "f".repeat(64);
  await assert.rejects(() => service.packageDetail({contractVersion: "case-export-package-detail-request-v1", packageId: created.packageId}, {uid: "user-1"}), (error) => error.code === "failed-precondition");
});

test("package detail rejects a non-canonical manifest even when digest and byte metadata are recomputed", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCaseExportService({db, clock, resolveContext});
  const ready = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const created = await service.createPackage(createPayload(ready.manifestDigestSha256), {uid: "user-1"});
  const stored = db.collections.case_export_packages[0].data;
  const parsed = JSON.parse(stored.manifestJson);
  const reordered = JSON.stringify({tenantScope: parsed.tenantScope, ...parsed});
  stored.manifestJson = reordered;
  stored.manifestBytes = Buffer.byteLength(reordered, "utf8");
  stored.manifestDigestSha256 = createHash("sha256").update(reordered).digest("hex");
  await assert.rejects(() => service.packageDetail({contractVersion: "case-export-package-detail-request-v1", packageId: created.packageId}, {uid: "user-1"}), (error) => error.code === "failed-precondition");
});

test("handlers require auth and App Check for package creation", async () => {
  const db = new FakeDb(baseCollections());
  const readyHandler = createHandler("readiness", {db, appCheck: false});
  await assert.rejects(() => readyHandler({data: {contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}}), (error) => error.code === "unauthenticated");

  const service = createCaseExportService({db, clock, resolveContext});
  const ready = await service.readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const createHandlerValue = createHandler("createPackage", {db});
  await assert.rejects(() => createHandlerValue({auth: {uid: "user-1"}, data: createPayload(ready.manifestDigestSha256)}), (error) => error.code === "failed-precondition");
});

test("transaction failure leaves no partial export writes", async () => {
  const source = baseCollections();
  const readyDb = new FakeDb(source);
  const ready = await createCaseExportService({db: readyDb, clock, resolveContext}).readiness({contractVersion: "case-export-readiness-request-v1", caseId: "case-1"}, {uid: "user-1"});
  const db = new FakeDb(source, {transactionFailure: true});
  const service = createCaseExportService({db, clock, resolveContext});
  const before = structuredClone(db.collections);
  await assert.rejects(() => service.createPackage(createPayload(ready.manifestDigestSha256), {uid: "user-1"}), /simulated transaction failure/);
  assert.deepEqual(db.collections, before);
  assert.equal(db.writes, 0);
});
