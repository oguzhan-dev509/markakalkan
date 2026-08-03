/* eslint-disable max-len */
"use strict";

const CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION =
  "subscription-service-request-create-command-v1";
const SUBSCRIPTION_REQUEST_CONTRACT_VERSION =
  "subscription-service-request-v1";
const SUBSCRIPTION_CALLABLE_CONTRACT_VERSION =
  "subscription-service-callable-v1";

const PRODUCT_CODES = Object.freeze([
  "broad_digital_scan_subscription",
]);

const SOURCE_TYPES = Object.freeze([
  "public_lite_risk_scan",
]);

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class SubscriptionRequestContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "SubscriptionRequestContractError";
    this.code = code;
  }
}

function fail(message, code = "invalid-argument") {
  throw new SubscriptionRequestContractError(code, message);
}

function objectRequired(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail(`${field} invalid`);
  }
  return value;
}

function strict(raw, version, fields, field = "request") {
  objectRequired(raw, field);
  const allowed = new Set(["contractVersion", ...fields]);
  if (
    raw.contractVersion !== version ||
    Object.keys(raw).some((key) => !allowed.has(key))
  ) {
    fail(`${field} contract invalid`);
  }
}

function requiredString(value, field, minimum = 1, maximum = 500) {
  if (typeof value !== "string") {
    fail(`${field} invalid`);
  }
  const clean = value.trim();
  if (clean.length < minimum || clean.length > maximum) {
    fail(`${field} invalid`);
  }
  for (const character of clean) {
    const code = character.charCodeAt(0);
    if (code === 127 || (code < 32 && ![9, 10, 13].includes(code))) {
      fail(`${field} invalid`);
    }
  }
  return clean;
}

function optionalString(value, field, maximum = 500) {
  if (value == null) {
    return null;
  }
  return requiredString(value, field, 1, maximum);
}

function requiredUuid(value, field) {
  const clean = requiredString(value, field, 36, 36).toLowerCase();
  if (!UUID.test(clean)) {
    fail(`${field} invalid`);
  }
  return clean;
}

function requiredEnum(value, values, field) {
  const clean = requiredString(value, field, 1, 80).toLowerCase();
  if (!values.includes(clean)) {
    fail(`${field} unsupported`);
  }
  return clean;
}

function normalizeWebsite(value) {
  const clean = requiredString(value, "source.officialWebsiteUrl", 8, 2048);
  let url;
  try {
    url = new URL(clean);
  } catch (_) {
    fail("source.officialWebsiteUrl invalid");
  }
  if (
    !["http:", "https:"].includes(url.protocol) ||
    !url.hostname ||
    url.username ||
    url.password
  ) {
    fail("source.officialWebsiteUrl invalid");
  }
  url.hash = "";
  return url.toString();
}

function normalizeSource(raw) {
  objectRequired(raw, "source");
  const allowed = new Set([
    "sourceType",
    "scanRunId",
    "reportId",
    "brandName",
    "officialWebsiteUrl",
  ]);
  if (Object.keys(raw).some((key) => !allowed.has(key))) {
    fail("source invalid");
  }
  return Object.freeze({
    sourceType: requiredEnum(
        raw.sourceType,
        SOURCE_TYPES,
        "source.sourceType",
    ),
    scanRunId: requiredString(raw.scanRunId, "source.scanRunId", 1, 160),
    reportId: optionalString(raw.reportId, "source.reportId", 160),
    brandName: requiredString(raw.brandName, "source.brandName", 1, 240),
    officialWebsiteUrl: normalizeWebsite(raw.officialWebsiteUrl),
  });
}

function parseCreateSubscriptionRequestCommand(raw) {
  strict(
      raw,
      CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION,
      [
        "requestId",
        "productCode",
        "source",
        "actorUid",
        "actorEmail",
      ],
      "request",
  );
  return Object.freeze({
    contractVersion: raw.contractVersion,
    requestId: requiredUuid(raw.requestId, "requestId"),
    productCode: requiredEnum(raw.productCode, PRODUCT_CODES, "productCode"),
    source: normalizeSource(raw.source),
    actorUid: requiredString(raw.actorUid, "actorUid", 1, 128),
    actorEmail: optionalString(raw.actorEmail, "actorEmail", 320),
  });
}

module.exports = Object.freeze({
  CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION,
  PRODUCT_CODES,
  SOURCE_TYPES,
  SUBSCRIPTION_CALLABLE_CONTRACT_VERSION,
  SUBSCRIPTION_REQUEST_CONTRACT_VERSION,
  SubscriptionRequestContractError,
  normalizeSource,
  parseCreateSubscriptionRequestCommand,
});
