"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  withRunRetentionStorage,
} = require("./retention_firestore_adapter");
const {
  buildRunRecursiveCleanupPlan,
  cleanupStepCodes,
} = require("./retention_contract");
const port = require("./recursive_cleanup_firestore_port");

const scanRunId = "cleanup-run-1";
const expiresAt = "2026-07-29T15:00:00.000Z";
const now = "2026-07-29T16:00:00.000Z";

function clone(value) {
  return structuredClone(value);
}

class FakeDocumentSnapshot {
  constructor(ref, value) {
    this.ref = ref;
    this.exists = value !== undefined;
    this._value = value;
  }

  data() {
    return clone(this._value);
  }
}

class FakeQuerySnapshot {
  constructor(docs) {
    this.docs = docs;
    this.size = docs.length;
    this.empty = docs.length === 0;
  }
}

class FakeQuery {
  constructor(db, path, limitValue) {
    this.db = db;
    this.path = path;
    this.limitValue = limitValue;
  }

  async get() {
    const prefix = `${this.path}/`;
    const documents = [...this.db.documents.entries()]
        .filter(([path]) => {
          if (!path.startsWith(prefix)) return false;
          return !path.slice(prefix.length).includes("/");
        })
        .sort(([left], [right]) => left.localeCompare(right))
        .slice(0, this.limitValue)
        .map(([path, value]) => new FakeDocumentSnapshot(
            new FakeDocumentReference(this.db, path),
            value));
    return new FakeQuerySnapshot(documents);
  }
}

class FakeCollectionReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(this.db, `${this.path}/${id}`);
  }

  limit(value) {
    return new FakeQuery(this.db, this.path, value);
  }
}

class FakeDocumentReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  collection(name) {
    return new FakeCollectionReference(this.db, `${this.path}/${name}`);
  }

  async get() {
    return new FakeDocumentSnapshot(
        this,
        this.db.documents.get(this.path));
  }
}

class FakeBatch {
  constructor(db) {
    this.db = db;
    this.deletes = [];
  }

  delete(ref) {
    this.deletes.push(ref.path);
    return this;
  }

  async commit() {
    for (const path of this.deletes) {
      this.db.documents.delete(path);
    }
    return [];
  }
}

class FakeTransaction {
  constructor(db) {
    this.db = db;
    this.deletes = [];
  }

  async get(ref) {
    return ref.get();
  }

  delete(ref) {
    this.deletes.push(ref.path);
    return this;
  }

  commit() {
    for (const path of this.deletes) {
      this.db.documents.delete(path);
    }
  }
}

class FakeDb {
  constructor(entries = []) {
    this.documents = new Map(entries.map(
        ([path, value]) => [path, clone(value)]));
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  batch() {
    return new FakeBatch(this);
  }

  async runTransaction(handler) {
    const transaction = new FakeTransaction(this);
    const result = await handler(transaction);
    transaction.commit();
    return result;
  }
}

function runDocument(overrides = {}) {
  return withRunRetentionStorage({
    scanRunId,
    status: "completed",
    expiresAt,
    ...overrides,
  });
}

function rootPath(id = scanRunId) {
  return `risk_scan_runs/${id}`;
}

function request(overrides = {}) {
  return {
    scanRunId,
    now,
    batchSize: 2,
    ...overrides,
  };
}

function database({
  run = runDocument(),
  findings = [],
  observations = [],
  channels = [],
} = {}) {
  const entries = [[rootPath(), run]];
  for (const id of findings) {
    entries.push([`${rootPath()}/findings/${id}`, {id}]);
  }
  for (const id of observations) {
    entries.push([`${rootPath()}/observations/${id}`, {id}]);
  }
  for (const id of channels) {
    entries.push([`${rootPath()}/channels/${id}`, {id}]);
  }
  return new FakeDb(entries);
}

test("cleanup collections are frozen and exact", () => {
  assert.equal(Object.isFrozen(port.CLEANUP_COLLECTIONS), true);
  assert.deepEqual(port.CLEANUP_COLLECTIONS, {
    deleteFindings: "findings",
    deleteObservations: "observations",
    deleteChannels: "channels",
  });
});

test("runs collection is stable", () => {
  assert.equal(port.RUNS_COLLECTION, "risk_scan_runs");
});

test("db guard accepts a compatible database", () => {
  assert.equal(port.assertDb(database()) instanceof FakeDb, true);
});

test("db guard rejects an incomplete database", () => {
  assert.throws(() => port.assertDb({collection() {}}));
});

test("cleanup request normalizes required values", () => {
  assert.deepEqual(port.assertCleanupRequest(request()), request());
});

test("cleanup request rejects extra keys", () => {
  assert.throws(() => port.assertCleanupRequest({
    ...request(),
    force: true,
  }));
});

test("cleanup request rejects invalid run id", () => {
  assert.throws(() => port.assertCleanupRequest(
      request({scanRunId: "bad/id"})));
});

test("cleanup request rejects date-only now", () => {
  assert.throws(() => port.assertCleanupRequest(
      request({now: "2026-07-29"})));
});

test("cleanup request accepts an expected digest", () => {
  const digest = "a".repeat(64);
  assert.equal(
      port.assertCleanupRequest(request({
        expectedCleanupPlanDigestSha256: digest,
      })).expectedCleanupPlanDigestSha256,
      digest);
});

test("cleanup request rejects uppercase digest", () => {
  assert.throws(() => port.assertCleanupRequest(request({
    expectedCleanupPlanDigestSha256: "A".repeat(64),
  })));
});

test("collection step resolves findings", () => {
  const root = database().collection("risk_scan_runs").doc(scanRunId);
  assert.equal(
      port.collectionForStep(root, "deleteFindings").path,
      `${rootPath()}/findings`);
});

test("collection step rejects root deletion", () => {
  const root = database().collection("risk_scan_runs").doc(scanRunId);
  assert.throws(() => port.collectionForStep(root, "deleteRunRoot"));
});

test("expected digest accepts a matching plan", () => {
  const plan = buildRunRecursiveCleanupPlan({
    run: runDocument(),
    now,
    batchSize: 2,
  });
  assert.equal(
      port.assertExpectedPlanDigest(
          plan, plan.cleanupPlanDigestSha256),
      plan);
});

test("expected digest conflicts on mismatch", () => {
  const plan = buildRunRecursiveCleanupPlan({
    run: runDocument(),
    now,
    batchSize: 2,
  });
  assert.throws(
      () => port.assertExpectedPlanDigest(plan, "a".repeat(64)),
      (error) => error.code === "conflict");
});

test("missing result is complete and idempotent", () => {
  const value = port.buildMissingResult(request());
  assert.equal(value.outcome, "idempotent_success");
  assert.equal(value.complete, true);
  assert.deepEqual(value.completedStepCodes, cleanupStepCodes);
});

test("missing result preserves expected digest", () => {
  const digest = "b".repeat(64);
  assert.equal(
      port.buildMissingResult(request({
        expectedCleanupPlanDigestSha256: digest,
      })).cleanupPlanDigestSha256,
      digest);
});

test("query snapshot deletion removes every selected document", async () => {
  const db = database({findings: ["a", "b", "c"]});
  const root = db.collection("risk_scan_runs").doc(scanRunId);
  const snapshot = await root.collection("findings").limit(2).get();
  assert.equal(await port.deleteQuerySnapshot(db, snapshot), 2);
  assert.equal(
      await port.collectionHasDocuments(root.collection("findings")),
      true);
});

test("empty query deletion performs no writes", async () => {
  const db = database();
  const root = db.collection("risk_scan_runs").doc(scanRunId);
  const snapshot = await root.collection("findings").limit(2).get();
  assert.equal(await port.deleteQuerySnapshot(db, snapshot), 0);
});

test("collection existence detects empty collection", async () => {
  const db = database();
  const root = db.collection("risk_scan_runs").doc(scanRunId);
  assert.equal(
      await port.collectionHasDocuments(root.collection("findings")),
      false);
});

test("missing run cleanup is idempotent", async () => {
  const result = await port.executeRunRecursiveCleanupStep(
      new FakeDb(), request());
  assert.equal(result.outcome, "idempotent_success");
  assert.equal(result.complete, true);
});

test("non-terminal run cannot be cleaned", async () => {
  const db = database({run: runDocument({status: "created"})});
  await assert.rejects(
      port.executeRunRecursiveCleanupStep(db, request()),
      (error) => error.code === "failed-precondition");
});

test("unexpired run cannot be cleaned", async () => {
  const db = database({
    run: runDocument({expiresAt: "2026-07-30T15:00:00.000Z"}),
  });
  await assert.rejects(
      port.executeRunRecursiveCleanupStep(db, request()),
      (error) => error.code === "failed-precondition");
});

test("first cleanup batch deletes findings only", async () => {
  const db = database({
    findings: ["a", "b", "c"],
    observations: ["o"],
    channels: ["c"],
  });
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.outcome, "batch_deleted");
  assert.equal(result.stepCode, "deleteFindings");
  assert.equal(result.deletedCount, 2);
  assert.equal(result.remainingInStep, true);
  assert.equal(db.documents.has(`${rootPath()}/observations/o`), true);
});

test("final findings batch advances to observations", async () => {
  const db = database({
    findings: ["a"],
    observations: ["o"],
  });
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.outcome, "step_completed");
  assert.equal(result.nextStepCode, "deleteObservations");
  assert.deepEqual(result.completedStepCodes, ["deleteFindings"]);
});

test("empty findings allow observation deletion", async () => {
  const db = database({observations: ["a", "b", "c"]});
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.stepCode, "deleteObservations");
  assert.equal(result.deletedCount, 2);
});

test("empty evidence allows channel deletion", async () => {
  const db = database({channels: ["a", "b"]});
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.stepCode, "deleteChannels");
  assert.equal(result.outcome, "step_completed");
  assert.equal(result.nextStepCode, "deleteRunRoot");
});

test("empty descendants delete the root", async () => {
  const db = database();
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.outcome, "deleted");
  assert.equal(result.complete, true);
  assert.equal(db.documents.has(rootPath()), false);
});

test("root delete returns exact completed prefix", async () => {
  const result = await port.executeRunRecursiveCleanupStep(
      database(), request());
  assert.deepEqual(result.completedStepCodes, cleanupStepCodes);
  assert.equal(result.nextStepCode, null);
});

test("expected digest binds cleanup replay", async () => {
  const run = runDocument();
  const plan = buildRunRecursiveCleanupPlan({
    run,
    now,
    batchSize: 2,
  });
  const result = await port.executeRunRecursiveCleanupStep(
      database({run}),
      request({
        expectedCleanupPlanDigestSha256:
          plan.cleanupPlanDigestSha256,
      }));
  assert.equal(
      result.cleanupPlanDigestSha256,
      plan.cleanupPlanDigestSha256);
});

test("changed batch size conflicts with expected digest", async () => {
  const run = runDocument();
  const plan = buildRunRecursiveCleanupPlan({
    run,
    now,
    batchSize: 2,
  });
  await assert.rejects(
      port.executeRunRecursiveCleanupStep(
          database({run}),
          request({
            batchSize: 1,
            expectedCleanupPlanDigestSha256:
              plan.cleanupPlanDigestSha256,
          })),
      (error) => error.code === "conflict");
});

test("cleanup never deletes deferred top-level records", async () => {
  const db = database();
  db.documents.set(
      "risk_scan_reports/report-1",
      {scanRunId});
  db.documents.set(
      "risk_scan_claims/claim-1",
      {scanRunId});
  await port.executeRunRecursiveCleanupStep(db, request());
  assert.equal(db.documents.has("risk_scan_reports/report-1"), true);
  assert.equal(db.documents.has("risk_scan_claims/claim-1"), true);
});
