/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  CALLABLE_NAME,
  CALLABLE_OPTIONS,
  buildCreateDigitalDetectiveTask,
  createDigitalDetectiveTaskHandler,
} = require("./digital_detective_create");

class FakeSnapshot {
  constructor(data) {
    this._data = data;
    this.exists = data !== undefined;
  }

  data() {
    return this._data;
  }
}

class FakeRef {
  constructor(db, path, id = null) {
    this.db = db;
    this.path = path;
    this.id = id || path.split("/").at(-1);
  }

  collection(name) {
    return new FakeCollection(this.db, `${this.path}/${name}`);
  }
}

class FakeCollection {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id = null) {
    const resolved = id || `auto-${++this.db.autoId}`;
    return new FakeRef(this.db, `${this.path}/${resolved}`, resolved);
  }
}

class FakeTransaction {
  constructor(db) {
    this.db = db;
    this.creates = new Map();
  }

  async get(ref) {
    if (this.creates.has(ref.path)) {
      return new FakeSnapshot(this.creates.get(ref.path));
    }
    return new FakeSnapshot(this.db.docs.get(ref.path));
  }

  create(ref, data) {
    if (this.db.docs.has(ref.path) || this.creates.has(ref.path)) {
      throw new Error(`already exists: ${ref.path}`);
    }
    this.creates.set(ref.path, data);
    return this;
  }

  commit() {
    for (const [path, data] of this.creates.entries()) {
      this.db.docs.set(path, data);
    }
  }
}

class FakeDb {
  constructor() {
    this.docs = new Map();
    this.autoId = 0;
  }

  collection(name) {
    return new FakeCollection(this, name);
  }

  seed(path, data) {
    this.docs.set(path, data);
  }

  async runTransaction(callback) {
    const tx = new FakeTransaction(this);
    const result = await callback(tx);
    tx.commit();
    return result;
  }
}

function log() {
  return {
    info() {},
    error() {},
  };
}

function request(data = {}, overrides = {}) {
  return {
    auth: {
      uid: "user-1",
      token: {email: "USER@EXAMPLE.COM"},
    },
    app: {appId: "verified-app"},
    data,
    ...overrides,
  };
}

function validData(overrides = {}) {
  return {
    taskName: "Primary task",
    brandName: "Example Brand",
    productName: "Example Product",
    categoryId: "fashion",
    subcategory: "shoes",
    violationIds: ["counterfeit"],
    sources: ["marketplace"],
    searchTerms: ["example product"],
    excludedTerms: ["used"],
    countries: ["TR"],
    cities: ["Istanbul"],
    minimumPrice: 10,
    maximumPrice: 100,
    currency: "TRY",
    frequency: "once",
    riskLevel: "medium",
    startDate: "2026-09-04T00:00:00.000Z",
    endDate: "2026-09-05T00:00:00.000Z",
    submissionId: "submission-0001",
    ...overrides,
  };
}

test("callable name and hardened options are stable", () => {
  assert.equal(CALLABLE_NAME, "createDigitalDetectiveTask");
  assert.deepEqual(CALLABLE_OPTIONS, {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 1,
  });
});

test("builder passes hardened options to onCall", () => {
  const db = new FakeDb();
  let captured = null;
  const result = buildCreateDigitalDetectiveTask({
    db,
    log: log(),
    onCallImpl(options, handler) {
      captured = {options, handler};
      return "callable";
    },
  });

  assert.equal(result, "callable");
  assert.equal(captured.options, CALLABLE_OPTIONS);
  assert.equal(typeof captured.handler, "function");
});

test("missing auth is rejected before any transaction", async () => {
  const db = new FakeDb();
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  await assert.rejects(
      () => handler({
        app: {appId: "verified-app"},
        data: validData(),
      }),
      (error) =>
        error instanceof HttpsError &&
        error.code === "unauthenticated",
  );
  assert.equal(db.docs.size, 0);
});

test("missing App Check is rejected before any transaction", async () => {
  const db = new FakeDb();
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  await assert.rejects(
      () => handler({
        auth: {uid: "user-1", token: {}},
        data: validData(),
      }),
      (error) =>
        error instanceof HttpsError &&
        error.code === "failed-precondition",
  );
  assert.equal(db.docs.size, 0);
});

test("client cannot supply server-owned identity or status", async () => {
  const db = new FakeDb();
  db.seed("brands/user-1", {ownerUid: "user-1"});
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  await assert.rejects(
      () => handler(request(validData({ownerUid: "spoofed"}))),
      (error) =>
        error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
});

test("brand scope is derived from authenticated uid", async () => {
  const db = new FakeDb();
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  await assert.rejects(
      () => handler(request(validData())),
      (error) =>
        error instanceof HttpsError &&
        error.code === "permission-denied",
  );
});

test("exact replay returns the original task and creates no second task", async () => {
  const db = new FakeDb();
  db.seed("brands/user-1", {ownerUid: "user-1"});
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  const first = await handler(request(validData()));
  const second = await handler(request(validData()));

  assert.equal(first.idempotentReplay, false);
  assert.equal(second.idempotentReplay, true);
  assert.equal(second.taskId, first.taskId);

  const taskPaths = [...db.docs.keys()].filter((path) =>
    path.includes("/digitalDetectiveTasks/"));
  const receiptPaths = [...db.docs.keys()].filter((path) =>
    path.includes("/_digitalDetectiveTaskCreateReceipts/"));

  assert.equal(taskPaths.length, 1);
  assert.equal(receiptPaths.length, 1);

  const task = db.docs.get(taskPaths[0]);
  assert.equal(task.ownerUid, "user-1");
  assert.equal(task.ownerEmail, "user@example.com");
  assert.equal(task.status, "queued");
  assert.equal(task.resultCount, 0);
  assert.equal(task.processedCount, 0);
});

test("same submission id with a different payload fails closed", async () => {
  const db = new FakeDb();
  db.seed("brands/user-1", {ownerUid: "user-1"});
  const handler = createDigitalDetectiveTaskHandler({db, log: log()});

  await handler(request(validData()));

  await assert.rejects(
      () => handler(request(validData({taskName: "Different task"}))),
      (error) =>
        error instanceof HttpsError &&
        error.code === "already-exists",
  );

  const taskPaths = [...db.docs.keys()].filter((path) =>
    path.includes("/digitalDetectiveTasks/"));
  assert.equal(taskPaths.length, 1);
});
