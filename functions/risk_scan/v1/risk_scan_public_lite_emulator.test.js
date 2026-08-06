"use strict";

const {after, before, beforeEach, test} = require("node:test");
const assert = require("node:assert/strict");
const {
  deleteApp,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const contract = require("./public_lite_contract");
const publicPort = require("./public_lite_firestore_port");
const storagePort = require("./firestore_storage_port");
const {riskScanReportId} = require("./identifiers");

const PROJECT_ID = "demo-markakalkan-hrt-1d-1d";
const secretKey = "s".repeat(48);
const baseNow = new Date("2026-07-29T16:00:00.000Z");
let sequence = 0;
let app;
let db;

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

function buildCommand(overrides = {}) {
  return contract.buildPublicLiteStartCommand({
    data: {
      requestId: overrides.requestId || unique("public-request"),
      brandName: "Örnek Marka",
      officialWebsiteUrl: "https://example.com/",
      anonymousClientNonce:
        overrides.anonymousClientNonce || "shared-browser-nonce",
    },
    appId: "1:123:web:abc",
    networkAddress: "203.0.113.10",
    secretKey,
    now: overrides.now || baseNow,
    rateLimit: overrides.rateLimit,
  });
}

const PUBLIC_LITE_EMULATOR_RETRY_MAX_ATTEMPTS = 3;
const PUBLIC_LITE_EMULATOR_RETRY_DELAYS_MS =
  Object.freeze([25, 50]);

function isRetryableClosedTransactionError(error) {
  if (!error || error.code !== 3) return false;
  const expected =
    "transaction is invalid or closed.";
  const details =
    typeof error.details === "string" ?
      error.details.trim().toLowerCase() :
      "";
  const message =
    typeof error.message === "string" ?
      error.message.trim().toLowerCase() :
      "";
  return details === expected ||
    message === expected ||
    message === `3 invalid_argument: ${expected}`;
}

function waitForPublicLiteEmulatorRetry(delayMs) {
  return new Promise((resolve) => {
    setTimeout(resolve, delayMs);
  });
}

async function retryPublicLiteStartForEmulator(operation, attempt = 1) {
  if (typeof operation !== "function") {
    throw new TypeError("operation is required");
  }
  try {
    return await operation();
  } catch (error) {
    if (!isRetryableClosedTransactionError(error) ||
        attempt >= PUBLIC_LITE_EMULATOR_RETRY_MAX_ATTEMPTS) {
      throw error;
    }
    await waitForPublicLiteEmulatorRetry(
        PUBLIC_LITE_EMULATOR_RETRY_DELAYS_MS[attempt - 1]);
    return retryPublicLiteStartForEmulator(operation, attempt + 1);
  }
}

async function advanceToReporting(command) {
  const scanRunId = command.run.scanRunId;
  const times = [
    "2026-07-29T16:05:00.000Z",
    "2026-07-29T16:06:00.000Z",
    "2026-07-29T16:07:00.000Z",
    "2026-07-29T16:08:00.000Z",
    "2026-07-29T16:09:00.000Z",
  ];
  await storagePort.transitionRun(db, {
    scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: times[0],
  });
  await storagePort.transitionRun(db, {
    scanRunId,
    expectedStatus: "validatingTarget",
    nextStatus: "queued",
    updatedAt: times[1],
  });
  await storagePort.transitionRun(db, {
    scanRunId,
    expectedStatus: "queued",
    nextStatus: "acquiring",
    updatedAt: times[2],
  });
  await storagePort.transitionRun(db, {
    scanRunId,
    expectedStatus: "acquiring",
    nextStatus: "assessing",
    updatedAt: times[3],
  });
  await storagePort.transitionRun(db, {
    scanRunId,
    expectedStatus: "assessing",
    nextStatus: "reporting",
    updatedAt: times[4],
  });
  for (const channelCode of [
    "similarDomains", "openWeb", "marketplaceLimited",
  ]) {
    await storagePort.transitionChannel(db, {
      scanRunId,
      channelCode,
      expectedStatus: "queued",
      nextStatus: "acquiring",
      updatedAt: times[2],
      startedAt: times[2],
      attemptCount: 1,
    });
    await storagePort.transitionChannel(db, {
      scanRunId,
      channelCode,
      expectedStatus: "acquiring",
      nextStatus: "assessing",
      updatedAt: times[3],
    });
    await storagePort.transitionChannel(db, {
      scanRunId,
      channelCode,
      expectedStatus: "assessing",
      nextStatus: "completed",
      updatedAt: times[4],
      completedAt: times[4],
      coverageStatus: "complete",
    });
  }
}

function emptyReport(command) {
  const reportVersion = "1";
  return {
    scanRunId: command.run.scanRunId,
    reportId: riskScanReportId({
      scanRunId: command.run.scanRunId,
      reportVersion,
    }),
    reportVersion,
    generatedAt: "2026-07-29T16:10:00.000Z",
    status: "completed",
    coverageStatus: "complete",
    overallRiskLevel: "low",
    overallConfidenceLevel: "medium",
    recommendedAction: "noImmediateAction",
    summary: "Public Lite taraması tamamlandı.",
    findingCount: 0,
    observationCount: 0,
    topFindingSnapshots: [],
    channelDistribution: [
      "similarDomains", "openWeb", "marketplaceLimited",
    ].map((channelCode) => ({
      channelCode,
      status: "completed",
      coverageStatus: "complete",
      observationCount: 0,
      findingCount: 0,
    })),
    immutable: true,
  };
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-1d-1d");
  db = getFirestore(app);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  if (app && getApps().includes(app)) await deleteApp(app);
});

test("public emulator guard uses demo project and loopback host", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});

test(
    "public start writes root, three channels, and one rate bucket",
    async () => {
      const command = buildCommand();
      const result = await publicPort.createPublicLiteRun(db, command);
      assert.equal(result.outcome, "created");
      const root = await db.collection("risk_scan_runs")
          .doc(command.run.scanRunId).get();
      const channels = await root.ref.collection("channels").get();
      const networkBucket = await db.collection("risk_scan_rate_limits")
          .doc(command.rateLimitRecords[0].bucketId).get();
      const clientBucket = await db.collection("risk_scan_rate_limits")
          .doc(command.rateLimitRecords[1].bucketId).get();
      assert.equal(root.exists, true);
      assert.equal(channels.size, 3);
      assert.equal(networkBucket.data().count, 1);
      assert.equal(clientBucket.data().count, 1);
    });

test("parallel exact start collapses without double rate charge", async () => {
  const command = buildCommand();
  const results = await Promise.all([
    retryPublicLiteStartForEmulator(
        () => publicPort.createPublicLiteRun(db, command)),
    retryPublicLiteStartForEmulator(
        () => publicPort.createPublicLiteRun(db, command)),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);
  const bucket = await db.collection("risk_scan_rate_limits")
      .doc(command.rateLimitRecords[0].bucketId).get();
  assert.equal(bucket.data().count, 1);
});

test("distinct requests in one bucket increment atomically", async () => {
  const first = buildCommand();
  const second = buildCommand();
  await Promise.all([
    publicPort.createPublicLiteRun(db, first),
    publicPort.createPublicLiteRun(db, second),
  ]);
  const bucket = await db.collection("risk_scan_rate_limits")
      .doc(first.rateLimitRecords[0].bucketId).get();
  assert.equal(bucket.data().count, 2);
});

test("parallel rate limit rejection leaves one complete winner", async () => {
  const first = buildCommand({rateLimit: 1});
  const second = buildCommand({rateLimit: 1});
  const outcomes = await Promise.allSettled([
    publicPort.createPublicLiteRun(db, first),
    publicPort.createPublicLiteRun(db, second),
  ]);
  const fulfilled = outcomes.filter((item) => item.status === "fulfilled");
  assert.equal(fulfilled.length, 1);
  const rejected = outcomes.find((item) => item.status === "rejected");
  assert.equal(rejected.reason.code, "resource-exhausted");
  const roots = await db.collection("risk_scan_runs").get();
  assert.equal(roots.size >= 1, true);
});

test("exact replay after lifecycle advance remains idempotent", async () => {
  const command = buildCommand();
  await publicPort.createPublicLiteRun(db, command);
  await storagePort.transitionRun(db, {
    scanRunId: command.run.scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: "2026-07-29T16:05:00.000Z",
  });
  const replay = await publicPort.createPublicLiteRun(db, {
    ...buildCommand({
      requestId: command.run.requestId,
      anonymousClientNonce: "shared-browser-nonce",
      now: new Date("2026-07-29T16:15:00.000Z"),
    }),
  });
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(replay.run.status, "validatingTarget");
});

test("valid access returns a masked status projection", async () => {
  const command = buildCommand();
  await publicPort.createPublicLiteRun(db, command);
  const projection = await publicPort.getPublicLiteStatus(db, {
    accessKey: command.accessKey,
    now: "2026-07-29T16:30:00.000Z",
  });
  const serialized = JSON.stringify(projection);
  assert.equal(projection.scanRunId, command.run.scanRunId);
  assert.equal(serialized.includes("accessSecret"), false);
  assert.equal(serialized.includes("fingerprint"), false);
});

test("invalid access key does not reveal run existence", async () => {
  const command = buildCommand();
  await publicPort.createPublicLiteRun(db, command);
  const parsed = contract.parseAccessKey(command.accessKey);
  const invalid = contract.buildAccessKey(
      parsed.scanRunId, "x".repeat(43));
  await assert.rejects(
      () => publicPort.getPublicLiteStatus(db, {
        accessKey: invalid,
        now: "2026-07-29T16:30:00.000Z",
      }),
      (error) => error.code === "not-found");
});

test("report read is blocked until immutable report exists", async () => {
  const command = buildCommand();
  await publicPort.createPublicLiteRun(db, command);
  await assert.rejects(
      () => publicPort.getPublicLiteReport(db, {
        accessKey: command.accessKey,
        now: "2026-07-29T16:30:00.000Z",
      }),
      (error) => error.code === "failed-precondition");
});

test(
    "completed immutable report is returned only as public projection",
    async () => {
      const command = buildCommand();
      await publicPort.createPublicLiteRun(db, command);
      await advanceToReporting(command);
      const report = emptyReport(command);
      await storagePort.createReportAndCompleteRun(db, {report});
      const projection = await publicPort.getPublicLiteReport(db, {
        accessKey: command.accessKey,
        now: "2026-07-29T16:30:00.000Z",
      });
      const serialized = JSON.stringify(projection);
      assert.equal(projection.report.reportId, report.reportId);
      assert.equal(serialized.includes("reportDigestSha256"), false);
      assert.equal(serialized.includes("storageFingerprint"), false);
    });
