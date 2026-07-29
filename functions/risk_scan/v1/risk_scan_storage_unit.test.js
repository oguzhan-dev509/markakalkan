"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

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
const documents = require("./storage_documents");
const port = require("./firestore_storage_port");

const now = "2026-07-29T15:00:00.000Z";
const t1 = "2026-07-29T15:10:00.000Z";
const t2 = "2026-07-29T15:20:00.000Z";
const t3 = "2026-07-29T15:30:00.000Z";
const expiresAt = "2026-08-05T15:00:00.000Z";
const digestA = "a".repeat(64);
const digestC = "c".repeat(64);

function clone(value) {
  return structuredClone(value);
}

class FakeDocumentSnapshot {
  constructor(value) {
    this.value = value;
    this.exists = value !== undefined;
  }

  data() {
    return this.exists ? clone(this.value) : undefined;
  }
}

class FakeDocumentReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  collection(name) {
    return new FakeCollectionReference(this.db, `${this.path}/${name}`);
  }
}

class FakeCollectionReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(this.db, `${this.path}/${id}`);
  }
}

class FakeTransaction {
  constructor(data) {
    this.data = data;
  }

  async get(ref) {
    return new FakeDocumentSnapshot(this.data.get(ref.path));
  }

  create(ref, value) {
    if (this.data.has(ref.path)) {
      const error = new Error("already exists");
      error.code = "already-exists";
      throw error;
    }
    this.data.set(ref.path, clone(value));
  }

  update(ref, patch) {
    if (!this.data.has(ref.path)) {
      const error = new Error("not found");
      error.code = "not-found";
      throw error;
    }
    this.data.set(ref.path, {
      ...clone(this.data.get(ref.path)),
      ...clone(patch),
    });
  }
}

class FakeFirestore {
  constructor() {
    this.data = new Map();
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  async runTransaction(callback) {
    const working = new Map();
    for (const [key, value] of this.data.entries()) {
      working.set(key, clone(value));
    }
    const result = await callback(new FakeTransaction(working));
    this.data = working;
    return result;
  }

  get(path) {
    const value = this.data.get(path);
    return value === undefined ? undefined : clone(value);
  }

  set(path, value) {
    this.data.set(path, clone(value));
  }
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

function runInput(overrides = {}) {
  const requestId = overrides.requestId || "request-1";
  const requestFingerprintSha256 =
    overrides.requestFingerprintSha256 || sha256Hex("request-payload-1");
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
    deduplicationFingerprintSha256: sha256Hex("dedupe-1"),
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt: now,
    updatedAt: now,
    expiresAt,
    accessSecretDigestSha256: digestA,
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
  const sourceUrlCanonical =
    overrides.sourceUrlCanonical || "https://suspect.example/page";
  const contentFingerprintSha256 =
    overrides.contentFingerprintSha256 || sha256Hex("content-1");
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
    sourceHost: "suspect.example",
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
  const findingType = overrides.findingType || "contentSimilarity";
  const observationRefs = overrides.observationRefs || [observationId];
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
    attemptCount: 1,
    startedAt: t1,
    completedAt: t2,
    updatedAt: t2,
    ...overrides,
  });
}

function reportInput(scanRunId, overrides = {}) {
  const reportVersion = overrides.reportVersion || "1";
  const channelDistribution = overrides.channelDistribution || [
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
  ];
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
    channelDistribution,
    immutable: true,
    ...overrides,
  };
}

async function seedBundle(db, runOverrides = {}, channelOverrides = {}) {
  const run = runInput(runOverrides);
  const result = await port.createRunBundle(db, {
    run,
    channels: allChannels(run.scanRunId, channelOverrides),
  });
  return {run, result};
}

// Storage document contract: 22 tests.
test("run document mirrors the run contract version", () => {
  const value = documents.buildRunDocument(runInput());
  assert.equal(value.contractVersion, "risk-scan-run-v1");
});

test("run document uses deterministic run identity", () => {
  const value = documents.buildRunDocument(runInput());
  assert.equal(value.scanRunId, runInput().scanRunId);
});

test("run document rejects a mismatched run id", () => {
  assert.throws(() =>
    documents.buildRunDocument(runInput({scanRunId: "wrong"})));
});

test("public lite run requires an access digest", () => {
  assert.throws(() => documents.buildRunDocument(runInput({
    accessSecretDigestSha256: null,
    accessSecretAlgorithm: null,
  })));
});

test("registered run rejects an access digest", () => {
  assert.throws(() => documents.buildRunDocument(runInput({
    accessTier: "registered",
    identityMode: "resolved",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    createdByUid: "user-1",
  })));
});

test("resolved registered run is accepted", () => {
  const value = documents.buildRunDocument(runInput({
    accessTier: "registered",
    identityMode: "resolved",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    createdByUid: "user-1",
    accessSecretDigestSha256: null,
    accessSecretAlgorithm: null,
  }));
  assert.equal(value.tenantId, "tenant-1");
});

test("run expiry must follow creation", () => {
  assert.throws(() => documents.buildRunDocument(runInput({
    expiresAt: now,
  })));
});

test("storage fingerprint is stable", () => {
  assert.equal(
      documents.buildRunDocument(runInput()).storageFingerprintSha256,
      documents.buildRunDocument(runInput()).storageFingerprintSha256);
});

test("storage fingerprint changes with run status", () => {
  assert.notEqual(
      documents.buildRunDocument(runInput()).storageFingerprintSha256,
      documents.buildRunDocument(
          runInput({status: "validatingTarget"}))
          .storageFingerprintSha256);
});

test("channel rejects negative counters", () => {
  assert.throws(() => documents.buildChannelDocument(
      channelInput(runInput().scanRunId, "openWeb", {
        observationCount: -1,
      })));
});

test("channel rejects duplicate limit reasons", () => {
  assert.throws(() => documents.buildChannelDocument(
      channelInput(runInput().scanRunId, "openWeb", {
        limitReasonCodes: ["robots", "robots"],
      })));
});

test("observation identity is deterministic", () => {
  const run = runInput();
  const value = documents.buildObservationDocument(
      observationInput(run.scanRunId));
  assert.match(value.observationId, /^[a-f0-9]{64}$/);
});

test("observation must be immutable", () => {
  const run = runInput();
  assert.throws(() => documents.buildObservationDocument(
      observationInput(run.scanRunId, {immutable: false})));
});

test("observation rejects a mismatched identity", () => {
  const run = runInput();
  assert.throws(() => documents.buildObservationDocument(
      observationInput(run.scanRunId, {observationId: "wrong"})));
});

test("automatic finding may remain review required", () => {
  const run = runInput();
  const observation = observationInput(run.scanRunId);
  const value = documents.buildFindingDocument(
      findingInput(run.scanRunId, observation.observationId));
  assert.equal(value.reviewStatus, "reviewRequired");
});

test("automatic finding cannot be confirmed", () => {
  const run = runInput();
  const observation = observationInput(run.scanRunId);
  assert.throws(() => documents.buildFindingDocument(
      findingInput(run.scanRunId, observation.observationId, {
        reviewStatus: "confirmed",
      })));
});

test("human reviewed finding requires both review fields", () => {
  const run = runInput();
  const observation = observationInput(run.scanRunId);
  assert.throws(() => documents.buildFindingDocument(
      findingInput(run.scanRunId, observation.observationId, {
        reviewStatus: "suspicious",
        reviewedAt: t3,
      })));
});

test("not requested finding rejects promotion binding", () => {
  const run = runInput();
  const observation = observationInput(run.scanRunId);
  assert.throws(() => documents.buildFindingDocument(
      findingInput(run.scanRunId, observation.observationId, {
        promotionRequestId: "request-promotion-1",
      })));
});

test("report digest is calculated from the immutable snapshot", () => {
  const run = runInput();
  const value = documents.buildReportDocument(reportInput(run.scanRunId));
  assert.match(value.reportDigestSha256, /^[a-f0-9]{64}$/);
});

test("report rejects a supplied mismatched digest", () => {
  const run = runInput();
  assert.throws(() => documents.buildReportDocument(
      reportInput(run.scanRunId, {reportDigestSha256: digestC})));
});

test("report must be immutable", () => {
  const run = runInput();
  assert.throws(() => documents.buildReportDocument(
      reportInput(run.scanRunId, {immutable: false})));
});

test("replay guard rejects a different storage fingerprint", () => {
  assert.throws(
      () => documents.assertReplayMatch(
          documents.buildRunDocument(runInput()),
          documents.buildRunDocument(runInput({status: "cancelled"})),
          "run"),
      (error) => error.code === "conflict");
});

// Firestore port with an isolated in-memory adapter: 24 tests.
test("storage port rejects an invalid database", async () => {
  await assert.rejects(() =>
    port.createRunBundle({}, {run: runInput(), channels: []}));
});

test("run bundle requires all V1 channels", async () => {
  const db = new FakeFirestore();
  const run = runInput();
  await assert.rejects(() => port.createRunBundle(db, {
    run,
    channels: [channelInput(run.scanRunId, "openWeb")],
  }));
});

test("run bundle creates root and three channels atomically", async () => {
  const db = new FakeFirestore();
  const {run, result} = await seedBundle(db);
  assert.equal(result.outcome, "created");
  assert.ok(db.get(`risk_scan_runs/${run.scanRunId}`));
  assert.ok(db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`));
});

test("matching run bundle replay is idempotent", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  const replay = await port.createRunBundle(db, {
    run,
    channels: allChannels(run.scanRunId),
  });
  assert.equal(replay.outcome, "idempotent_success");
});

test("mismatched run bundle replay conflicts", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  await assert.rejects(() => port.createRunBundle(db, {
    run: {...run, status: "validatingTarget"},
    channels: allChannels(run.scanRunId),
  }), (error) => error.code === "conflict");
});

test("partial run bundle conflicts atomically", async () => {
  const db = new FakeFirestore();
  const run = documents.buildRunDocument(runInput());
  db.set(`risk_scan_runs/${run.scanRunId}`, run);
  await assert.rejects(() => port.createRunBundle(db, {
    run: runInput(),
    channels: allChannels(run.scanRunId),
  }), (error) => error.code === "conflict");
  assert.equal(db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`), undefined);
});

test("run transition applies an allowed transition", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  const result = await port.transitionRun(db, {
    scanRunId: run.scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: t1,
  });
  assert.equal(result.status, "validatingTarget");
});

test("run transition replay is idempotent", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db, {status: "validatingTarget"});
  const result = await port.transitionRun(db, {
    scanRunId: run.scanRunId,
    expectedStatus: "created",
    nextStatus: "validatingTarget",
    updatedAt: t1,
  });
  assert.equal(result.outcome, "idempotent_success");
});

test("run transition rejects stale expected status", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db, {status: "validatingTarget"});
  await assert.rejects(() => port.transitionRun(db, {
    scanRunId: run.scanRunId,
    expectedStatus: "created",
    nextStatus: "queued",
    updatedAt: t1,
  }), (error) => error.code === "conflict");
});

test("channel transition applies an allowed transition", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  const result = await port.transitionChannel(db, {
    scanRunId: run.scanRunId,
    channelCode: "openWeb",
    expectedStatus: "queued",
    nextStatus: "acquiring",
    updatedAt: t1,
    startedAt: t1,
    attemptCount: 1,
  });
  assert.equal(result.status, "acquiring");
});

test("channel transition rejects an illegal terminal jump", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  await assert.rejects(() => port.transitionChannel(db, {
    scanRunId: run.scanRunId,
    channelCode: "openWeb",
    expectedStatus: "queued",
    nextStatus: "completed",
    updatedAt: t1,
  }));
});

test("observation append creates immutable evidence", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "acquiring"},
      {status: "acquiring", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  const result = await port.appendObservation(db, {observation});
  assert.equal(result.outcome, "created");
  assert.ok(db.get(
      `risk_scan_runs/${run.scanRunId}/observations/` +
      observation.observationId));
});

test("observation append increments the channel once", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "acquiring"},
      {status: "acquiring", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  await port.appendObservation(db, {observation});
  const stored = db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`);
  assert.equal(stored.observationCount, 1);
});

test("observation replay does not increment twice", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "acquiring"},
      {status: "acquiring", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  await port.appendObservation(db, {observation});
  const replay = await port.appendObservation(db, {observation});
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`)
      .observationCount, 1);
});

test("observation append rejects an inactive run", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(db);
  await assert.rejects(() => port.appendObservation(db, {
    observation: observationInput(run.scanRunId),
  }), (error) => error.code === "failed-precondition");
});

test("finding append requires an existing observation", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "assessing"},
      {status: "assessing", startedAt: t1});
  const observation = observationInput(run.scanRunId);
  await assert.rejects(() => port.appendFinding(db, {
    finding: findingInput(run.scanRunId, observation.observationId),
  }), (error) => error.code === "not-found");
});

test("finding append creates a finding and increments once", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "assessing"},
      {status: "assessing", startedAt: t1});
  const observation = documents.buildObservationDocument(
      observationInput(run.scanRunId));
  db.set(
      `risk_scan_runs/${run.scanRunId}/observations/` +
      observation.observationId,
      observation);
  const finding = findingInput(run.scanRunId, observation.observationId);
  const result = await port.appendFinding(db, {finding});
  assert.equal(result.outcome, "created");
  assert.equal(db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`).findingCount, 1);
});

test("finding replay does not increment twice", async () => {
  const db = new FakeFirestore();
  const {run} = await seedBundle(
      db,
      {status: "assessing"},
      {status: "assessing", startedAt: t1});
  const observation = documents.buildObservationDocument(
      observationInput(run.scanRunId));
  db.set(
      `risk_scan_runs/${run.scanRunId}/observations/` +
      observation.observationId,
      observation);
  const finding = findingInput(run.scanRunId, observation.observationId);
  await port.appendFinding(db, {finding});
  const replay = await port.appendFinding(db, {finding});
  assert.equal(replay.outcome, "idempotent_success");
  assert.equal(db.get(
      `risk_scan_runs/${run.scanRunId}/channels/openWeb`).findingCount, 1);
});

test("report creation completes a reporting run", async () => {
  const db = new FakeFirestore();
  const run = runInput({status: "reporting"});
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
  const storedRun = db.get(`risk_scan_runs/${run.scanRunId}`);
  assert.equal(storedRun.status, "completed");
  assert.equal(storedRun.latestReportId, report.reportId);
});

test("report replay is idempotent", async () => {
  const db = new FakeFirestore();
  const run = runInput({status: "reporting"});
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
  await port.createReportAndCompleteRun(db, {report});
  const replay = await port.createReportAndCompleteRun(db, {report});
  assert.equal(replay.outcome, "idempotent_success");
});

test("report creation rejects stale channel counts", async () => {
  const db = new FakeFirestore();
  const run = runInput({status: "reporting"});
  await port.createRunBundle(db, {
    run,
    channels: [
      completedChannel(run.scanRunId, "similarDomains"),
      completedChannel(run.scanRunId, "openWeb"),
      completedChannel(run.scanRunId, "marketplaceLimited"),
    ],
  });
  await assert.rejects(() => port.createReportAndCompleteRun(db, {
    report: reportInput(run.scanRunId),
  }), (error) => error.code === "conflict");
});

test("report creation requires reporting status", async () => {
  const db = new FakeFirestore();
  const run = runInput({status: "assessing"});
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
  await assert.rejects(() => port.createReportAndCompleteRun(db, {
    report: reportInput(run.scanRunId),
  }), (error) => error.code === "failed-precondition");
});

test("report conflict does not create a partial report", async () => {
  const db = new FakeFirestore();
  const run = runInput({status: "reporting"});
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
    port.createReportAndCompleteRun(db, {report}));
  assert.equal(db.get(`risk_scan_reports/${report.reportId}`), undefined);
});

test("collection names are frozen and exact", () => {
  assert.deepEqual(port.COLLECTIONS, {
    runs: "risk_scan_runs",
    reports: "risk_scan_reports",
    channels: "channels",
    observations: "observations",
    findings: "findings",
  });
  assert.equal(Object.isFrozen(port.COLLECTIONS), true);
});
