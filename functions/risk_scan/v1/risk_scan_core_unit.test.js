"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const contracts = require("./contracts");
const canonical = require("./canonical");
const identifiers = require("./identifiers");
const lifecycle = require("./lifecycle");
const projection = require("./public_projection");
const rateLimit = require("./rate_limit_contract");

const digestA = "a".repeat(64);
const digestB = "b".repeat(64);
const now = "2026-07-29T15:00:00.000Z";
const later = "2026-07-29T16:00:00.000Z";

function sampleRun(overrides = {}) {
  return {
    scanRunId: "run-1",
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "completed",
    coverageStatus: "complete",
    createdAt: now,
    updatedAt: later,
    expiresAt: "2026-08-05T15:00:00.000Z",
    target: {
      brandNameNormalized: "ornek marka",
      officialHost: "example.com",
    },
    accessSecretDigestSha256: digestA,
    requestFingerprintSha256: digestB,
    ...overrides,
  };
}

function sampleChannel(overrides = {}) {
  return {
    channelCode: "openWeb",
    status: "completed",
    coverageStatus: "complete",
    observationCount: 2,
    findingCount: 1,
    limitReasonCodes: [],
    startedAt: now,
    completedAt: later,
    ...overrides,
  };
}

function sampleFinding(overrides = {}) {
  return {
    findingId: "finding-1",
    findingType: "contentSimilarity",
    channelCode: "openWeb",
    riskLevel: "high",
    confidenceLevel: "medium",
    impactLevel: "high",
    interventionDifficulty: "moderate",
    reviewStatus: "reviewRequired",
    recommendationCode: "reviewFinding",
    title: "  Benzer içerik bulundu  ",
    summary: "İnceleme gerektiren bir eşleşme.",
    sourceUrlCanonical: "https://unsafe.example/path",
    ...overrides,
  };
}

function sampleReport(overrides = {}) {
  return {
    reportId: "report-1",
    reportVersion: "1",
    generatedAt: later,
    status: "completed",
    coverageStatus: "complete",
    overallRiskLevel: "high",
    overallConfidenceLevel: "medium",
    recommendedAction: "reviewTopFindings",
    summary: "Tarama tamamlandı.",
    findingCount: 1,
    observationCount: 2,
    topFindingSnapshots: [sampleFinding()],
    channelDistribution: [sampleChannel()],
    reportDigestSha256: digestA,
    tenantId: "tenant-secret",
    ...overrides,
  };
}

function sampleRateRecord(overrides = {}) {
  return {
    contractVersion: contracts.RATE_LIMIT_CONTRACT_VERSION_V1,
    bucketId: "bucket-1",
    appId: "app-1",
    ipHashSha256: digestA,
    anonymousClientNonceDigestSha256: digestB,
    windowCode: "public-lite-hour",
    windowStartedAt: now,
    purgeAt: later,
    limit: 3,
    count: 1,
    firstRequestAt: now,
    lastRequestAt: now,
    ...overrides,
  };
}

// Contract primitives: 17 tests.
test("contract versions mirror HRT V1", () => {
  assert.equal(contracts.contractVersions.target, "risk-scan-target-v1");
  assert.equal(contracts.contractVersions.claim, "risk-scan-claim-v1");
});

test("enum arrays are frozen", () => {
  assert.equal(Object.isFrozen(contracts.runStatuses), true);
  assert.throws(() => contracts.runStatuses.push("other"));
});

test("isPlainObject accepts object literals", () => {
  assert.equal(contracts.isPlainObject({a: 1}), true);
});

test("assertPlainObject rejects arrays", () => {
  assert.throws(() => contracts.assertPlainObject([], "value"));
});

test("assertEnum accepts a known value", () => {
  assert.equal(
      contracts.assertEnum("quick", contracts.scanModes, "scanMode"),
      "quick");
});

test("assertEnum rejects an unknown value", () => {
  assert.throws(() =>
    contracts.assertEnum("deep", contracts.scanModes, "scanMode"));
});

test("assertNonEmptyString trims input", () => {
  assert.equal(contracts.assertNonEmptyString("  value  ", "x"), "value");
});

test("assertNonEmptyString rejects blank input", () => {
  assert.throws(() => contracts.assertNonEmptyString("  ", "x"));
});

test("assertOptionalString accepts null", () => {
  assert.equal(contracts.assertOptionalString(null, "x"), null);
});

test("assertIsoTimestamp accepts ISO timestamps", () => {
  assert.equal(contracts.assertIsoTimestamp(now, "now"), now);
});

test("assertIsoTimestamp rejects date-only strings", () => {
  assert.throws(() => contracts.assertIsoTimestamp("2026-07-29", "now"));
});

test("assertSha256Hex accepts lowercase digest", () => {
  assert.equal(contracts.assertSha256Hex(digestA, "digest"), digestA);
});

test("assertSha256Hex rejects uppercase digest", () => {
  assert.throws(() =>
    contracts.assertSha256Hex("A".repeat(64), "digest"));
});

test("assertDocumentId accepts a safe id", () => {
  assert.equal(contracts.assertDocumentId("abc-123", "id"), "abc-123");
});

test("assertDocumentId rejects path separators", () => {
  assert.throws(() => contracts.assertDocumentId("a/b", "id"));
});

test("assertExactKeys accepts an allowlisted object", () => {
  assert.deepEqual(
      contracts.assertExactKeys({a: 1}, ["a"], "value"), {a: 1});
});

test("assertExactKeys rejects additional keys", () => {
  assert.throws(() =>
    contracts.assertExactKeys({a: 1, b: 2}, ["a"], "value"));
});

// Canonical and digest behavior: 15 tests.
test("canonicalJson sorts object keys", () => {
  assert.equal(canonical.canonicalJson({b: 2, a: 1}), "{\"a\":1,\"b\":2}");
});

test("canonicalJson sorts nested object keys", () => {
  assert.equal(
      canonical.canonicalJson({z: {b: 2, a: 1}}),
      "{\"z\":{\"a\":1,\"b\":2}}");
});

test("canonicalJson preserves array order", () => {
  assert.equal(canonical.canonicalJson([2, 1]), "[2,1]");
});

test("canonicalJson normalizes negative zero", () => {
  assert.equal(canonical.canonicalJson({value: -0}), "{\"value\":0}");
});

test("canonicalJson rejects non-finite numbers", () => {
  assert.throws(() => canonical.canonicalJson({value: Number.NaN}));
});

test("canonicalJson rejects undefined values", () => {
  assert.throws(() => canonical.canonicalJson({value: undefined}));
});

test("sha256Hex matches a known vector", () => {
  assert.equal(
      canonical.sha256Hex("abc"),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("canonical digest is key-order stable", () => {
  assert.equal(
      canonical.canonicalJsonDigestSha256({a: 1, b: 2}),
      canonical.canonicalJsonDigestSha256({b: 2, a: 1}));
});

test("canonical digest changes with payload", () => {
  assert.notEqual(
      canonical.canonicalJsonDigestSha256({a: 1}),
      canonical.canonicalJsonDigestSha256({a: 2}));
});

test("length-prefixed encoding uses UTF-8 byte length", () => {
  assert.equal(canonical.encodeLengthPrefixed(["ü"]), "2:ü");
});

test("length-prefixed encoding rejects non-string parts", () => {
  assert.throws(() => canonical.encodeLengthPrefixed([1]));
});

test("length-prefixed digest is deterministic", () => {
  assert.equal(
      canonical.lengthPrefixedDigestSha256("x", ["a", "b"]),
      canonical.lengthPrefixedDigestSha256("x", ["a", "b"]));
});

test("length-prefixed digest is namespace-sensitive", () => {
  assert.notEqual(
      canonical.lengthPrefixedDigestSha256("x", ["a"]),
      canonical.lengthPrefixedDigestSha256("y", ["a"]));
});

test("timingSafeSha256Equal accepts equal digests", () => {
  assert.equal(canonical.timingSafeSha256Equal(digestA, digestA), true);
});

test("timingSafeSha256Equal rejects malformed digests", () => {
  assert.equal(canonical.timingSafeSha256Equal("bad", digestA), false);
});

// Deterministic identifiers: 10 tests.
test("deriveId is deterministic", () => {
  assert.equal(
      identifiers.deriveId("namespace", ["a"]),
      identifiers.deriveId("namespace", ["a"]));
});

test("riskScanRunId returns lowercase SHA-256", () => {
  assert.match(
      identifiers.riskScanRunId({
        requestId: "request-1",
        requestFingerprintSha256: digestA,
      }), /^[a-f0-9]{64}$/);
});

test("riskScanRunId validates the request fingerprint", () => {
  assert.throws(() => identifiers.riskScanRunId({
    requestId: "request-1",
    requestFingerprintSha256: "bad",
  }));
});

test("observation id changes with source URL", () => {
  const base = {
    scanRunId: "run-1",
    channelCode: "openWeb",
    contentFingerprintSha256: digestA,
  };
  assert.notEqual(
      identifiers.riskScanObservationId({
        ...base,
        sourceUrlCanonical: "https://a.example",
      }),
      identifiers.riskScanObservationId({
        ...base,
        sourceUrlCanonical: "https://b.example",
      }));
});

test("observation id rejects an unknown channel", () => {
  assert.throws(() => identifiers.riskScanObservationId({
    scanRunId: "run-1",
    channelCode: "unknown",
    sourceUrlCanonical: "https://a.example",
    contentFingerprintSha256: digestA,
  }));
});

test("finding id sorts and deduplicates observation refs", () => {
  const left = identifiers.riskScanFindingId({
    scanRunId: "run-1",
    findingType: "similarDomain",
    observationRefs: ["b", "a", "a"],
  });
  const right = identifiers.riskScanFindingId({
    scanRunId: "run-1",
    findingType: "similarDomain",
    observationRefs: ["a", "b"],
  });
  assert.equal(left, right);
});

test("finding id changes with finding type", () => {
  const base = {scanRunId: "run-1", observationRefs: ["a"]};
  assert.notEqual(
      identifiers.riskScanFindingId({
        ...base,
        findingType: "similarDomain",
      }),
      identifiers.riskScanFindingId({
        ...base,
        findingType: "contentSimilarity",
      }));
});

test("report id changes with report version", () => {
  assert.notEqual(
      identifiers.riskScanReportId({scanRunId: "run-1", reportVersion: "1"}),
      identifiers.riskScanReportId({scanRunId: "run-1", reportVersion: "2"}));
});

test("claim id changes with request id", () => {
  assert.notEqual(
      identifiers.riskScanClaimId({scanRunId: "run-1", requestId: "a"}),
      identifiers.riskScanClaimId({scanRunId: "run-1", requestId: "b"}));
});

test("rate-limit bucket id is deterministic", () => {
  const input = {
    appId: "app-1",
    ipHashSha256: digestA,
    anonymousClientNonceDigestSha256: digestB,
    windowCode: "hour",
  };
  assert.equal(
      identifiers.riskScanRateLimitBucketId(input),
      identifiers.riskScanRateLimitBucketId(input));
});

// Lifecycle boundaries: 22 tests.
test("run transition created to validatingTarget is allowed", () => {
  assert.equal(
      lifecycle.assertRunTransition("created", "validatingTarget"),
      "validatingTarget");
});

test("run transition created to completed is rejected", () => {
  assert.throws(() =>
    lifecycle.assertRunTransition("created", "completed"));
});

test("terminal run status cannot transition", () => {
  assert.throws(() =>
    lifecycle.assertRunTransition("completed", "expired"));
});

test("retryable run may return to queued", () => {
  assert.equal(
      lifecycle.assertRunTransition("failedRetryable", "queued"),
      "queued");
});

test("channel transition queued to acquiring is allowed", () => {
  assert.equal(
      lifecycle.assertChannelTransition("queued", "acquiring"),
      "acquiring");
});

test("terminal channel status cannot transition", () => {
  assert.throws(() =>
    lifecycle.assertChannelTransition("completed", "queued"));
});

test("review transition signal to suspicious is allowed", () => {
  assert.equal(
      lifecycle.assertReviewTransition("signal", "suspicious"),
      "suspicious");
});

test("review transition confirmed to signal is rejected", () => {
  assert.throws(() =>
    lifecycle.assertReviewTransition("confirmed", "signal"));
});

test("automatic scan may produce signal", () => {
  assert.equal(lifecycle.assertAutomaticReviewStatus("signal"), "signal");
});

test("automatic scan cannot produce confirmed", () => {
  assert.throws(() =>
    lifecycle.assertAutomaticReviewStatus("confirmed"));
});

test("claim transition issued to claimed is allowed", () => {
  assert.equal(
      lifecycle.assertClaimTransition("issued", "claimed"), "claimed");
});

test("terminal claim status cannot transition", () => {
  assert.throws(() =>
    lifecycle.assertClaimTransition("claimed", "revoked"));
});

test("immutable records require true", () => {
  const record = {immutable: true};
  assert.equal(lifecycle.assertImmutableRecord(record, "report"), record);
});

test("mutable records are rejected", () => {
  assert.throws(() =>
    lifecycle.assertImmutableRecord({immutable: false}, "report"));
});

test("anonymous identity accepts null scope", () => {
  const record = {
    identityMode: "anonymous",
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
  };
  assert.equal(lifecycle.assertIdentityScope(record), record);
});

test("anonymous identity rejects resolved fields", () => {
  assert.throws(() => lifecycle.assertIdentityScope({
    identityMode: "anonymous",
    tenantId: "tenant-1",
    canonicalBrandId: null,
    createdByUid: null,
  }));
});

test("resolved identity requires full scope", () => {
  const record = {
    identityMode: "resolved",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    createdByUid: "user-1",
  };
  assert.equal(lifecycle.assertIdentityScope(record), record);
});

test("resolved identity rejects missing owner", () => {
  assert.throws(() => lifecycle.assertIdentityScope({
    identityMode: "resolved",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    createdByUid: null,
  }));
});

test("promotion accepts reviewed resolved finding", () => {
  assert.equal(lifecycle.assertPromotionEligibility({
    identityMode: "resolved",
    reviewStatus: "confirmed",
    reviewedAt: now,
    reviewedByUid: "user-1",
  }), true);
});

test("promotion rejects anonymous identity", () => {
  assert.throws(() => lifecycle.assertPromotionEligibility({
    identityMode: "anonymous",
    reviewStatus: "confirmed",
    reviewedAt: now,
    reviewedByUid: "user-1",
  }));
});

test("promotion rejects non-human review status", () => {
  assert.throws(() => lifecycle.assertPromotionEligibility({
    identityMode: "resolved",
    reviewStatus: "reviewRequired",
    reviewedAt: now,
    reviewedByUid: "user-1",
  }));
});

test("promotion rejects already promoted findings", () => {
  assert.throws(() => lifecycle.assertPromotionEligibility({
    identityMode: "resolved",
    reviewStatus: "suspicious",
    reviewedAt: now,
    reviewedByUid: "user-1",
    promotionStatus: "promoted",
  }));
});

// Public projection: 10 tests.
test("cleanText removes control characters and trims", () => {
  assert.equal(projection.cleanText("  a\n\tb  ", 20), "a b");
});

test("target projection uses an allowlist", () => {
  assert.deepEqual(
      projection.targetProjection({
        brandNameNormalized: "marka",
        officialHost: "example.com",
        officialWebsiteCanonicalUrl: "https://example.com/private",
      }),
      {brandNameNormalized: "marka", officialHost: "example.com"});
});

test("channel projection normalizes counters", () => {
  assert.equal(
      projection.channelProjection(sampleChannel({findingCount: null}))
          .findingCount,
      0);
});

test("finding projection excludes source URLs", () => {
  const output = projection.findingProjection(sampleFinding());
  assert.equal(Object.hasOwn(output, "sourceUrlCanonical"), false);
});

test("report projection excludes report digest", () => {
  const output = projection.reportProjection(sampleReport());
  assert.equal(Object.hasOwn(output, "reportDigestSha256"), false);
});

test("public projection excludes run secrets", () => {
  const output = projection.buildPublicLiteProjection({
    run: sampleRun(),
    channels: [sampleChannel()],
    report: sampleReport(),
  });
  const json = JSON.stringify(output);
  assert.equal(json.includes("accessSecretDigestSha256"), false);
  assert.equal(json.includes("tenant-secret"), false);
});

test("public projection includes safe summary fields", () => {
  const output = projection.buildPublicLiteProjection({
    run: sampleRun(),
    channels: [sampleChannel()],
    report: sampleReport(),
  });
  assert.equal(output.status, "completed");
  assert.equal(output.report.overallRiskLevel, "high");
});

test("sensitive-key guard rejects nested digests", () => {
  assert.throws(() => projection.assertNoSensitiveKeys({
    nested: {claimTokenDigestSha256: digestA},
  }));
});

test("public projection requires a channels array", () => {
  assert.throws(() => projection.buildPublicLiteProjection({
    run: sampleRun(),
    channels: {},
  }));
});

test("public projection caps top finding snapshots", () => {
  const findings = Array.from({length: 25}, (_, index) =>
    sampleFinding({findingId: `finding-${index}`}));
  const output = projection.reportProjection(
      sampleReport({topFindingSnapshots: findings}));
  assert.equal(output.topFindingSnapshots.length, 20);
});

// Rate-limit contract: 10 tests.
test("positive integer validator accepts one", () => {
  assert.equal(rateLimit.assertPositiveInteger(1, "value"), 1);
});

test("positive integer validator rejects zero", () => {
  assert.throws(() => rateLimit.assertPositiveInteger(0, "value"));
});

test("raw network guard rejects IP fields", () => {
  assert.throws(() =>
    rateLimit.assertNoRawNetworkIdentifiers({ip: "127.0.0.1"}));
});

test("rate-limit record starts at one", () => {
  const record = rateLimit.createRateLimitRecord({
    bucketId: "bucket-1",
    appId: "app-1",
    ipHashSha256: digestA,
    anonymousClientNonceDigestSha256: digestB,
    windowCode: "hour",
    windowStartedAt: now,
    purgeAt: later,
    limit: 3,
    now,
  });
  assert.equal(record.count, 1);
});

test("rate-limit record rejects invalid purge ordering", () => {
  assert.throws(() => rateLimit.createRateLimitRecord({
    bucketId: "bucket-1",
    appId: "app-1",
    ipHashSha256: digestA,
    anonymousClientNonceDigestSha256: digestB,
    windowCode: "hour",
    windowStartedAt: later,
    purgeAt: now,
    limit: 3,
    now,
  }));
});

test("rate-limit increment increases count", () => {
  const output = rateLimit.incrementRateLimitRecord(sampleRateRecord(), later);
  assert.equal(output.count, 2);
});

test("rate-limit increment returns resource-exhausted", () => {
  assert.throws(
      () => rateLimit.incrementRateLimitRecord(
          sampleRateRecord({count: 3}), later),
      (error) => error.code === "resource-exhausted");
});

test("rateLimitRemaining never becomes negative", () => {
  assert.equal(rateLimit.rateLimitRemaining(
      sampleRateRecord({count: 3})), 0);
});

test("rate-limit increment does not mutate existing record", () => {
  const existing = sampleRateRecord();
  rateLimit.incrementRateLimitRecord(existing, later);
  assert.equal(existing.count, 1);
});

test("raw network guard rejects client nonce", () => {
  assert.throws(() =>
    rateLimit.assertNoRawNetworkIdentifiers({clientNonce: "raw"}));
});
