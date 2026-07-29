"use strict";

const {
  assertDocumentId,
  assertEnum,
  assertNonEmptyString,
  assertSha256Hex,
  channelCodes,
  findingTypes,
} = require("./contracts");
const {lengthPrefixedDigestSha256} = require("./canonical");

function deriveId(namespace, parts) {
  return lengthPrefixedDigestSha256(namespace, parts);
}

function riskScanRunId({requestId, requestFingerprintSha256}) {
  return deriveId("risk-scan-run-v1", [
    assertNonEmptyString(requestId, "requestId", 180),
    assertSha256Hex(requestFingerprintSha256, "requestFingerprintSha256"),
  ]);
}

function riskScanObservationId({
  scanRunId,
  channelCode,
  sourceUrlCanonical,
  contentFingerprintSha256,
}) {
  return deriveId("risk-scan-observation-v1", [
    assertDocumentId(scanRunId, "scanRunId"),
    assertEnum(channelCode, channelCodes, "channelCode"),
    assertNonEmptyString(sourceUrlCanonical, "sourceUrlCanonical", 4096),
    assertSha256Hex(
        contentFingerprintSha256, "contentFingerprintSha256"),
  ]);
}

function riskScanFindingId({
  scanRunId,
  findingType,
  observationRefs,
}) {
  if (!Array.isArray(observationRefs) || observationRefs.length === 0) {
    throw new TypeError("observationRefs must be a non-empty array");
  }
  const normalizedRefs = [...new Set(observationRefs.map((value) =>
    assertDocumentId(value, "observationRef")))].sort();
  return deriveId("risk-scan-finding-v1", [
    assertDocumentId(scanRunId, "scanRunId"),
    assertEnum(findingType, findingTypes, "findingType"),
    ...normalizedRefs,
  ]);
}

function riskScanReportId({scanRunId, reportVersion}) {
  return deriveId("risk-scan-report-v1", [
    assertDocumentId(scanRunId, "scanRunId"),
    assertNonEmptyString(reportVersion, "reportVersion", 64),
  ]);
}

function riskScanClaimId({scanRunId, requestId}) {
  return deriveId("risk-scan-claim-v1", [
    assertDocumentId(scanRunId, "scanRunId"),
    assertNonEmptyString(requestId, "requestId", 180),
  ]);
}

function riskScanRateLimitBucketId({
  appId,
  ipHashSha256,
  anonymousClientNonceDigestSha256,
  windowCode,
}) {
  return deriveId("risk-scan-rate-limit-v1", [
    assertNonEmptyString(appId, "appId", 512),
    assertSha256Hex(ipHashSha256, "ipHashSha256"),
    assertSha256Hex(
        anonymousClientNonceDigestSha256,
        "anonymousClientNonceDigestSha256"),
    assertNonEmptyString(windowCode, "windowCode", 64),
  ]);
}

module.exports = {
  deriveId,
  riskScanClaimId,
  riskScanFindingId,
  riskScanObservationId,
  riskScanRateLimitBucketId,
  riskScanReportId,
  riskScanRunId,
};
