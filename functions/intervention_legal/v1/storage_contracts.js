"use strict";

const {
  InterventionLegalContractError,
  objectRequired,
} = require("./contracts");

const REQUIRED_STORAGE_METHODS = Object.freeze([
  "getCommandReceipt",
  "resolveCaseScope",
  "findLegalMatterByKey",
  "getLegalMatterById",
  "createLegalMatterAtomic",
  "transitionLegalMatterAtomic",
  "getApprovalRequestById",
  "getLegalTeamProfileByUid",
  "resolveClientAuthority",
  "recordApprovalDecisionAtomic",
]);

function assertStoragePort(store) {
  objectRequired(store, "store");
  const missing = REQUIRED_STORAGE_METHODS.filter(
    (name) => typeof store[name] !== "function",
  );
  if (missing.length > 0) {
    throw new InterventionLegalContractError(
      "failed-precondition",
      "storage port is incomplete",
      {missing},
    );
  }
  return store;
}

function assertClock(clock) {
  if (typeof clock !== "function") {
    throw new InterventionLegalContractError(
      "failed-precondition",
      "clock must be a function",
    );
  }
  const value = clock();
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw new InterventionLegalContractError(
      "failed-precondition",
      "clock must return an ISO-8601 timestamp",
    );
  }
  return clock;
}

function assertReceiptShape(receipt) {
  if (receipt === null || receipt === undefined) return null;
  objectRequired(receipt, "receipt");
  for (const field of [
    "idempotencyKey",
    "payloadFingerprint",
    "resultType",
    "resultId",
  ]) {
    if (typeof receipt[field] !== "string" || receipt[field].trim() === "") {
      throw new InterventionLegalContractError(
        "internal",
        `receipt.${field} is invalid`,
      );
    }
  }
  return receipt;
}

module.exports = Object.freeze({
  REQUIRED_STORAGE_METHODS,
  assertStoragePort,
  assertClock,
  assertReceiptShape,
});
