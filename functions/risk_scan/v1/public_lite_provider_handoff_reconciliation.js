"use strict";

const {onSchedule} = require("firebase-functions/v2/scheduler");
const firebaseLogger = require("firebase-functions/logger");
const {
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
} = require("./public_lite_provider_handoff_contract");
const {
  DEFAULT_PUBLIC_LITE_HANDOFF_DUE_SCAN_LIMIT,
  MAX_PUBLIC_LITE_HANDOFF_DUE_SCAN_LIMIT,
  createPublicLiteProviderHandoffFirestorePort,
} = require("./public_lite_provider_handoff_firestore_port");
const {
  dispatchAcceptedPublicLiteProviderHandoff,
  productionClock,
} = require("./public_lite_provider_handoff_service");
const {
  N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN,
  PUBLIC_LITE_ACQUISITION_WEBHOOK_URL,
  createPublicLiteAcquisitionDispatcher,
} = require("./public_lite_provider_handoff_trigger");

const PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_FUNCTION_NAME =
  "reconcilePublicLiteRiskScanProviderHandoffs";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_SCHEDULE =
  "every 5 minutes";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_TIME_ZONE = "Etc/UTC";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_REGION = "europe-west3";
const DEFAULT_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT = 25;
const MAX_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT = 100;

function assertPositiveInteger(value, label, maximum) {
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new TypeError(`${label} must be between 1 and ${maximum}`);
  }
  return value;
}

function assertLogger(logger) {
  if (!logger || typeof logger.info !== "function" ||
      typeof logger.warn !== "function" ||
      typeof logger.error !== "function") {
    throw new TypeError("logger info, warn, and error functions are required");
  }
  return logger;
}

function assertClock(clock) {
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }
  return clock;
}

function normalizeNow(value) {
  const date = value instanceof Date ?
    new Date(value.getTime()) : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError("clock.now must return a valid date");
  }
  return date;
}

function safeErrorCode(error) {
  return error && typeof error.code === "string" ?
    error.code.slice(0, 100) : "internal";
}

function scheduledReconciliationOptions({
  acquisitionToken = N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN,
} = {}) {
  if (!acquisitionToken) {
    throw new TypeError("acquisitionToken is required");
  }
  return Object.freeze({
    schedule: PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_SCHEDULE,
    timeZone: PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_TIME_ZONE,
    region: PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_REGION,
    secrets: [acquisitionToken],
    maxInstances: 1,
    concurrency: 1,
    timeoutSeconds: 540,
    memory: "256MiB",
  });
}

function assertReconciliationPort(port) {
  if (!port || typeof port.listDueHandoffs !== "function" ||
      typeof port.claimChildDispatch !== "function" ||
      typeof port.markChildDispatchSucceeded !== "function" ||
      typeof port.markChildDispatchFailed !== "function") {
    throw new TypeError("reconciliation port is incomplete");
  }
  return port;
}

function freezeSummary(summary) {
  return Object.freeze({
    ...summary,
    handoffResults: Object.freeze(
        summary.handoffResults.map((item) => Object.freeze({...item}))),
  });
}

function createPublicLiteProviderHandoffReconciliationHandler({
  port,
  dispatcher,
  clock = productionClock(),
  logger = firebaseLogger,
  scanLimit = DEFAULT_PUBLIC_LITE_HANDOFF_DUE_SCAN_LIMIT,
  processLimit = DEFAULT_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT,
  dispatchHandoff = dispatchAcceptedPublicLiteProviderHandoff,
} = {}) {
  const handoffPort = assertReconciliationPort(port);
  if (!dispatcher || typeof dispatcher.dispatch !== "function") {
    throw new TypeError("dispatcher.dispatch is required");
  }
  assertClock(clock);
  assertLogger(logger);
  const normalizedScanLimit = assertPositiveInteger(
      scanLimit,
      "scanLimit",
      MAX_PUBLIC_LITE_HANDOFF_DUE_SCAN_LIMIT);
  const normalizedProcessLimit = assertPositiveInteger(
      processLimit,
      "processLimit",
      MAX_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT);
  if (typeof dispatchHandoff !== "function") {
    throw new TypeError("dispatchHandoff must be a function");
  }

  return async (event = {}) => {
    const nowDate = normalizeNow(clock.now());
    const now = nowDate.toISOString();
    const cycleId = String(
        event.id || event.scheduleTime || now).slice(0, 160);
    let records;
    try {
      records = await handoffPort.listDueHandoffs({
        now: nowDate,
        limit: normalizedScanLimit,
      });
    } catch (error) {
      logger.error("Public Lite handoff reconciliation query failed", {
        contractVersion:
          PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
        errorCode: safeErrorCode(error),
      });
      throw error;
    }

    const summary = {
      contractVersion:
        PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
      functionName:
        PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_FUNCTION_NAME,
      scheduleTime:
        typeof event.scheduleTime === "string" ? event.scheduleTime : null,
      now,
      scannedCount: records.length,
      attemptedCount: 0,
      childDispatchedCount: 0,
      retryableFailureCount: 0,
      terminalFailureCount: 0,
      leaseHeldCount: 0,
      notDueCount: 0,
      alreadyDispatchedCount: 0,
      completedCount: 0,
      terminalCount: 0,
      skippedProcessLimitCount: 0,
      failedCount: 0,
      handoffResults: [],
    };

    for (const record of records) {
      if (summary.attemptedCount >= normalizedProcessLimit) {
        summary.skippedProcessLimitCount += 1;
        continue;
      }
      summary.attemptedCount += 1;
      const ownerId = (
        `reconcile:${cycleId}:${record.executionId}`).slice(0, 256);
      try {
        const result = await dispatchHandoff({
          executionId: record.executionId,
          ownerId,
          port: handoffPort,
          dispatcher,
          clock,
        });
        const countKey = {
          child_dispatched: "childDispatchedCount",
          retryable_failure: "retryableFailureCount",
          terminal_failure: "terminalFailureCount",
          lease_held: "leaseHeldCount",
          not_due: "notDueCount",
          already_dispatched: "alreadyDispatchedCount",
          completed: "completedCount",
          terminal: "terminalCount",
        }[result.outcome];
        if (countKey) summary[countKey] += 1;
        summary.handoffResults.push({
          executionId: record.executionId,
          handoffId: record.handoffId,
          outcome: result.outcome,
          attemptCount: result.attemptCount || null,
        });
        logger.info("Public Lite handoff reconciliation candidate processed", {
          executionId: record.executionId,
          handoffId: record.handoffId,
          outcome: result.outcome,
          attemptCount: result.attemptCount || null,
        });
      } catch (error) {
        summary.failedCount += 1;
        summary.handoffResults.push({
          executionId: record.executionId,
          handoffId: record.handoffId,
          outcome: "failed",
          errorCode: safeErrorCode(error),
        });
        logger.error("Public Lite handoff reconciliation candidate failed", {
          executionId: record.executionId,
          handoffId: record.handoffId,
          errorCode: safeErrorCode(error),
        });
      }
    }

    const result = freezeSummary(summary);
    logger.info("Public Lite handoff reconciliation cycle completed", {
      contractVersion: result.contractVersion,
      scannedCount: result.scannedCount,
      attemptedCount: result.attemptedCount,
      childDispatchedCount: result.childDispatchedCount,
      retryableFailureCount: result.retryableFailureCount,
      terminalFailureCount: result.terminalFailureCount,
      failedCount: result.failedCount,
    });
    return result;
  };
}

function buildReconcilePublicLiteRiskScanProviderHandoffs({
  db,
  clock,
  logger = firebaseLogger,
  scanLimit,
  processLimit,
  dispatchHandoff,
  fetchImpl,
  acquisitionToken = N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN,
  webhookUrl = PUBLIC_LITE_ACQUISITION_WEBHOOK_URL,
  portFactory = createPublicLiteProviderHandoffFirestorePort,
  dispatcherFactory = createPublicLiteAcquisitionDispatcher,
  onScheduleImpl = onSchedule,
} = {}) {
  if (!db) throw new TypeError("db is required");
  if (typeof portFactory !== "function") {
    throw new TypeError("portFactory must be a function");
  }
  if (typeof dispatcherFactory !== "function") {
    throw new TypeError("dispatcherFactory must be a function");
  }
  if (typeof onScheduleImpl !== "function") {
    throw new TypeError("onScheduleImpl must be a function");
  }
  const port = portFactory(db);
  const dispatcher = dispatcherFactory({
    fetchImpl,
    acquisitionToken,
    webhookUrl,
  });
  return onScheduleImpl(
      scheduledReconciliationOptions({acquisitionToken}),
      createPublicLiteProviderHandoffReconciliationHandler({
        port,
        dispatcher,
        clock,
        logger,
        scanLimit,
        processLimit,
        dispatchHandoff,
      }));
}

module.exports = Object.freeze({
  DEFAULT_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT,
  MAX_PUBLIC_LITE_HANDOFF_PROCESS_LIMIT,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_FUNCTION_NAME,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_REGION,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_SCHEDULE,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_TIME_ZONE,
  assertClock,
  assertLogger,
  assertPositiveInteger,
  assertReconciliationPort,
  buildReconcilePublicLiteRiskScanProviderHandoffs,
  createPublicLiteProviderHandoffReconciliationHandler,
  freezeSummary,
  normalizeNow,
  safeErrorCode,
  scheduledReconciliationOptions,
});
