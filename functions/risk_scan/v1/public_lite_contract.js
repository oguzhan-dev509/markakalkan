"use strict";

const crypto = require("node:crypto");
const {
  assertExactKeys,
  assertNonEmptyString,
} = require("./contracts");
const {
  canonicalJsonDigestSha256,
  encodeLengthPrefixed,
  sha256Hex,
} = require("./canonical");
const {
  riskScanRateLimitBucketId,
  riskScanRunId,
} = require("./identifiers");

const PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1 =
  "risk-scan-public-lite-callable-v1";
const PUBLIC_LITE_ACCESS_KEY_PREFIX_V1 = "hrt1";
const PUBLIC_LITE_ACCESS_SECRET_ALGORITHM_V1 = "sha256";
const PUBLIC_LITE_HMAC_ALGORITHM_V1 = "hmac-sha256-v1";
const PUBLIC_LITE_RUN_LIFETIME_MS = 24 * 60 * 60 * 1000;
const PUBLIC_LITE_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const PUBLIC_LITE_RATE_LIMIT_PURGE_MS = 2 * 60 * 60 * 1000;
const PUBLIC_LITE_RATE_LIMIT_DEFAULT = 5;

const START_KEYS = Object.freeze([
  "requestId",
  "brandName",
  "officialWebsiteUrl",
  "anonymousClientNonce",
]);
const ACCESS_KEYS = Object.freeze(["accessKey"]);

class RiskScanPublicLiteError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "RiskScanPublicLiteError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new RiskScanPublicLiteError(code, message);
}

function assertSecretKey(value) {
  if (typeof value !== "string" && !Buffer.isBuffer(value)) {
    throw new TypeError("secretKey must be a string or Buffer");
  }
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value, "utf8");
  if (buffer.length < 32) {
    throw new TypeError("secretKey must contain at least 32 bytes");
  }
  return buffer;
}

function hmacHex(secretKey, namespace, parts) {
  const key = assertSecretKey(secretKey);
  return crypto.createHmac("sha256", key)
      .update(encodeLengthPrefixed([
        PUBLIC_LITE_HMAC_ALGORITHM_V1,
        namespace,
        ...parts,
      ]))
      .digest("hex");
}

function hmacBase64Url(secretKey, namespace, parts) {
  const key = assertSecretKey(secretKey);
  return crypto.createHmac("sha256", key)
      .update(encodeLengthPrefixed([
        PUBLIC_LITE_HMAC_ALGORITHM_V1,
        namespace,
        ...parts,
      ]))
      .digest("base64url");
}

function normalizeBrandName(value) {
  const normalized = assertNonEmptyString(value, "brandName", 300)
      .normalize("NFKC")
      .replace(/\s+/g, " ")
      .trim()
      .toLocaleLowerCase("und");
  if (!normalized) throw new TypeError("brandName is invalid");
  return normalized;
}

function normalizeOfficialWebsite(value) {
  const input = assertNonEmptyString(value, "officialWebsiteUrl", 4096);
  let parsed;
  try {
    parsed = new URL(input);
  } catch {
    throw new TypeError("officialWebsiteUrl must be a valid URL");
  }
  if (!["http:", "https:"].includes(parsed.protocol) ||
      parsed.username || parsed.password || !parsed.hostname) {
    throw new TypeError("officialWebsiteUrl must be an HTTP(S) origin");
  }
  const host = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (!host || host.length > 253) {
    throw new TypeError("officialWebsiteUrl host is invalid");
  }
  const port = parsed.port && !(
    (parsed.protocol === "https:" && parsed.port === "443") ||
    (parsed.protocol === "http:" && parsed.port === "80")) ?
    `:${parsed.port}` : "";
  return {
    officialHost: host,
    officialWebsiteCanonicalUrl: `${parsed.protocol}//${host}${port}/`,
  };
}

function normalizeStartData(data) {
  assertExactKeys(data, START_KEYS, "data");
  const requestId = assertNonEmptyString(data.requestId, "requestId", 180);
  const brandNameNormalized = normalizeBrandName(data.brandName);
  const website = normalizeOfficialWebsite(data.officialWebsiteUrl);
  const anonymousClientNonce = assertNonEmptyString(
      data.anonymousClientNonce, "anonymousClientNonce", 256);
  return {
    requestId,
    brandNameNormalized,
    ...website,
    anonymousClientNonce,
  };
}

function normalizeAccessData(data) {
  assertExactKeys(data, ACCESS_KEYS, "data");
  return {
    accessKey: assertNonEmptyString(data.accessKey, "accessKey", 180),
  };
}

function normalizeNetworkAddress(value) {
  return assertNonEmptyString(value, "networkAddress", 200);
}

function normalizeAppId(value) {
  return assertNonEmptyString(value, "appId", 512);
}

function normalizeNow(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError("clock returned an invalid date");
  }
  return date;
}

function windowStart(date, windowMs = PUBLIC_LITE_RATE_LIMIT_WINDOW_MS) {
  const start = Math.floor(date.getTime() / windowMs) * windowMs;
  return new Date(start);
}

function buildAccessKey(scanRunId, accessSecret) {
  return `${PUBLIC_LITE_ACCESS_KEY_PREFIX_V1}.${scanRunId}.${accessSecret}`;
}

function parseAccessKey(accessKey) {
  const normalized = assertNonEmptyString(accessKey, "accessKey", 180);
  const parts = normalized.split(".");
  if (parts.length !== 3 || parts[0] !== PUBLIC_LITE_ACCESS_KEY_PREFIX_V1 ||
      !/^[a-f0-9]{64}$/.test(parts[1]) ||
      !/^[A-Za-z0-9_-]{43}$/.test(parts[2])) {
    fail("not-found", "Tarama bulunamadı veya erişim anahtarı geçersiz.");
  }
  return {scanRunId: parts[1], accessSecret: parts[2]};
}

function buildPublicLiteStartCommand({
  data,
  appId,
  networkAddress,
  secretKey,
  now,
  rateLimit = PUBLIC_LITE_RATE_LIMIT_DEFAULT,
}) {
  const input = normalizeStartData(data);
  const normalizedAppId = normalizeAppId(appId);
  const normalizedNetworkAddress = normalizeNetworkAddress(networkAddress);
  const timestamp = normalizeNow(now);
  if (!Number.isInteger(rateLimit) || rateLimit < 1 || rateLimit > 1000) {
    throw new TypeError("rateLimit must be an integer from 1 to 1000");
  }

  const nonceDigestSha256 = sha256Hex(input.anonymousClientNonce);
  const targetCore = {
    brandNameNormalized: input.brandNameNormalized,
    officialHost: input.officialHost,
    officialWebsiteCanonicalUrl: input.officialWebsiteCanonicalUrl,
  };
  const targetFingerprintSha256 = canonicalJsonDigestSha256(targetCore);
  const requestPayload = {
    requestId: input.requestId,
    targetFingerprintSha256,
    anonymousClientNonceDigestSha256: nonceDigestSha256,
    scanMode: "quick",
    accessTier: "publicLite",
  };
  const requestFingerprintSha256 =
    canonicalJsonDigestSha256(requestPayload);
  const scanRunId = riskScanRunId({
    requestId: input.requestId,
    requestFingerprintSha256,
  });
  const accessSecret = hmacBase64Url(
      secretKey,
      "risk-scan-public-lite-access-secret-v1",
      [scanRunId, input.requestId, requestFingerprintSha256]);
  const accessSecretDigestSha256 = sha256Hex(accessSecret);
  const ipHashSha256 = hmacHex(
      secretKey,
      "risk-scan-public-lite-network-hash-v1",
      [normalizedAppId, normalizedNetworkAddress]);
  const nonceBucketDigestSha256 = hmacHex(
      secretKey,
      "risk-scan-public-lite-client-nonce-v1",
      [normalizedAppId, input.anonymousClientNonce]);
  const networkScopeNonceDigestSha256 = hmacHex(
      secretKey,
      "risk-scan-public-lite-network-scope-v1",
      [normalizedAppId]);
  const clientScopeIpHashSha256 = hmacHex(
      secretKey,
      "risk-scan-public-lite-client-scope-v1",
      [normalizedAppId]);

  const windowStarted = windowStart(timestamp);
  const windowStartedAt = windowStarted.toISOString();
  const windowCode = windowStartedAt.slice(0, 13);
  const purgeAt = new Date(
      windowStarted.getTime() + PUBLIC_LITE_RATE_LIMIT_PURGE_MS)
      .toISOString();
  function buildRateLimitInput(
      bucketIpHashSha256, bucketNonceDigestSha256) {
    return {
      bucketId: riskScanRateLimitBucketId({
        appId: normalizedAppId,
        ipHashSha256: bucketIpHashSha256,
        anonymousClientNonceDigestSha256: bucketNonceDigestSha256,
        windowCode,
      }),
      appId: normalizedAppId,
      ipHashSha256: bucketIpHashSha256,
      anonymousClientNonceDigestSha256: bucketNonceDigestSha256,
      windowCode,
      windowStartedAt,
      purgeAt,
      limit: rateLimit,
      now: timestamp.toISOString(),
    };
  }
  const rateLimitRecords = [
    buildRateLimitInput(ipHashSha256, networkScopeNonceDigestSha256),
    buildRateLimitInput(clientScopeIpHashSha256, nonceBucketDigestSha256),
  ];
  const createdAt = timestamp.toISOString();
  const expiresAt = new Date(
      timestamp.getTime() + PUBLIC_LITE_RUN_LIFETIME_MS).toISOString();

  const run = {
    scanRunId,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    coverageStatus: "insufficient",
    target: {...targetCore, targetFingerprintSha256},
    requestId: input.requestId,
    requestFingerprintSha256,
    deduplicationFingerprintSha256: canonicalJsonDigestSha256({
      scanMode: "quick",
      targetFingerprintSha256,
    }),
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt,
    updatedAt: createdAt,
    expiresAt,
    accessSecretDigestSha256,
    accessSecretAlgorithm: PUBLIC_LITE_ACCESS_SECRET_ALGORITHM_V1,
    latestReportId: null,
  };
  const channels = ["similarDomains", "openWeb", "marketplaceLimited"]
      .map((channelCode) => ({
        scanRunId,
        channelCode,
        status: "queued",
        coverageStatus: "insufficient",
        observationCount: 0,
        findingCount: 0,
        limitReasonCodes: [],
        attemptCount: 0,
        startedAt: null,
        completedAt: null,
        updatedAt: createdAt,
      }));
  return {
    contractVersion: PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
    accessKey: buildAccessKey(scanRunId, accessSecret),
    accessSecretDigestSha256,
    run,
    channels,
    rateLimitRecords,
  };
}

module.exports = {
  ACCESS_KEYS,
  PUBLIC_LITE_ACCESS_KEY_PREFIX_V1,
  PUBLIC_LITE_ACCESS_SECRET_ALGORITHM_V1,
  PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
  PUBLIC_LITE_HMAC_ALGORITHM_V1,
  PUBLIC_LITE_RATE_LIMIT_DEFAULT,
  PUBLIC_LITE_RATE_LIMIT_PURGE_MS,
  PUBLIC_LITE_RATE_LIMIT_WINDOW_MS,
  PUBLIC_LITE_RUN_LIFETIME_MS,
  RiskScanPublicLiteError,
  START_KEYS,
  assertSecretKey,
  buildAccessKey,
  buildPublicLiteStartCommand,
  hmacBase64Url,
  hmacHex,
  normalizeAccessData,
  normalizeAppId,
  normalizeBrandName,
  normalizeNetworkAddress,
  normalizeOfficialWebsite,
  normalizeStartData,
  parseAccessKey,
  windowStart,
};
