"use strict";

const {onSchedule} = require("firebase-functions/v2/scheduler");
const firebaseLogger = require("firebase-functions/logger");
const {
  DEFAULT_CLEANUP_BATCH_SIZE,
  MAX_CLEANUP_BATCH_SIZE,
  MAX_GRACE_SECONDS,
  terminalCleanupStatuses,
} = require("./retention_contract");
const {
  assertRunRetentionStorage,
} = require("./retention_firestore_adapter");
const {
  RUNS_COLLECTION,
  executeRunRecursiveCleanupStep,
} = require("./recursive_cleanup_firestore_port");

const SCHEDULED_CLEANUP_CONTRACT_VERSION_V1 =
  "risk-scan-scheduled-cleanup-v1";
const SCHEDULED_CLEANUP_FUNCTION_NAME = "cleanupExpiredRiskScanRuns";
const REGION = "europe-west3";
const SCHEDULE = "every 15 minutes";
const TIME_ZONE = "Etc/UTC";
const DEFAULT_SCAN_LIMIT = 100;
const MAX_SCAN_LIMIT = 500;
const DEFAULT_PROCESS_LIMIT = 25;
const MAX_PROCESS_LIMIT = 100;
const DEFAULT_MINIMUM_GRACE_SECONDS = 0;

function scheduledCleanupOptions() {
  return Object.freeze({
    schedule: SCHEDULE,
    timeZone: TIME_ZONE,
    region: REGION,
    maxInstances: 1,
    concurrency: 1,
    timeoutSeconds: 540,
    memory: "256MiB",
  });
}
function productionClock() {
  return {now: () => new Date()};
}
function assertClock(clock) {
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }
  return clock;
}
function assertLogger(logger) {
  if (!logger ||
      typeof logger.info !== "function" ||
      typeof logger.warn !== "function" ||
      typeof logger.error !== "function") {
    throw new TypeError("logger info, warn, and error functions are required");
  }
  return logger;
}
function assertPositiveInteger(value, label, maximum) {
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new TypeError(`${label} must be between 1 and ${maximum}`);
  }
  return value;
}
function assertMinimumGraceSeconds(value) {
  if (!Number.isInteger(value) || value < 0 || value > MAX_GRACE_SECONDS) {
    throw new TypeError(
        `minimumGraceSeconds must be between 0 and ${MAX_GRACE_SECONDS}`);
  }
  return value;
}
function assertBatchSize(value) {
  return assertPositiveInteger(value, "batchSize", MAX_CLEANUP_BATCH_SIZE);
}
function normalizeNow(value) {
  const date = value instanceof Date ?
    new Date(value.getTime()) : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError("clock.now must return a valid date");
  }
  return date;
}
function buildExpiredRunQuery(db, {
  now,
  minimumGraceSeconds = DEFAULT_MINIMUM_GRACE_SECONDS,
  scanLimit = DEFAULT_SCAN_LIMIT,
} = {}) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("db.collection is required");
  }
  const normalizedNow = normalizeNow(now);
  const graceSeconds = assertMinimumGraceSeconds(minimumGraceSeconds);
  const limit = assertPositiveInteger(scanLimit, "scanLimit", MAX_SCAN_LIMIT);
  const cutoff = new Date(
      normalizedNow.getTime() - (graceSeconds * 1000));
  return {
    cutoff,
    query: db.collection(RUNS_COLLECTION)
        .where("expiresAtTimestamp", "<=", cutoff)
        .orderBy("expiresAtTimestamp", "asc")
        .limit(limit),
  };
}
function isTerminalCleanupStatus(status) {
  return terminalCleanupStatuses.includes(status);
}
function safeErrorCode(error) {
  return error && typeof error.code === "string" ? error.code : "internal";
}
function freezeSummary(summary) {
  return Object.freeze({
    ...summary,
    runResults: Object.freeze(
        summary.runResults.map((item) => Object.freeze({...item}))),
  });
}
function createScheduledCleanupHandler({
  db,
  clock = productionClock(),
  logger = firebaseLogger,
  scanLimit = DEFAULT_SCAN_LIMIT,
  processLimit = DEFAULT_PROCESS_LIMIT,
  batchSize = DEFAULT_CLEANUP_BATCH_SIZE,
  minimumGraceSeconds = DEFAULT_MINIMUM_GRACE_SECONDS,
  executeCleanupStep = executeRunRecursiveCleanupStep,
} = {}) {
  if (!db) throw new TypeError("db is required");
  assertClock(clock);
  assertLogger(logger);
  const normalizedScanLimit = assertPositiveInteger(
      scanLimit, "scanLimit", MAX_SCAN_LIMIT);
  const normalizedProcessLimit = assertPositiveInteger(
      processLimit, "processLimit", MAX_PROCESS_LIMIT);
  const normalizedBatchSize = assertBatchSize(batchSize);
  const normalizedGraceSeconds = assertMinimumGraceSeconds(
      minimumGraceSeconds);
  if (typeof executeCleanupStep !== "function") {
    throw new TypeError("executeCleanupStep must be a function");
  }

  return async (event = {}) => {
    const nowDate = normalizeNow(clock.now());
    const now = nowDate.toISOString();
    const builtQuery = buildExpiredRunQuery(db, {
      now: nowDate,
      minimumGraceSeconds: normalizedGraceSeconds,
      scanLimit: normalizedScanLimit,
    });
    let snapshot;
    try {
      snapshot = await builtQuery.query.get();
    } catch (error) {
      logger.error("Risk scan scheduled cleanup query failed", {
        contractVersion: SCHEDULED_CLEANUP_CONTRACT_VERSION_V1,
        errorCode: safeErrorCode(error),
      });
      throw error;
    }

    const summary = {
      contractVersion: SCHEDULED_CLEANUP_CONTRACT_VERSION_V1,
      functionName: SCHEDULED_CLEANUP_FUNCTION_NAME,
      scheduleTime:
        typeof event.scheduleTime === "string" ? event.scheduleTime : null,
      now,
      cutoffAt: builtQuery.cutoff.toISOString(),
      scannedCount: snapshot.size,
      terminalCandidateCount: 0,
      attemptedCount: 0,
      progressedCount: 0,
      completedCount: 0,
      skippedNonTerminalCount: 0,
      skippedProcessLimitCount: 0,
      failedCount: 0,
      deletedDocumentCount: 0,
      runResults: [],
    };

    for (const document of snapshot.docs) {
      const scanRunId = document.id;
      let run;
      try {
        run = assertRunRetentionStorage(document.data());
        if (run.scanRunId !== scanRunId) {
          const error = new Error(
              "stored run identity does not match its path");
          error.code = "conflict";
          throw error;
        }
      } catch (error) {
        summary.failedCount += 1;
        summary.runResults.push({
          scanRunId,
          outcome: "failed",
          errorCode: safeErrorCode(error),
        });
        logger.error("Risk scan scheduled cleanup candidate is invalid", {
          scanRunId,
          errorCode: safeErrorCode(error),
        });
        continue;
      }

      if (!isTerminalCleanupStatus(run.status)) {
        summary.skippedNonTerminalCount += 1;
        continue;
      }
      summary.terminalCandidateCount += 1;
      if (summary.attemptedCount >= normalizedProcessLimit) {
        summary.skippedProcessLimitCount += 1;
        continue;
      }

      summary.attemptedCount += 1;
      try {
        const result = await executeCleanupStep(db, {
          scanRunId,
          now,
          minimumGraceSeconds: normalizedGraceSeconds,
          batchSize: normalizedBatchSize,
        });
        summary.deletedDocumentCount += result.deletedCount;
        if (result.complete) {
          summary.completedCount += 1;
        } else {
          summary.progressedCount += 1;
        }
        summary.runResults.push({
          scanRunId,
          outcome: result.outcome,
          stepCode: result.stepCode,
          complete: result.complete,
          deletedCount: result.deletedCount,
        });
        logger.info("Risk scan scheduled cleanup step completed", {
          scanRunId,
          outcome: result.outcome,
          stepCode: result.stepCode,
          complete: result.complete,
          deletedCount: result.deletedCount,
        });
      } catch (error) {
        summary.failedCount += 1;
        summary.runResults.push({
          scanRunId,
          outcome: "failed",
          errorCode: safeErrorCode(error),
        });
        logger.error("Risk scan scheduled cleanup step failed", {
          scanRunId,
          errorCode: safeErrorCode(error),
        });
      }
    }

    const result = freezeSummary(summary);
    logger.info("Risk scan scheduled cleanup cycle completed", {
      contractVersion: result.contractVersion,
      scannedCount: result.scannedCount,
      terminalCandidateCount: result.terminalCandidateCount,
      attemptedCount: result.attemptedCount,
      progressedCount: result.progressedCount,
      completedCount: result.completedCount,
      failedCount: result.failedCount,
      deletedDocumentCount: result.deletedDocumentCount,
    });
    return result;
  };
}
function buildCleanupExpiredRiskScanRuns({
  db,
  clock,
  logger,
  scanLimit,
  processLimit,
  batchSize,
  minimumGraceSeconds,
  executeCleanupStep,
  onScheduleImpl = onSchedule,
} = {}) {
  if (typeof onScheduleImpl !== "function") {
    throw new TypeError("onScheduleImpl must be a function");
  }
  return onScheduleImpl(
      scheduledCleanupOptions(),
      createScheduledCleanupHandler({
        db,
        clock,
        logger,
        scanLimit,
        processLimit,
        batchSize,
        minimumGraceSeconds,
        executeCleanupStep,
      }));
}

module.exports = {
  DEFAULT_MINIMUM_GRACE_SECONDS,
  DEFAULT_PROCESS_LIMIT,
  DEFAULT_SCAN_LIMIT,
  MAX_PROCESS_LIMIT,
  MAX_SCAN_LIMIT,
  REGION,
  SCHEDULE,
  SCHEDULED_CLEANUP_CONTRACT_VERSION_V1,
  SCHEDULED_CLEANUP_FUNCTION_NAME,
  TIME_ZONE,
  assertBatchSize,
  assertClock,
  assertLogger,
  assertMinimumGraceSeconds,
  assertPositiveInteger,
  buildCleanupExpiredRiskScanRuns,
  buildExpiredRunQuery,
  createScheduledCleanupHandler,
  freezeSummary,
  isTerminalCleanupStatus,
  normalizeNow,
  productionClock,
  safeErrorCode,
  scheduledCleanupOptions,
};
