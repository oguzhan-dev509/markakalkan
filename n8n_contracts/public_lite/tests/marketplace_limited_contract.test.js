'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ADAPTER_CODE,
  CHANNEL_CODE,
  DISPATCH_ENVELOPE_CONTRACT_VERSION,
  MARKETPLACE_LIMITED_CONTRACT_VERSION,
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  createMarketplaceLimitedRequest,
  createChannelAdapterResult,
  normalizeChannelAdapterResult,
  hashParts,
  normalizeHttpUrl,
} = require('../src/acquisition/marketplace_limited_contract');

const {
  PROVIDER_RESULT_VERSION,
} = require('../src/contracts');

const FINGERPRINT = 'a'.repeat(64);
const EVIDENCE = 'b'.repeat(64);

function validInput(overrides = {}) {
  return {
    contractVersion: DISPATCH_ENVELOPE_CONTRACT_VERSION,
    executionId: 'execution-1',
    scanRunId: 'scan-1',
    target: {
      brandNameNormalized: 'Acme',
      officialHost: 'acme.example',
      officialWebsiteCanonicalUrl: 'https://www.acme.example/',
      targetFingerprintSha256: FINGERPRINT,
    },
    ...overrides,
  };
}

test('creates an anonymous marketplace request', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  assert.equal(
    request.contractVersion,
    MARKETPLACE_LIMITED_CONTRACT_VERSION,
  );
  assert.equal(request.channelCode, CHANNEL_CODE);
  assert.equal(request.adapterCode, ADAPTER_CODE);
  assert.equal(request.queryText, 'Acme');
  assert.match(request.idempotencyKey, /^[0-9a-f]{64}$/u);
});

test('creates a deterministic idempotency key', () => {
  const left = createMarketplaceLimitedRequest(validInput());
  const right = createMarketplaceLimitedRequest(validInput());
  assert.equal(left.idempotencyKey, right.idempotencyKey);
});

test('changes the idempotency key when execution changes', () => {
  const left = createMarketplaceLimitedRequest(validInput());
  const right = createMarketplaceLimitedRequest(
    validInput({executionId: 'execution-2'}),
  );
  assert.notEqual(left.idempotencyKey, right.idempotencyKey);
});

test('rejects unsupported dispatch contract versions', () => {
  assert.throws(
    () => createMarketplaceLimitedRequest(
      validInput({contractVersion: 'unsupported-v1'}),
    ),
    /supported dispatch envelope/u,
  );
});

test('rejects tenant scope fields recursively', () => {
  assert.throws(
    () => createMarketplaceLimitedRequest({
      ...validInput(),
      target: {
        ...validInput().target,
        tenantId: 'tenant-1',
      },
    }),
    /tenantId is forbidden/u,
  );
});

test('rejects a malformed target fingerprint', () => {
  assert.throws(
    () => createMarketplaceLimitedRequest({
      ...validInput(),
      target: {
        ...validInput().target,
        targetFingerprintSha256: 'abc',
      },
    }),
    /SHA-256/u,
  );
});

test('rejects an official URL outside the official host', () => {
  assert.throws(
    () => createMarketplaceLimitedRequest({
      ...validInput(),
      target: {
        ...validInput().target,
        officialWebsiteCanonicalUrl: 'https://evil.example/',
      },
    }),
    /must belong to officialHost/u,
  );
});

test('normalizes HTTP URLs deterministically', () => {
  assert.equal(
    normalizeHttpUrl(
      'HTTPS://Example.COM:443/path?z=2&a=1#fragment',
      'url',
    ),
    'https://example.com/path?a=1&z=2',
  );
});

test('rejects URL credentials', () => {
  assert.throws(
    () => normalizeHttpUrl(
      'https://user:pass@example.com/',
      'url',
    ),
    /must not contain URL credentials/u,
  );
});

test('hashParts is deterministic and boundary-safe', () => {
  assert.equal(
    hashParts(['ab', 'c']),
    hashParts(['ab', 'c']),
  );
  assert.notEqual(
    hashParts(['ab', 'c']),
    hashParts(['a', 'bc']),
  );
});

test('creates a completed provider result with evidence', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  const result = createChannelAdapterResult({
    request,
    status: 'completed',
    acquisition: {
      attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
      finalUrl: 'https://www.trendyol.com/sr?q=Acme',
      httpStatus: 200,
      acquiredAt: '2026-08-04T00:00:00.000Z',
      outcomeCode: 'public_candidates_acquired',
      evidenceSha256: EVIDENCE,
      responseBytes: 100,
      retryable: false,
    },
    observations: [{
      observationId: 'c'.repeat(64),
      rank: 1,
      title: 'Acme Product',
      canonicalUrl:
        'https://www.trendyol.com/acme/product-p-1',
      sourceHost: 'www.trendyol.com',
      evidenceSha256: EVIDENCE,
    }],
  });

  assert.equal(
    result.contractVersion,
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  );
  assert.equal(result.status, 'completed');
  assert.equal(result.summary.candidateCount, 1);
  assert.equal(result.error, null);
});

test('allows a real completed zero-candidate result with evidence', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  const result = createChannelAdapterResult({
    request,
    status: 'completed',
    acquisition: {
      attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
      finalUrl: 'https://www.trendyol.com/sr?q=Acme',
      httpStatus: 200,
      acquiredAt: '2026-08-04T00:00:00.000Z',
      outcomeCode: 'public_search_completed_no_candidates',
      evidenceSha256: EVIDENCE,
      responseBytes: 50,
      retryable: false,
    },
    observations: [],
  });
  assert.equal(result.status, 'completed');
  assert.equal(result.summary.candidateCount, 0);
});

test('rejects completed results without acquisition evidence', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  assert.throws(
    () => createChannelAdapterResult({
      request,
      status: 'completed',
      acquisition: {
        attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
        finalUrl: 'https://www.trendyol.com/sr?q=Acme',
        httpStatus: 200,
        acquiredAt: '2026-08-04T00:00:00.000Z',
        outcomeCode: 'public_search_completed_no_candidates',
        evidenceSha256: null,
        responseBytes: 0,
        retryable: false,
      },
      observations: [],
    }),
    /require acquisition evidence/u,
  );
});

test('rejects observations on non-completed results', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  assert.throws(
    () => createChannelAdapterResult({
      request,
      status: 'dataUnavailable',
      acquisition: {
        attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
        finalUrl: 'https://www.trendyol.com/sr?q=Acme',
        httpStatus: 403,
        acquiredAt: '2026-08-04T00:00:00.000Z',
        outcomeCode: 'access_policy_blocked',
        evidenceSha256: EVIDENCE,
        responseBytes: 10,
        retryable: false,
      },
      observations: [{
        observationId: 'c'.repeat(64),
        title: 'Not allowed',
        canonicalUrl:
          'https://www.trendyol.com/acme/product-p-1',
        sourceHost: 'www.trendyol.com',
        evidenceSha256: EVIDENCE,
      }],
    }),
    /must not contain observations/u,
  );
});

test('requires an error object for failed results', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  assert.throws(
    () => createChannelAdapterResult({
      request,
      status: 'failed',
      acquisition: {
        attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
        finalUrl: null,
        httpStatus: null,
        acquiredAt: '2026-08-04T00:00:00.000Z',
        outcomeCode: 'network_error',
        evidenceSha256: null,
        responseBytes: null,
        retryable: true,
      },
      observations: [],
    }),
    /require result.error/u,
  );
});


test('uses a distinct channel adapter result version', () => {
  assert.equal(
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    'risk-scan-public-lite-channel-adapter-result-v1',
  );
  assert.notEqual(
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    PROVIDER_RESULT_VERSION,
  );
});

test('normalizes a channel adapter result', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  const result = createChannelAdapterResult({
    request,
    status: 'completed',
    acquisition: {
      attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
      finalUrl: 'https://www.trendyol.com/sr?q=Acme',
      httpStatus: 200,
      acquiredAt: '2026-08-04T00:00:00.000Z',
      outcomeCode: 'public_candidates_acquired',
      evidenceSha256: EVIDENCE,
      responseBytes: 100,
      retryable: false,
    },
    observations: [{
      observationId: 'c'.repeat(64),
      rank: 1,
      title: 'Acme Product',
      canonicalUrl:
        'https://www.trendyol.com/acme/product-p-1',
      sourceHost: 'www.trendyol.com',
      evidenceSha256: EVIDENCE,
    }],
  });
  const normalized = normalizeChannelAdapterResult(result);
  assert.deepEqual(normalized, result);
  assert.equal(Object.isFrozen(normalized), true);
});

test('rejects the legacy provider result version', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  const result = createChannelAdapterResult({
    request,
    status: 'completed',
    acquisition: {
      attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
      finalUrl: 'https://www.trendyol.com/sr?q=Acme',
      httpStatus: 200,
      acquiredAt: '2026-08-04T00:00:00.000Z',
      outcomeCode: 'public_search_completed_no_candidates',
      evidenceSha256: EVIDENCE,
      responseBytes: 50,
      retryable: false,
    },
    observations: [],
  });
  assert.throws(
    () => normalizeChannelAdapterResult({
      ...result,
      contractVersion: PROVIDER_RESULT_VERSION,
    }),
    /contractVersion is unsupported/u,
  );
});

test('rejects extra channel adapter result keys', () => {
  const request = createMarketplaceLimitedRequest(validInput());
  const result = createChannelAdapterResult({
    request,
    status: 'completed',
    acquisition: {
      attemptedUrl: 'https://www.trendyol.com/sr?q=Acme',
      finalUrl: 'https://www.trendyol.com/sr?q=Acme',
      httpStatus: 200,
      acquiredAt: '2026-08-04T00:00:00.000Z',
      outcomeCode: 'public_search_completed_no_candidates',
      evidenceSha256: EVIDENCE,
      responseBytes: 50,
      retryable: false,
    },
    observations: [],
  });
  assert.throws(
    () => normalizeChannelAdapterResult({
      ...result,
      providerCode: 'not-allowed',
    }),
    /keys are invalid/u,
  );
});
