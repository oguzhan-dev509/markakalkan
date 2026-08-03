/* eslint-disable max-len */
"use strict";

const crypto = require("node:crypto");

const {
  SUBSCRIPTION_CALLABLE_CONTRACT_VERSION,
  SUBSCRIPTION_REQUEST_CONTRACT_VERSION,
  SubscriptionRequestContractError,
  parseCreateSubscriptionRequestCommand,
} = require("./contracts");

function buildSubscriptionRequestId({actorUid, requestId}) {
  const digest = crypto
      .createHash("sha256")
      .update(`${actorUid}\n${requestId}`, "utf8")
      .digest("hex");
  return `subreq_${digest.slice(0, 40)}`;
}

function immutableRecord(value) {
  return Object.freeze({...value});
}

function assertReplayMatches(existing, expected) {
  const fields = [
    "requestId",
    "productCode",
    "sourceType",
    "sourceScanRunId",
    "sourceReportId",
    "brandName",
    "officialWebsiteUrl",
    "requestedByUid",
  ];
  for (const field of fields) {
    if ((existing?.[field] ?? null) !== (expected[field] ?? null)) {
      throw new SubscriptionRequestContractError(
          "aborted",
          "requestId başka bir abonelik talebi için kullanılmış",
      );
    }
  }
}

function buildCreateSubscriptionRequestService({store, clock}) {
  if (
    !store ||
    typeof store.createSubscriptionRequestAtomic !== "function"
  ) {
    throw new TypeError("store.createSubscriptionRequestAtomic required");
  }
  if (typeof clock !== "function") {
    throw new TypeError("clock must be a function");
  }

  return async function createSubscriptionRequest(raw) {
    const command = parseCreateSubscriptionRequestCommand(raw);
    const now = clock();
    const subscriptionRequestId = buildSubscriptionRequestId({
      actorUid: command.actorUid,
      requestId: command.requestId,
    });

    const subscriptionRequest = immutableRecord({
      contractVersion: SUBSCRIPTION_REQUEST_CONTRACT_VERSION,
      subscriptionRequestId,
      requestId: command.requestId,
      productCode: command.productCode,
      sourceType: command.source.sourceType,
      sourceScanRunId: command.source.scanRunId,
      sourceReportId: command.source.reportId,
      brandName: command.source.brandName,
      officialWebsiteUrl: command.source.officialWebsiteUrl,
      requestedByUid: command.actorUid,
      requestedByEmail: command.actorEmail,
      status: "requested",
      createdAt: now,
      updatedAt: now,
      version: 1,
    });

    const result = await store.createSubscriptionRequestAtomic({
      subscriptionRequest,
    });
    const stored = result?.subscriptionRequest;

    if (!stored || typeof stored !== "object") {
      throw new SubscriptionRequestContractError(
          "internal",
          "abonelik talebi saklama sonucu geçersiz",
      );
    }

    if (result.idempotentReplay === true) {
      assertReplayMatches(stored, subscriptionRequest);
    }

    return immutableRecord({
      contractVersion: SUBSCRIPTION_CALLABLE_CONTRACT_VERSION,
      resultType: "subscription_service_request",
      resultId: subscriptionRequestId,
      status: stored.status || "requested",
      idempotentReplay: result.idempotentReplay === true,
    });
  };
}

module.exports = Object.freeze({
  assertReplayMatches,
  buildCreateSubscriptionRequestService,
  buildSubscriptionRequestId,
});
