"use strict";

const {
  PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS,
  buildDispatchLease,
  buildPublicLiteDispatchEnvelope,
  buildPublicLiteExecutionCommand,
  buildPublicLiteExecutionRecord,
  assertExecutionCommand,
  normalizeDispatchOwnerId,
  normalizeDispatchReceipt,
} = require("./public_lite_execution_contract");

class PublicLiteExecutionServiceError extends Error {
  constructor(code, message, retryable = false) {
    super(message);
    this.name = "PublicLiteExecutionServiceError";
    this.code = code;
    this.retryable = retryable;
  }
}

function fail(code, message, retryable = false) {
  throw new PublicLiteExecutionServiceError(
      code, message, retryable);
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

function assertExecutionPort(port) {
  const methods = [
    "prepareExecution",
    "queueExecution",
    "claimDispatch",
    "markDispatchSucceeded",
    "markDispatchFailed",
  ];
  if (!port || methods.some((name) => typeof port[name] !== "function")) {
    throw new TypeError(
        `execution port requires: ${methods.join(", ")}`);
  }
  return port;
}

function assertDispatcher(dispatcher) {
  if (!dispatcher || typeof dispatcher.dispatch !== "function") {
    throw new TypeError("dispatcher.dispatch is required");
  }
  return dispatcher;
}

function normalizeNow(clock) {
  const value = assertClock(clock).now();
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError("clock.now must return a valid time");
  }
  return date.toISOString();
}

function assertOutcome(value, allowed, label) {
  if (!value || typeof value !== "object" ||
      !allowed.includes(value.outcome)) {
    fail("internal", `${label} returned an invalid outcome`);
  }
  return value;
}

async function preparePublicLiteExecution({
  event,
  port,
  clock = productionClock(),
}) {
  const executionPort = assertExecutionPort(port);
  const command = buildPublicLiteExecutionCommand(event);
  const record = buildPublicLiteExecutionRecord(command);
  const prepared = assertOutcome(
      await executionPort.prepareExecution({command, record}),
      ["created", "idempotent_success"],
      "prepareExecution");
  const queued = assertOutcome(
      await executionPort.queueExecution({
        executionId: command.executionId,
        scanRunId: command.scanRunId,
        updatedAt: normalizeNow(clock),
      }),
      ["queued", "idempotent_success"],
      "queueExecution");
  return Object.freeze({
    outcome: prepared.outcome === "created" ?
      "prepared" : "idempotent_prepared",
    command,
    record,
    queueOutcome: queued.outcome,
  });
}

function normalizeDispatchFailure(error) {
  const candidateCode = typeof error?.code === "string" ?
    error.code.trim().slice(0, 100) : "dispatch_failed";
  const rawCode = /^[A-Za-z0-9_.-]+$/.test(candidateCode) ?
    candidateCode : "dispatch_failed";
  const statusCode = Number(error?.statusCode || error?.status || 0);
  const explicitRetryable = error?.retryable;
  let retryable;
  if (typeof explicitRetryable === "boolean") {
    retryable = explicitRetryable;
  } else if (["invalid-argument", "failed-precondition"].includes(
      rawCode)) {
    retryable = false;
  } else if (statusCode === 408 || statusCode === 425 ||
      statusCode === 429 || statusCode >= 500 || statusCode === 0) {
    retryable = true;
  } else {
    retryable = false;
  }
  const safeStatus = Number.isFinite(statusCode) ? statusCode : 0;
  const message = safeStatus > 0 ?
    `Dispatch failed with HTTP ${safeStatus}.` :
    "Dispatch failed before a provider receipt was accepted.";
  return Object.freeze({
    code: rawCode || "dispatch_failed",
    message,
    retryable,
    statusCode: safeStatus,
  });
}


async function dispatchPreparedPublicLiteExecution({
  command,
  ownerId,
  port,
  dispatcher,
  clock = productionClock(),
}) {
  const executionPort = assertExecutionPort(port);
  const executionDispatcher = assertDispatcher(dispatcher);
  assertExecutionCommand(command);
  const normalizedOwnerId = normalizeDispatchOwnerId(ownerId);
  const now = normalizeNow(clock);
  const claim = assertOutcome(
      await executionPort.claimDispatch({
        executionId: command.executionId,
        scanRunId: command.scanRunId,
        ownerId: normalizedOwnerId,
        now,
        maxAttempts: PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS,
      }),
      [
        "claimed",
        "lease_held",
        "already_dispatched",
        "terminal",
      ],
      "claimDispatch");

  if (claim.outcome !== "claimed") {
    return Object.freeze({
      outcome: claim.outcome,
      executionId: command.executionId,
    });
  }

  const lease = buildDispatchLease({
    executionId: command.executionId,
    ownerId: normalizedOwnerId,
    attemptCount: claim.attemptCount,
    now,
  });
  const envelope = buildPublicLiteDispatchEnvelope(command);

  let rawReceipt;
  try {
    rawReceipt = await executionDispatcher.dispatch(envelope);
  } catch (error) {
    const failure = normalizeDispatchFailure(error);
    const terminalByAttempts =
      claim.attemptCount >= PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS;
    const retryable = failure.retryable && !terminalByAttempts;
    const marked = assertOutcome(
        await executionPort.markDispatchFailed({
          executionId: command.executionId,
          scanRunId: command.scanRunId,
          ownerId: normalizedOwnerId,
          attemptCount: claim.attemptCount,
          failure,
          retryable,
          failedAt: normalizeNow(clock),
        }),
        ["retryable_failure", "terminal_failure",
          "idempotent_success"],
        "markDispatchFailed");
    return Object.freeze({
      outcome: retryable ? "retryable_failure" : "terminal_failure",
      executionId: command.executionId,
      attemptCount: claim.attemptCount,
      failure,
      storageOutcome: marked.outcome,
    });
  }

  let receipt;
  try {
    receipt = normalizeDispatchReceipt(rawReceipt, {
      expectedExecutionId: command.executionId,
    });
  } catch {
    const failure = Object.freeze({
      code: "invalid_dispatch_receipt",
      message: "Provider returned an invalid dispatch receipt.",
      retryable: false,
      statusCode: 0,
    });
    const marked = assertOutcome(
        await executionPort.markDispatchFailed({
          executionId: command.executionId,
          scanRunId: command.scanRunId,
          ownerId: normalizedOwnerId,
          attemptCount: claim.attemptCount,
          failure,
          retryable: false,
          failedAt: normalizeNow(clock),
        }),
        ["terminal_failure", "idempotent_success"],
        "markDispatchFailed");
    return Object.freeze({
      outcome: "terminal_failure",
      executionId: command.executionId,
      attemptCount: claim.attemptCount,
      failure,
      storageOutcome: marked.outcome,
    });
  }


  const marked = assertOutcome(
      await executionPort.markDispatchSucceeded({
        executionId: command.executionId,
        scanRunId: command.scanRunId,
        ownerId: normalizedOwnerId,
        attemptCount: claim.attemptCount,
        receipt,
        dispatchedAt: receipt.acceptedAt,
      }),
      ["dispatched", "idempotent_success"],
      "markDispatchSucceeded");
  return Object.freeze({
    outcome: "dispatched",
    executionId: command.executionId,
    attemptCount: claim.attemptCount,
    lease,
    receipt,
    handoffId: receipt.handoffId,
    storageOutcome: marked.outcome,
  });
}

async function orchestratePublicLiteExecution({
  event,
  ownerId,
  port,
  dispatcher,
  clock = productionClock(),
}) {
  const prepared = await preparePublicLiteExecution({
    event,
    port,
    clock,
  });
  return dispatchPreparedPublicLiteExecution({
    command: prepared.command,
    ownerId,
    port,
    dispatcher,
    clock,
  });
}

module.exports = Object.freeze({
  PublicLiteExecutionServiceError,
  assertDispatcher,
  assertExecutionPort,
  dispatchPreparedPublicLiteExecution,
  normalizeDispatchFailure,
  orchestratePublicLiteExecution,
  preparePublicLiteExecution,
  productionClock,
});
