"use strict";

const {
  assertEnum,
  assertIsoTimestamp,
  assertNonEmptyString,
  channelStatuses,
  claimStatuses,
  identityModes,
  promotionStatuses,
  reviewStatuses,
  runStatuses,
} = require("./contracts");

const runTransitions = Object.freeze({
  created: ["validatingTarget", "cancelled", "expired"],
  validatingTarget: [
    "queued",
    "failedTerminal",
    "cancelled",
    "expired",
  ],
  queued: [
    "acquiring",
    "failedRetryable",
    "failedTerminal",
    "cancelled",
    "expired",
  ],
  acquiring: [
    "assessing",
    "completedWithLimits",
    "failedRetryable",
    "failedTerminal",
    "cancelled",
    "expired",
  ],
  assessing: [
    "reporting",
    "completedWithLimits",
    "failedRetryable",
    "failedTerminal",
    "cancelled",
    "expired",
  ],
  reporting: [
    "completed",
    "completedWithLimits",
    "failedRetryable",
    "failedTerminal",
    "cancelled",
    "expired",
  ],
  failedRetryable: ["queued", "cancelled", "expired"],
  completed: [],
  completedWithLimits: [],
  failedTerminal: [],
  cancelled: [],
  expired: [],
});

const channelTransitions = Object.freeze({
  queued: ["acquiring", "skipped", "failedRetryable", "failedTerminal"],
  acquiring: [
    "assessing",
    "completedWithLimits",
    "failedRetryable",
    "failedTerminal",
  ],
  assessing: [
    "completed",
    "completedWithLimits",
    "failedRetryable",
    "failedTerminal",
  ],
  failedRetryable: ["queued"],
  completed: [],
  completedWithLimits: [],
  failedTerminal: [],
  skipped: [],
});

const reviewTransitions = Object.freeze({
  signal: ["reviewRequired", "suspicious", "confirmed", "falsePositive"],
  reviewRequired: ["suspicious", "confirmed", "falsePositive"],
  suspicious: ["confirmed", "falsePositive"],
  confirmed: [],
  falsePositive: [],
});

const claimTransitions = Object.freeze({
  issued: ["claimed", "expired", "revoked"],
  claimed: [],
  expired: [],
  revoked: [],
});

function canTransition(table, from, to) {
  return Boolean(table[from]?.includes(to));
}

function assertTransition(table, allowed, from, to, label) {
  assertEnum(from, allowed, `${label}.from`);
  assertEnum(to, allowed, `${label}.to`);
  if (!canTransition(table, from, to)) {
    throw new TypeError(`${label} transition is not allowed`);
  }
  return to;
}

function assertRunTransition(from, to) {
  return assertTransition(
      runTransitions, runStatuses, from, to, "runStatus");
}

function assertChannelTransition(from, to) {
  return assertTransition(
      channelTransitions, channelStatuses, from, to, "channelStatus");
}

function assertReviewTransition(from, to) {
  return assertTransition(
      reviewTransitions, reviewStatuses, from, to, "reviewStatus");
}

function assertClaimTransition(from, to) {
  return assertTransition(
      claimTransitions, claimStatuses, from, to, "claimStatus");
}

function assertAutomaticReviewStatus(status) {
  assertEnum(status, reviewStatuses, "reviewStatus");
  if (!["signal", "reviewRequired"].includes(status)) {
    throw new TypeError("automatic scan cannot produce a human decision");
  }
  return status;
}

function assertImmutableRecord(record, label) {
  if (!record || record.immutable !== true) {
    throw new TypeError(`${label}.immutable must be true`);
  }
  return record;
}

function assertIdentityScope(record) {
  const mode = assertEnum(
      record?.identityMode, identityModes, "identityMode");
  const tenantId = record.tenantId ?? null;
  const canonicalBrandId = record.canonicalBrandId ?? null;
  const createdByUid = record.createdByUid ?? null;
  if (mode === "anonymous") {
    if (tenantId !== null || canonicalBrandId !== null ||
        createdByUid !== null) {
      throw new TypeError("anonymous identity must not contain resolved scope");
    }
    return record;
  }
  assertNonEmptyString(tenantId, "tenantId", 180);
  assertNonEmptyString(canonicalBrandId, "canonicalBrandId", 180);
  assertNonEmptyString(createdByUid, "createdByUid", 180);
  return record;
}

function assertPromotionEligibility({
  identityMode,
  reviewStatus,
  reviewedAt,
  reviewedByUid,
  promotionStatus = "notRequested",
}) {
  assertEnum(identityMode, identityModes, "identityMode");
  assertEnum(reviewStatus, reviewStatuses, "reviewStatus");
  assertEnum(promotionStatus, promotionStatuses, "promotionStatus");
  if (identityMode !== "resolved") {
    throw new TypeError("shared-risk promotion requires resolved identity");
  }
  if (!["suspicious", "confirmed"].includes(reviewStatus)) {
    throw new TypeError("shared-risk promotion requires human review");
  }
  assertIsoTimestamp(reviewedAt, "reviewedAt");
  assertNonEmptyString(reviewedByUid, "reviewedByUid", 180);
  if (promotionStatus !== "notRequested") {
    throw new TypeError("finding was already promoted");
  }
  return true;
}

module.exports = {
  assertAutomaticReviewStatus,
  assertChannelTransition,
  assertClaimTransition,
  assertIdentityScope,
  assertImmutableRecord,
  assertPromotionEligibility,
  assertReviewTransition,
  assertRunTransition,
  canTransition,
  channelTransitions,
  claimTransitions,
  reviewTransitions,
  runTransitions,
};
