"use strict";

const {
  STORAGE_SCHEMA_VERSION_V1,
  accessTiers,
  acquisitionStatuses,
  assertDocumentId,
  assertEnum,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertOptionalString,
  assertPlainObject,
  assertSha256Hex,
  channelCodes,
  channelStatuses,
  confidenceLevels,
  contractVersions,
  coverageStatuses,
  findingTypes,
  identityModes,
  impactLevels,
  interventionDifficulties,
  observationSourceTypes,
  promotionStatuses,
  recommendationCodes,
  reportRecommendedActions,
  reviewStatuses,
  riskLevels,
  runStatuses,
  scanModes,
} = require("./contracts");
const {
  canonicalJsonDigestSha256,
} = require("./canonical");
const {
  riskScanFindingId,
  riskScanObservationId,
  riskScanReportId,
  riskScanRunId,
} = require("./identifiers");
const {
  assertAutomaticReviewStatus,
  assertIdentityScope,
  assertImmutableRecord,
} = require("./lifecycle");

const {
  splitRetentionStorageFields,
} = require("./retention_firestore_adapter");
const ACCESS_SECRET_ALGORITHM_V1 = "sha256";
const STORAGE_FINGERPRINT_ALGORITHM_V1 = "sha256-canonical-json-v1";

function assertNonNegativeInteger(value, label) {
  if (!Number.isInteger(value) || value < 0) {
    throw new TypeError(`${label} must be a non-negative integer`);
  }
  return value;
}

function nullableIso(value, label) {
  if (value === null || value === undefined) return null;
  return assertIsoTimestamp(value, label);
}

function nullableDocumentId(value, label) {
  if (value === null || value === undefined) return null;
  return assertDocumentId(value, label);
}

function nullableDigest(value, label) {
  if (value === null || value === undefined) return null;
  return assertSha256Hex(value, label);
}

function uniqueStrings(values, label, maximum = 64) {
  if (!Array.isArray(values)) {
    throw new TypeError(`${label} must be an array`);
  }
  const normalized = values.map((value, index) =>
    assertNonEmptyString(value, `${label}[${index}]`, 180));
  if (normalized.length > maximum) {
    throw new TypeError(`${label} exceeds its maximum size`);
  }
  if (new Set(normalized).size !== normalized.length) {
    throw new TypeError(`${label} must not contain duplicates`);
  }
  return normalized;
}

function withStorageFingerprint(document) {
  const {
    fingerprintDocument,
    retentionStorageFields,
  } = splitRetentionStorageFields(document);
  const withoutFingerprint = {...fingerprintDocument};
  delete withoutFingerprint.storageFingerprintAlgorithm;
  delete withoutFingerprint.storageFingerprintSha256;
  const fingerprintPayload = {
    ...withoutFingerprint,
    storageFingerprintAlgorithm: STORAGE_FINGERPRINT_ALGORITHM_V1,
  };
  return {
    ...fingerprintPayload,
    ...retentionStorageFields,
    storageFingerprintSha256:
      canonicalJsonDigestSha256(fingerprintPayload),
  };
}

function assertReplayMatch(existing, expected, label) {
  assertPlainObject(existing, `${label}.existing`);
  assertPlainObject(expected, `${label}.expected`);
  const existingFingerprint = assertSha256Hex(
      existing.storageFingerprintSha256,
      `${label}.existing.storageFingerprintSha256`);
  const expectedFingerprint = assertSha256Hex(
      expected.storageFingerprintSha256,
      `${label}.expected.storageFingerprintSha256`);
  if (existingFingerprint !== expectedFingerprint) {
    const error = new Error(`${label} replay conflicts with stored data`);
    error.code = "conflict";
    throw error;
  }
  return true;
}

function buildTarget(target) {
  assertPlainObject(target, "target");
  const output = {
    brandNameNormalized: assertNonEmptyString(
        target.brandNameNormalized, "target.brandNameNormalized", 300),
    officialHost: assertNonEmptyString(
        target.officialHost, "target.officialHost", 512),
    officialWebsiteCanonicalUrl: assertOptionalString(
        target.officialWebsiteCanonicalUrl,
        "target.officialWebsiteCanonicalUrl",
        4096),
    targetFingerprintSha256: assertSha256Hex(
        target.targetFingerprintSha256,
        "target.targetFingerprintSha256"),
  };
  return output;
}

function buildRunDocument(input) {
  assertPlainObject(input, "run");
  const requestId = assertNonEmptyString(input.requestId, "requestId", 180);
  const requestFingerprintSha256 = assertSha256Hex(
      input.requestFingerprintSha256, "requestFingerprintSha256");
  const expectedId = riskScanRunId({requestId, requestFingerprintSha256});
  const scanRunId = assertDocumentId(input.scanRunId, "scanRunId");
  if (scanRunId !== expectedId) {
    throw new TypeError("scanRunId does not match deterministic identity");
  }

  const run = {
    contractVersion: contractVersions.run,
    storageSchemaVersion: STORAGE_SCHEMA_VERSION_V1,
    scanRunId,
    scanMode: assertEnum(input.scanMode, scanModes, "scanMode"),
    accessTier: assertEnum(input.accessTier, accessTiers, "accessTier"),
    identityMode: assertEnum(
        input.identityMode, identityModes, "identityMode"),
    status: assertEnum(input.status, runStatuses, "status"),
    coverageStatus: assertEnum(
        input.coverageStatus, coverageStatuses, "coverageStatus"),
    target: buildTarget(input.target),
    requestId,
    requestFingerprintSha256,
    deduplicationFingerprintSha256: assertSha256Hex(
        input.deduplicationFingerprintSha256,
        "deduplicationFingerprintSha256"),
    tenantId: nullableDocumentId(input.tenantId, "tenantId"),
    canonicalBrandId: nullableDocumentId(
        input.canonicalBrandId, "canonicalBrandId"),
    createdByUid: nullableDocumentId(input.createdByUid, "createdByUid"),
    createdAt: assertIsoTimestamp(input.createdAt, "createdAt"),
    updatedAt: assertIsoTimestamp(input.updatedAt, "updatedAt"),
    expiresAt: assertIsoTimestamp(input.expiresAt, "expiresAt"),
    accessSecretDigestSha256: nullableDigest(
        input.accessSecretDigestSha256, "accessSecretDigestSha256"),
    accessSecretAlgorithm: assertOptionalString(
        input.accessSecretAlgorithm, "accessSecretAlgorithm", 64),
    latestReportId: nullableDocumentId(
        input.latestReportId, "latestReportId"),
  };
  assertIdentityScope(run);

  if (run.accessTier === "publicLite") {
    if (run.identityMode !== "anonymous") {
      throw new TypeError("publicLite run must remain anonymous");
    }
    if (run.accessSecretDigestSha256 === null ||
        run.accessSecretAlgorithm !== ACCESS_SECRET_ALGORITHM_V1) {
      throw new TypeError("publicLite run requires a digested access secret");
    }
  } else if (run.accessSecretDigestSha256 !== null ||
      run.accessSecretAlgorithm !== null) {
    throw new TypeError("registered run must not store an access secret");
  }
  if (Date.parse(run.expiresAt) <= Date.parse(run.createdAt)) {
    throw new TypeError("expiresAt must be after createdAt");
  }
  return withStorageFingerprint(run);
}

function buildChannelDocument(input) {
  assertPlainObject(input, "channel");
  const channel = {
    contractVersion: contractVersions.channel,
    storageSchemaVersion: STORAGE_SCHEMA_VERSION_V1,
    scanRunId: assertDocumentId(input.scanRunId, "scanRunId"),
    channelCode: assertEnum(
        input.channelCode, channelCodes, "channelCode"),
    status: assertEnum(input.status, channelStatuses, "status"),
    coverageStatus: assertEnum(
        input.coverageStatus, coverageStatuses, "coverageStatus"),
    observationCount: assertNonNegativeInteger(
        input.observationCount, "observationCount"),
    findingCount: assertNonNegativeInteger(
        input.findingCount, "findingCount"),
    limitReasonCodes: uniqueStrings(
        input.limitReasonCodes, "limitReasonCodes", 32),
    attemptCount: assertNonNegativeInteger(
        input.attemptCount, "attemptCount"),
    startedAt: nullableIso(input.startedAt, "startedAt"),
    completedAt: nullableIso(input.completedAt, "completedAt"),
    updatedAt: assertIsoTimestamp(input.updatedAt, "updatedAt"),
  };
  return withStorageFingerprint(channel);
}

function buildObservationDocument(input) {
  assertPlainObject(input, "observation");
  const scanRunId = assertDocumentId(input.scanRunId, "scanRunId");
  const channelCode = assertEnum(
      input.channelCode, channelCodes, "channelCode");
  const sourceUrlCanonical = assertNonEmptyString(
      input.sourceUrlCanonical, "sourceUrlCanonical", 4096);
  const contentFingerprintSha256 = assertSha256Hex(
      input.contentFingerprintSha256, "contentFingerprintSha256");
  const expectedId = riskScanObservationId({
    scanRunId,
    channelCode,
    sourceUrlCanonical,
    contentFingerprintSha256,
  });
  const observationId = assertDocumentId(
      input.observationId, "observationId");
  if (observationId !== expectedId) {
    throw new TypeError(
        "observationId does not match deterministic identity");
  }

  const observation = {
    contractVersion: contractVersions.observation,
    storageSchemaVersion: STORAGE_SCHEMA_VERSION_V1,
    scanRunId,
    observationId,
    channelCode,
    sourceType: assertEnum(
        input.sourceType, observationSourceTypes, "sourceType"),
    acquisitionStatus: assertEnum(
        input.acquisitionStatus,
        acquisitionStatuses,
        "acquisitionStatus"),
    sourceUrlCanonical,
    sourceHost: assertNonEmptyString(
        input.sourceHost, "sourceHost", 512),
    sourceTitleSnapshot: assertOptionalString(
        input.sourceTitleSnapshot, "sourceTitleSnapshot", 1000),
    contentFingerprintSha256,
    observedAt: assertIsoTimestamp(input.observedAt, "observedAt"),
    acquiredAt: nullableIso(input.acquiredAt, "acquiredAt"),
    createdAt: assertIsoTimestamp(input.createdAt, "createdAt"),
    immutable: input.immutable,
  };
  assertImmutableRecord(observation, "observation");
  return withStorageFingerprint(observation);
}

function buildFindingDocument(input) {
  assertPlainObject(input, "finding");
  const scanRunId = assertDocumentId(input.scanRunId, "scanRunId");
  const findingType = assertEnum(
      input.findingType, findingTypes, "findingType");
  const observationRefs = uniqueStrings(
      input.observationRefs, "observationRefs", 100)
      .map((value) => assertDocumentId(value, "observationRef"))
      .sort();
  if (observationRefs.length === 0) {
    throw new TypeError("observationRefs must not be empty");
  }
  const expectedId = riskScanFindingId({
    scanRunId,
    findingType,
    observationRefs,
  });
  const findingId = assertDocumentId(input.findingId, "findingId");
  if (findingId !== expectedId) {
    throw new TypeError("findingId does not match deterministic identity");
  }

  const reviewStatus = assertEnum(
      input.reviewStatus, reviewStatuses, "reviewStatus");
  const reviewedAt = nullableIso(input.reviewedAt, "reviewedAt");
  const reviewedByUid = nullableDocumentId(
      input.reviewedByUid, "reviewedByUid");
  if (reviewedAt === null && reviewedByUid === null) {
    assertAutomaticReviewStatus(reviewStatus);
  } else if (reviewedAt === null || reviewedByUid === null) {
    throw new TypeError(
        "reviewedAt and reviewedByUid must be provided together");
  }

  const promotionStatus = assertEnum(
      input.promotionStatus, promotionStatuses, "promotionStatus");
  const promotionRequestId = nullableDocumentId(
      input.promotionRequestId, "promotionRequestId");
  const promotedSignalId = nullableDocumentId(
      input.promotedSignalId, "promotedSignalId");
  const promotedAt = nullableIso(input.promotedAt, "promotedAt");
  if (promotionStatus === "notRequested" &&
      [promotionRequestId, promotedSignalId, promotedAt]
          .some((value) => value !== null)) {
    throw new TypeError(
        "notRequested finding must not contain promotion binding");
  }
  if (promotionStatus === "promoted" &&
      [promotionRequestId, promotedSignalId, promotedAt]
          .some((value) => value === null)) {
    throw new TypeError("promoted finding requires complete binding");
  }

  const finding = {
    contractVersion: contractVersions.finding,
    storageSchemaVersion: STORAGE_SCHEMA_VERSION_V1,
    scanRunId,
    findingId,
    channelCode: assertEnum(
        input.channelCode, channelCodes, "channelCode"),
    findingType,
    observationRefs,
    riskLevel: assertEnum(input.riskLevel, riskLevels, "riskLevel"),
    confidenceLevel: assertEnum(
        input.confidenceLevel, confidenceLevels, "confidenceLevel"),
    impactLevel: assertEnum(
        input.impactLevel, impactLevels, "impactLevel"),
    interventionDifficulty: assertEnum(
        input.interventionDifficulty,
        interventionDifficulties,
        "interventionDifficulty"),
    reviewStatus,
    recommendationCode: assertEnum(
        input.recommendationCode,
        recommendationCodes,
        "recommendationCode"),
    title: assertNonEmptyString(input.title, "title", 300),
    summary: assertNonEmptyString(input.summary, "summary", 4000),
    reviewedAt,
    reviewedByUid,
    promotionStatus,
    promotionRequestId,
    promotedSignalId,
    promotedAt,
    createdAt: assertIsoTimestamp(input.createdAt, "createdAt"),
    updatedAt: assertIsoTimestamp(input.updatedAt, "updatedAt"),
  };
  return withStorageFingerprint(finding);
}

function buildFindingSnapshot(input) {
  assertPlainObject(input, "findingSnapshot");
  return {
    findingId: assertDocumentId(input.findingId, "findingId"),
    findingType: assertEnum(
        input.findingType, findingTypes, "findingType"),
    riskLevel: assertEnum(input.riskLevel, riskLevels, "riskLevel"),
    confidenceLevel: assertEnum(
        input.confidenceLevel, confidenceLevels, "confidenceLevel"),
    impactLevel: assertEnum(
        input.impactLevel, impactLevels, "impactLevel"),
    interventionDifficulty: assertEnum(
        input.interventionDifficulty,
        interventionDifficulties,
        "interventionDifficulty"),
    reviewStatus: assertEnum(
        input.reviewStatus, reviewStatuses, "reviewStatus"),
    recommendationCode: assertEnum(
        input.recommendationCode,
        recommendationCodes,
        "recommendationCode"),
    title: assertNonEmptyString(input.title, "title", 300),
    summary: assertNonEmptyString(input.summary, "summary", 4000),
  };
}

function buildChannelSnapshot(input) {
  assertPlainObject(input, "channelSnapshot");
  return {
    channelCode: assertEnum(
        input.channelCode, channelCodes, "channelCode"),
    status: assertEnum(input.status, channelStatuses, "status"),
    coverageStatus: assertEnum(
        input.coverageStatus, coverageStatuses, "coverageStatus"),
    observationCount: assertNonNegativeInteger(
        input.observationCount, "observationCount"),
    findingCount: assertNonNegativeInteger(
        input.findingCount, "findingCount"),
  };
}

function buildReportDocument(input) {
  assertPlainObject(input, "report");
  const scanRunId = assertDocumentId(input.scanRunId, "scanRunId");
  const reportVersion = assertNonEmptyString(
      input.reportVersion, "reportVersion", 64);
  const expectedId = riskScanReportId({scanRunId, reportVersion});
  const reportId = assertDocumentId(input.reportId, "reportId");
  if (reportId !== expectedId) {
    throw new TypeError("reportId does not match deterministic identity");
  }

  const topFindingSnapshots = input.topFindingSnapshots;
  if (!Array.isArray(topFindingSnapshots) ||
      topFindingSnapshots.length > 20) {
    throw new TypeError(
        "topFindingSnapshots must be an array with at most 20 items");
  }
  const channelDistribution = input.channelDistribution;
  if (!Array.isArray(channelDistribution) ||
      channelDistribution.length === 0) {
    throw new TypeError("channelDistribution must be a non-empty array");
  }
  const normalizedChannels = channelDistribution.map(buildChannelSnapshot);
  const channelSet = new Set(
      normalizedChannels.map((item) => item.channelCode));
  if (channelSet.size !== normalizedChannels.length) {
    throw new TypeError("channelDistribution contains duplicate channels");
  }

  const report = {
    contractVersion: contractVersions.report,
    storageSchemaVersion: STORAGE_SCHEMA_VERSION_V1,
    scanRunId,
    reportId,
    reportVersion,
    generatedAt: assertIsoTimestamp(input.generatedAt, "generatedAt"),
    status: assertEnum(input.status, runStatuses, "status"),
    coverageStatus: assertEnum(
        input.coverageStatus, coverageStatuses, "coverageStatus"),
    overallRiskLevel: assertEnum(
        input.overallRiskLevel, riskLevels, "overallRiskLevel"),
    overallConfidenceLevel: assertEnum(
        input.overallConfidenceLevel,
        confidenceLevels,
        "overallConfidenceLevel"),
    recommendedAction: assertEnum(
        input.recommendedAction,
        reportRecommendedActions,
        "recommendedAction"),
    summary: assertNonEmptyString(input.summary, "summary", 8000),
    findingCount: assertNonNegativeInteger(
        input.findingCount, "findingCount"),
    observationCount: assertNonNegativeInteger(
        input.observationCount, "observationCount"),
    topFindingSnapshots: topFindingSnapshots.map(buildFindingSnapshot),
    channelDistribution: normalizedChannels,
    immutable: input.immutable,
  };
  assertImmutableRecord(report, "report");
  if (!["completed", "completedWithLimits"].includes(report.status)) {
    throw new TypeError("report status must be terminal success");
  }

  const reportDigestSha256 = canonicalJsonDigestSha256(report);
  if (input.reportDigestSha256 !== undefined &&
      input.reportDigestSha256 !== reportDigestSha256) {
    throw new TypeError("reportDigestSha256 does not match report snapshot");
  }
  return withStorageFingerprint({
    ...report,
    reportDigestSha256,
  });
}

module.exports = {
  ACCESS_SECRET_ALGORITHM_V1,
  STORAGE_FINGERPRINT_ALGORITHM_V1,
  assertNonNegativeInteger,
  assertReplayMatch,
  buildChannelDocument,
  buildFindingDocument,
  buildObservationDocument,
  buildReportDocument,
  buildRunDocument,
  withStorageFingerprint,
};
