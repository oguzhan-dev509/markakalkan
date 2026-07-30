"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  MAX_CLEANUP_BATCH_SIZE,
  MAX_GRACE_SECONDS,
} = require("./retention_contract");
const {
  withRunRetentionStorage,
} = require("./retention_firestore_adapter");
const scheduled = require("./scheduled_cleanup");

const now = new Date("2026-07-30T05:00:00.000Z");
function clone(value) {
  return structuredClone(value);
}
function runDocument(scanRunId, overrides = {}) {
  return withRunRetentionStorage({
    scanRunId,
    status: "completed",
    expiresAt: "2026-07-30T04:00:00.000Z",
    ...overrides,
  });
}
class FakeDocumentSnapshot {
  constructor(id, value) {
    this.id = id;
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
  constructor(db) {
    this.db = db;
    this.whereClause = null;
    this.orderClause = null;
    this.limitValue = null;
  }
  where(field, operator, value) {
    this.whereClause = {field, operator, value};
    this.db.lastQuery = this;
    return this;
  }
  orderBy(field, direction) {
    this.orderClause = {field, direction};
    return this;
  }
  limit(value) {
    this.limitValue = value;
    return this;
  }
  async get() {
    if (this.db.queryError) throw this.db.queryError;
    const cutoff = this.whereClause.value.getTime();
    const documents = [...this.db.documents.entries()]
        .filter(([, value]) =>
          value.expiresAtTimestamp.getTime() <= cutoff)
        .sort(([, left], [, right]) =>
          left.expiresAtTimestamp.getTime() -
          right.expiresAtTimestamp.getTime())
        .slice(0, this.limitValue)
        .map(([id, value]) => new FakeDocumentSnapshot(id, value));
    return new FakeQuerySnapshot(documents);
  }
}
class FakeCollection {
  constructor(db, name) {
    this.db = db;
    this.name = name;
  }
  where(field, operator, value) {
    return new FakeQuery(this.db).where(field, operator, value);
  }
}
class FakeDb {
  constructor(entries = []) {
    this.documents = new Map(entries.map(
        ([id, value]) => [id, clone(value)]));
    this.lastCollection = null;
    this.lastQuery = null;
    this.queryError = null;
  }
  collection(name) {
    this.lastCollection = name;
    return new FakeCollection(this, name);
  }
}
function fakeLogger() {
  return {
    infos: [],
    warnings: [],
    errors: [],
    info(message, data) {
      this.infos.push({message, data});
    },
    warn(message, data) {
      this.warnings.push({message, data});
    },
    error(message, data) {
      this.errors.push({message, data});
    },
  };
}
function cleanupResult(overrides = {}) {
  return {
    outcome: "batch_deleted",
    scanRunId: "run-1",
    cleanupPlanDigestSha256: "a".repeat(64),
    completedStepCodes: [],
    nextStepCode: "deleteFindings",
    complete: false,
    stepCode: "deleteFindings",
    deletedCount: 2,
    remainingInStep: true,
    deferredTopLevelCollections: [
      "risk_scan_reports",
      "risk_scan_claims",
    ],
    ...overrides,
  };
}
function handlerFixture({entries, executeCleanupStep, overrides} = {}) {
  const db = new FakeDb(entries || [
    ["run-1", runDocument("run-1")],
  ]);
  const logger = fakeLogger();
  const calls = [];
  const execute = executeCleanupStep || (async (inputDb, request) => {
    calls.push({inputDb, request});
    return cleanupResult({scanRunId: request.scanRunId});
  });
  const handler = scheduled.createScheduledCleanupHandler({
    db,
    logger,
    clock: {now: () => now},
    executeCleanupStep: execute,
    ...overrides,
  });
  return {calls, db, handler, logger};
}

// Stable contract and options: 8 tests.
test("scheduled cleanup contract version is stable", () => {
  assert.equal(
      scheduled.SCHEDULED_CLEANUP_CONTRACT_VERSION_V1,
      "risk-scan-scheduled-cleanup-v1");
});
test("scheduled cleanup function name is stable", () => {
  assert.equal(
      scheduled.SCHEDULED_CLEANUP_FUNCTION_NAME,
      "cleanupExpiredRiskScanRuns");
});
test("scheduled cleanup cadence is UTC every fifteen minutes", () => {
  assert.equal(scheduled.SCHEDULE, "every 15 minutes");
  assert.equal(scheduled.TIME_ZONE, "Etc/UTC");
});
test("scheduled cleanup region is europe-west3", () => {
  assert.equal(scheduled.REGION, "europe-west3");
});
test("scheduled options enforce one instance and one concurrency", () => {
  const options = scheduled.scheduledCleanupOptions();
  assert.equal(options.maxInstances, 1);
  assert.equal(options.concurrency, 1);
});
test("scheduled options use bounded runtime resources", () => {
  const options = scheduled.scheduledCleanupOptions();
  assert.equal(options.timeoutSeconds, 540);
  assert.equal(options.memory, "256MiB");
});
test("scheduled options include schedule location", () => {
  const options = scheduled.scheduledCleanupOptions();
  assert.equal(options.schedule, scheduled.SCHEDULE);
  assert.equal(options.timeZone, scheduled.TIME_ZONE);
  assert.equal(options.region, scheduled.REGION);
});
test("scheduled options are frozen", () => {
  assert.equal(Object.isFrozen(scheduled.scheduledCleanupOptions()), true);
});

// Validation helpers: 13 tests.
test("terminal cleanup status is recognized", () => {
  assert.equal(scheduled.isTerminalCleanupStatus("completed"), true);
});
test("non-terminal cleanup status is rejected", () => {
  assert.equal(scheduled.isTerminalCleanupStatus("queued"), false);
});
test("positive integer accepts its maximum", () => {
  assert.equal(scheduled.assertPositiveInteger(10, "value", 10), 10);
});
test("positive integer rejects zero", () => {
  assert.throws(() => scheduled.assertPositiveInteger(0, "value", 10));
});
test("positive integer rejects values above maximum", () => {
  assert.throws(() => scheduled.assertPositiveInteger(11, "value", 10));
});
test("batch size accepts retention maximum", () => {
  assert.equal(
      scheduled.assertBatchSize(MAX_CLEANUP_BATCH_SIZE),
      MAX_CLEANUP_BATCH_SIZE);
});
test("batch size rejects values above retention maximum", () => {
  assert.throws(() =>
    scheduled.assertBatchSize(MAX_CLEANUP_BATCH_SIZE + 1));
});
test("minimum grace accepts zero", () => {
  assert.equal(scheduled.assertMinimumGraceSeconds(0), 0);
});
test("minimum grace rejects more than thirty days", () => {
  assert.throws(() =>
    scheduled.assertMinimumGraceSeconds(MAX_GRACE_SECONDS + 1));
});
test("clock guard accepts now function", () => {
  const clock = {now: () => now};
  assert.equal(scheduled.assertClock(clock), clock);
});
test("clock guard rejects missing now function", () => {
  assert.throws(() => scheduled.assertClock({}));
});
test("logger guard requires info warn and error", () => {
  assert.throws(() => scheduled.assertLogger({info() {}, error() {}}));
});
test("normalize now rejects invalid dates", () => {
  assert.throws(() => scheduled.normalizeNow("not-a-date"));
});

// Query construction: 5 tests.
test("expired query uses the run collection and timestamp field", () => {
  const db = new FakeDb();
  const built = scheduled.buildExpiredRunQuery(db, {now, scanLimit: 7});
  assert.equal(db.lastCollection, "risk_scan_runs");
  assert.equal(db.lastQuery.whereClause.field, "expiresAtTimestamp");
  assert.equal(db.lastQuery.whereClause.operator, "<=");
  assert.equal(db.lastQuery.limitValue, 7);
  assert.equal(built.query, db.lastQuery);
});
test("expired query orders by the timestamp ascending", () => {
  const db = new FakeDb();
  scheduled.buildExpiredRunQuery(db, {now});
  assert.deepEqual(db.lastQuery.orderClause, {
    field: "expiresAtTimestamp",
    direction: "asc",
  });
});
test("expired query subtracts the configured grace", () => {
  const db = new FakeDb();
  const built = scheduled.buildExpiredRunQuery(db, {
    now,
    minimumGraceSeconds: 60,
  });
  assert.equal(
      built.cutoff.toISOString(),
      "2026-07-30T04:59:00.000Z");
});
test("expired query rejects an invalid database", () => {
  assert.throws(() => scheduled.buildExpiredRunQuery({}, {now}));
});
test("expired query rejects a scan limit above maximum", () => {
  assert.throws(() => scheduled.buildExpiredRunQuery(new FakeDb(), {
    now,
    scanLimit: scheduled.MAX_SCAN_LIMIT + 1,
  }));
});

// Handler behavior: 8 tests.
test(
    "handler executes one cleanup step for an expired terminal run",
    async () => {
      const fixture = handlerFixture();
      const result = await fixture.handler({scheduleTime: now.toISOString()});
      assert.equal(fixture.calls.length, 1);
      assert.deepEqual(fixture.calls[0].request, {
        scanRunId: "run-1",
        now: now.toISOString(),
        minimumGraceSeconds: 0,
        batchSize: 200,
      });
      assert.equal(result.attemptedCount, 1);
      assert.equal(result.progressedCount, 1);
      assert.equal(result.deletedDocumentCount, 2);
    });
test("handler skips an expired non-terminal run", async () => {
  const fixture = handlerFixture({entries: [
    ["run-1", runDocument("run-1", {status: "queued"})],
  ]});
  const result = await fixture.handler();
  assert.equal(result.skippedNonTerminalCount, 1);
  assert.equal(result.attemptedCount, 0);
});
test("handler does not scan a future terminal run", async () => {
  const fixture = handlerFixture({entries: [
    ["run-1", runDocument("run-1", {
      expiresAt: "2026-07-30T06:00:00.000Z",
    })],
  ]});
  const result = await fixture.handler();
  assert.equal(result.scannedCount, 0);
  assert.equal(result.attemptedCount, 0);
});
test("handler enforces the process limit", async () => {
  const fixture = handlerFixture({
    entries: [
      ["run-1", runDocument("run-1")],
      ["run-2", runDocument("run-2")],
      ["run-3", runDocument("run-3")],
    ],
    overrides: {processLimit: 2},
  });
  const result = await fixture.handler();
  assert.equal(result.terminalCandidateCount, 3);
  assert.equal(result.attemptedCount, 2);
  assert.equal(result.skippedProcessLimitCount, 1);
});
test("handler contains an invalid retention candidate", async () => {
  const fixture = handlerFixture({entries: [
    ["bad-run", {
      scanRunId: "bad-run",
      status: "completed",
      expiresAt: "2026-07-30T04:00:00.000Z",
      expiresAtTimestamp: new Date("2026-07-30T04:00:00.000Z"),
    }],
    ["run-1", runDocument("run-1")],
  ]});
  const result = await fixture.handler();
  assert.equal(result.failedCount, 1);
  assert.equal(result.attemptedCount, 1);
  assert.equal(fixture.logger.errors.length, 1);
});
test("handler contains a cleanup step failure", async () => {
  const error = new Error("cleanup failed");
  error.code = "aborted";
  const fixture = handlerFixture({
    executeCleanupStep: async () => {
      throw error;
    },
  });
  const result = await fixture.handler();
  assert.equal(result.failedCount, 1);
  assert.equal(result.runResults[0].errorCode, "aborted");
});
test("handler rethrows a query failure after safe logging", async () => {
  const fixture = handlerFixture();
  const error = new Error("query failed");
  error.code = "unavailable";
  fixture.db.queryError = error;
  await assert.rejects(() => fixture.handler(), error);
  assert.equal(fixture.logger.errors[0].data.errorCode, "unavailable");
});
test("handler returns a deeply frozen run result array", async () => {
  const fixture = handlerFixture();
  const result = await fixture.handler();
  assert.equal(Object.isFrozen(result), true);
  assert.equal(Object.isFrozen(result.runResults), true);
  assert.equal(Object.isFrozen(result.runResults[0]), true);
});

// Builder and safe helpers: 2 tests.
test("builder passes exact options and handler to onSchedule", () => {
  const db = new FakeDb();
  let captured;
  const marker = () => {};
  const built = scheduled.buildCleanupExpiredRiskScanRuns({
    db,
    logger: fakeLogger(),
    clock: {now: () => now},
    onScheduleImpl(options, handler) {
      captured = {options, handler};
      return marker;
    },
  });
  assert.equal(built, marker);
  assert.deepEqual(captured.options, scheduled.scheduledCleanupOptions());
  assert.equal(typeof captured.handler, "function");
});
test("safe error code hides messages and defaults to internal", () => {
  assert.equal(scheduled.safeErrorCode(new Error("secret")), "internal");
  assert.equal(scheduled.safeErrorCode({code: "aborted"}), "aborted");
});
