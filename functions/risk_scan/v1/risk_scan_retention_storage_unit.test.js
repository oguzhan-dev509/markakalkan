"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {sha256Hex} = require("./canonical");
const {riskScanRunId} = require("./identifiers");
const adapter = require("./retention_firestore_adapter");
const documents = require("./storage_documents");

const createdAt = "2026-07-29T15:00:00.000Z";
const expiresAt = "2026-08-05T15:00:00.000Z";
const purgeAt = "2026-07-29T17:00:00.000Z";

function runInput(overrides = {}) {
  const requestId = "retention-storage-request-1";
  const requestFingerprintSha256 = sha256Hex("retention-storage-payload");
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
      targetFingerprintSha256: sha256Hex("retention-storage-target"),
    },
    requestId,
    requestFingerprintSha256,
    deduplicationFingerprintSha256: sha256Hex("retention-storage-dedupe"),
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt,
    updatedAt: createdAt,
    expiresAt,
    accessSecretDigestSha256: "a".repeat(64),
    accessSecretAlgorithm: "sha256",
    latestReportId: null,
    ...overrides,
  };
}

function rateLimitRecord(overrides = {}) {
  return {
    contractVersion: "risk-scan-rate-limit-v1",
    bucketId: "bucket-1",
    appId: "1:123:web:abc",
    ipHashSha256: "b".repeat(64),
    anonymousClientNonceDigestSha256: "c".repeat(64),
    windowCode: "2026-07-29T16",
    windowStartedAt: "2026-07-29T16:00:00.000Z",
    purgeAt,
    limit: 5,
    count: 1,
    firstRequestAt: "2026-07-29T16:00:00.000Z",
    lastRequestAt: "2026-07-29T16:00:00.000Z",
    ...overrides,
  };
}

test("retention storage derived fields are frozen and exact", () => {
  assert.equal(
      Object.isFrozen(adapter.RETENTION_STORAGE_DERIVED_FIELDS), true);
  assert.deepEqual(adapter.RETENTION_STORAGE_DERIVED_FIELDS, [
    "retentionContractVersion",
    "expiresAtTimestamp",
    "purgeAtTimestamp",
    "nativeTtlEligible",
    "cleanupStrategy",
    "ttlCollectionGroup",
    "ttlField",
  ]);
});

test("timestamp factory returns a date-compatible value", () => {
  const value = adapter.firestoreDateTimestampFactory.fromDate(
      new Date(createdAt));
  assert.equal(value.toDate().toISOString(), createdAt);
});

test("timestampToMillis accepts Date", () => {
  assert.equal(
      adapter.timestampToMillis(new Date(createdAt), "value"),
      Date.parse(createdAt));
});

test("timestampToMillis accepts toDate adapter", () => {
  assert.equal(
      adapter.timestampToMillis({
        toDate() {
          return new Date(createdAt);
        },
      }, "value"),
      Date.parse(createdAt));
});

test("timestampToMillis accepts toMillis adapter", () => {
  assert.equal(
      adapter.timestampToMillis({
        toMillis() {
          return Date.parse(createdAt);
        },
      }, "value"),
      Date.parse(createdAt));
});

test("timestampToMillis accepts Firestore clone fields", () => {
  assert.equal(
      adapter.timestampToMillis({
        _seconds: Math.floor(Date.parse(createdAt) / 1000),
        _nanoseconds: 0,
      }, "value"),
      Date.parse(createdAt));
});

test("timestampToMillis rejects invalid input", () => {
  assert.throws(() => adapter.timestampToMillis({}, "value"));
});

test("timestamp comparison accepts matching values", () => {
  assert.equal(
      adapter.assertTimestampMatchesIso(
          createdAt, new Date(createdAt), "createdAt") instanceof Date,
      true);
});

test("timestamp comparison rejects mismatch", () => {
  assert.throws(() => adapter.assertTimestampMatchesIso(
      createdAt,
      new Date("2026-07-29T15:00:01.000Z"),
      "createdAt"));
});

test("run retention storage preserves ISO expiry", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  assert.equal(run.expiresAt, expiresAt);
});

test("run retention storage writes Date timestamp input", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  assert.equal(run.expiresAtTimestamp instanceof Date, true);
  assert.equal(run.expiresAtTimestamp.toISOString(), expiresAt);
});

test("run retention storage metadata is exact", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  assert.equal(run.retentionContractVersion, "risk-scan-retention-v1");
  assert.equal(run.nativeTtlEligible, false);
  assert.equal(run.cleanupStrategy, "recursiveServerSide");
});

test("run retention assertion accepts integrated record", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  assert.equal(adapter.assertRunRetentionStorage(run), run);
});

test("run retention assertion rejects missing timestamp", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  delete run.expiresAtTimestamp;
  assert.throws(() => adapter.assertRunRetentionStorage(run));
});

test("run retention assertion rejects timestamp mismatch", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  run.expiresAtTimestamp = new Date(createdAt);
  assert.throws(() => adapter.assertRunRetentionStorage(run));
});

test("run retention assertion rejects native TTL enablement", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  run.nativeTtlEligible = true;
  assert.throws(() => adapter.assertRunRetentionStorage(run));
});

test("rate-limit retention storage writes Date timestamp input", () => {
  const record = adapter.withRateLimitRetentionStorage(rateLimitRecord());
  assert.equal(record.purgeAtTimestamp instanceof Date, true);
  assert.equal(record.purgeAtTimestamp.toISOString(), purgeAt);
});

test("rate-limit retention metadata is exact", () => {
  const record = adapter.withRateLimitRetentionStorage(rateLimitRecord());
  assert.equal(record.retentionContractVersion, "risk-scan-retention-v1");
  assert.equal(record.nativeTtlEligible, true);
  assert.equal(record.ttlCollectionGroup, "risk_scan_rate_limits");
  assert.equal(record.ttlField, "purgeAtTimestamp");
});

test("rate-limit retention assertion accepts integrated record", () => {
  const record = adapter.withRateLimitRetentionStorage(rateLimitRecord());
  assert.equal(adapter.assertRateLimitRetentionStorage(record), record);
});

test("rate-limit retention assertion rejects timestamp mismatch", () => {
  const record = adapter.withRateLimitRetentionStorage(rateLimitRecord());
  record.purgeAtTimestamp = new Date(createdAt);
  assert.throws(() => adapter.assertRateLimitRetentionStorage(record));
});

test("rate-limit retention assertion rejects wrong TTL field", () => {
  const record = adapter.withRateLimitRetentionStorage(rateLimitRecord());
  record.ttlField = "purgeAt";
  assert.throws(() => adapter.assertRateLimitRetentionStorage(record));
});

test("split separates derived retention fields", () => {
  const run = adapter.withRunRetentionStorage(
      documents.buildRunDocument(runInput()));
  const split = adapter.splitRetentionStorageFields(run);
  assert.equal(split.fingerprintDocument.expiresAtTimestamp, undefined);
  assert.equal(
      split.retentionStorageFields.expiresAtTimestamp instanceof Date, true);
});

test("fingerprint remains compatible after retention integration", () => {
  const base = documents.buildRunDocument(runInput());
  const integrated = adapter.withRunRetentionStorage(base);
  const refingerprinted = documents.withStorageFingerprint(integrated);
  assert.equal(
      refingerprinted.storageFingerprintSha256,
      base.storageFingerprintSha256);
});

test("fingerprint update preserves retention fields", () => {
  const base = documents.buildRunDocument(runInput());
  const integrated = adapter.withRunRetentionStorage(base);
  const updated = documents.withStorageFingerprint({
    ...integrated,
    status: "validatingTarget",
  });
  assert.equal(updated.expiresAtTimestamp.toISOString(), expiresAt);
  assert.equal(updated.retentionContractVersion, "risk-scan-retention-v1");
  assert.notEqual(
      updated.storageFingerprintSha256,
      base.storageFingerprintSha256);
});
