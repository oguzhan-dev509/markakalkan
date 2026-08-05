"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const contract = require("./public_lite_execution_contract");
const service = require("./public_lite_execution_service");
const {
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1,
  createPublicLiteExecutionFirestorePort,
  withExecutionStorageFingerprint,
} = require("./public_lite_execution_firestore_port");

const now = "2026-08-04T10:00:00.000Z";
const queuedAt = "2026-08-04T10:01:00.000Z";
const dispatchedAt = "2026-08-04T10:02:00.000Z";
const failedAt = "2026-08-04T10:03:00.000Z";
const completedAt = "2026-08-04T10:04:00.000Z";
const expiresAt = "2026-08-05T10:00:00.000Z";
const digestA = "a".repeat(64);
const digestB = "b".repeat(64);
const digestC = "c".repeat(64);

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

class FakeDocumentReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  collection(name) {
    return new FakeCollectionReference(this.store, `${this.path}/${name}`);
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
        type: "create", reference, value: clone(value),
      }),
      update: (reference, value) => writes.push({
        type: "update", reference, value: clone(value),
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
        this.documents.set(write.reference.path, {
          ...clone(existing),
          ...write.value,
        });
      }
    }
    return result;
  }
}

function runDocument(overrides = {}) {
  return {
    contractVersion: "risk-scan-run-v1",
    storageSchemaVersion: "risk-scan-storage-v1",
    storageFingerprintAlgorithm: "sha256-canonical-json-v1",
    storageFingerprintSha256: digestA,
    scanRunId: digestA,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    coverageStatus: "insufficient",
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
    updatedAt: now,
    expiresAt,
    accessSecretDigestSha256: digestC,
    accessSecretAlgorithm: "sha256",
    latestReportId: null,
    ...overrides,
  };
}

function channelDocument(channelCode, overrides = {}) {
  return {
    contractVersion: "risk-scan-channel-v1",
    storageSchemaVersion: "risk-scan-storage-v1",
    storageFingerprintAlgorithm: "sha256-canonical-json-v1",
    storageFingerprintSha256: digestB,
    scanRunId: digestA,
    channelCode,
    status: "queued",
    coverageStatus: "insufficient",
    observationCount: 0,
    findingCount: 0,
    limitReasonCodes: [],
    attemptCount: 0,
    startedAt: null,
    completedAt: null,
    updatedAt: now,
    ...overrides,
  };
}

function initialDocuments(runOverrides = {}, channelOverrides = {}) {
  const documents = {
    [`risk_scan_runs/${digestA}`]: runDocument(runOverrides),
  };
  for (const code of [
    "similarDomains", "openWeb", "marketplaceLimited",
  ]) {
    documents[`risk_scan_runs/${digestA}/channels/${code}`] =
      channelDocument(code, channelOverrides);
  }
  return documents;
}

function event(overrides = {}) {
  return {
    eventId: "event-1",
    eventTime: now,
    run: runDocument(),
    channels: [
      "similarDomains", "openWeb", "marketplaceLimited",
    ].map((channelCode) => channelDocument(channelCode)),
    ...overrides,
  };
}

function command(eventOverrides = {}) {
  return contract.buildPublicLiteExecutionCommand(event(eventOverrides));
}

function record(input = command()) {
  return contract.buildPublicLiteExecutionRecord(input);
}

async function preparedPort({runOverrides = {}, channelOverrides = {}} = {}) {
  const db = new FakeFirestore(
      initialDocuments(runOverrides, channelOverrides));
  const port = createPublicLiteExecutionFirestorePort(db);
  const value = command();
  await port.prepareExecution({command: value, record: record(value)});
  return {db, port, command: value};
}

function stored(db, path) {
  return db.documents.get(path);
}

function executionPath(value = command()) {
  return `${PUBLIC_LITE_EXECUTION_COLLECTIONS.executions}/` +
    value.executionId;
}

function sequenceClock(values) {
  let index = 0;
  return {
    now: () => values[Math.min(index++, values.length - 1)],
  };
}

test("execution Firestore storage version is fixed", () => {
  assert.equal(
      PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1,
      "risk-scan-public-lite-execution-storage-v1");
});

test("prepare stores command without access secret", async () => {
  const {db, command: value} = await preparedPort();
  const execution = stored(db, executionPath(value));
  assert.equal(execution.status, "prepared");
  assert.equal(execution.command.executionId, value.executionId);
  const serialized = JSON.stringify(execution).toLowerCase();
  assert.equal(serialized.includes("accesssecret"), false);
  assert.equal(serialized.includes("accesskey"), false);
});

test("prepare exact replay is idempotent", async () => {
  const {port, command: value} = await preparedPort();
  const result = await port.prepareExecution({
    command: value,
    record: record(value),
  });
  assert.equal(result.outcome, "idempotent_success");
});

test("prepare conflicting event replay is rejected", async () => {
  const {port, command: value} = await preparedPort();
  const conflict = {...value, eventId: "event-2"};
  await assert.rejects(
      () => port.prepareExecution({
        command: conflict,
        record: record(conflict),
      }),
      (error) => error.code === "conflict");
});

test("queue advances created run through validation to queued", async () => {
  const {db, port, command: value} = await preparedPort();
  const result = await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  assert.equal(result.outcome, "queued");
  assert.equal(stored(db, `risk_scan_runs/${digestA}`).status, "queued");
});

test("queue replay is idempotent", async () => {
  const {port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  const replay = await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  assert.equal(replay.outcome, "idempotent_success");
});

test("claim creates one bounded dispatch lease", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  const claim = await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  assert.deepEqual(claim, {outcome: "claimed", attemptCount: 1});
  const execution = stored(db, executionPath(value));
  assert.equal(execution.status, "dispatching");
  assert.equal(execution.leaseOwner, "worker-1");
  assert.equal(execution.attemptCount, 1);
});

test("active lease blocks a second worker", async () => {
  const {port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const second = await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-2",
    now: "2026-08-04T10:02:00.000Z",
    maxAttempts: 5,
  });
  assert.equal(second.outcome, "lease_held");
});

test("expired lease can be reclaimed", async () => {
  const {port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const reclaimed = await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-2",
    now: "2026-08-04T10:07:00.000Z",
    maxAttempts: 5,
  });
  assert.deepEqual(reclaimed, {outcome: "claimed", attemptCount: 2});
});

test("dispatch success atomically starts run and all channels", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const result = await port.markDispatchSucceeded({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
    dispatchedAt,
  });
  assert.equal(result.outcome, "dispatched");
  assert.equal(stored(db, executionPath(value)).status, "dispatched");
  assert.equal(stored(db, `risk_scan_runs/${digestA}`).status, "acquiring");
  for (const code of [
    "similarDomains", "openWeb", "marketplaceLimited",
  ]) {
    const channel = stored(
        db, `risk_scan_runs/${digestA}/channels/${code}`);
    assert.equal(channel.status, "acquiring");
    assert.equal(channel.attemptCount, 1);
  }
});

test("dispatch success replay verifies the same receipt", async () => {
  const {port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const input = {
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
    dispatchedAt,
  };
  await port.markDispatchSucceeded(input);
  const replay = await port.markDispatchSucceeded(input);
  assert.equal(replay.outcome, "idempotent_success");
});

test("conflicting dispatch receipt is rejected", async () => {
  const {port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const base = {
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    dispatchedAt,
  };
  await port.markDispatchSucceeded({
    ...base,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
  });
  await assert.rejects(() => port.markDispatchSucceeded({
    ...base,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-2",
      acceptedAt: dispatchedAt,
    },
  }), (error) => error.code === "conflict");
});

test("retryable dispatch failure marks complete retry bundle", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const result = await port.markDispatchFailed({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    failure: {code: "http_503", message: "Unavailable"},
    retryable: true,
    failedAt,
  });
  assert.equal(result.outcome, "retryable_failure");
  assert.equal(stored(db, executionPath(value)).status, "retryableFailure");
  assert.equal(
      stored(db, `risk_scan_runs/${digestA}`).status,
      "failedRetryable");
});

test("retryable bundle can be requeued", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  await port.markDispatchFailed({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    failure: {code: "http_503", message: "Unavailable"},
    retryable: true,
    failedAt,
  });
  const result = await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: "2026-08-04T10:04:00.000Z",
  });
  assert.equal(result.outcome, "queued");
  assert.equal(stored(db, `risk_scan_runs/${digestA}`).status, "queued");
  assert.equal(
      stored(db, `risk_scan_runs/${digestA}/channels/openWeb`).status,
      "queued");
});

test("terminal dispatch failure closes run and channels", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  const result = await port.markDispatchFailed({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    failure: {code: "invalid_payload", message: "Rejected"},
    retryable: false,
    failedAt,
  });
  assert.equal(result.outcome, "terminal_failure");
  assert.equal(stored(db, executionPath(value)).status, "terminalFailure");
  assert.equal(
      stored(db, `risk_scan_runs/${digestA}`).status,
      "failedTerminal");
});

test("attempt exhaustion closes the execution without dispatch", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  const path = executionPath(value);
  db.documents.set(path, withExecutionStorageFingerprint({
    ...stored(db, path),
    status: "retryableFailure",
    attemptCount: 5,
    leaseOwner: null,
    leaseExpiresAt: null,
  }));
  const result = await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: failedAt,
    maxAttempts: 5,
  });
  assert.equal(result.outcome, "terminal");
  assert.equal(stored(db, path).status, "terminalFailure");
  assert.equal(
      stored(db, `risk_scan_runs/${digestA}`).status,
      "failedTerminal");
});

test("get execution rejects cross-run scope", async () => {
  const {port, command: value} = await preparedPort();
  await assert.rejects(() => port.getExecution({
    executionId: value.executionId,
    scanRunId: digestB,
  }), (error) => error.code === "not-found");
});

test("dispatched execution can be completed idempotently", async () => {
  const {db, port, command: value} = await preparedPort();
  await port.queueExecution({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    updatedAt: queuedAt,
  });
  await port.claimDispatch({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  await port.markDispatchSucceeded({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
    dispatchedAt,
  });
  const result = await port.markExecutionCompleted({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    completedAt,
  });
  const replay = await port.markExecutionCompleted({
    executionId: value.executionId,
    scanRunId: value.scanRunId,
    completedAt,
  });
  assert.equal(result.outcome, "completed");
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(stored(db, executionPath(value)).status, "completed");
});

test("orchestration service works against the Firestore port", async () => {
  const db = new FakeFirestore(initialDocuments());
  const port = createPublicLiteExecutionFirestorePort(db);
  const result = await service.orchestratePublicLiteExecution({
    event: event(),
    ownerId: "eventarc-worker-1",
    port,
    dispatcher: {
      dispatch: async () => ({
        providerCode: "n8n_public_lite",
        externalExecutionId: "n8n-execution-1",
        acceptedAt: dispatchedAt,
      }),
    },
    clock: sequenceClock([queuedAt, queuedAt, dispatchedAt]),
  });
  assert.equal(result.outcome, "dispatched");
  assert.equal(stored(db, `risk_scan_runs/${digestA}`).status, "acquiring");
});
