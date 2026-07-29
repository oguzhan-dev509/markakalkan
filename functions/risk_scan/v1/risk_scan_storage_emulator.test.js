"use strict";

const {
  after,
  before,
  test,
} = require("node:test");
const assert = require("node:assert/strict");
const {
  deleteApp,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const {
  getFirestore,
} = require("firebase-admin/firestore");

const {
  canonicalJsonDigestSha256,
  sha256Hex,
} = require("./canonical");
const {
  riskScanFindingId,
  riskScanObservationId,
  riskScanReportId,
  riskScanRunId,
} = require("./identifiers");
const port = require("./firestore_storage_port");

const PROJECT_ID = "demo-markakalkan-hrt-1d-1c";
const now = "2026-07-29T15:00:00.000Z";
const t1 = "2026-07-29T15:10:00.000Z";
const t2 = "2026-07-29T15:20:00.000Z";
const t3 = "2026-07-29T15:30:00.000Z";
const expiresAt = "2026-08-05T15:00:00.000Z";
const accessDigest = "a".repeat(64);
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

function target() {
  const core = {
    brandNameNormalized: "ornek marka",
    officialHost: "example.com",
    officialWebsiteCanonicalUrl: "https://example.com/",
  };
  return {
    ...core,
    targetFingerprintSha256: canonicalJsonDigestSha256(core),
  };
}

function runInput(label, overrides = {}) {
  const requestId = unique(label);
  const requestFingerprintSha256 = sha256Hex(`${requestId}-payload`);
  return {
    scanRunId: riskScanRunId({requestId, requestFingerprintSha256}),
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    coverageStatus: "insufficient",
    target: target(),
    requestId,
    requestFingerprintSha256,
    deduplicationFingerprintSha256: sha256Hex(`${requestId}-dedupe`),
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt: now,
    updatedAt: now,
    expiresAt,
    accessSecretDigestSha256: accessDigest,
    accessSecretAlgorithm: "sha256",
    latestReportId: null,
    ...overrides,
  };
}

function channelInput(scanRunId, channelCode, overrides = {}) {
  return {
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
    updatedAt: now,
    ...overrides,
  };
}

function allChannels(scanRunId, overrides = {}) {
  return ["similarDomains", "openWeb", "marketplaceLimited"].map(
      (channelCode) => channelInput(scanRunId, channelCode, overrides));
}

function observationInput(scanRunId, overrides = {}) {
  const channelCode = overrides.channelCode || "openWeb";
  const sourceUrlCanonical = overrides.sourceUrlCanonical ||
    `https://${unique("source")}.example/page`;
  const contentFingerprintSha256 =
    overrides.contentFingerprintSha256 ||
    sha256Hex(`${sourceUrlCanonical}-content`);
  return {
    scanRunId,
    observationId: riskScanObservationId({
      scanRunId,
      channelCode,
      sourceUrlCanonical,
      contentFingerprintSha256,
    }),
    channelCode,
    sourceType: "webPage",
    acquisitionStatus: "acquired",
    sourceUrlCanonical,
    sourceHost: new URL(sourceUrlCanonical).host,
    sourceTitleSnapshot: "Şüpheli sayfa",
    contentFingerprintSha256,
    observedAt: t1,
    acquiredAt: t1,
    createdAt: t1,
    immutable: true,
    ...overrides,
  };
}

function findingInput(scanRunId, observationId, overrides = {}) {
  const observationRefs = overrides.observationRefs || [observationId];
  const findingType = overrides.findingType || "contentSimilarity";
  return {
    scanRunId,
    findingId: riskScanFindingId({
      scanRunId,
      findingType,
      observationRefs,
    }),
    channelCode: "openWeb",
    findingType,
    observationRefs,
    riskLevel: "high",
    confidenceLevel: "medium",
    impactLevel: "high",
    interventionDifficulty: "moderate",
    reviewStatus: "reviewRequired",
    recommendationCode: "reviewFinding",
    title: "Benzer içerik bulundu",
    summary: "İnsan incelemesi gerektiren içerik benzerliği.",
    reviewedAt: null,
    reviewedByUid: null,
    promotionStatus: "notRequested",
    promotionRequestId: null,
    promotedSignalId: null,
    promotedAt: null,
    createdAt: t2,
    updatedAt: t2,
    ...overrides,
  };
}

function completedChannel(scanRunId, channelCode, overrides = {}) {
  return channelInput(scanRunId, channelCode, {
    status: "completed",
    coverageStatus: "complete",
    observationCount: 0,
    findingCount: 0,
    attemptCount: 1,
    startedAt: t1,
    completedAt: t2,
    updatedAt: t2,
    ...overrides,
  });
}

function reportInput(scanRunId, overrides = {}) {
  const reportVersion = "1";
  return {
    scanRunId,
    reportId: riskScanReportId({scanRunId, reportVersion}),
    reportVersion,
    generatedAt: t3,
    status: "completed",
    coverageStatus: "complete",
    overallRiskLevel: "high",
    overallConfidenceLevel: "medium",
    recommendedAction: "reviewTopFindings",
    summary: "Tarama tamamlandı.",
    findingCount: 1,
    observationCount: 1,
    topFindingSnapshots: [{
      findingId: "finding-snapshot-1",
      findingType: "contentSimilarity",
      riskLevel: "high",
      confidenceLevel: "medium",
      impactLevel: "high",
      interventionDifficulty: "moderate",
      reviewStatus: "reviewRequired",
      recommendationCode: "reviewFinding",
      title: "Benzer içerik bulundu",
      summary: "İnsan incelemesi gerektirir.",
    }],
    channelDistribution: [
      {
        channelCode: "similarDomains",
        status: "completed",
        coverageStatus: "complete",
        observationCount: 0,
        findingCount: 0,
      },
      {
        channelCode: "openWeb",
        status: "completed",
        coverageStatus: "complete",
        observationCount: 1,
        findingCount: 1,
      },
      {
        channelCode: "marketplaceLimited",
        status: "completed",
        coverageStatus: "complete",
        observationCount: 0,
        findingCount: 0,
      },
    ],
    immutable: true,
    ...overrides,
  };
}

async function createBundle(run, channelOverrides = {}) {
  return port.createRunBundle(db, {
    run,
    channels: allChannels(run.scanRunId, channelOverrides),
  });
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-1d-1c");
  db = getFirestore(app);
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  if (app && getApps().includes(app)) {
    await deleteApp(app);
  }
});

test("emulator guard uses only a demo project and loopback host", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});

test("run bundle writes one root and three sibling channels", async () => {
  const run = runInput("bundle");
  const result = await createBundle(run);
  assert.equal(result.outcome, "created");

  const root = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  const channels = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("channels").get();
  assert.equal(root.exists, true);
  assert.equal(channels.size, 3);
});

test("parallel matching run creation collapses atomically", async () => {
  const run = runInput("parallel-run");
  const payload = {
    run,
    channels: allChannels(run.scanRunId),
  };
  const results = await Promise.all([
    port.createRunBundle(db, payload),
    port.createRunBundle(db, payload),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);
});

test("conflicting run replay does not overwrite the winner", async () => {
  const run = runInput("run-conflict");
  await createBundle(run);
  await assert.rejects(() => createBundle({
    ...run,
    status: "validatingTarget",
  }), (error) => error.code === "conflict");

  const stored = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  assert.equal(stored.data().status, "created");
});

test("run and channel lifecycle transitions persist", async () => {
  const run = runInput("transitions");
  await createBundle(run);
  await port.transitionRun(db, {
    scanRunId: run.scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: t1,
  });
  await port.transitionChannel(db, {
    scanRunId: run.scanRunId,
    channelCode: "openWeb",
    expectedStatus: "queued",
    nextStatus: "acquiring",
    updatedAt: t1,
    startedAt: t1,
    attemptCount: 1,
  });

  const root = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  const channel = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("channels").doc("openWeb").get();
  assert.equal(root.data().status, "validatingTarget");
  assert.equal(channel.data().status, "acquiring");
});

test("parallel observation replay increments its channel once", async () => {
  const run = runInput("parallel-observation", {status: "acquiring"});
  await createBundle(run, {status: "acquiring", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  const results = await Promise.all([
    port.appendObservation(db, {observation}),
    port.appendObservation(db, {observation}),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);

  const channel = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("channels").doc("openWeb").get();
  assert.equal(channel.data().observationCount, 1);
});

test("conflicting observation replay keeps immutable source data", async () => {
  const run = runInput("observation-conflict", {status: "acquiring"});
  await createBundle(run, {status: "acquiring", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  await port.appendObservation(db, {observation});

  await assert.rejects(() => port.appendObservation(db, {
    observation: {
      ...observation,
      sourceTitleSnapshot: "Değiştirilmiş başlık",
    },
  }), (error) => error.code === "conflict");

  const stored = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("observations")
      .doc(observation.observationId).get();
  assert.equal(stored.data().sourceTitleSnapshot, "Şüpheli sayfa");
});

test("finding without its observation rolls back fully", async () => {
  const run = runInput("missing-observation", {status: "assessing"});
  await createBundle(run, {status: "assessing", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  const finding = findingInput(run.scanRunId, observation.observationId);

  await assert.rejects(() =>
    port.appendFinding(db, {finding}),
  (error) => error.code === "not-found");

  const stored = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("findings")
      .doc(finding.findingId).get();
  const channel = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("channels").doc("openWeb").get();
  assert.equal(stored.exists, false);
  assert.equal(channel.data().findingCount, 0);
});

test("parallel finding replay increments its channel once", async () => {
  const run = runInput("parallel-finding", {status: "assessing"});
  await createBundle(run, {status: "assessing", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  await port.appendObservation(db, {observation});
  const finding = findingInput(run.scanRunId, observation.observationId);

  const results = await Promise.all([
    port.appendFinding(db, {finding}),
    port.appendFinding(db, {finding}),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);

  const channel = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).collection("channels").doc("openWeb").get();
  assert.equal(channel.data().findingCount, 1);
});

test("report is top-level immutable data and completes the run", async () => {
  const run = runInput("report", {status: "reporting"});
  await port.createRunBundle(db, {
    run,
    channels: [
      completedChannel(run.scanRunId, "similarDomains"),
      completedChannel(run.scanRunId, "openWeb", {
        observationCount: 1,
        findingCount: 1,
      }),
      completedChannel(run.scanRunId, "marketplaceLimited"),
    ],
  });
  const report = reportInput(run.scanRunId);
  const result = await port.createReportAndCompleteRun(db, {report});
  assert.equal(result.outcome, "created");

  const storedReport = await db.collection("risk_scan_reports")
      .doc(report.reportId).get();
  const storedRun = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  assert.equal(storedReport.data().immutable, true);
  assert.equal(storedRun.data().status, "completed");
  assert.equal(storedRun.data().latestReportId, report.reportId);
});

test("parallel report replay creates one immutable snapshot", async () => {
  const run = runInput("parallel-report", {status: "reporting"});
  await port.createRunBundle(db, {
    run,
    channels: [
      completedChannel(run.scanRunId, "similarDomains"),
      completedChannel(run.scanRunId, "openWeb", {
        observationCount: 1,
        findingCount: 1,
      }),
      completedChannel(run.scanRunId, "marketplaceLimited"),
    ],
  });
  const report = reportInput(run.scanRunId);
  const results = await Promise.all([
    port.createReportAndCompleteRun(db, {report}),
    port.createReportAndCompleteRun(db, {report}),
  ]);
  assert.deepEqual(
      results.map((item) => item.outcome).sort(),
      ["created", "idempotent_success"]);

  const reports = await db.collection("risk_scan_reports")
      .where("scanRunId", "==", run.scanRunId).get();
  assert.equal(reports.size, 1);
});

test("stale report aggregate rolls back atomically", async () => {
  const run = runInput("stale-report", {status: "reporting"});
  await port.createRunBundle(db, {
    run,
    channels: [
      completedChannel(run.scanRunId, "similarDomains"),
      completedChannel(run.scanRunId, "openWeb"),
      completedChannel(run.scanRunId, "marketplaceLimited"),
    ],
  });
  const report = reportInput(run.scanRunId);
  await assert.rejects(() =>
    port.createReportAndCompleteRun(db, {report}),
  (error) => error.code === "conflict");

  const storedReport = await db.collection("risk_scan_reports")
      .doc(report.reportId).get();
  const storedRun = await db.collection("risk_scan_runs")
      .doc(run.scanRunId).get();
  assert.equal(storedReport.exists, false);
  assert.equal(storedRun.data().status, "reporting");
  assert.equal(storedRun.data().latestReportId, null);
});
