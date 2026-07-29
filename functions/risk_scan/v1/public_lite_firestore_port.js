"use strict";

const {
  channelCodes,
  assertDocumentId,
  assertIsoTimestamp,
  assertPlainObject,
} = require("./contracts");
const {
  sha256Hex,
  timingSafeSha256Equal,
} = require("./canonical");
const {
  buildPublicLiteProjection,
} = require("./public_projection");
const {
  createRateLimitRecord,
  incrementRateLimitRecord,
} = require("./rate_limit_contract");
const {
  buildChannelDocument,
  buildRunDocument,
} = require("./storage_documents");
const {
  parseAccessKey,
  RiskScanPublicLiteError,
} = require("./public_lite_contract");

const {
  assertRateLimitRetentionStorage,
  assertRunRetentionStorage,
  withRateLimitRetentionStorage,
  withRunRetentionStorage,
} = require("./retention_firestore_adapter");
const PUBLIC_COLLECTIONS = Object.freeze({
  runs: "risk_scan_runs",
  reports: "risk_scan_reports",
  rateLimits: "risk_scan_rate_limits",
  channels: "channels",
});

function fail(code, message) {
  throw new RiskScanPublicLiteError(code, message);
}

function assertDb(db) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function runRef(db, scanRunId) {
  return db.collection(PUBLIC_COLLECTIONS.runs)
      .doc(assertDocumentId(scanRunId, "scanRunId"));
}

function channelRefs(rootRef) {
  return channelCodes.map((channelCode) =>
    rootRef.collection(PUBLIC_COLLECTIONS.channels).doc(channelCode));
}

function reportRef(db, reportId) {
  return db.collection(PUBLIC_COLLECTIONS.reports)
      .doc(assertDocumentId(reportId, "reportId"));
}

function rateLimitRef(db, bucketId) {
  return db.collection(PUBLIC_COLLECTIONS.rateLimits)
      .doc(assertDocumentId(bucketId, "bucketId"));
}

function snapshotData(snapshot, label) {
  if (!snapshot.exists) fail("not-found", `${label} was not found`);
  return snapshot.data();
}

function assertStoredRunReplay(existing, expected) {
  assertPlainObject(existing, "existingRun");
  const existingHasRetention =
    existing.retentionContractVersion !== undefined;
  const expectedHasRetention =
    expected.retentionContractVersion !== undefined;
  if (existingHasRetention || expectedHasRetention) {
    assertRunRetentionStorage(existing);
    assertRunRetentionStorage(expected);
  }
  const exactFields = [
    "scanRunId",
    "requestId",
    "requestFingerprintSha256",
    "deduplicationFingerprintSha256",
    "accessSecretDigestSha256",
    "accessSecretAlgorithm",
    "accessTier",
    "identityMode",
  ];
  for (const field of exactFields) {
    if (existing[field] !== expected[field]) {
      fail("conflict", `stored run ${field} conflicts with replay`);
    }
  }
  if (!existing.target ||
      existing.target.targetFingerprintSha256 !==
        expected.target.targetFingerprintSha256) {
    fail("conflict", "stored run target conflicts with replay");
  }
  return existing;
}

function assertStoredChannelScope(channel, scanRunId, channelCode) {
  assertPlainObject(channel, "channel");
  if (channel.scanRunId !== scanRunId ||
      channel.channelCode !== channelCode) {
    fail("conflict", "stored channel scope conflicts with its path");
  }
  return channel;
}

function assertRateLimitScope(existing, expected) {
  const existingHasRetention =
    existing.retentionContractVersion !== undefined;
  const expectedHasRetention =
    expected.retentionContractVersion !== undefined;
  if (existingHasRetention || expectedHasRetention) {
    assertRateLimitRetentionStorage(existing);
    assertRateLimitRetentionStorage(expected);
  }
  const fields = [
    "bucketId",
    "appId",
    "ipHashSha256",
    "anonymousClientNonceDigestSha256",
    "windowCode",
    "windowStartedAt",
    "purgeAt",
    "limit",
  ];
  for (const field of fields) {
    if (existing[field] !== expected[field]) {
      fail("conflict", `rate-limit ${field} conflicts with stored data`);
    }
  }
  return existing;
}

async function createPublicLiteRun(db, command) {
  assertDb(db);
  assertPlainObject(command, "command");
  const run = withRunRetentionStorage(
      buildRunDocument(command.run));
  const channels = command.channels.map(buildChannelDocument);
  if (channels.length !== channelCodes.length ||
      new Set(channels.map((item) => item.channelCode)).size !==
        channelCodes.length) {
    throw new TypeError("command must contain every V1 channel once");
  }
  if (!Array.isArray(command.rateLimitRecords) ||
      command.rateLimitRecords.length !== 2) {
    throw new TypeError("command must contain two rate-limit records");
  }
  const rateLimitCandidates = command.rateLimitRecords
      .map((input) => withRateLimitRetentionStorage(
          createRateLimitRecord(input)));
  if (new Set(rateLimitCandidates.map((item) => item.bucketId)).size !== 2) {
    throw new TypeError("rate-limit bucket ids must be unique");
  }
  const rootRef = runRef(db, run.scanRunId);
  const childRefs = channelRefs(rootRef);
  const bucketRefs = rateLimitCandidates.map((item) =>
    rateLimitRef(db, item.bucketId));

  return db.runTransaction(async (transaction) => {
    const rootSnapshot = await transaction.get(rootRef);
    const childSnapshots = [];
    for (const ref of childRefs) {
      childSnapshots.push(await transaction.get(ref));
    }
    const bucketSnapshots = [];
    for (const ref of bucketRefs) {
      bucketSnapshots.push(await transaction.get(ref));
    }

    const existence = [
      rootSnapshot.exists,
      ...childSnapshots.map((snapshot) => snapshot.exists),
    ];
    if (existence.every(Boolean)) {
      const storedRun = assertStoredRunReplay(rootSnapshot.data(), run);
      childSnapshots.forEach((snapshot, index) =>
        assertStoredChannelScope(
            snapshot.data(), run.scanRunId, channelCodes[index]));
      return {
        outcome: "idempotent_success",
        run: storedRun,
        channels: childSnapshots.map((snapshot) => snapshot.data()),
      };
    }
    if (existence.some(Boolean)) {
      fail("conflict", "partial public-lite run bundle already exists");
    }

    const rateLimitWrites = bucketSnapshots.map((snapshot, index) => {
      const candidate = rateLimitCandidates[index];
      if (!snapshot.exists) {
        return {kind: "create", value: candidate};
      }
      const existing = assertRateLimitScope(snapshot.data(), candidate);
      return {
        kind: "update",
        value: incrementRateLimitRecord(
            existing, command.rateLimitRecords[index].now),
      };
    });
    rateLimitWrites.forEach((write, index) => {
      if (write.kind === "create") {
        transaction.create(bucketRefs[index], write.value);
      } else {
        transaction.update(bucketRefs[index], write.value);
      }
    });

    transaction.create(rootRef, run);
    childRefs.forEach((ref, index) =>
      transaction.create(ref, channels[index]));
    return {outcome: "created", run, channels};
  });
}

function assertPublicLiteAccess(run, accessSecret, now) {
  assertRunRetentionStorage(run);
  if (run.accessTier !== "publicLite" || run.identityMode !== "anonymous" ||
      run.accessSecretAlgorithm !== "sha256") {
    fail("not-found", "Tarama bulunamadı veya erişim anahtarı geçersiz.");
  }
  const suppliedDigest = sha256Hex(accessSecret);
  if (!timingSafeSha256Equal(
      suppliedDigest, run.accessSecretDigestSha256)) {
    fail("not-found", "Tarama bulunamadı veya erişim anahtarı geçersiz.");
  }
  const normalizedNow = assertIsoTimestamp(now, "now");
  if (Date.parse(run.expiresAt) <= Date.parse(normalizedNow)) {
    fail("failed-precondition", "Tarama erişim süresi doldu.");
  }
  return run;
}

async function loadAuthorizedBundle(db, {accessKey, now}) {
  assertDb(db);
  const parsed = parseAccessKey(accessKey);
  const rootRef = runRef(db, parsed.scanRunId);
  const rootSnapshot = await rootRef.get();
  if (!rootSnapshot.exists) {
    fail("not-found", "Tarama bulunamadı veya erişim anahtarı geçersiz.");
  }
  const run = assertPublicLiteAccess(
      rootSnapshot.data(), parsed.accessSecret, now);
  const refs = channelRefs(rootRef);
  const snapshots = await Promise.all(refs.map((ref) => ref.get()));
  if (snapshots.some((snapshot) => !snapshot.exists)) {
    fail("conflict", "Tarama kanal kayıtları eksik.");
  }
  const channels = snapshots.map((snapshot, index) =>
    assertStoredChannelScope(
        snapshot.data(), run.scanRunId, channelCodes[index]));
  return {run, channels};
}

async function getPublicLiteStatus(db, input) {
  const bundle = await loadAuthorizedBundle(db, input);
  return buildPublicLiteProjection({...bundle, report: null});
}

async function getPublicLiteReport(db, input) {
  const bundle = await loadAuthorizedBundle(db, input);
  if (!["completed", "completedWithLimits"].includes(bundle.run.status) ||
      !bundle.run.latestReportId) {
    fail("failed-precondition", "Tarama raporu henüz hazır değil.");
  }
  const snapshot = await reportRef(db, bundle.run.latestReportId).get();
  const report = snapshotData(snapshot, "report");
  if (report.scanRunId !== bundle.run.scanRunId ||
      report.reportId !== bundle.run.latestReportId ||
      report.immutable !== true) {
    fail("conflict", "Tarama raporu run kapsamıyla uyuşmuyor.");
  }
  return buildPublicLiteProjection({...bundle, report});
}

module.exports = {
  PUBLIC_COLLECTIONS,
  assertPublicLiteAccess,
  assertRateLimitScope,
  assertStoredChannelScope,
  assertStoredRunReplay,
  createPublicLiteRun,
  getPublicLiteReport,
  getPublicLiteStatus,
  loadAuthorizedBundle,
};
