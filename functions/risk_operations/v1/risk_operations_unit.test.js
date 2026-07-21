/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {riskOperationsDiagnosticsV1, riskOperationsRequestV1} = require("./contracts");
const {CALLABLE_OPTIONS, createRiskOperationsCallableHandlerV1, diagnosticLogFields} = require("./callable");
const {caseCandidacy, evidenceQuality, graphNode, timelineEvent} = require("./projection");
const {createRiskOperationsReadServiceV1, paginate} = require("./service");

class Snapshot {
  constructor(id, data) {
    this.id = id; this._data = data;
  } data() {
    return this._data;
  }
}
class Query {
  constructor(store, name, filters = [], maximum = 1000) {
    this.store = store; this.name = name; this.filters = filters; this.maximum = maximum;
  } where(field, op, value) {
    assert.equal(op, "=="); return new Query(this.store, this.name, [...this.filters, [field, value]], this.maximum);
  } limit(value) {
    return new Query(this.store, this.name, this.filters, value);
  } async get() {
    if (this.store.fail === this.name) throw new Error("source unavailable"); const entries = this.store.collections[this.name] || []; return {docs: entries.filter((item) => this.filters.every(([field, value]) => item.data[field] === value)).slice(0, this.maximum).map((item) => new Snapshot(item.id, item.data))};
  }
}
class DocumentRef {
  constructor(store, path) {
    this.store = store; this.path = path;
  } collection(name) {
    return new Query(this.store, `${this.path}/${name}`);
  }
}
class Collection extends Query {
  doc(id) {
    return new DocumentRef(this.store, `${this.name}/${id}`);
  }
}
class FakeDb {
  constructor(collections, fail = null) {
    this.collections = collections; this.fail = fail; this.writes = 0;
  } collection(name) {
    return new Collection(this, name);
  }
}
const contextDocs = {"tenant_memberships": [{id: "membership-1", data: {uid: "user-1", tenantId: "tenant-1", status: "active"}}], "canonical_brands": [{id: "brand-1", data: {tenantId: "tenant-1", status: "active"}}], "monitoring_signals": [], "verificationScans": [], "shared_risk_signals": [], "brands/user-1/digitalDetectiveTasks": []};
const clock = {now: () => "2026-07-21T00:00:00.000Z"};
const diagnostics = Object.freeze({clientTabId: "client-tab-0001", navigationId: "navigation-0001", pageInstanceId: "page-instance-0001", loadAttemptId: "load-attempt-0001", trigger: "initial_mount", attemptSequence: 1});
const request = (value = {}) => ({...diagnostics, ...value});

test("request filters are strict and bounded", () => {
  assert.equal(riskOperationsRequestV1(request({pageSize: 50})).pageSize, 50);
  for (const invalid of [{unknown: true}, {pageSize: 51}, {severity: "urgent"}, {occurredFrom: "yesterday"}, {occurredFrom: "2026-07-22T00:00:00.000Z", occurredTo: "2026-07-21T00:00:00.000Z"}]) assert.throws(() => riskOperationsRequestV1(request(invalid)), /invalid|unsupported/);
});

test("diagnostic contract accepts canonical triggers and rejects malformed values", () => {
  for (const trigger of ["initial_mount", "date_change", "filter_change", "pull_to_refresh", "error_retry", "pagination"]) assert.equal(riskOperationsDiagnosticsV1(request({trigger})).trigger, trigger);
  for (const invalid of [request({trigger: "automatic_retry"}), request({attemptSequence: 0}), request({attemptSequence: -1}), request({attemptSequence: 1000001}), request({clientTabId: "x"}), request({loadAttemptId: "x".repeat(65)})]) assert.throws(() => riskOperationsDiagnosticsV1(invalid), /invalid|unsupported/);
});

test("evidence quality covers every canonical level", () => {
  assert.equal(evidenceQuality({assessable: false}).level, "unavailable");
  assert.equal(evidenceQuality({primaryVerified: true}).level, "verified_primary");
  assert.equal(evidenceQuality({sourceCount: 2}).level, "corroborated");
  assert.equal(evidenceQuality({sourceCount: 1}).level, "single_source");
  assert.equal(evidenceQuality({}).level, "insufficient");
});

test("case candidacy covers every status and always requires review", () => {
  const evaluatedAt = clock.now();
  const evidence = (level) => ({level});
  const values = [
    caseCandidacy({severity: "low", evidence: evidence("single_source"), evaluatedAt}),
    caseCandidacy({severity: "high", confidenceValue: .7, evidence: evidence("single_source"), evaluatedAt}),
    caseCandidacy({severity: "critical", confidenceValue: .9, evidence: evidence("corroborated"), sourceCount: 2, identityResolved: true, evaluatedAt}),
    caseCandidacy({severity: "critical", evidence: evidence("insufficient"), evaluatedAt}),
  ];
  assert.deepEqual(values.map((item) => item.status), ["not_candidate", "review_candidate", "strong_candidate", "blocked_insufficient_evidence"]);
  assert.equal(values.every((item) => item.requiresHumanReview), true);
});

test("timeline preserves unknown time and graph masks labels", () => {
  const timeline = timelineEvent({sourceSystem: "monitoring", sourceRecordId: "record", occurredAt: null, summary: "Observed"});
  assert.equal(timeline.occurredAt, null); assert.equal(timeline.occurredAtStatus, "unknown");
  const node = graphNode({id: "brand", type: "brand", label: "Sensitive Brand", sourceSystem: "monitoring", confidenceValue: .7, evidence: {level: "single_source"}});
  assert.match(node.maskedLabel, /^Se\*+nd$/); assert.doesNotMatch(node.maskedLabel, /Sensitive Brand/);
});

test("server resolves tenant context and returns deterministic empty projection without writes", async () => {
  const db = new FakeDb(contextDocs); const service = createRiskOperationsReadServiceV1({db, clock});
  const result = await service.list(request(), {uid: "user-1"});
  assert.deepEqual(result.tenantContext, {tenantId: "tenant-1", canonicalBrandId: "brand-1"});
  assert.deepEqual(result.items, []); assert.equal(result.summary.totalVisibleSignals, 0); assert.equal(result.writesPerformed, 0); assert.equal(db.writes, 0);
});

test("membership and tenant or brand mismatch fail closed", async () => {
  const service = createRiskOperationsReadServiceV1({db: new FakeDb(contextDocs), clock});
  await assert.rejects(() => service.list(request(), {uid: "missing"}), /no active tenant/);
  await assert.rejects(() => service.list(request({tenantId: "other"}), {uid: "user-1"}), /mismatch/);
  await assert.rejects(() => service.list(request({canonicalBrandId: "other"}), {uid: "user-1"}), /mismatch/);
});

test("monitoring adapter projects, filters and pagination deterministically", async () => {
  const monitoring = [
    {id: "b", data: {tenantId: "tenant-1", brandId: "brand-1", pageId: "page-b", signalLevel: "high", status: "new", title: "B signal", summary: "Repeated listing", detectedAt: "2026-07-20T00:00:00.000Z", createdAt: "2026-07-20T00:00:00.000Z", repeated: true}},
    {id: "a", data: {tenantId: "tenant-1", brandId: "brand-1", pageId: "page-a", signalLevel: "critical", status: "new", title: "A signal", summary: "Critical listing", detectedAt: "2026-07-20T00:00:00.000Z", createdAt: "2026-07-20T00:00:00.000Z", evidenceVerified: true, confidence: .9}},
  ];
  const db = new FakeDb({...contextDocs, monitoring_signals: monitoring}); const service = createRiskOperationsReadServiceV1({db, clock});
  const first = await service.list(request({sourceSystem: "monitoring", pageSize: 1}), {uid: "user-1"});
  assert.equal(first.items.length, 1); assert.ok(first.nextPageToken); assert.equal(first.items[0].sourceSystem, "monitoring");
  const second = await service.list(request({sourceSystem: "monitoring", pageSize: 1, pageToken: first.nextPageToken}), {uid: "user-1"});
  assert.equal(second.items.length, 1); assert.notEqual(first.items[0].signalId, second.items[0].signalId);
  assert.throws(() => paginate(first.items, riskOperationsRequestV1(request({pageToken: "bad"}))), /pageToken invalid/);
});

test("partial source failure is explicit and other sources remain available", async () => {
  const result = await createRiskOperationsReadServiceV1({db: new FakeDb(contextDocs, "monitoring_signals"), clock}).list(request(), {uid: "user-1"});
  assert.equal(result.sourceAvailability.find((item) => item.sourceSystem === "monitoring").status, "unavailable");
  assert.equal(result.sourceAvailability.find((item) => item.sourceSystem === "traceability").status, "available");
});

test("callable requires Auth and App Check and exposes immutable metadata", async () => {
  assert.deepEqual(CALLABLE_OPTIONS, {region: "europe-west3", enforceAppCheck: true, maxInstances: 3});
  const logs = []; const handler = createRiskOperationsCallableHandlerV1({db: new FakeDb(contextDocs), clock, logInfo: (event) => logs.push(event)});
  await assert.rejects(() => handler({data: request()}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  await assert.rejects(() => handler({auth: {uid: "user-1"}, data: request()}), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  const result = await handler({auth: {uid: "user-1", token: {email: "private@example.test"}}, app: {appId: "verified", token: "raw-app-check-token"}, data: request({query: "private-query"})});
  assert.equal(result.readOnly, true); assert.equal(result.writesPerformed, 0);
  assert.equal(logs.length, 2); assert.equal(logs[0].eventName, "risk_operations_read_started"); assert.equal(logs[1].eventName, "risk_operations_read_completed"); assert.equal(logs[1].transactionCommitted, false); assert.equal(logs[1].writeAttempted, false);
  const serialized = JSON.stringify(logs); for (const key of ["clientTabId", "navigationId", "pageInstanceId", "loadAttemptId"]) assert.equal(serialized.includes(diagnostics[key]), false); for (const sensitive of ["user-1", "verified", "private@example.test", "raw-app-check-token", "private-query"]) assert.equal(serialized.includes(sensitive), false);
  assert.equal(diagnosticLogFields(diagnostics).hashedClientTabId.length, 64);
});

test("diagnostics never grant tenant authority or bypass membership", async () => {
  const handler = createRiskOperationsCallableHandlerV1({db: new FakeDb(contextDocs), clock, logInfo: () => {}});
  await assert.rejects(() => handler({auth: {uid: "missing"}, app: {appId: "verified"}, data: request()}), /no active tenant/);
});
