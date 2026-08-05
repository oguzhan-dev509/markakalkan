'use strict';

const crypto = require('node:crypto');

const MARKETPLACE_LIMITED_CONTRACT_VERSION =
  'risk-scan-public-lite-marketplace-limited-v1';
const CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION =
  'risk-scan-public-lite-channel-adapter-result-v1';
const DISPATCH_ENVELOPE_CONTRACT_VERSION =
  'risk-scan-public-lite-dispatch-envelope-v1';
const CHANNEL_CODE = 'marketplaceLimited';
const ADAPTER_CODE = 'trendyol_public_listing_v1';

const EXECUTION_STATUSES = Object.freeze([
  'completed',
  'dataUnavailable',
  'failed',
]);

const CHANNEL_ADAPTER_RESULT_KEYS = Object.freeze([
  'contractVersion',
  'channelCode',
  'adapterCode',
  'executionId',
  'scanRunId',
  'targetFingerprintSha256',
  'idempotencyKey',
  'status',
  'acquisition',
  'observations',
  'summary',
  'error',
]);

const FORBIDDEN_SCOPE_FIELDS = Object.freeze([
  'tenantId',
  'brandId',
  'canonicalBrandId',
  'createdByUid',
  'updatedByUid',
  'actorUid',
]);

function isPlainObject(value) {
  if (
    value === null ||
    typeof value !== 'object' ||
    Array.isArray(value)
  ) {
    return false;
  }

  const prototype = Object.getPrototypeOf(value);
  return (
    prototype === Object.prototype ||
    prototype === null
  );
}

function assertPlainObject(value, label) {
  if (!isPlainObject(value)) {
    throw new TypeError(`${label} must be a plain object`);
  }
  return value;
}

function assertExactKeys(value, expected, label) {
  assertPlainObject(value, label);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length ||
    actual.some((key, index) => key !== wanted[index])
  ) {
    throw new TypeError(`${label} keys are invalid`);
  }
  return value;
}

function normalizeRequiredString(value, label, maxLength = 500) {
  if (typeof value !== 'string') {
    throw new TypeError(`${label} must be a string`);
  }

  const normalized = value.trim();
  if (!normalized) {
    throw new TypeError(`${label} must not be empty`);
  }
  if (normalized.length > maxLength) {
    throw new RangeError(
      `${label} must be at most ${maxLength} characters`,
    );
  }
  return normalized;
}

function normalizeOptionalString(value, label, maxLength = 500) {
  if (value === undefined || value === null) {
    return null;
  }
  return normalizeRequiredString(value, label, maxLength);
}

function assertSha256(value, label) {
  const normalized = normalizeRequiredString(value, label, 64);
  if (!/^[0-9a-f]{64}$/u.test(normalized)) {
    throw new TypeError(`${label} must be a lowercase SHA-256 hex value`);
  }
  return normalized;
}

function normalizeHttpUrl(value, label) {
  const normalized = normalizeRequiredString(value, label, 2048);
  let parsed;
  try {
    parsed = new URL(normalized);
  } catch (error) {
    throw new TypeError(`${label} must be an absolute URL`, {
      cause: error,
    });
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new TypeError(`${label} must use http or https`);
  }
  if (parsed.username || parsed.password) {
    throw new TypeError(`${label} must not contain URL credentials`);
  }

  parsed.hash = '';
  parsed.hostname = parsed.hostname.toLowerCase();
  if (
    (parsed.protocol === 'https:' && parsed.port === '443') ||
    (parsed.protocol === 'http:' && parsed.port === '80')
  ) {
    parsed.port = '';
  }

  const sortedParameters = [...parsed.searchParams.entries()]
    .sort(([leftKey, leftValue], [rightKey, rightValue]) => {
      if (leftKey === rightKey) {
        return leftValue.localeCompare(rightValue);
      }
      return leftKey.localeCompare(rightKey);
    });

  parsed.search = '';
  for (const [key, parameterValue] of sortedParameters) {
    parsed.searchParams.append(key, parameterValue);
  }

  return parsed.toString();
}

function assertNoForbiddenScopeFields(value, path = 'request') {
  if (!isPlainObject(value)) {
    return;
  }

  for (const field of FORBIDDEN_SCOPE_FIELDS) {
    if (Object.hasOwn(value, field)) {
      throw new TypeError(
        `${path}.${field} is forbidden in the anonymous adapter boundary`,
      );
    }
  }

  for (const [key, nested] of Object.entries(value)) {
    if (isPlainObject(nested)) {
      assertNoForbiddenScopeFields(nested, `${path}.${key}`);
    } else if (Array.isArray(nested)) {
      nested.forEach((item, index) => {
        if (isPlainObject(item)) {
          assertNoForbiddenScopeFields(
            item,
            `${path}.${key}[${index}]`,
          );
        }
      });
    }
  }
}

function hashParts(parts) {
  const digest = crypto.createHash('sha256');
  for (const part of parts) {
    digest.update(String(part), 'utf8');
    digest.update('\u0000', 'utf8');
  }
  return digest.digest('hex');
}

function createMarketplaceLimitedRequest(input) {
  assertPlainObject(input, 'input');
  assertNoForbiddenScopeFields(input);

  const contractVersion = normalizeRequiredString(
    input.contractVersion,
    'input.contractVersion',
    120,
  );
  if (contractVersion !== DISPATCH_ENVELOPE_CONTRACT_VERSION) {
    throw new TypeError(
      'input.contractVersion is not a supported dispatch envelope version',
    );
  }

  const executionId = normalizeRequiredString(
    input.executionId,
    'input.executionId',
    160,
  );
  const scanRunId = normalizeRequiredString(
    input.scanRunId,
    'input.scanRunId',
    160,
  );

  const target = assertPlainObject(input.target, 'input.target');
  const brandNameNormalized = normalizeRequiredString(
    target.brandNameNormalized,
    'input.target.brandNameNormalized',
    240,
  );
  const officialHost = normalizeRequiredString(
    target.officialHost,
    'input.target.officialHost',
    253,
  ).toLowerCase();
  if (
    !/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/u
      .test(officialHost)
  ) {
    throw new TypeError(
      'input.target.officialHost must be a valid DNS host',
    );
  }

  const officialWebsiteCanonicalUrl = normalizeHttpUrl(
    target.officialWebsiteCanonicalUrl,
    'input.target.officialWebsiteCanonicalUrl',
  );
  const officialWebsiteHost = new URL(
    officialWebsiteCanonicalUrl,
  ).hostname.toLowerCase();
  if (
    officialWebsiteHost !== officialHost &&
    !officialWebsiteHost.endsWith(`.${officialHost}`)
  ) {
    throw new TypeError(
      'input.target.officialWebsiteCanonicalUrl must belong to officialHost',
    );
  }

  const targetFingerprintSha256 = assertSha256(
    target.targetFingerprintSha256,
    'input.target.targetFingerprintSha256',
  );

  const queryText = normalizeOptionalString(
    input.queryText,
    'input.queryText',
    240,
  ) || brandNameNormalized;

  const idempotencyKey = hashParts([
    executionId,
    scanRunId,
    targetFingerprintSha256,
    ADAPTER_CODE,
  ]);

  return Object.freeze({
    contractVersion: MARKETPLACE_LIMITED_CONTRACT_VERSION,
    sourceContractVersion: contractVersion,
    channelCode: CHANNEL_CODE,
    adapterCode: ADAPTER_CODE,
    executionId,
    scanRunId,
    idempotencyKey,
    target: Object.freeze({
      brandNameNormalized,
      officialHost,
      officialWebsiteCanonicalUrl,
      targetFingerprintSha256,
    }),
    queryText,
  });
}

function normalizeAcquisition(acquisition) {
  const value = assertPlainObject(acquisition, 'result.acquisition');
  const attemptedUrl = normalizeHttpUrl(
    value.attemptedUrl,
    'result.acquisition.attemptedUrl',
  );
  const finalUrl = normalizeOptionalString(
    value.finalUrl,
    'result.acquisition.finalUrl',
    2048,
  );

  return Object.freeze({
    attemptedUrl,
    finalUrl: finalUrl === null ?
      null :
      normalizeHttpUrl(
        finalUrl,
        'result.acquisition.finalUrl',
      ),
    httpStatus: Number.isInteger(value.httpStatus) ?
      value.httpStatus :
      null,
    acquiredAt: normalizeRequiredString(
      value.acquiredAt,
      'result.acquisition.acquiredAt',
      80,
    ),
    outcomeCode: normalizeRequiredString(
      value.outcomeCode,
      'result.acquisition.outcomeCode',
      120,
    ),
    evidenceSha256: value.evidenceSha256 === null ||
      value.evidenceSha256 === undefined ?
      null :
      assertSha256(
        value.evidenceSha256,
        'result.acquisition.evidenceSha256',
      ),
    responseBytes: Number.isSafeInteger(value.responseBytes) &&
      value.responseBytes >= 0 ?
      value.responseBytes :
      null,
    retryable: value.retryable === true,
  });
}

function normalizeObservation(observation, index) {
  const value = assertPlainObject(
    observation,
    `result.observations[${index}]`,
  );
  return Object.freeze({
    observationId: assertSha256(
      value.observationId,
      `result.observations[${index}].observationId`,
    ),
    rank: Number.isSafeInteger(value.rank) && value.rank > 0 ?
      value.rank :
      index + 1,
    title: normalizeRequiredString(
      value.title,
      `result.observations[${index}].title`,
      500,
    ),
    canonicalUrl: normalizeHttpUrl(
      value.canonicalUrl,
      `result.observations[${index}].canonicalUrl`,
    ),
    sourceHost: normalizeRequiredString(
      value.sourceHost,
      `result.observations[${index}].sourceHost`,
      253,
    ).toLowerCase(),
    evidenceSha256: assertSha256(
      value.evidenceSha256,
      `result.observations[${index}].evidenceSha256`,
    ),
  });
}

function createChannelAdapterResult(input) {
  const value = assertPlainObject(input, 'result');
  const status = normalizeRequiredString(
    value.status,
    'result.status',
    80,
  );
  if (!EXECUTION_STATUSES.includes(status)) {
    throw new TypeError('result.status is not supported');
  }

  const observations = Array.isArray(value.observations) ?
    value.observations.map(normalizeObservation) :
    [];
  const acquisition = normalizeAcquisition(value.acquisition);

  if (
    status === 'completed' &&
    acquisition.evidenceSha256 === null
  ) {
    throw new TypeError(
      'completed results require acquisition evidence',
    );
  }
  if (
    status !== 'completed' &&
    observations.length > 0
  ) {
    throw new TypeError(
      'non-completed results must not contain observations',
    );
  }

  const error = value.error === null ||
    value.error === undefined ?
    null :
    Object.freeze({
      code: normalizeRequiredString(
        value.error.code,
        'result.error.code',
        120,
      ),
      message: normalizeRequiredString(
        value.error.message,
        'result.error.message',
        1000,
      ),
      retryable: value.error.retryable === true,
    });

  if (status === 'failed' && error === null) {
    throw new TypeError('failed results require result.error');
  }

  const request = assertPlainObject(value.request, 'result.request');
  const normalizedRequest = createMarketplaceLimitedRequest({
    contractVersion: request.sourceContractVersion,
    executionId: request.executionId,
    scanRunId: request.scanRunId,
    target: request.target,
    queryText: request.queryText,
  });

  return normalizeChannelAdapterResult({
    contractVersion: CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    channelCode: CHANNEL_CODE,
    adapterCode: ADAPTER_CODE,
    executionId: normalizedRequest.executionId,
    scanRunId: normalizedRequest.scanRunId,
    targetFingerprintSha256:
      normalizedRequest.target.targetFingerprintSha256,
    idempotencyKey: normalizedRequest.idempotencyKey,
    status,
    acquisition,
    observations,
    summary: {
      candidateCount: observations.length,
      truncated: value.truncated === true,
    },
    error,
  });
}

function normalizeChannelAdapterResult(input) {
  const value = assertExactKeys(
    input,
    CHANNEL_ADAPTER_RESULT_KEYS,
    'channelAdapterResult',
  );
  if (
    value.contractVersion !==
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION
  ) {
    throw new TypeError(
      'channelAdapterResult.contractVersion is unsupported',
    );
  }
  if (value.channelCode !== CHANNEL_CODE) {
    throw new TypeError(
      'channelAdapterResult.channelCode is unsupported',
    );
  }
  if (value.adapterCode !== ADAPTER_CODE) {
    throw new TypeError(
      'channelAdapterResult.adapterCode is unsupported',
    );
  }

  const status = normalizeRequiredString(
    value.status,
    'channelAdapterResult.status',
    80,
  );
  if (!EXECUTION_STATUSES.includes(status)) {
    throw new TypeError(
      'channelAdapterResult.status is not supported',
    );
  }

  const acquisition = normalizeAcquisition(value.acquisition);
  const observations = Array.isArray(value.observations) ?
    value.observations.map(normalizeObservation) :
    (() => {
      throw new TypeError(
        'channelAdapterResult.observations must be an array',
      );
    })();

  const summary = assertExactKeys(
    value.summary,
    ['candidateCount', 'truncated'],
    'channelAdapterResult.summary',
  );
  if (
    !Number.isSafeInteger(summary.candidateCount) ||
    summary.candidateCount < 0 ||
    summary.candidateCount !== observations.length
  ) {
    throw new TypeError(
      'channelAdapterResult.summary.candidateCount is invalid',
    );
  }
  if (typeof summary.truncated !== 'boolean') {
    throw new TypeError(
      'channelAdapterResult.summary.truncated must be boolean',
    );
  }

  const error = value.error === null ?
    null :
    Object.freeze({
      code: normalizeRequiredString(
        assertPlainObject(
          value.error,
          'channelAdapterResult.error',
        ).code,
        'channelAdapterResult.error.code',
        120,
      ),
      message: normalizeRequiredString(
        value.error.message,
        'channelAdapterResult.error.message',
        1000,
      ),
      retryable: value.error.retryable === true,
    });

  if (
    status === 'completed' &&
    acquisition.evidenceSha256 === null
  ) {
    throw new TypeError(
      'completed channel adapter results require acquisition evidence',
    );
  }
  if (
    status !== 'completed' &&
    observations.length > 0
  ) {
    throw new TypeError(
      'non-completed channel adapter results must not contain observations',
    );
  }
  if (status === 'failed' && error === null) {
    throw new TypeError(
      'failed channel adapter results require result.error',
    );
  }

  return Object.freeze({
    contractVersion: CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    channelCode: CHANNEL_CODE,
    adapterCode: ADAPTER_CODE,
    executionId: normalizeRequiredString(
      value.executionId,
      'channelAdapterResult.executionId',
      160,
    ),
    scanRunId: normalizeRequiredString(
      value.scanRunId,
      'channelAdapterResult.scanRunId',
      160,
    ),
    targetFingerprintSha256: assertSha256(
      value.targetFingerprintSha256,
      'channelAdapterResult.targetFingerprintSha256',
    ),
    idempotencyKey: assertSha256(
      value.idempotencyKey,
      'channelAdapterResult.idempotencyKey',
    ),
    status,
    acquisition,
    observations: Object.freeze(observations),
    summary: Object.freeze({
      candidateCount: observations.length,
      truncated: summary.truncated,
    }),
    error,
  });
}

module.exports = {
  ADAPTER_CODE,
  CHANNEL_CODE,
  DISPATCH_ENVELOPE_CONTRACT_VERSION,
  EXECUTION_STATUSES,
  FORBIDDEN_SCOPE_FIELDS,
  MARKETPLACE_LIMITED_CONTRACT_VERSION,
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  assertNoForbiddenScopeFields,
  createMarketplaceLimitedRequest,
  createChannelAdapterResult,
  normalizeChannelAdapterResult,
  hashParts,
  normalizeHttpUrl,
};
