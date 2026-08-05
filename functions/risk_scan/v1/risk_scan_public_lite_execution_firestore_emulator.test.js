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
const executionService = require("./public_lite_execution_service");
const {
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  createPublicLiteExecutionFirestorePort,
} = require("./public_lite_execution_firestore_port");

const PROJECT_ID = "demo-markakalkan-hrt-exec-1c1";
const secretKey = "s".repeat(48);
const baseNow = new Date("2026-08-04T10:00:00.000Z");
const queuedAt = "2026-08-04T10:01:00.000Z";
const dispatchedAt = "2026-08-04T10:02:00.000Z";
const failedAt = "2026-08-04T10:03:00.000Z";
let sequence = 0;
let app;
let db;
let port;

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
    appId: "1:123:web:hrt-exec-1c1",
    networkAddress: "203.0.113.10",
    secretKey,
    now: baseNow,
  });
}

async function createExecutionEvent(eventId = unique("event")) {
  const start = buildStartCommand();
  await publicPort.createPublicLiteRun(db, start);
  const rootRef = db.collection("risk_scan_runs").doc(start.run.scanRunId);
  const [runSnapshot, channelSnapshot] = await Promise.all([
    rootRef.get(),
    rootRef.collection("channels").get(),
  ]);
  const channels = channelSnapshot.docs.map((document) => document.data());
  return {
    start,
    event: {
      eventId,
      eventTime: baseNow.toISOString(),
      run: runSnapshot.data(),
      channels,
    },
  };
}

async function prepareAndQueue() {
  const bundle = await createExecutionEvent();
  const command = executionContract.buildPublicLiteExecutionCommand(
      bundle.event);
  const record = executionContract.buildPublicLiteExecutionRecord(command);
  await port.prepareExecution({command, record});
  await port.queueExecution({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    updatedAt: queuedAt,
  });
  return {...bundle, command};
}

async function readExecution(command) {
  return db.collection(PUBLIC_LITE_EXECUTION_COLLECTIONS.executions)
      .doc(command.executionId).get();
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-exec-1c1");
  db = getFirestore(app);
  port = createPublicLiteExecutionFirestorePort(db);
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

test("prepare and queue persist one execution and queued run", async () => {
  const {command} = await prepareAndQueue();
  const [executionSnapshot, runSnapshot] = await Promise.all([
    readExecution(command),
    db.collection("risk_scan_runs").doc(command.scanRunId).get(),
  ]);
  assert.equal(executionSnapshot.exists, true);
  assert.equal(executionSnapshot.data().status, "prepared");
  assert.equal(runSnapshot.data().status, "queued");
});

test("parallel prepare collapses to one execution document", async () => {
  const {event} = await createExecutionEvent();
  const command = executionContract.buildPublicLiteExecutionCommand(event);
  const record = executionContract.buildPublicLiteExecutionRecord(command);
  const outcomes = await Promise.all([
    port.prepareExecution({command, record}),
    port.prepareExecution({command, record}),
  ]);
  assert.deepEqual(
      outcomes.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);
  const executions = await db.collection(
      PUBLIC_LITE_EXECUTION_COLLECTIONS.executions).get();
  assert.equal(executions.size, 1);
});

test("parallel dispatch claims produce one lease winner", async () => {
  const {command} = await prepareAndQueue();
  const outcomes = await Promise.all([
    port.claimDispatch({
      executionId: command.executionId,
      scanRunId: command.scanRunId,
      ownerId: "worker-1",
      now: queuedAt,
      maxAttempts: 5,
    }),
    port.claimDispatch({
      executionId: command.executionId,
      scanRunId: command.scanRunId,
      ownerId: "worker-2",
      now: queuedAt,
      maxAttempts: 5,
    }),
  ]);
  assert.deepEqual(
      outcomes.map((item) => item.outcome).sort(),
      ["claimed", "lease_held"]);
});

test("dispatch success advances run and every channel atomically", async () => {
  const {command} = await prepareAndQueue();
  await port.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  await port.markDispatchSucceeded({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n-execution-1",
      acceptedAt: dispatchedAt,
    },
    dispatchedAt,
  });

  const rootRef = db.collection("risk_scan_runs").doc(command.scanRunId);
  const [executionSnapshot, runSnapshot, channelsSnapshot] =
    await Promise.all([
      readExecution(command),
      rootRef.get(),
      rootRef.collection("channels").get(),
    ]);
  assert.equal(executionSnapshot.data().status, "dispatched");
  assert.equal(runSnapshot.data().status, "acquiring");
  assert.equal(
      channelsSnapshot.docs.every(
          (document) => document.data().status === "acquiring"),
      true);
});

test("retryable failure can be safely requeued", async () => {
  const {command} = await prepareAndQueue();
  await port.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  await port.markDispatchFailed({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    failure: {code: "http_503", message: "Unavailable"},
    retryable: true,
    failedAt,
  });
  const queued = await port.queueExecution({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    updatedAt: "2026-08-04T10:04:00.000Z",
  });
  const runSnapshot = await db.collection("risk_scan_runs")
      .doc(command.scanRunId).get();
  assert.equal(queued.outcome, "queued");
  assert.equal(runSnapshot.data().status, "queued");
});

test("terminal failure closes the complete queued bundle", async () => {
  const {command} = await prepareAndQueue();
  await port.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    now: queuedAt,
    maxAttempts: 5,
  });
  await port.markDispatchFailed({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "worker-1",
    attemptCount: 1,
    failure: {code: "invalid_payload", message: "Rejected"},
    retryable: false,
    failedAt,
  });
  const rootRef = db.collection("risk_scan_runs").doc(command.scanRunId);
  const [executionSnapshot, runSnapshot, channelsSnapshot] =
    await Promise.all([
      readExecution(command),
      rootRef.get(),
      rootRef.collection("channels").get(),
    ]);
  assert.equal(executionSnapshot.data().status, "terminalFailure");
  assert.equal(runSnapshot.data().status, "failedTerminal");
  assert.equal(
      channelsSnapshot.docs.every(
          (document) => document.data().status === "failedTerminal"),
      true);
});

test("orchestration dispatches once and stores provider receipt", async () => {
  const {event} = await createExecutionEvent();
  let dispatchCount = 0;
  const result = await executionService.orchestratePublicLiteExecution({
    event,
    ownerId: "eventarc-worker-1",
    port,
    dispatcher: {
      dispatch: async (envelope) => {
        dispatchCount += 1;
        assert.equal(envelope.identityMode, "anonymous");
        return {
          providerCode: "n8n_public_lite",
          externalExecutionId: "n8n-execution-1",
          acceptedAt: dispatchedAt,
        };
      },
    },
    clock: {
      now: () => dispatchedAt,
    },
  });
  const executionSnapshot = await readExecution(result);
  assert.equal(result.outcome, "dispatched");
  assert.equal(dispatchCount, 1);
  assert.equal(
      executionSnapshot.data().externalExecutionId,
      "n8n-execution-1");
});
