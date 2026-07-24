/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {Readable} = require("node:stream");
const {test} = require("node:test");
const {
  BUCKET,
  MAX_SESSION_ISSUES_PER_WINDOW,
  MAX_SIZE_BYTES,
  MIME_EXTENSIONS,
  SERVICE_ACCOUNT,
  EvidenceObjectBindingError,
  callableOptions,
  createEvidenceObjectBindingService,
  createGoogleUploadInitiator,
  createRequest,
  createStorageObjectPromoter,
  detailRequest,
  finalizeRequest,
  handler,
  serverEvidenceObjectName,
  serverObjectName,
} = require("./evidence_object_binding");

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";
const SECOND_REQUEST_ID = "323e4567-e89b-42d3-a456-426614174000";
const FINALIZE_REQUEST_ID = "223e4567-e89b-42d3-a456-426614174000";
const NOW = new Date("2026-07-24T09:00:00.000Z");

class Snapshot {
  constructor(id, value) {
    this.id = id;
    this.value = value;
    this.exists = value !== undefined;
  }
  data() {
    return this.value === undefined ? undefined : structuredClone(this.value);
  }
}
class DocumentRef {
  constructor(db, collectionName, id) {
    this.db = db;
    this.collectionName = collectionName;
    this.id = id;
  }
  get() {
    return Promise.resolve(new Snapshot(this.id, this.db.value(this.collectionName, this.id)));
  }
}
class Query {
  constructor(db, collectionName, filters = [], maximum = Infinity) {
    this.db = db;
    this.collectionName = collectionName;
    this.filters = filters;
    this.maximum = maximum;
  }
  where(field, operation, value) {
    assert.equal(operation, "==");
    return new Query(this.db, this.collectionName, [...this.filters, [field, value]], this.maximum);
  }
  limit(value) {
    return new Query(this.db, this.collectionName, this.filters, value);
  }
  async get() {
    const rows = Object.entries(this.db.state[this.collectionName] || {}).filter(([, data]) => this.filters.every(([field, value]) => data[field] === value)).slice(0, this.maximum);
    return {docs: rows.map(([id, data]) => new Snapshot(id, data))};
  }
}
class CollectionRef extends Query {
  doc(id) {
    return new DocumentRef(this.db, this.collectionName, id);
  }
}
class FakeDb {
  constructor(seed) {
    this.state = structuredClone(seed);
    this.failAfterWrites = null;
    this.writeCount = 0;
  }
  collection(name) {
    return new CollectionRef(this, name);
  }
  value(collectionName, id) {
    return this.state[collectionName]?.[id];
  }
  async runTransaction(callback) {
    const next = structuredClone(this.state);
    let writes = 0;
    const mutate = (action) => {
      writes += 1;
      if (this.failAfterWrites != null && writes > this.failAfterWrites) throw new Error("transaction failure");
      action();
    };
    const transaction = {
      get: async (ref) => new Snapshot(ref.id, next[ref.collectionName]?.[ref.id]),
      create: (ref, value) => mutate(() => {
        next[ref.collectionName] ||= {};
        if (next[ref.collectionName][ref.id] !== undefined) throw new Error("already exists");
        next[ref.collectionName][ref.id] = structuredClone(value);
      }),
      update: (ref, value) => mutate(() => {
        if (next[ref.collectionName]?.[ref.id] === undefined) throw new Error("missing");
        Object.assign(next[ref.collectionName][ref.id], structuredClone(value));
      }),
    };
    const result = await callback(transaction);
    this.state = next;
    this.writeCount += writes;
    return result;
  }
}
function seed() {
  return {
    tenant_memberships: {membership: {uid: "user-1", tenantId: "tenant-1", status: "active"}},
    canonical_brands: {"brand-1": {tenantId: "tenant-1", status: "active"}},
    case_files: {"case-1": {tenantId: "tenant-1", canonicalBrandId: "brand-1", status: "open"}},
    case_evidence_refs: {"evidence-1": {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", chainEventCount: 7, custodyStatus: "registered", objectBindingSummary: {preservedField: "keep"}}},
    case_evidence_upload_sessions: {},
    case_evidence_objects: {},
    case_evidence_object_events: {},
    case_events: {},
    case_audit_events: {},
  };
}
function invocation(origin = "https://markakalkan-app.web.app") {
  return {auth: {uid: "user-1"}, app: {appId: "app-1"}, rawRequest: {headers: {origin}}};
}
function createPayload(overrides = {}) {
  return {contractVersion: "case-evidence-upload-session-create-request-v1", caseId: "case-1", evidenceRefId: "evidence-1", fileName: "kanıt.pdf", contentType: "application/pdf", sizeBytes: 8, requestId: REQUEST_ID, ...overrides};
}
function finalizePayload(sessionId, overrides = {}) {
  return {contractVersion: "case-evidence-upload-finalize-request-v1", uploadSessionId: sessionId, generation: "42", requestId: FINALIZE_REQUEST_ID, ...overrides};
}
function storageFile(content, metadata) {
  return {
    content,
    getMetadata: async () => [structuredClone(metadata)],
    createReadStream: () => Readable.from([content]),
  };
}
function harness(options = {}) {
  const db = new FakeDb(options.seed || seed());
  const initiated = [];
  const promotions = [];
  const files = new Map();
  const nowState = {value: new Date(options.now || NOW)};
  let promotionFailures = Number(options.promotionFailures || 0);
  const bucket = {
    name: BUCKET,
    file: (name, fileOptions = {}) => {
      const key = `${name}|${fileOptions.generation || "latest"}`;
      if (!files.has(key)) throw new Error(`missing storage fixture ${key}`);
      return files.get(key);
    },
  };
  const promoteObject = async (value) => {
    promotions.push({destinationObjectName: value.destinationObjectName, contentType: value.contentType, metadata: structuredClone(value.metadata)});
    if (promotionFailures > 0) {
      promotionFailures -= 1;
      throw new Error("promotion failure");
    }
    const generation = "84";
    const content = value.sourceFile.content;
    const metadata = {
      bucket: BUCKET,
      name: value.destinationObjectName,
      generation,
      size: String(content.length),
      contentType: value.contentType,
      metadata: structuredClone(value.metadata),
    };
    const file = storageFile(content, metadata);
    files.set(`${value.destinationObjectName}|${generation}`, file);
    files.set(`${value.destinationObjectName}|latest`, file);
    return {duplicate: promotions.length > 1, file, metadata};
  };
  const service = createEvidenceObjectBindingService({
    db,
    bucket,
    initiateUpload: async (value) => {
      initiated.push(structuredClone(value));
      if (options.initiationError) throw options.initiationError;
      return "https://upload.example/session-secret";
    },
    promoteObject,
    clock: {now: () => new Date(nowState.value), timestamp: (date) => date.toISOString()},
  });
  return {db, initiated, promotions, files, bucket, service, nowState};
}
function addStagingFixture(value, created, overrides = {}) {
  const session = value.db.state.case_evidence_upload_sessions[created.uploadSessionId];
  const content = overrides.content || Buffer.from("evidence");
  const metadata = {
    bucket: BUCKET,
    name: session.objectName,
    generation: overrides.generation || "42",
    size: String(overrides.size ?? content.length),
    contentType: overrides.contentType || session.contentType,
    metadata: {
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      caseId: "case-1",
      evidenceRefId: overrides.evidenceRefId || "evidence-1",
      uploadSessionId: created.uploadSessionId,
      objectStage: overrides.objectStage || "staging",
    },
  };
  value.files.set(`${session.objectName}|${metadata.generation}`, storageFile(content, metadata));
  return {session, metadata, content};
}

test("strict contracts reject unsafe IDs, unknown storage fields and MIME/extension mismatch", () => {
  for (const field of ["origin", "bucket", "objectName", "generation"]) assert.throws(() => createRequest(createPayload({[field]: "forbidden"})), EvidenceObjectBindingError);
  assert.throws(() => createRequest(createPayload({sizeBytes: MAX_SIZE_BYTES + 1})), EvidenceObjectBindingError);
  assert.throws(() => createRequest(createPayload({contentType: "application/x-msdownload"})), EvidenceObjectBindingError);
  assert.throws(() => createRequest(createPayload({caseId: "case/1"})), EvidenceObjectBindingError);
  assert.throws(() => createRequest(createPayload({evidenceRefId: "evidence\\1"})), EvidenceObjectBindingError);
  assert.throws(() => createRequest(createPayload({fileName: "payload.exe"})), EvidenceObjectBindingError);
  assert.equal(createRequest(createPayload({fileName: "foto.JPEG", contentType: "image/jpeg"})).fileName, "foto.JPEG");
  assert.equal(Object.keys(MIME_EXTENSIONS).length, 13);
  assert.throws(() => finalizeRequest(finalizePayload("A".repeat(64))), EvidenceObjectBindingError);
  assert.throws(() => detailRequest({contractVersion: "case-evidence-object-detail-request-v1", evidenceObjectId: "/" + "a".repeat(63)}), EvidenceObjectBindingError);
  assert.throws(() => finalizeRequest(finalizePayload("a".repeat(64), {bucket: BUCKET})), EvidenceObjectBindingError);
});

test("write callable boundary requires Auth and App Check and uses the dedicated runtime identity", async () => {
  const writeHandler = handler("createUploadSession", {service: {createUploadSession: async () => ({ok: true})}, appCheck: true, log: {info: () => {}}});
  await assert.rejects(() => writeHandler({data: {}, app: {appId: "app-1"}}), (error) => error.code === "unauthenticated");
  await assert.rejects(() => writeHandler({data: {}, auth: {uid: "user-1"}}), (error) => error.code === "failed-precondition");
  assert.equal((await writeHandler({data: {}, auth: {uid: "user-1"}, app: {appId: "app-1"}})).ok, true);
  assert.deepEqual(callableOptions(true, 1), {region: "europe-west3", enforceAppCheck: true, maxInstances: 1, serviceAccount: SERVICE_ACCOUNT});
});

test("authenticated JSON API initiation uses exact size, MIME, origin and create-only precondition", async () => {
  const calls = [];
  const initiate = createGoogleUploadInitiator({
    credential: {getAccessToken: async () => ({access_token: "token-secret"})},
    fetchImpl: async (url, options) => {
      calls.push({url: String(url), options});
      return {ok: true, status: 200, headers: {get: (name) => name === "location" ? "https://upload.example/private" : null}};
    },
  });
  const result = await initiate({bucket: BUCKET, objectName: "server/name.pdf", contentType: "application/pdf", sizeBytes: 8, metadata: {tenantId: "tenant-1"}, origin: "https://markakalkan.com"});
  assert.equal(result, "https://upload.example/private");
  const url = new URL(calls[0].url);
  assert.equal(url.searchParams.get("uploadType"), "resumable");
  assert.equal(url.searchParams.get("ifGenerationMatch"), "0");
  assert.equal(url.searchParams.get("name"), "server/name.pdf");
  assert.equal(calls[0].options.headers["X-Upload-Content-Length"], "8");
  assert.equal(calls[0].options.headers["X-Upload-Content-Type"], "application/pdf");
  assert.equal(calls[0].options.headers.Origin, "https://markakalkan.com");
  assert.match(calls[0].options.headers.Authorization, /^Bearer /);
});

test("storage promotion is create-only and recovers an already-created destination without delete", async () => {
  const calls = [];
  const permanentMetadata = {bucket: BUCKET, name: "case-evidence/permanent/evidence.pdf", generation: "84", size: "8", contentType: "application/pdf", metadata: {objectStage: "evidence"}};
  const copiedFile = {getMetadata: async () => [permanentMetadata]};
  const destination = {getMetadata: async () => [permanentMetadata]};
  const bucket = {file: (name, options = {}) => options.generation ? {name, options} : destination};
  const source = {
    copy: async (target, options) => {
      calls.push({target, options});
      return [copiedFile];
    },
  };
  const promote = createStorageObjectPromoter();
  const first = await promote({bucket, sourceFile: source, destinationObjectName: permanentMetadata.name, contentType: "application/pdf", metadata: {objectStage: "evidence"}});
  assert.equal(first.duplicate, false);
  assert.equal(calls[0].options.preconditionOpts.ifGenerationMatch, 0);
  assert.equal(calls[0].options.contentType, "application/pdf");
  assert.deepEqual(calls[0].options.metadata, {objectStage: "evidence"});
  const conflictSource = {
    copy: async () => {
      const error = new Error("exists");
      error.code = 412;
      throw error;
    },
  };
  const recovered = await promote({bucket, sourceFile: conflictSource, destinationObjectName: permanentMetadata.name, contentType: "application/pdf", metadata: {objectStage: "evidence"}});
  assert.equal(recovered.duplicate, true);
  assert.equal(recovered.metadata.generation, "84");
});

test("session is deterministic, single-active, quota-controlled and duplicate calls do not mint another URI", async () => {
  const value = harness();
  const result = await value.service.createUploadSession(createPayload(), invocation());
  assert.equal(result.duplicate, false);
  assert.equal(result.uploadUriAvailable, true);
  assert.equal(value.initiated.length, 1);
  assert.equal(value.initiated[0].objectName, serverObjectName({tenantId: "tenant-1"}, "case-1", "evidence-1", result.uploadSessionId, "application/pdf"));
  const summary = value.db.state.case_evidence_refs["evidence-1"].objectBindingSummary;
  assert.equal(summary.preservedField, "keep");
  assert.equal(summary.activeUploadSessionId, result.uploadSessionId);
  assert.equal(summary.activeUploadStatus, "upload_pending");
  assert.equal(summary.uploadSessionIssueCount, 1);
  const duplicate = await value.service.createUploadSession(createPayload(), invocation());
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.uploadUri, null);
  assert.equal(duplicate.uploadUriAvailable, false);
  assert.equal(value.initiated.length, 1);
  await assert.rejects(() => value.service.createUploadSession(createPayload({requestId: SECOND_REQUEST_ID}), invocation()), (error) => error.code === "resource-exhausted");
  assert.equal(Object.keys(value.db.state.case_evidence_upload_sessions).length, 1);
  const quotaSeed = seed();
  quotaSeed.case_evidence_refs["evidence-1"].objectBindingSummary = {uploadSessionWindowStartedAt: NOW.toISOString(), uploadSessionIssueCount: MAX_SESSION_ISSUES_PER_WINDOW};
  await assert.rejects(() => harness({seed: quotaSeed}).service.createUploadSession(createPayload(), invocation()), (error) => error.code === "resource-exhausted");
});

test("failed upload initiation leaves Firestore session and evidence summary unchanged", async () => {
  const value = harness({initiationError: new Error("network")});
  const before = structuredClone(value.db.state.case_evidence_refs["evidence-1"]);
  await assert.rejects(() => value.service.createUploadSession(createPayload(), invocation()));
  assert.equal(Object.keys(value.db.state.case_evidence_upload_sessions).length, 0);
  assert.deepEqual(value.db.state.case_evidence_refs["evidence-1"], before);
});

test("finalization reserves promotion, copies to permanent path and atomically binds immutable identity", async () => {
  const value = harness();
  const created = await value.service.createUploadSession(createPayload(), invocation());
  const {session} = addStagingFixture(value, created);
  const result = await value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation());
  assert.equal(result.duplicate, false);
  assert.equal(result.sha256, "ee8250fb76e094b34b471f13a73dbbe51d1ae142e9df59d7c0d31ec20f0a0a8e");
  assert.equal(value.promotions.length, 1);
  assert.equal(value.promotions[0].destinationObjectName, serverEvidenceObjectName({tenantId: "tenant-1"}, "case-1", "evidence-1", created.uploadSessionId, "application/pdf"));
  const objectRecord = value.db.state.case_evidence_objects[result.evidenceObjectId];
  assert.equal(objectRecord.immutable, true);
  assert.notEqual(objectRecord.objectName, session.objectName);
  assert.equal(objectRecord.generation, "84");
  assert.equal(objectRecord.stagingGeneration, "42");
  const evidence = value.db.state.case_evidence_refs["evidence-1"];
  assert.equal(evidence.chainEventCount, 7);
  assert.equal(evidence.custodyStatus, "registered");
  assert.equal(evidence.objectBindingSummary.preservedField, "keep");
  assert.equal(evidence.objectBindingSummary.objectCount, 1);
  assert.equal(evidence.objectBindingSummary.activeUploadSessionId, null);
  assert.equal(evidence.objectBindingSummary.activeUploadStatus, null);
  const sessionAfter = value.db.state.case_evidence_upload_sessions[created.uploadSessionId];
  assert.equal(sessionAfter.status, "finalized");
  assert.equal(sessionAfter.permanentGeneration, "84");
  const duplicate = await value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation());
  assert.equal(duplicate.duplicate, true);
  assert.equal(value.promotions.length, 1);
  assert.equal(Object.keys(value.db.state.case_evidence_objects).length, 1);
});

test("promotion failure remains tracked and retry completes even after the original session expiry", async () => {
  const value = harness({promotionFailures: 1});
  const created = await value.service.createUploadSession(createPayload(), invocation());
  addStagingFixture(value, created);
  await assert.rejects(() => value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation()), /promotion failure/);
  assert.equal(value.db.state.case_evidence_upload_sessions[created.uploadSessionId].status, "promotion_pending");
  assert.equal(value.db.state.case_evidence_refs["evidence-1"].objectBindingSummary.activeUploadStatus, "promotion_pending");
  assert.equal(Object.keys(value.db.state.case_evidence_objects).length, 0);
  value.nowState.value = new Date("2026-07-25T12:00:00.000Z");
  const result = await value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation());
  assert.equal(result.duplicate, false);
  assert.equal(value.db.state.case_evidence_upload_sessions[created.uploadSessionId].status, "finalized");
});

test("final binding transaction failure leaves a recoverable promotion reservation and no partial records", async () => {
  const value = harness();
  const created = await value.service.createUploadSession(createPayload(), invocation());
  addStagingFixture(value, created);
  value.db.failAfterWrites = 2;
  await assert.rejects(() => value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation()), /transaction failure/);
  assert.equal(value.db.state.case_evidence_upload_sessions[created.uploadSessionId].status, "promotion_pending");
  assert.equal(Object.keys(value.db.state.case_evidence_objects).length, 0);
  assert.equal(Object.keys(value.db.state.case_evidence_object_events).length, 0);
  assert.equal(Object.keys(value.db.state.case_events).length, 0);
  assert.equal(Object.keys(value.db.state.case_audit_events).length, 0);
  value.db.failAfterWrites = null;
  const result = await value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation());
  assert.equal(result.duplicate, false);
  assert.equal(Object.keys(value.db.state.case_evidence_objects).length, 1);
  assert.equal(value.promotions.length, 2);
});

test("expired upload session and stream length mismatch are rejected before binding", async () => {
  const expired = harness();
  const created = await expired.service.createUploadSession(createPayload(), invocation());
  expired.db.state.case_evidence_upload_sessions[created.uploadSessionId].expiresAt = "2026-07-24T08:59:59.000Z";
  await assert.rejects(() => expired.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation()), (error) => error.code === "failed-precondition");
  assert.equal(Object.keys(expired.db.state.case_evidence_objects).length, 0);
  const mismatch = harness();
  const mismatchCreated = await mismatch.service.createUploadSession(createPayload(), invocation());
  addStagingFixture(mismatch, mismatchCreated, {content: Buffer.from("short"), size: 8});
  await assert.rejects(() => mismatch.service.finalizeUpload(finalizePayload(mismatchCreated.uploadSessionId), invocation()), (error) => error.code === "failed-precondition");
  assert.equal(Object.keys(mismatch.db.state.case_evidence_objects).length, 0);
});

test("metadata mismatch and closed cases are rejected without promotion", async () => {
  const value = harness();
  const created = await value.service.createUploadSession(createPayload(), invocation());
  addStagingFixture(value, created, {evidenceRefId: "WRONG"});
  await assert.rejects(() => value.service.finalizeUpload(finalizePayload(created.uploadSessionId), invocation()), (error) => error.code === "failed-precondition");
  assert.equal(value.promotions.length, 0);
  const closedSeed = seed();
  closedSeed.case_files["case-1"].status = "archived";
  await assert.rejects(() => harness({seed: closedSeed}).service.createUploadSession(createPayload(), invocation()), (error) => error.code === "failed-precondition");
  await assert.rejects(() => value.service.createUploadSession(createPayload(), invocation("https://evil.example")), (error) => error.code === "permission-denied");
});

test("object detail is tenant-scoped, zero-write and omits permanent and staging storage identity", async () => {
  const seeded = seed();
  seeded.case_evidence_objects["a".repeat(64)] = {tenantId: "tenant-1", canonicalBrandId: "brand-1", caseId: "case-1", evidenceRefId: "evidence-1", originalFileName: "kanıt.pdf", contentType: "application/pdf", sizeBytes: 8, sha256: "b".repeat(64), hashAlgorithm: "SHA-256", bucket: BUCKET, objectName: "secret/path", generation: "84", stagingObjectName: "secret/staging", stagingGeneration: "42", createdByUid: "user-1", createdAt: NOW.toISOString()};
  seeded.case_evidence_object_events.event = {tenantId: "tenant-1", canonicalBrandId: "brand-1", evidenceObjectId: "a".repeat(64), eventType: "evidence_object_bound", actorUid: "user-1", occurredAt: NOW.toISOString()};
  const value = harness({seed: seeded});
  const before = structuredClone(value.db.state);
  const result = await value.service.objectDetail({contractVersion: "case-evidence-object-detail-request-v1", evidenceObjectId: "a".repeat(64)}, invocation());
  assert.equal(result.writesPerformed, 0);
  assert.equal(result.originalFileName, "kanıt.pdf");
  for (const key of ["bucket", "objectName", "generation", "stagingObjectName", "stagingGeneration", "createdByUid"]) assert.equal(result[key], undefined);
  assert.equal(result.events[0].actorUid, undefined);
  assert.deepEqual(value.db.state, before);
});
