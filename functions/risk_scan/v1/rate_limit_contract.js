"use strict";

const {
  RATE_LIMIT_CONTRACT_VERSION_V1,
  assertDocumentId,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertPlainObject,
  assertSha256Hex,
} = require("./contracts");

const rawNetworkKeys = Object.freeze([
  "ip",
  "ipAddress",
  "rawIp",
  "userAgent",
  "deviceId",
  "clientNonce",
]);

function assertPositiveInteger(value, label, maximum = 1000000) {
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new TypeError(`${label} must be a positive integer`);
  }
  return value;
}

function assertNoRawNetworkIdentifiers(record) {
  assertPlainObject(record, "rateLimitRecord");
  const forbidden = rawNetworkKeys.filter((key) =>
    Object.prototype.hasOwnProperty.call(record, key));
  if (forbidden.length > 0) {
    throw new TypeError(
        `raw network identifiers are forbidden: ${forbidden.join(", ")}`);
  }
  return record;
}

function createRateLimitRecord({
  bucketId,
  appId,
  ipHashSha256,
  anonymousClientNonceDigestSha256,
  windowCode,
  windowStartedAt,
  purgeAt,
  limit,
  now,
}) {
  const record = {
    contractVersion: RATE_LIMIT_CONTRACT_VERSION_V1,
    bucketId: assertDocumentId(bucketId, "bucketId"),
    appId: assertNonEmptyString(appId, "appId", 512),
    ipHashSha256: assertSha256Hex(ipHashSha256, "ipHashSha256"),
    anonymousClientNonceDigestSha256: assertSha256Hex(
        anonymousClientNonceDigestSha256,
        "anonymousClientNonceDigestSha256"),
    windowCode: assertNonEmptyString(windowCode, "windowCode", 64),
    windowStartedAt: assertIsoTimestamp(
        windowStartedAt, "windowStartedAt"),
    purgeAt: assertIsoTimestamp(purgeAt, "purgeAt"),
    limit: assertPositiveInteger(limit, "limit"),
    count: 1,
    firstRequestAt: assertIsoTimestamp(now, "now"),
    lastRequestAt: assertIsoTimestamp(now, "now"),
  };
  if (Date.parse(record.purgeAt) <= Date.parse(record.windowStartedAt)) {
    throw new TypeError("purgeAt must be after windowStartedAt");
  }
  return assertNoRawNetworkIdentifiers(record);
}

function incrementRateLimitRecord(existing, now) {
  assertNoRawNetworkIdentifiers(existing);
  const count = assertPositiveInteger(existing.count, "count");
  const limit = assertPositiveInteger(existing.limit, "limit");
  if (count >= limit) {
    const error = new Error("rate limit exceeded");
    error.code = "resource-exhausted";
    throw error;
  }
  return {
    ...existing,
    count: count + 1,
    lastRequestAt: assertIsoTimestamp(now, "now"),
  };
}

function rateLimitRemaining(record) {
  assertNoRawNetworkIdentifiers(record);
  const count = assertPositiveInteger(record.count, "count");
  const limit = assertPositiveInteger(record.limit, "limit");
  return Math.max(0, limit - count);
}

module.exports = {
  assertNoRawNetworkIdentifiers,
  assertPositiveInteger,
  createRateLimitRecord,
  incrementRateLimitRecord,
  rateLimitRemaining,
  rawNetworkKeys,
};
