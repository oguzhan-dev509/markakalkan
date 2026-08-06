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
const handoffContract = require("./public_lite_provider_handoff_contract");
const {
  createPublicLiteProviderHandoffFirestorePort,
} = require("./public_lite_provider_handoff_firestore_port");

const PROJECT_ID = "demo-markakalkan-hrt-handoff-b4b4";
const secretKey = "s".repeat(48);
const baseNow = new Date("2026-08-04T10:00:00.000Z");
const queuedAt = "2026-08-04T10:01:00.000Z";
let sequence = 0;
let app;
let db;
let executionPort;
let handoffPort;

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

async function createDispatchingExecution() {
  const start = publicContract.buildPublicLiteStartCommand({
    data: {
      requestId: unique("request"),
      brandName: "Beauty of Joseon",
      officialWebsiteUrl: "https://beautyofjoseon.com/",
      anonymousClientNonce: unique("browser"),
    },
    appId: "1:123:web:hrt-handoff-b4b4",
    networkAddress: "203.0.113.10",
    secretKey,
    now: baseNow,
  });
  await publicPort.createPublicLiteRun(db, start);
  const runRef = db.collection("risk_scan_runs").doc(start.run.scanRunId);
  const [runSnapshot, channelSnapshot] = await Promise.all([
    runRef.get(),
    runRef.collection("channels").get(),
  ]);
  const command = executionContract.buildPublicLiteExecutionCommand({
    eventId: unique("event"),
    eventTime: baseNow.toISOString(),
    run: runSnapshot.data(),
    channels: channelSnapshot.docs.map((item) => item.data()),
  });
  const record = executionContract.buildPublicLiteExecutionRecord(command);
  await executionPort.prepareExecution({command, record});
  await executionPort.queueExecution({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    updatedAt: queuedAt,
  });
  await executionPort.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "gateway-worker",
    now: queuedAt,
    maxAttempts: 5,
  });
  return command;
}

function handoffRequest(command, overrides = {}) {
  return {
    contractVersion:
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
    providerCode: "n8n_public_lite",
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    gatewayExecutionId: "gateway-execution-1",
    dispatchEnvelope:
      executionContract.buildPublicLiteDispatchEnvelope(command),
    ...overrides,
  };
}

async function accept(command) {
  return handoffPort.acceptHandoff({
    request: handoffRequest(command),
    acceptedAt: "2026-08-04T10:02:00.000Z",
    purgeAtTimestamp: new Date("2026-09-03T10:02:00.000Z"),
  });
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-handoff-b4b4");
  db = getFirestore(app);
  executionPort = createPublicLiteExecutionFirestorePort(db);
  handoffPort = createPublicLiteProviderHandoffFirestorePort(db);
});

beforeEach(async () => clearEmulator());

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

test("durable acceptance creates one execution-scoped handoff", async () => {
  const command = await createDispatchingExecution();
  const result = await accept(command);
  assert.equal(result.outcome, "created");
  const snapshot = await db.collection(
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION)
      .doc(command.executionId)
      .get();
  assert.equal(snapshot.exists, true);
  assert.equal(snapshot.data().state, "accepted");
  assert.equal(snapshot.data().executionId, command.executionId);
});

test("exact durable acceptance replay is idempotent", async () => {
  const command = await createDispatchingExecution();
  const first = await accept(command);
  const second = await handoffPort.acceptHandoff({
    request: handoffRequest(command, {
      gatewayExecutionId: "gateway-execution-2",
    }),
    acceptedAt: "2026-08-04T10:03:00.000Z",
    purgeAtTimestamp: new Date("2026-09-03T10:03:00.000Z"),
  });
  assert.equal(first.outcome, "created");
  assert.equal(second.outcome, "idempotent_success");
  assert.equal(second.record.gatewayExecutionId, "gateway-execution-1");
});

test("conflicting durable acceptance replay is rejected", async () => {
  const command = await createDispatchingExecution();
  await accept(command);
  const changed = handoffRequest(command);
  changed.dispatchEnvelope = {
    ...changed.dispatchEnvelope,
    requestedAt: "2026-08-04T10:00:01.000Z",
  };
  await assert.rejects(
      handoffPort.acceptHandoff({
        request: changed,
        acceptedAt: "2026-08-04T10:03:00.000Z",
        purgeAtTimestamp: new Date("2026-09-03T10:03:00.000Z"),
      }),
      (error) => error.code === "conflict");
});

test("child lease and dispatch receipt persist atomically", async () => {
  const command = await createDispatchingExecution();
  const accepted = await accept(command);
  const claim = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "child-worker-1",
    now: "2026-08-04T10:03:00.000Z",
    maxAttempts: 5,
  });
  assert.equal(claim.outcome, "claimed");
  const second = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "child-worker-2",
    now: "2026-08-04T10:03:01.000Z",
    maxAttempts: 5,
  });
  assert.equal(second.outcome, "lease_held");
  const marked = await handoffPort.markChildDispatchSucceeded({
    executionId: command.executionId,
    ownerId: "child-worker-1",
    attemptCount: claim.attemptCount,
    leaseToken: claim.leaseToken,
    receipt: {
      contractVersion:
        handoffContract
            .PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V1,
      providerCode: "n8n_public_lite",
      handoffId: accepted.record.handoffId,
      executionId: command.executionId,
      externalExecutionId: "child-execution-1",
      acceptedAt: "2026-08-04T10:04:00.000Z",
    },
    dispatchedAt: "2026-08-04T10:04:00.000Z",
  });
  assert.equal(marked.outcome, "child_dispatched");
  const stored = await handoffPort.getHandoff({
    executionId: command.executionId,
  });
  assert.equal(stored.state, "child_dispatched");
  assert.equal(stored.childExternalExecutionId, "child-execution-1");
});

test("retryable child failure can be claimed again", async () => {
  const command = await createDispatchingExecution();
  await accept(command);
  const first = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "child-worker-1",
    now: "2026-08-04T10:03:00.000Z",
    maxAttempts: 5,
  });
  await handoffPort.markChildDispatchFailed({
    executionId: command.executionId,
    ownerId: "child-worker-1",
    attemptCount: first.attemptCount,
    leaseToken: first.leaseToken,
    failure: {code: "upstream_unavailable"},
    retryable: true,
    failedAt: "2026-08-04T10:04:00.000Z",
  });
  const second = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "child-worker-2",
    now: "2026-08-04T10:05:00.000Z",
    maxAttempts: 5,
  });
  assert.equal(second.outcome, "claimed");
  assert.equal(second.attemptCount, 2);
});
