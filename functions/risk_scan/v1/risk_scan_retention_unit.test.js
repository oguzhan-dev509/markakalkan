"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const retention = require("./retention_contract");

const expiredAt = "2026-07-29T15:00:00.000Z";
const exactNow = "2026-07-29T15:00:00.000Z";
const laterNow = "2026-07-29T16:00:00.000Z";

function timestampFactory() {
  return {
    fromDate(date) {
      const milliseconds = date.getTime();
      return Object.freeze({
        seconds: Math.floor(milliseconds / 1000),
        nanoseconds: (milliseconds % 1000) * 1000000,
        toDate() {
          return new Date(milliseconds);
        },
      });
    },
  };
}

function run(overrides = {}) {
  return {
    scanRunId: "run-1",
    status: "completed",
    expiresAt: expiredAt,
    untouched: "preserve",
    ...overrides,
  };
}

function plan(overrides = {}) {
  return retention.buildRunRecursiveCleanupPlan({
    run: run(),
    now: laterNow,
    ...overrides,
  });
}

test("retention contract version is stable", () => {
  assert.equal(
      retention.RETENTION_CONTRACT_VERSION_V1,
      "risk-scan-retention-v1");
});

test("retention policies are frozen", () => {
  assert.equal(Object.isFrozen(retention.retentionPolicies), true);
  assert.equal(Object.isFrozen(retention.retentionPolicies.runs), true);
});

test("retention policy matrix is exact", () => {
  assert.deepEqual(retention.retentionPolicies, {
    rateLimits: {
      collectionGroup: "risk_scan_rate_limits",
      isoField: "purgeAt",
      timestampField: "purgeAtTimestamp",
      nativeTtlEligible: true,
      cleanupStrategy: "nativeTtlCandidate",
    },
    runs: {
      collectionGroup: "risk_scan_runs",
      isoField: "expiresAt",
      timestampField: "expiresAtTimestamp",
      nativeTtlEligible: false,
      cleanupStrategy: "recursiveServerSide",
    },
    reports: {
      collectionGroup: "risk_scan_reports",
      nativeTtlEligible: false,
      cleanupStrategy: "retentionPolicyDeferred",
    },
    claims: {
      collectionGroup: "risk_scan_claims",
      nativeTtlEligible: false,
      cleanupStrategy: "retentionPolicyDeferred",
    },
  });
});

test("terminal cleanup statuses are frozen", () => {
  assert.equal(Object.isFrozen(retention.terminalCleanupStatuses), true);
});

test("terminal cleanup statuses are exact", () => {
  assert.deepEqual(retention.terminalCleanupStatuses, [
    "completed",
    "completedWithLimits",
    "failedTerminal",
    "cancelled",
    "expired",
  ]);
});

test("run descendant collections are frozen and exact", () => {
  assert.equal(Object.isFrozen(retention.runDescendantCollections), true);
  assert.deepEqual(retention.runDescendantCollections, [
    "findings",
    "observations",
    "channels",
  ]);
});

test("cleanup step codes are frozen and exact", () => {
  assert.equal(Object.isFrozen(retention.cleanupStepCodes), true);
  assert.deepEqual(retention.cleanupStepCodes, [
    "deleteFindings",
    "deleteObservations",
    "deleteChannels",
    "deleteRunRoot",
  ]);
});

test("timestamp factory accepts a compatible adapter", () => {
  assert.equal(
      typeof retention.assertTimestampFactory(timestampFactory()).fromDate,
      "function");
});

test("timestamp factory rejects a missing adapter", () => {
  assert.throws(() => retention.assertTimestampFactory({}));
});

test("ISO timestamp converts to a Firestore-compatible timestamp", () => {
  const value = retention.isoToFirestoreTimestamp(
      expiredAt, "expiredAt", timestampFactory());
  assert.equal(value.toDate().toISOString(), expiredAt);
});

test("timestamp conversion rejects a date-only value", () => {
  assert.throws(() => retention.isoToFirestoreTimestamp(
      "2026-07-29", "expiredAt", timestampFactory()));
});

test("timestamp conversion rejects a null result", () => {
  assert.throws(() => retention.isoToFirestoreTimestamp(
      expiredAt,
      "expiredAt",
      {fromDate() {
        return null;
      }}));
});

test("timestamp conversion rejects a missing toDate method", () => {
  assert.throws(() => retention.isoToFirestoreTimestamp(
      expiredAt,
      "expiredAt",
      {fromDate() {
        return {};
      }}));
});

test("timestamp conversion rejects a round-trip mismatch", () => {
  assert.throws(() => retention.isoToFirestoreTimestamp(
      expiredAt,
      "expiredAt",
      {fromDate() {
        return {
          toDate() {
            return new Date("2026-07-29T15:00:01.000Z");
          },
        };
      }}));
});

test("rate-limit retention fields are exact", () => {
  const value = retention.buildRateLimitRetentionFields(
      {purgeAt: expiredAt},
      timestampFactory());
  assert.equal(value.retentionContractVersion, "risk-scan-retention-v1");
  assert.equal(value.purgeAt, expiredAt);
  assert.equal(value.purgeAtTimestamp.toDate().toISOString(), expiredAt);
  assert.equal(value.nativeTtlEligible, true);
  assert.equal(value.ttlCollectionGroup, "risk_scan_rate_limits");
  assert.equal(value.ttlField, "purgeAtTimestamp");
});

test("rate-limit retention fields are deeply frozen", () => {
  const value = retention.buildRateLimitRetentionFields(
      {purgeAt: expiredAt},
      timestampFactory());
  assert.equal(Object.isFrozen(value), true);
  assert.equal(Object.isFrozen(value.purgeAtTimestamp), true);
});

test("rate-limit retention rejects extra keys", () => {
  assert.throws(() => retention.buildRateLimitRetentionFields(
      {purgeAt: expiredAt, rawIp: "127.0.0.1"},
      timestampFactory()));
});

test("run retention fields are exact", () => {
  const value = retention.buildRunRetentionFields(
      {expiresAt: expiredAt},
      timestampFactory());
  assert.equal(value.retentionContractVersion, "risk-scan-retention-v1");
  assert.equal(value.expiresAt, expiredAt);
  assert.equal(value.expiresAtTimestamp.toDate().toISOString(), expiredAt);
  assert.equal(value.nativeTtlEligible, false);
  assert.equal(value.cleanupStrategy, "recursiveServerSide");
});

test("run retention fields never mark native TTL eligible", () => {
  assert.equal(
      retention.buildRunRetentionFields(
          {expiresAt: expiredAt},
          timestampFactory()).nativeTtlEligible,
      false);
});

test("run retention rejects extra keys", () => {
  assert.throws(() => retention.buildRunRetentionFields(
      {expiresAt: expiredAt, nativeTtlEligible: true},
      timestampFactory()));
});

for (const status of [
  "completed",
  "completedWithLimits",
  "failedTerminal",
  "cancelled",
  "expired",
]) {
  test(`${status} run is a cleanup candidate`, () => {
    const value = retention.assertCleanupCandidate(
        run({status}),
        {now: exactNow});
    assert.equal(value.status, status);
  });
}

test("created run is not a cleanup candidate", () => {
  assert.throws(
      () => retention.assertCleanupCandidate(
          run({status: "created"}),
          {now: laterNow}),
      (error) => error.code === "failed-precondition");
});

test("failedRetryable run is not a cleanup candidate", () => {
  assert.throws(
      () => retention.assertCleanupCandidate(
          run({status: "failedRetryable"}),
          {now: laterNow}),
      (error) => error.code === "failed-precondition");
});

test("cleanup candidate rejects time before expiry", () => {
  assert.throws(
      () => retention.assertCleanupCandidate(
          run(),
          {now: "2026-07-29T14:59:59.999Z"}),
      (error) => error.code === "failed-precondition");
});

test("cleanup candidate accepts the exact expiry instant", () => {
  const value = retention.assertCleanupCandidate(
      run(),
      {now: exactNow});
  assert.equal(value.eligibleAt, expiredAt);
});

test("cleanup grace period delays eligibility", () => {
  assert.throws(
      () => retention.assertCleanupCandidate(
          run(),
          {now: laterNow, minimumGraceSeconds: 3601}),
      (error) => error.code === "failed-precondition");
});

test("cleanup grace period exposes eligibleAt", () => {
  const value = retention.assertCleanupCandidate(
      run(),
      {now: laterNow, minimumGraceSeconds: 3600});
  assert.equal(value.eligibleAt, laterNow);
});

test("cleanup grace period rejects a negative value", () => {
  assert.throws(() => retention.assertCleanupCandidate(
      run(),
      {now: laterNow, minimumGraceSeconds: -1}));
});

test("cleanup grace period rejects more than thirty days", () => {
  assert.throws(() => retention.assertCleanupCandidate(
      run(),
      {
        now: "2026-09-01T15:00:00.000Z",
        minimumGraceSeconds: retention.MAX_GRACE_SECONDS + 1,
      }));
});

test("cleanup options reject extra keys", () => {
  assert.throws(() => retention.assertCleanupCandidate(
      run(),
      {now: laterNow, force: true}));
});

test("cleanup plan uses the default batch size", () => {
  assert.equal(plan().batchSize, 200);
});

test("cleanup plan accepts the maximum batch size", () => {
  assert.equal(plan({batchSize: 500}).batchSize, 500);
});

test("cleanup plan rejects a zero batch size", () => {
  assert.throws(() => plan({batchSize: 0}));
});

test("cleanup plan rejects a batch size over the maximum", () => {
  assert.throws(() => plan({batchSize: 501}));
});

test("cleanup plan paths and order are exact", () => {
  assert.deepEqual(plan().steps, [
    {
      stepCode: "deleteFindings",
      operation: "deleteCollection",
      path: "risk_scan_runs/run-1/findings",
    },
    {
      stepCode: "deleteObservations",
      operation: "deleteCollection",
      path: "risk_scan_runs/run-1/observations",
    },
    {
      stepCode: "deleteChannels",
      operation: "deleteCollection",
      path: "risk_scan_runs/run-1/channels",
    },
    {
      stepCode: "deleteRunRoot",
      operation: "deleteDocument",
      path: "risk_scan_runs/run-1",
    },
  ]);
});

test("cleanup plan defers reports and claims", () => {
  assert.deepEqual(plan().deferredTopLevelCollections, [
    "risk_scan_reports",
    "risk_scan_claims",
  ]);
});

test("cleanup plan never enables native run TTL", () => {
  assert.equal(plan().nativeRunTtlEligible, false);
  assert.equal(plan().cleanupStrategy, "recursiveServerSide");
});

test("cleanup plan does not persist evaluation time", () => {
  assert.equal(Object.hasOwn(plan(), "now"), false);
});

test("cleanup plan digest is stable", () => {
  assert.equal(
      plan().cleanupPlanDigestSha256,
      plan().cleanupPlanDigestSha256);
});

test("cleanup plan digest changes with run identity", () => {
  const other = retention.buildRunRecursiveCleanupPlan({
    run: run({scanRunId: "run-2"}),
    now: laterNow,
  });
  assert.notEqual(
      plan().cleanupPlanDigestSha256,
      other.cleanupPlanDigestSha256);
});

test("cleanup plan is deeply frozen", () => {
  const value = plan();
  assert.equal(Object.isFrozen(value), true);
  assert.equal(Object.isFrozen(value.steps), true);
  assert.equal(Object.isFrozen(value.steps[0]), true);
  assert.equal(Object.isFrozen(value.deferredTopLevelCollections), true);
});

test("cleanup plan rejects extra command keys", () => {
  assert.throws(() => retention.buildRunRecursiveCleanupPlan({
    run: run(),
    now: laterNow,
    force: true,
  }));
});

test("cleanup plan rejects an invalid run id", () => {
  assert.throws(() => retention.buildRunRecursiveCleanupPlan({
    run: run({scanRunId: "bad/id"}),
    now: laterNow,
  }));
});

test("cleanup progress starts with findings", () => {
  const progress = retention.assertCleanupProgress(plan(), []);
  assert.equal(progress.nextStepCode, "deleteFindings");
  assert.equal(progress.complete, false);
});

test("cleanup progress advances in exact order", () => {
  const progress = retention.assertCleanupProgress(
      plan(),
      ["deleteFindings", "deleteObservations"]);
  assert.equal(progress.nextStepCode, "deleteChannels");
});

test("cleanup progress rejects duplicates", () => {
  assert.throws(() => retention.assertCleanupProgress(
      plan(),
      ["deleteFindings", "deleteFindings"]));
});

test("cleanup progress rejects out-of-order steps", () => {
  assert.throws(() => retention.assertCleanupProgress(
      plan(),
      ["deleteObservations"]));
});

test("cleanup progress is complete after root deletion", () => {
  const progress = retention.assertCleanupProgress(
      plan(),
      [...retention.cleanupStepCodes]);
  assert.equal(progress.nextStepCode, null);
  assert.equal(progress.complete, true);
});

test("cleanup progress output is frozen", () => {
  const progress = retention.assertCleanupProgress(plan(), []);
  assert.equal(Object.isFrozen(progress), true);
  assert.equal(Object.isFrozen(progress.completedStepCodes), true);
});

test("cleanup plan replay accepts the same digest", () => {
  assert.equal(
      retention.assertCleanupPlanReplay(plan(), plan()),
      true);
});

test("cleanup plan replay rejects a different digest", () => {
  const changed = plan({batchSize: 100});
  assert.throws(
      () => retention.assertCleanupPlanReplay(plan(), changed),
      (error) => error.code === "conflict");
});

test("cleanup planning does not mutate the run input", () => {
  const input = run();
  const before = structuredClone(input);
  retention.buildRunRecursiveCleanupPlan({
    run: input,
    now: laterNow,
  });
  assert.deepEqual(input, before);
});
