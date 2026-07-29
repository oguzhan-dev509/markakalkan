"use strict";

const assert = require("node:assert/strict");
const {after, before, beforeEach, test} = require("node:test");
const {
  deleteApp,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const {sha256Hex} = require("./canonical");
const {riskScanRunId} = require("./identifiers");
const publicContract = require("./public_lite_contract");
const publicPort = require("./public_lite_firestore_port");
const storageDocuments = require("./storage_documents");
const storagePort = require("./firestore_storage_port");

const PROJECT_ID = "demo-markakalkan-hrt-1d-1i";
const createdAt = "2026-07-29T15:00:00.000Z";
const expiresAt = "2026-08-05T15:00:00.000Z";
let app;
let db;
let sequence = 0;

function assertEmulatorGuard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error("Firestore emulator loopback host is required");
  }
  if (!PROJECT_ID.startsWith("demo-")) {
    throw new Error("Only a demo project is allowed");
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("Production credentials are forbidden");
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

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${sequence}`;
}

function runInput() {
  const requestId = unique("retention-run");
  const requestFingerprintSha256 = sha256Hex(`${requestId}-payload`);
  return {
    scanRunId: riskScanRunId({requestId, requestFingerprintSha256}),
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    coverageStatus: "insufficient",
    target: {
      brandNameNormalized: "ornek marka",
      officialHost: "example.com",
      officialWebsiteCanonicalUrl: "https://example.com/",
      targetFingerprintSha256: sha256Hex(`${requestId}-target`),
    },
    requestId,
    requestFingerprintSha256,
    deduplicationFingerprintSha256: sha256Hex(`${requestId}-dedupe`),
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt,
    updatedAt: createdAt,
    expiresAt,
    accessSecretDigestSha256: "a".repeat(64),
    accessSecretAlgorithm: "sha256",
    latestReportId: null,
  };
}

function channels(scanRunId) {
  return ["similarDomains", "openWeb", "marketplaceLimited"].map(
      (channelCode) => ({
        scanRunId,
        channelCode,
        status: "queued",
        coverageStatus: "insufficient",
        observationCount: 0,
        findingCount: 0,
        limitReasonCodes: [],
        attemptCount: 0,
        startedAt: null,
        completedAt: null,
        updatedAt: createdAt,
      }));
}

function publicCommand(overrides = {}) {
  return publicContract.buildPublicLiteStartCommand({
    data: {
      requestId: overrides.requestId || unique("public-retention"),
      brandName: "Örnek Marka",
      officialWebsiteUrl: "https://example.com/",
      anonymousClientNonce: "retention-browser-nonce",
    },
    appId: "1:123:web:retention",
    networkAddress: "203.0.113.10",
    secretKey: "k".repeat(48),
    now: new Date("2026-07-29T16:00:00.000Z"),
    rateLimit: 5,
  });
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-1d-1i");
  db = getFirestore(app);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  if (app && getApps().includes(app)) {
    await deleteApp(app);
  }
});

test("retention storage emulator guard is isolated", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});

test("standard run stores Timestamp without changing fingerprint", async () => {
  const run = runInput();
  const pure = storageDocuments.buildRunDocument(run);
  await storagePort.createRunBundle(db, {
    run,
    channels: channels(run.scanRunId),
  });

  const snapshot = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  const stored = snapshot.data();
  assert.equal(stored.expiresAt, expiresAt);
  assert.equal(stored.expiresAtTimestamp.toDate().toISOString(), expiresAt);
  assert.equal(stored.nativeTtlEligible, false);
  assert.equal(stored.cleanupStrategy, "recursiveServerSide");
  assert.equal(
      stored.storageFingerprintSha256,
      pure.storageFingerprintSha256);
});

test("run transition preserves retention Timestamp", async () => {
  const run = runInput();
  await storagePort.createRunBundle(db, {
    run,
    channels: channels(run.scanRunId),
  });
  await storagePort.transitionRun(db, {
    scanRunId: run.scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: "2026-07-29T15:10:00.000Z",
  });

  const snapshot = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  const stored = snapshot.data();
  assert.equal(stored.status, "validatingTarget");
  assert.equal(stored.expiresAtTimestamp.toDate().toISOString(), expiresAt);
  assert.equal(stored.nativeTtlEligible, false);
});

test("public start stores run and rate-limit Timestamps", async () => {
  const command = publicCommand();
  await publicPort.createPublicLiteRun(db, command);

  const runSnapshot = await db.collection("risk_scan_runs")
      .doc(command.run.scanRunId).get();
  const run = runSnapshot.data();
  assert.equal(
      run.expiresAtTimestamp.toDate().toISOString(),
      command.run.expiresAt);

  for (const candidate of command.rateLimitRecords) {
    const snapshot = await db.collection("risk_scan_rate_limits")
        .doc(candidate.bucketId).get();
    const stored = snapshot.data();
    assert.equal(
        stored.purgeAtTimestamp.toDate().toISOString(),
        candidate.purgeAt);
    assert.equal(stored.nativeTtlEligible, true);
    assert.equal(stored.ttlField, "purgeAtTimestamp");
  }
});

test("public replay preserves retention and avoids double charge", async () => {
  const command = publicCommand();
  const first = await publicPort.createPublicLiteRun(db, command);
  const second = await publicPort.createPublicLiteRun(db, command);
  assert.deepEqual(
      [first.outcome, second.outcome].sort(),
      ["created", "idempotent_success"]);

  const bucket = await db.collection("risk_scan_rate_limits")
      .doc(command.rateLimitRecords[0].bucketId).get();
  assert.equal(bucket.data().count, 1);
  assert.equal(
      bucket.data().purgeAtTimestamp.toDate().toISOString(),
      command.rateLimitRecords[0].purgeAt);

  const run = await db.collection("risk_scan_runs")
      .doc(command.run.scanRunId).get();
  assert.equal(
      run.data().expiresAtTimestamp.toDate().toISOString(),
      command.run.expiresAt);
});
