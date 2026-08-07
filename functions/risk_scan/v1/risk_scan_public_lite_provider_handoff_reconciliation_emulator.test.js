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

const PROJECT_ID = "demo-markakalkan-hrt-handoff-b4c";
const secretKey = "s".repeat(48);
const baseNow = new Date("2026-08-06T12:00:00.000Z");
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

async function createAcceptedHandoff() {
  const start = publicContract.buildPublicLiteStartCommand({
    data: {
      requestId: unique("request"),
      brandName: "Beauty of Joseon",
      officialWebsiteUrl: "https://beautyofjoseon.com/",
      anonymousClientNonce: unique("browser"),
    },
    appId: "1:123:web:hrt-handoff-b4c",
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
    updatedAt: "2026-08-06T12:01:00.000Z",
  });
  await executionPort.claimDispatch({
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    ownerId: "gateway-worker",
    now: "2026-08-06T12:01:00.000Z",
    maxAttempts: 5,
  });
  const accepted = await handoffPort.acceptHandoff({
    request: {
      contractVersion:
        handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
      providerCode: "n8n_public_lite",
      executionId: command.executionId,
      scanRunId: command.scanRunId,
      gatewayExecutionId: unique("gateway"),
      dispatchEnvelope:
        executionContract.buildPublicLiteDispatchEnvelope(command),
    },
    acceptedAt: "2026-08-06T12:02:00.000Z",
    purgeAtTimestamp: new Date("2026-09-05T12:02:00.000Z"),
  });
  return {command, accepted};
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-handoff-b4c");
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

test("due query returns an accepted handoff", async () => {
  const {command} = await createAcceptedHandoff();
  const due = await handoffPort.listDueHandoffs({
    now: new Date("2026-08-06T12:02:00.000Z"),
    limit: 10,
  });
  assert.equal(due.length, 1);
  assert.equal(due[0].executionId, command.executionId);
});

test("concurrent reconcilers produce one transactional claimant", async () => {
  const {command} = await createAcceptedHandoff();
  const results = await Promise.all([
    handoffPort.claimChildDispatch({
      executionId: command.executionId,
      ownerId: "reconciler-1",
      now: "2026-08-06T12:03:00.000Z",
      maxAttempts: 5,
    }),
    handoffPort.claimChildDispatch({
      executionId: command.executionId,
      ownerId: "reconciler-2",
      now: "2026-08-06T12:03:00.000Z",
      maxAttempts: 5,
    }),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["claimed", "lease_held"]);
});

test("retry backoff prevents immediate reclaim", async () => {
  const {command} = await createAcceptedHandoff();
  const claim = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "reconciler-1",
    now: "2026-08-06T12:03:00.000Z",
    maxAttempts: 5,
  });
  await handoffPort.markChildDispatchFailed({
    executionId: command.executionId,
    ownerId: "reconciler-1",
    attemptCount: claim.attemptCount,
    leaseToken: claim.leaseToken,
    failure: {code: "upstream_unavailable"},
    retryable: true,
    failedAt: "2026-08-06T12:04:00.000Z",
  });
  const early = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "reconciler-2",
    now: "2026-08-06T12:04:59.999Z",
    maxAttempts: 5,
  });
  const due = await handoffPort.claimChildDispatch({
    executionId: command.executionId,
    ownerId: "reconciler-2",
    now: "2026-08-06T12:05:00.000Z",
    maxAttempts: 5,
  });
  assert.equal(early.outcome, "not_due");
  assert.equal(due.outcome, "claimed");
  assert.equal(due.attemptCount, 2);
});

test("attempt exhaustion creates durable dead letter", async () => {
  const {command} = await createAcceptedHandoff();
  let now = new Date("2026-08-06T12:03:00.000Z");
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    const claim = await handoffPort.claimChildDispatch({
      executionId: command.executionId,
      ownerId: `reconciler-${attempt}`,
      now: now.toISOString(),
      maxAttempts: 5,
    });
    assert.equal(claim.outcome, "claimed");
    const failedAt = new Date(now.getTime() + 1000);
    const failure = await handoffPort.markChildDispatchFailed({
      executionId: command.executionId,
      ownerId: `reconciler-${attempt}`,
      attemptCount: claim.attemptCount,
      leaseToken: claim.leaseToken,
      failure: {code: "upstream_unavailable"},
      retryable: true,
      failedAt: failedAt.toISOString(),
    });
    if (attempt < 5) {
      assert.equal(failure.outcome, "retryable_failure");
      now = new Date(
          failure.record.childDispatchDueAtTimestamp.getTime());
    } else {
      assert.equal(failure.outcome, "terminal_failure");
      assert.equal(failure.record.state, "dead_letter");
      assert.equal(failure.record.childDispatchDueAtTimestamp, null);
      assert.equal(failure.record.deadLetteredAt, failedAt.toISOString());
    }
  }
});
