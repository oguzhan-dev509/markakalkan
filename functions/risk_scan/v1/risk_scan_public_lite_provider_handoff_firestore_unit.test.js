"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const executionContract = require("./public_lite_execution_contract");
const {
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  withExecutionStorageFingerprint,
} = require("./public_lite_execution_firestore_port");
const handoffContract = require("./public_lite_provider_handoff_contract");
const {
  createPublicLiteProviderHandoffFirestorePort,
} = require("./public_lite_provider_handoff_firestore_port");

const now = "2026-08-04T10:00:00.000Z";
const later = "2026-08-04T10:01:00.000Z";
const digestA = "a".repeat(64);
const digestB = "b".repeat(64);
const digestC = "c".repeat(64);

function clone(value) {
  if (value === undefined) return undefined;
  return structuredClone(value);
}

class FakeDocumentReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  async get() {
    return this.store.snapshot(this);
  }
}

class FakeCollectionReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(this.store, `${this.path}/${id}`);
  }
}

class FakeFirestore {
  constructor(initial = {}) {
    this.documents = new Map(
        Object.entries(initial).map(([path, value]) => [path, clone(value)]));
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  snapshot(reference) {
    const value = this.documents.get(reference.path);
    return {
      exists: value !== undefined,
      data: () => clone(value),
      ref: reference,
    };
  }

  async runTransaction(callback) {
    const writes = [];
    const transaction = {
      get: async (reference) => this.snapshot(reference),
      create: (reference, value) => writes.push({
        type: "create",
        reference,
        value: clone(value),
      }),
      update: (reference, value) => writes.push({
        type: "update",
        reference,
        value: clone(value),
      }),
    };
    const result = await callback(transaction);
    for (const write of writes) {
      const existing = this.documents.get(write.reference.path);
      if (write.type === "create") {
        if (existing !== undefined) {
          const error = new Error("already exists");
          error.code = 6;
          throw error;
        }
        this.documents.set(write.reference.path, write.value);
      } else {
        if (existing === undefined) throw new Error("missing document");
        this.documents.set(write.reference.path, write.value);
      }
    }
    return result;
  }
}

function run(overrides = {}) {
  return {
    contractVersion: "risk-scan-run-v1",
    scanRunId: digestA,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    target: {
      brandNameNormalized: "beauty of joseon",
      officialHost: "beautyofjoseon.com",
      officialWebsiteCanonicalUrl: "https://beautyofjoseon.com/",
      targetFingerprintSha256: digestB,
    },
    requestId: "request-1",
    requestFingerprintSha256: digestB,
    deduplicationFingerprintSha256: digestC,
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt: now,
    expiresAt: "2026-08-05T10:00:00.000Z",
    ...overrides,
  };
}

function command() {
  return executionContract.buildPublicLiteExecutionCommand({
    eventId: "event-1",
    eventTime: now,
    run: run(),
    channels: [
      "similarDomains",
      "openWeb",
      "marketplaceLimited",
    ].map((channelCode) => ({
      scanRunId: digestA,
      channelCode,
      status: "queued",
    })),
  });
}

function executionDocument(status = "dispatching") {
  const value = command();
  const record = executionContract.buildPublicLiteExecutionRecord(value);
  return withExecutionStorageFingerprint({
    ...record,
    command: value,
    status,
    attemptCount: status === "dispatching" ? 1 : 0,
    leaseOwner: status === "dispatching" ? "gateway-worker" : null,
    leaseExpiresAt: status === "dispatching" ?
      "2026-08-04T10:05:00.000Z" : null,
    updatedAt: now,
  });
}

function request(overrides = {}) {
  const value = command();
  return {
    contractVersion:
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
    providerCode: "n8n_public_lite",
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    gatewayExecutionId: "gateway-execution-1",
    dispatchEnvelope:
      executionContract.buildPublicLiteDispatchEnvelope(value),
    ...overrides,
  };
}

function createPort(status = "dispatching") {
  const value = command();
  const path = `${PUBLIC_LITE_EXECUTION_COLLECTIONS.executions}/` +
    value.executionId;
  const db = new FakeFirestore({[path]: executionDocument(status)});
  return {
    db,
    port: createPublicLiteProviderHandoffFirestorePort(db),
    command: value,
  };
}

function handoffPath(value = command()) {
  return `${handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION}/` +
    value.executionId;
}

function stored(db, path) {
  return db.documents.get(path);
}

async function acceptedPort() {
  const state = createPort();
  const accepted = await state.port.acceptHandoff({
    request: request(),
    acceptedAt: now,
    purgeAtTimestamp: new Date("2026-09-03T10:00:00.000Z"),
  });
  return {...state, accepted};
}

test("accept creates one durable record keyed by executionId", async () => {
  const {db, port, command: value} = createPort();
  const result = await port.acceptHandoff({
    request: request(),
    acceptedAt: now,
    purgeAtTimestamp: new Date("2026-09-03T10:00:00.000Z"),
  });
  assert.equal(result.outcome, "created");
  const document = stored(db, handoffPath(value));
  assert.equal(document.executionId, value.executionId);
  assert.equal(document.state, "accepted");
  assert.equal(document.purgeAtTimestamp instanceof Date, true);
});

test(
    "exact replay converges despite another gateway execution id",
    async () => {
      const {port} = await acceptedPort();
      const result = await port.acceptHandoff({
        request: request({gatewayExecutionId: "gateway-execution-2"}),
        acceptedAt: later,
        purgeAtTimestamp: new Date("2026-09-03T10:01:00.000Z"),
      });
      assert.equal(result.outcome, "idempotent_success");
      assert.equal(result.replayed, true);
      assert.equal(result.record.gatewayExecutionId, "gateway-execution-1");
    });

test("conflicting envelope replay is rejected", async () => {
  const {port} = await acceptedPort();
  const changed = request();
  changed.dispatchEnvelope = {
    ...changed.dispatchEnvelope,
    requestedAt: later,
  };
  await assert.rejects(
      port.acceptHandoff({
        request: changed,
        acceptedAt: later,
        purgeAtTimestamp: new Date("2026-09-03T10:01:00.000Z"),
      }),
      (error) => error.code === "conflict");
});

test("new handoff requires a dispatching execution", async () => {
  const {port} = createPort("prepared");
  await assert.rejects(
      port.acceptHandoff({
        request: request(),
        acceptedAt: now,
        purgeAtTimestamp: new Date("2026-09-03T10:00:00.000Z"),
      }),
      (error) => error.code === "failed-precondition");
});

test("child claim stores one bounded lease and command", async () => {
  const {db, port, command: value} = await acceptedPort();
  const result = await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    now,
    maxAttempts: 5,
  });
  assert.equal(result.outcome, "claimed");
  assert.equal(result.command.executionId, value.executionId);
  assert.equal(result.command.attempt, 1);
  const document = stored(db, handoffPath(value));
  assert.equal(document.state, "child_dispatching");
  assert.equal(document.childDispatchAttemptCount, 1);
});

test("active child lease blocks another worker", async () => {
  const {port, command: value} = await acceptedPort();
  await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    now,
    maxAttempts: 5,
  });
  const second = await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-2",
    now: later,
    maxAttempts: 5,
  });
  assert.equal(second.outcome, "lease_held");
});

test("child dispatch success stores child execution identity", async () => {
  const {db, port, command: value, accepted} = await acceptedPort();
  const claim = await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    now,
    maxAttempts: 5,
  });
  const result = await port.markChildDispatchSucceeded({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    attemptCount: claim.attemptCount,
    leaseToken: claim.leaseToken,
    receipt: {
      contractVersion:
        handoffContract
            .PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V1,
      providerCode: "n8n_public_lite",
      handoffId: accepted.record.handoffId,
      executionId: value.executionId,
      externalExecutionId: "child-execution-1",
      acceptedAt: later,
    },
    dispatchedAt: later,
  });
  assert.equal(result.outcome, "child_dispatched");
  const document = stored(db, handoffPath(value));
  assert.equal(document.state, "child_dispatched");
  assert.equal(document.childExternalExecutionId, "child-execution-1");
});

test("retryable child failure can be reclaimed", async () => {
  const {port, command: value} = await acceptedPort();
  const claim = await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    now,
    maxAttempts: 5,
  });
  const failed = await port.markChildDispatchFailed({
    executionId: value.executionId,
    ownerId: "child-worker-1",
    attemptCount: claim.attemptCount,
    leaseToken: claim.leaseToken,
    failure: {code: "upstream_unavailable"},
    retryable: true,
    failedAt: later,
  });
  assert.equal(failed.outcome, "retryable_failure");
  const reclaimed = await port.claimChildDispatch({
    executionId: value.executionId,
    ownerId: "child-worker-2",
    now: "2026-08-04T10:02:00.000Z",
    maxAttempts: 5,
  });
  assert.equal(reclaimed.outcome, "claimed");
  assert.equal(reclaimed.attemptCount, 2);
});
