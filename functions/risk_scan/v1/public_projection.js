"use strict";

const {
  PUBLIC_PROJECTION_VERSION_V1,
  assertPlainObject,
} = require("./contracts");

const sensitiveKeyPattern = new RegExp(
    "(?:secret|digest|fingerprint|token|tenant|uid|" +
    "canonicalBrand|requestId|promotionRequest|promotedSignal|" +
    "firestore|documentPath)",
    "i");

function replaceControlCharacters(value) {
  return Array.from(value, (character) => {
    const codePoint = character.codePointAt(0);
    return codePoint <= 31 || codePoint === 127 ? " " : character;
  }).join("");
}

function cleanText(value, maximum) {
  if (typeof value !== "string") return null;
  const cleaned = replaceControlCharacters(value)
      .replace(/\s+/g, " ").trim();
  if (!cleaned) return null;
  return cleaned.slice(0, maximum);
}

function cleanNullable(value) {
  return value === undefined ? null : value;
}

function targetProjection(target) {
  if (!target || typeof target !== "object") return null;
  return {
    brandNameNormalized: cleanText(target.brandNameNormalized, 240),
    officialHost: cleanText(target.officialHost, 255),
  };
}

function channelProjection(channel) {
  assertPlainObject(channel, "channel");
  return {
    channelCode: cleanNullable(channel.channelCode),
    status: cleanNullable(channel.status),
    coverageStatus: cleanNullable(channel.coverageStatus),
    observationCount: Number(channel.observationCount || 0),
    findingCount: Number(channel.findingCount || 0),
    limitReasonCodes: Array.isArray(channel.limitReasonCodes) ?
      channel.limitReasonCodes.map((item) => cleanText(item, 120))
          .filter(Boolean).slice(0, 20) : [],
    startedAt: cleanNullable(channel.startedAt),
    completedAt: cleanNullable(channel.completedAt),
  };
}

function findingProjection(finding) {
  assertPlainObject(finding, "finding");
  return {
    findingId: cleanNullable(finding.findingId),
    findingType: cleanNullable(finding.findingType),
    channelCode: cleanNullable(finding.channelCode),
    riskLevel: cleanNullable(finding.riskLevel),
    confidenceLevel: cleanNullable(finding.confidenceLevel),
    impactLevel: cleanNullable(finding.impactLevel),
    interventionDifficulty: cleanNullable(
        finding.interventionDifficulty),
    reviewStatus: cleanNullable(finding.reviewStatus),
    recommendationCode: cleanNullable(finding.recommendationCode),
    title: cleanText(finding.title, 240),
    summary: cleanText(finding.summary, 1200),
  };
}

function reportProjection(report) {
  if (!report) return null;
  assertPlainObject(report, "report");
  return {
    reportId: cleanNullable(report.reportId),
    reportVersion: cleanNullable(report.reportVersion),
    generatedAt: cleanNullable(report.generatedAt),
    status: cleanNullable(report.status),
    coverageStatus: cleanNullable(report.coverageStatus),
    overallRiskLevel: cleanNullable(report.overallRiskLevel),
    overallConfidenceLevel: cleanNullable(report.overallConfidenceLevel),
    recommendedAction: cleanNullable(report.recommendedAction),
    summary: cleanText(report.summary, 2000),
    findingCount: Number(report.findingCount || 0),
    observationCount: Number(report.observationCount || 0),
    topFindingSnapshots: Array.isArray(report.topFindingSnapshots) ?
      report.topFindingSnapshots.map(findingProjection).slice(0, 20) : [],
    channelDistribution: Array.isArray(report.channelDistribution) ?
      report.channelDistribution.map(channelProjection).slice(0, 20) : [],
  };
}

function assertNoSensitiveKeys(value, path = "$") {
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      assertNoSensitiveKeys(item, `${path}[${index}]`));
    return value;
  }
  if (!value || typeof value !== "object") return value;
  for (const [key, child] of Object.entries(value)) {
    if (sensitiveKeyPattern.test(key)) {
      throw new TypeError(`${path}.${key} is sensitive`);
    }
    assertNoSensitiveKeys(child, `${path}.${key}`);
  }
  return value;
}

function buildPublicLiteProjection({run, channels = [], report = null}) {
  assertPlainObject(run, "run");
  if (!Array.isArray(channels)) {
    throw new TypeError("channels must be an array");
  }
  const projection = {
    contractVersion: PUBLIC_PROJECTION_VERSION_V1,
    scanRunId: cleanNullable(run.scanRunId),
    scanMode: cleanNullable(run.scanMode),
    accessTier: cleanNullable(run.accessTier),
    identityMode: cleanNullable(run.identityMode),
    status: cleanNullable(run.status),
    coverageStatus: cleanNullable(run.coverageStatus),
    createdAt: cleanNullable(run.createdAt),
    updatedAt: cleanNullable(run.updatedAt),
    expiresAt: cleanNullable(run.expiresAt),
    target: targetProjection(run.target),
    channels: channels.map(channelProjection),
    report: reportProjection(report),
  };
  assertNoSensitiveKeys(projection);
  return projection;
}

module.exports = {
  assertNoSensitiveKeys,
  buildPublicLiteProjection,
  channelProjection,
  cleanText,
  findingProjection,
  reportProjection,
  targetProjection,
};
