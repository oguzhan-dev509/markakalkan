"use strict";

const {
  channelCodes,
  assertDocumentId,
  assertIsoTimestamp,
} = require("./contracts");
const {
  assertChannelTransition,
  assertRunTransition,
} = require("./lifecycle");
const {
  assertNonNegativeInteger,
  assertReplayMatch,
  buildChannelDocument,
  buildFindingDocument,
  buildObservationDocument,
  buildReportDocument,
  buildRunDocument,
  withStorageFingerprint,
} = require("./storage_documents");

const {
  assertRunRetentionStorage,
  withRunRetentionStorage,
} = require("./retention_firestore_adapter");
const COLLECTIONS = Object.freeze({
  runs: "risk_scan_runs",
  reports: "risk_scan_reports",
  channels: "channels",
  observations: "observations",
  findings: "findings",
});

class RiskScanStorageError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "RiskScanStorageError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new RiskScanStorageError(code, message);
}

function assertDb(db) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function runRef(db, scanRunId) {
  return db.collection(COLLECTIONS.runs)
      .doc(assertDocumentId(scanRunId, "scanRunId"));
}

function channelRef(runDocumentRef, channelCode) {
  return runDocumentRef.collection(COLLECTIONS.channels).doc(channelCode);
}

function observationRef(runDocumentRef, observationId) {
  return runDocumentRef.collection(COLLECTIONS.observations)
      .doc(assertDocumentId(observationId, "observationId"));
}

function findingRef(runDocumentRef, findingId) {
  return runDocumentRef.collection(COLLECTIONS.findings)
      .doc(assertDocumentId(findingId, "findingId"));
}

function reportRef(db, reportId) {
  return db.collection(COLLECTIONS.reports)
      .doc(assertDocumentId(reportId, "reportId"));
}

function assertExactChannelSet(channels) {
  if (!Array.isArray(channels)) {
    throw new TypeError("channels must be an array");
  }
  const actual = channels.map((item) => item.channelCode).sort();
  const expected = [...channelCodes].sort();
  if (actual.length !== expected.length ||
      actual.some((value, index) => value !== expected[index])) {
    throw new TypeError(
        "run bundle must contain every V1 channel exactly once");
  }
  return channels;
}

function snapshotData(snapshot, label) {
  if (!snapshot.exists) fail("not-found", `${label} was not found`);
  return snapshot.data();
}

function assertRunScope(run, scanRunId) {
  assertRunRetentionStorage(run);
  if (run.scanRunId !== scanRunId) {
    fail("conflict", "stored run identity does not match its path");
  }
  return run;
}

function assertChannelScope(channel, scanRunId, channelCode) {
  if (channel.scanRunId !== scanRunId ||
      channel.channelCode !== channelCode) {
    fail("conflict", "stored channel scope does not match its path");
  }
  return channel;
}

function updatedDocument(existing, patch) {
  return withStorageFingerprint({...existing, ...patch});
}

async function createRunBundle(db, input) {
  assertDb(db);
  const run = withRunRetentionStorage(
      buildRunDocument(input.run));
  const channels = assertExactChannelSet(input.channels)
      .map(buildChannelDocument);
  for (const channel of channels) {
    if (channel.scanRunId !== run.scanRunId) {
      throw new TypeError("channel scanRunId does not match run");
    }
  }

  const rootRef = runRef(db, run.scanRunId);
  const channelRefs = channels.map((item) =>
    channelRef(rootRef, item.channelCode));

  return db.runTransaction(async (transaction) => {
    const runSnapshot = await transaction.get(rootRef);
    const channelSnapshots = [];
    for (const ref of channelRefs) {
      channelSnapshots.push(await transaction.get(ref));
    }

    const existence = [
      runSnapshot.exists,
      ...channelSnapshots.map((snapshot) => snapshot.exists),
    ];
    if (existence.every(Boolean)) {
      const storedRun = assertRunScope(
          runSnapshot.data(), run.scanRunId);
      assertReplayMatch(storedRun, run, "run");
      channelSnapshots.forEach((snapshot, index) =>
        assertReplayMatch(
            snapshot.data(), channels[index], `channel[${index}]`));
      return {
        outcome: "idempotent_success",
        scanRunId: run.scanRunId,
      };
    }
    if (existence.some(Boolean)) {
      fail("conflict", "partial run bundle already exists");
    }

    transaction.create(rootRef, run);
    channelRefs.forEach((ref, index) =>
      transaction.create(ref, channels[index]));
    return {outcome: "created", scanRunId: run.scanRunId};
  });
}

async function transitionRun(db, {
  scanRunId,
  expectedStatus,
  nextStatus,
  updatedAt,
  coverageStatus,
}) {
  assertDb(db);
  const rootRef = runRef(db, scanRunId);
  const normalizedUpdatedAt = assertIsoTimestamp(updatedAt, "updatedAt");

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rootRef);
    const existing = assertRunScope(
        snapshotData(snapshot, "run"), scanRunId);

    if (existing.status === nextStatus) {
      return {outcome: "idempotent_success", scanRunId};
    }
    if (existing.status !== expectedStatus) {
      fail("conflict", "run status no longer matches expectedStatus");
    }
    assertRunTransition(existing.status, nextStatus);

    const patch = {status: nextStatus, updatedAt: normalizedUpdatedAt};
    if (coverageStatus !== undefined) {
      patch.coverageStatus = coverageStatus;
    }
    const updated = updatedDocument(existing, patch);
    transaction.update(rootRef, updated);
    return {outcome: "updated", scanRunId, status: nextStatus};
  });
}

async function transitionChannel(db, {
  scanRunId,
  channelCode,
  expectedStatus,
  nextStatus,
  updatedAt,
  startedAt,
  completedAt,
  coverageStatus,
  limitReasonCodes,
  attemptCount,
}) {
  assertDb(db);
  const rootRef = runRef(db, scanRunId);
  const targetRef = channelRef(rootRef, channelCode);
  const normalizedUpdatedAt = assertIsoTimestamp(updatedAt, "updatedAt");

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(targetRef);
    const existing = assertChannelScope(
        snapshotData(snapshot, "channel"), scanRunId, channelCode);

    if (existing.status === nextStatus) {
      return {
        outcome: "idempotent_success",
        scanRunId,
        channelCode,
      };
    }
    if (existing.status !== expectedStatus) {
      fail("conflict", "channel status no longer matches expectedStatus");
    }
    assertChannelTransition(existing.status, nextStatus);

    const patch = {status: nextStatus, updatedAt: normalizedUpdatedAt};
    if (startedAt !== undefined) patch.startedAt = startedAt;
    if (completedAt !== undefined) patch.completedAt = completedAt;
    if (coverageStatus !== undefined) patch.coverageStatus = coverageStatus;
    if (limitReasonCodes !== undefined) {
      patch.limitReasonCodes = limitReasonCodes;
    }
    if (attemptCount !== undefined) patch.attemptCount = attemptCount;

    const updated = buildChannelDocument({...existing, ...patch});
    transaction.update(targetRef, updated);
    return {
      outcome: "updated",
      scanRunId,
      channelCode,
      status: nextStatus,
    };
  });
}

async function appendObservation(db, input) {
  assertDb(db);
  const observation = buildObservationDocument(input.observation);
  const rootRef = runRef(db, observation.scanRunId);
  const targetChannelRef = channelRef(rootRef, observation.channelCode);
  const targetObservationRef = observationRef(
      rootRef, observation.observationId);

  return db.runTransaction(async (transaction) => {
    const runSnapshot = await transaction.get(rootRef);
    const channelSnapshot = await transaction.get(targetChannelRef);
    const observationSnapshot = await transaction.get(targetObservationRef);

    const run = assertRunScope(
        snapshotData(runSnapshot, "run"), observation.scanRunId);
    const channel = assertChannelScope(
        snapshotData(channelSnapshot, "channel"),
        observation.scanRunId,
        observation.channelCode);

    if (observationSnapshot.exists) {
      assertReplayMatch(
          observationSnapshot.data(), observation, "observation");
      return {
        outcome: "idempotent_success",
        observationId: observation.observationId,
      };
    }
    if (!["acquiring", "assessing"].includes(run.status) ||
        !["acquiring", "assessing"].includes(channel.status)) {
      fail("failed-precondition",
          "observation append requires an active acquisition state");
    }

    const updatedAt = observation.createdAt;
    const updatedChannel = updatedDocument(channel, {
      observationCount: assertNonNegativeInteger(
          channel.observationCount, "channel.observationCount") + 1,
      updatedAt,
    });
    const updatedRun = updatedDocument(run, {updatedAt});

    transaction.create(targetObservationRef, observation);
    transaction.update(targetChannelRef, updatedChannel);
    transaction.update(rootRef, updatedRun);
    return {
      outcome: "created",
      observationId: observation.observationId,
    };
  });
}

async function appendFinding(db, input) {
  assertDb(db);
  const finding = buildFindingDocument(input.finding);
  const rootRef = runRef(db, finding.scanRunId);
  const targetChannelRef = channelRef(rootRef, finding.channelCode);
  const targetFindingRef = findingRef(rootRef, finding.findingId);
  const observationRefs = finding.observationRefs.map((observationId) =>
    observationRef(rootRef, observationId));

  return db.runTransaction(async (transaction) => {
    const runSnapshot = await transaction.get(rootRef);
    const channelSnapshot = await transaction.get(targetChannelRef);
    const findingSnapshot = await transaction.get(targetFindingRef);
    const observationSnapshots = [];
    for (const ref of observationRefs) {
      observationSnapshots.push(await transaction.get(ref));
    }

    const run = assertRunScope(
        snapshotData(runSnapshot, "run"), finding.scanRunId);
    const channel = assertChannelScope(
        snapshotData(channelSnapshot, "channel"),
        finding.scanRunId,
        finding.channelCode);

    if (findingSnapshot.exists) {
      assertReplayMatch(findingSnapshot.data(), finding, "finding");
      return {
        outcome: "idempotent_success",
        findingId: finding.findingId,
      };
    }
    if (run.status !== "assessing" || channel.status !== "assessing") {
      fail("failed-precondition",
          "finding append requires an assessing state");
    }

    observationSnapshots.forEach((snapshot, index) => {
      const observation = snapshotData(
          snapshot, `observation[${index}]`);
      if (observation.scanRunId !== finding.scanRunId ||
          observation.channelCode !== finding.channelCode ||
          observation.observationId !== finding.observationRefs[index]) {
        fail("conflict", "finding observation scope is invalid");
      }
    });

    const updatedAt = finding.createdAt;
    const updatedChannel = updatedDocument(channel, {
      findingCount: assertNonNegativeInteger(
          channel.findingCount, "channel.findingCount") + 1,
      updatedAt,
    });
    const updatedRun = updatedDocument(run, {updatedAt});

    transaction.create(targetFindingRef, finding);
    transaction.update(targetChannelRef, updatedChannel);
    transaction.update(rootRef, updatedRun);
    return {outcome: "created", findingId: finding.findingId};
  });
}

async function createReportAndCompleteRun(db, input) {
  assertDb(db);
  const report = buildReportDocument(input.report);
  const rootRef = runRef(db, report.scanRunId);
  const targetReportRef = reportRef(db, report.reportId);
  const channelRefs = report.channelDistribution.map((item) =>
    channelRef(rootRef, item.channelCode));

  return db.runTransaction(async (transaction) => {
    const runSnapshot = await transaction.get(rootRef);
    const reportSnapshot = await transaction.get(targetReportRef);
    const channelSnapshots = [];
    for (const ref of channelRefs) {
      channelSnapshots.push(await transaction.get(ref));
    }

    const run = assertRunScope(
        snapshotData(runSnapshot, "run"), report.scanRunId);

    if (reportSnapshot.exists) {
      assertReplayMatch(reportSnapshot.data(), report, "report");
      if (run.latestReportId !== report.reportId ||
          run.status !== report.status) {
        fail("conflict", "report exists without matching run completion");
      }
      return {
        outcome: "idempotent_success",
        reportId: report.reportId,
      };
    }
    if (run.status !== "reporting") {
      fail("failed-precondition",
          "report creation requires run status reporting");
    }

    let observationCount = 0;
    let findingCount = 0;
    channelSnapshots.forEach((snapshot, index) => {
      const expected = report.channelDistribution[index];
      const stored = assertChannelScope(
          snapshotData(snapshot, `channel[${index}]`),
          report.scanRunId,
          expected.channelCode);
      if (stored.status !== expected.status ||
          stored.coverageStatus !== expected.coverageStatus ||
          stored.observationCount !== expected.observationCount ||
          stored.findingCount !== expected.findingCount) {
        fail("conflict", "report channel snapshot is stale");
      }
      observationCount += stored.observationCount;
      findingCount += stored.findingCount;
    });
    if (observationCount !== report.observationCount ||
        findingCount !== report.findingCount) {
      fail("conflict", "report aggregate counts are stale");
    }

    const updatedRun = updatedDocument(run, {
      status: report.status,
      coverageStatus: report.coverageStatus,
      latestReportId: report.reportId,
      updatedAt: report.generatedAt,
    });
    transaction.create(targetReportRef, report);
    transaction.update(rootRef, updatedRun);
    return {outcome: "created", reportId: report.reportId};
  });
}

module.exports = {
  COLLECTIONS,
  RiskScanStorageError,
  appendFinding,
  appendObservation,
  createReportAndCompleteRun,
  createRunBundle,
  transitionChannel,
  transitionRun,
};
