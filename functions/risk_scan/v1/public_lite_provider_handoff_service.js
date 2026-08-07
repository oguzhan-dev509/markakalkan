"use strict";

const {
  PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS,
  PUBLIC_LITE_PROVIDER_HANDOFF_RETENTION_MS,
  buildPublicLiteProviderHandoffReceipt,
  normalizePublicLiteAcquisitionDispatchReceipt,
  normalizePublicLiteProviderHandoffRequest,
} = require("./public_lite_provider_handoff_contract");

class PublicLiteProviderHandoffServiceError extends Error {
  constructor(code, message, retryable = false) {
    super(message);
    this.name = "PublicLiteProviderHandoffServiceError";
    this.code = code;
    this.retryable = retryable;
  }
}

function fail(code, message, retryable = false) {
  throw new PublicLiteProviderHandoffServiceError(
      code, message, retryable);
}

function productionClock() {
  return {now: () => new Date()};
}

function normalizeNow(clock) {
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }
  const value = clock.now();
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError("clock.now must return a valid time");
  }
  return date;
}

function assertHandoffPort(port) {
  const methods = [
    "acceptHandoff",
    "claimChildDispatch",
    "markChildDispatchSucceeded",
    "markChildDispatchFailed",
  ];
  if (!port || methods.some((name) => typeof port[name] !== "function")) {
    throw new TypeError(`handoff port requires: ${methods.join(", ")}`);
  }
  return port;
}

function assertDispatcher(dispatcher) {
  if (!dispatcher || typeof dispatcher.dispatch !== "function") {
    throw new TypeError("dispatcher.dispatch is required");
  }
  return dispatcher;
}

function assertOutcome(value, allowed, label) {
  if (!value || typeof value !== "object" ||
      !allowed.includes(value.outcome)) {
    fail("internal", `${label} returned an invalid outcome`);
  }
  return value;
}

function normalizeChildDispatchFailure(error) {
  const candidate = typeof error?.code === "string" ?
    error.code.trim().slice(0, 100) : "child_dispatch_failed";
  const code = /^[A-Za-z0-9_.-]+$/.test(candidate) ?
    candidate : "child_dispatch_failed";
  const statusCode = Number(error?.statusCode || error?.status || 0);
  let retryable;
  if (typeof error?.retryable === "boolean") {
    retryable = error.retryable;
  } else if (["invalid-argument", "failed-precondition"].includes(code)) {
    retryable = false;
  } else {
    retryable = statusCode === 0 || statusCode === 408 ||
      statusCode === 425 || statusCode === 429 || statusCode >= 500;
  }
  return Object.freeze({
    code,
    message: statusCode > 0 ?
      `Child dispatch failed with HTTP ${statusCode}.` :
      "Child dispatch failed before provider acceptance.",
    retryable,
    statusCode: Number.isFinite(statusCode) ? statusCode : 0,
  });
}

async function acceptPublicLiteProviderHandoff({
  request,
  port,
  clock = productionClock(),
}) {
  const handoffPort = assertHandoffPort(port);
  normalizePublicLiteProviderHandoffRequest(request);
  const now = normalizeNow(clock);
  const result = assertOutcome(
      await handoffPort.acceptHandoff({
        request,
        acceptedAt: now.toISOString(),
        purgeAtTimestamp: new Date(
            now.getTime() + PUBLIC_LITE_PROVIDER_HANDOFF_RETENTION_MS),
      }),
      ["created", "idempotent_success"],
      "acceptHandoff");
  return Object.freeze({
    outcome: result.outcome,
    receipt: buildPublicLiteProviderHandoffReceipt({
      record: result.record,
      replayed: result.replayed,
    }),
  });
}

async function dispatchAcceptedPublicLiteProviderHandoff({
  executionId,
  ownerId,
  port,
  dispatcher,
  clock = productionClock(),
}) {
  const handoffPort = assertHandoffPort(port);
  const childDispatcher = assertDispatcher(dispatcher);
  const now = normalizeNow(clock).toISOString();
  const claim = assertOutcome(
      await handoffPort.claimChildDispatch({
        executionId,
        ownerId,
        now,
        maxAttempts: PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS,
      }),
      [
        "claimed",
        "not_due",
        "lease_held",
        "already_dispatched",
        "completed",
        "terminal",
      ],
      "claimChildDispatch");

  if (claim.outcome !== "claimed") {
    return Object.freeze({
      outcome: claim.outcome,
      executionId,
    });
  }

  let rawReceipt;
  try {
    rawReceipt = await childDispatcher.dispatch(claim.command);
  } catch (error) {
    const failure = normalizeChildDispatchFailure(error);
    const terminalByAttempts =
      claim.attemptCount >= PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS;
    const retryable = failure.retryable && !terminalByAttempts;
    const marked = assertOutcome(
        await handoffPort.markChildDispatchFailed({
          executionId,
          ownerId,
          attemptCount: claim.attemptCount,
          leaseToken: claim.leaseToken,
          failure,
          retryable,
          failedAt: normalizeNow(clock).toISOString(),
        }),
        ["retryable_failure", "terminal_failure", "idempotent_success"],
        "markChildDispatchFailed");
    return Object.freeze({
      outcome: retryable ? "retryable_failure" : "terminal_failure",
      executionId,
      attemptCount: claim.attemptCount,
      failure,
      storageOutcome: marked.outcome,
    });
  }

  let receipt;
  try {
    receipt = normalizePublicLiteAcquisitionDispatchReceipt(rawReceipt, {
      expectedHandoffId: claim.command.handoffId,
      expectedExecutionId: executionId,
    });
  } catch {
    const failure = Object.freeze({
      code: "invalid_child_dispatch_receipt",
      message: "Child provider returned an invalid dispatch receipt.",
      retryable: false,
      statusCode: 0,
    });
    const marked = assertOutcome(
        await handoffPort.markChildDispatchFailed({
          executionId,
          ownerId,
          attemptCount: claim.attemptCount,
          leaseToken: claim.leaseToken,
          failure,
          retryable: false,
          failedAt: normalizeNow(clock).toISOString(),
        }),
        ["terminal_failure", "idempotent_success"],
        "markChildDispatchFailed");
    return Object.freeze({
      outcome: "terminal_failure",
      executionId,
      attemptCount: claim.attemptCount,
      failure,
      storageOutcome: marked.outcome,
    });
  }

  const marked = assertOutcome(
      await handoffPort.markChildDispatchSucceeded({
        executionId,
        ownerId,
        attemptCount: claim.attemptCount,
        leaseToken: claim.leaseToken,
        receipt,
        dispatchedAt: receipt.acceptedAt,
      }),
      ["child_dispatched", "idempotent_success"],
      "markChildDispatchSucceeded");
  return Object.freeze({
    outcome: "child_dispatched",
    executionId,
    attemptCount: claim.attemptCount,
    receipt,
    storageOutcome: marked.outcome,
  });
}

module.exports = Object.freeze({
  PublicLiteProviderHandoffServiceError,
  acceptPublicLiteProviderHandoff,
  assertDispatcher,
  assertHandoffPort,
  dispatchAcceptedPublicLiteProviderHandoff,
  normalizeChildDispatchFailure,
  productionClock,
});
