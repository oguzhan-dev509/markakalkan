"use strict";

const {after, before, beforeEach, test} = require("node:test");
const assert = require("node:assert/strict");
const {
  deleteApp,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const publicContract = require("./public_lite_contract");
const publicPort = require("./public_lite_firestore_port");
const executionContract = require("./public_lite_execution_contract");
const {
  createPublicLiteExecutionFirestorePort,
} = require("./public_lite_execution_firestore_port");
const {
  PUBLIC_LITE_RESULT_COLLECTIONS,
  PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1,
  persistPublicLiteResultReceipt,
} = require("./public_lite_result_receipt_firestore_port");

const PROJECT_ID = "demo-markakalkan-hrt-exec-1c2";
const secretKey = "s".repeat(48);
const baseNow = new Date("2026-08-04T10:00:00.000Z");
const queuedAt = "2026-08-04T10:01:00.000Z";
const dispatchedAt = "2026-08-04T10:02:00.000Z";
const completedAt = "2026-08-04T10:10:00.000Z";
const receivedAt = "2026-08-04T10:11:00.000Z";
let sequence = 0;
let app;
let db;
let executionPort;

function assertEmulatorGuard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error("FIRESTORE_EMULATOR_HOST must be loopback");
  }
  const configuredProject =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    PROJECT_ID;
  if (configuredProject !== PROJECT_ID) {
    throw new Error(`unexpected emulator project: ${configuredProject}`);
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error(
        "GOOGLE_APPLICATION_CREDENTIALS must be unset for emulator tests");
  }
  return host;
}

async function clearEmulator() {
  const host = assertEmulatorGuard();
  const url = `http://${host}/emulator/v1/projects/${PROJECT_ID}` +
    "/databases/(default)/documents";
  const response = await fetch(url, {method: "DELETE"});
  if (!response.ok) {
    throw new Error(`emulator cleanup failed: ${response.status}`);
  }
}

function unique(label) {
  sequence += 1;
  return `${label}-${sequence}`;
}

function buildStartCommand() {
  return publicContract.buildPublicLiteStartCommand({
    data: {
      requestId: unique("request"),
      brandName: "Beauty of Joseon",
      officialWebsiteUrl: "https://beautyofjoseon.com/",
      anonymousClientNonce: unique("browser"),
    },
    appId: "1:123:web:hrt-exec-1c2",
    networkAddress: "203.0.113.10",
    secretKey,
    now: baseNow,
  });
}

async function createExecutionCommand() {
  const start = buildStartCommand();
  await publicPort.createPublicLiteRun(db, start);
  const rootRef = db.collection("risk_scan_runs").doc(start.run.scanRunId);
  const [runSnapshot, channelSnapshot] = await Promise.all([
    rootRef.get(),
    rootRef.collection("channels").get(),
  ]);
  const command = executionContract.buildPublicLiteExecutionCommand({
    eventId: unique("event"),
    eventTime: baseNow.toISOString(),
    run: runSnapshot.data(),
    channels: channelSnapshot.docs.map((document) => document.data()),
  });
  const record = executionContract.buildPublicLiteExecutionRecord(command);
  await executionPort.prepareExecution({command, record});
  await executionPort.queueExecution({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    updatedAt: queuedAt,
  });
  return command;
}

async function createDispatchedExecution() {
  const command = await createExecutionCommand();
  await executionPort.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "event-worker",
    now: queuedAt,
    maxAttempts: 5,
  });
  await executionPort.markDispatchSucceeded({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "event-worker",
    attemptCount: 1,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
    dispatchedAt,
  });
  return command;
}

function resultEnvelope(command, overrides = {}) {
  return {
    contractVersion: PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1,
    providerCode: "n8n_public_lite",
    externalExecutionId: "n8n-execution-1",
    providerEventId: "provider-event-1",
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    completedAt,
    resultPayload: {
      channels: [],
      source: "public-lite-pilot",
    },
    ...overrides,
  };
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-exec-1c2");
  db = getFirestore(app);
  executionPort = createPublicLiteExecutionFirestorePort(db);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  if (app && getApps().includes(app)) await deleteApp(app);
});

test("emulator guard uses a demo project and loopback host", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});

test(
    "a dispatched execution accepts one immutable result receipt",
    async () => {
      const command = await createDispatchedExecution();
      const result = await persistPublicLiteResultReceipt(db, {
        envelope: resultEnvelope(command),
        receivedAt,
      });
      assert.equal(result.outcome, "created");
      assert.equal(result.duplicate, false);
      const snapshot = await db.collection(
          PUBLIC_LITE_RESULT_COLLECTIONS.receipts).doc(result.receiptId).get();
      assert.equal(snapshot.exists, true);
      const stored = snapshot.data();
      assert.equal(stored.executionId, command.executionId);
      assert.equal(stored.processingStatus, "received");
      assert.equal(stored.immutable, true);
      assert.equal(stored.resultPayload.token, undefined);
    });

test("an exact provider replay is idempotent", async () => {
  const command = await createDispatchedExecution();
  const input = {
    envelope: resultEnvelope(command),
    receivedAt,
  };
  const first = await persistPublicLiteResultReceipt(db, input);
  const second = await persistPublicLiteResultReceipt(db, input);
  assert.equal(first.outcome, "created");
  assert.equal(second.outcome, "idempotent_success");
  assert.equal(second.duplicate, true);
  assert.equal(first.receiptId, second.receiptId);
});

test(
    "the same provider event cannot replay different payload data",
    async () => {
      const command = await createDispatchedExecution();
      await persistPublicLiteResultReceipt(db, {
        envelope: resultEnvelope(command),
        receivedAt,
      });
      await assert.rejects(
          persistPublicLiteResultReceipt(db, {
            envelope: resultEnvelope(command, {
              resultPayload: {channels: [], source: "changed"},
            }),
            receivedAt,
          }),
          (error) => error.code === "conflict");
    });

test("a result cannot bind to another external execution", async () => {
  const command = await createDispatchedExecution();
  await assert.rejects(
      persistPublicLiteResultReceipt(db, {
        envelope: resultEnvelope(command, {
          externalExecutionId: "another-execution",
        }),
        receivedAt,
      }),
      (error) => error.code === "conflict");
});

test(
    "an undispatched execution cannot accept a new result receipt",
    async () => {
      const command = await createExecutionCommand();
      await assert.rejects(
          persistPublicLiteResultReceipt(db, {
            envelope: resultEnvelope(command),
            receivedAt,
          }),
          (error) => error.code === "failed-precondition");
    });
