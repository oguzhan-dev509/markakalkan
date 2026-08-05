'use strict';

const {
  normalizeChannelResult,
} = require('../contracts');
const {
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  normalizeChannelAdapterResult,
} = require('./marketplace_limited_contract');

const SOURCE_TYPE = 'marketplace_public_listing';

function normalizeIsoTimestamp(value, label) {
  if (typeof value !== 'string') {
    throw new TypeError(`${label} must be a string`);
  }
  const normalized = value.trim();
  const timestamp = Date.parse(normalized);
  if (
    !normalized ||
    !Number.isFinite(timestamp) ||
    new Date(timestamp).toISOString() !== normalized
  ) {
    throw new TypeError(
      `${label} must be a canonical ISO-8601 timestamp`,
    );
  }
  return normalized;
}

function mapObservation(
  result,
  observation,
) {
  return {
    observationId: observation.observationId,
    observedAt: result.acquisition.acquiredAt,
    sourceUrl: observation.canonicalUrl,
    sourceHost: observation.sourceHost,
    sourceType: SOURCE_TYPE,
    title: observation.title,
    snippet: observation.title,
    imageUrls: [],
    signals: {
      adapterCode: result.adapterCode,
      rank: observation.rank,
      targetFingerprintSha256:
        result.targetFingerprintSha256,
    },
    evidence: {
      sha256: observation.evidenceSha256,
      acquisitionOutcomeCode:
        result.acquisition.outcomeCode,
      responseBytes:
        result.acquisition.responseBytes,
    },
  };
}

function mapMarketplaceLimitedResultToChannelResult(
  input,
  {
    completedAt,
  } = {},
) {
  const result = normalizeChannelAdapterResult(input);
  const normalizedCompletedAt = normalizeIsoTimestamp(
    completedAt,
    'completedAt',
  );
  const startedAt = result.acquisition.acquiredAt;
  if (
    Date.parse(normalizedCompletedAt) <
    Date.parse(startedAt)
  ) {
    throw new TypeError(
      'completedAt must not precede acquisition.acquiredAt',
    );
  }

  const channelResult = {
    channelCode: result.channelCode,
    status: result.status,
    startedAt,
    completedAt: normalizedCompletedAt,
    observations: result.observations.map(
      (observation) => mapObservation(
        result,
        observation,
      ),
    ),
    diagnostics: {
      channelAdapterContractVersion:
        CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
      adapterCode: result.adapterCode,
      executionId: result.executionId,
      scanRunId: result.scanRunId,
      targetFingerprintSha256:
        result.targetFingerprintSha256,
      idempotencyKey: result.idempotencyKey,
      attemptedUrl:
        result.acquisition.attemptedUrl,
      finalUrl: result.acquisition.finalUrl,
      httpStatus: result.acquisition.httpStatus,
      acquisitionOutcomeCode:
        result.acquisition.outcomeCode,
      acquisitionEvidenceSha256:
        result.acquisition.evidenceSha256,
      responseBytes:
        result.acquisition.responseBytes,
      retryable: result.acquisition.retryable,
      candidateCount:
        result.summary.candidateCount,
      truncated: result.summary.truncated,
      error: result.error,
    },
  };

  return normalizeChannelResult(channelResult, 0);
}

module.exports = {
  SOURCE_TYPE,
  mapMarketplaceLimitedResultToChannelResult,
  normalizeIsoTimestamp,
};
