'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  DISPATCH_ENVELOPE_CONTRACT_VERSION,
} = require('../src/acquisition/marketplace_limited_contract');
const {
  assertNoSensitiveRequestHeaders,
  buildTrendyolSearchUrl,
  classifyHttpStatus,
  containsBlockMarker,
  createTrendyolPublicListingAdapter,
  extractProductCandidates,
  isAllowedTrendyolHost,
  normalizeTrendyolUrl,
  readResponseBodyBounded,
} = require('../src/acquisition/trendyol_public_listing_adapter');

const FIXTURES = path.join(__dirname, '..', 'fixtures');
const FINGERPRINT = 'a'.repeat(64);
const EVIDENCE = 'b'.repeat(64);

function loadFixture(name) {
  return JSON.parse(
    fs.readFileSync(path.join(FIXTURES, name), 'utf8'),
  );
}

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

function fakeResponse(fixture, overrides = {}) {
  const body = Buffer.from(
    overrides.body ?? fixture.body,
    'utf8',
  );
  return {
    status: overrides.status ?? fixture.status,
    url: overrides.url ?? fixture.url,
    headers: new Headers({
      ...fixture.headers,
      ...(overrides.headers || {}),
    }),
    async arrayBuffer() {
      return body;
    },
  };
}

test('builds a public Trendyol search URL', () => {
  assert.equal(
    buildTrendyolSearchUrl('  Acme   Marka  '),
    'https://www.trendyol.com/sr?q=Acme+Marka',
  );
});

test('rejects an empty public search query', () => {
  assert.throws(
    () => buildTrendyolSearchUrl('   '),
    /must not be empty/u,
  );
});

test('recognizes Trendyol hosts only', () => {
  assert.equal(isAllowedTrendyolHost('trendyol.com'), true);
  assert.equal(
    isAllowedTrendyolHost('www.trendyol.com'),
    true,
  );
  assert.equal(
    isAllowedTrendyolHost('api.trendyol.com'),
    true,
  );
  assert.equal(
    isAllowedTrendyolHost('trendyol.com.evil.example'),
    false,
  );
});

test('normalizes allowed Trendyol URLs', () => {
  assert.equal(
    normalizeTrendyolUrl(
      '/acme/product-p-1#fragment',
      'https://www.trendyol.com/sr?q=Acme',
    ),
    'https://www.trendyol.com/acme/product-p-1',
  );
});

test('rejects external and insecure candidate URLs', () => {
  assert.equal(
    normalizeTrendyolUrl(
      'https://evil.example/product-p-1',
      'https://www.trendyol.com/',
    ),
    null,
  );
  assert.equal(
    normalizeTrendyolUrl(
      'http://www.trendyol.com/product-p-1',
      'https://www.trendyol.com/',
    ),
    null,
  );
});

test('rejects sensitive request headers', () => {
  assert.throws(
    () => assertNoSensitiveRequestHeaders({
      Authorization: 'Bearer value',
    }),
    /authorization is forbidden/u,
  );
  assert.throws(
    () => assertNoSensitiveRequestHeaders({
      Cookie: 'session=value',
    }),
    /cookie is forbidden/u,
  );
});

test('classifies access and rate-limit HTTP statuses', () => {
  assert.deepEqual(
    classifyHttpStatus(403),
    {
      status: 'dataUnavailable',
      outcomeCode: 'access_policy_blocked',
      retryable: false,
    },
  );
  assert.deepEqual(
    classifyHttpStatus(429),
    {
      status: 'dataUnavailable',
      outcomeCode: 'rate_limited',
      retryable: true,
    },
  );
});

test('classifies server errors as retryable failures', () => {
  assert.deepEqual(
    classifyHttpStatus(503),
    {
      status: 'failed',
      outcomeCode: 'upstream_server_error',
      retryable: true,
    },
  );
});

test('does not classify successful status values', () => {
  assert.equal(classifyHttpStatus(200), null);
});

test('detects access-policy block markers', () => {
  assert.equal(
    containsBlockMarker('Robot olmadığınızı doğrulayın'),
    true,
  );
  assert.equal(
    containsBlockMarker('Normal ürün sonuçları'),
    false,
  );
});

test('extracts and deduplicates public product candidates', () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const candidates = extractProductCandidates(
    fixture.body,
    {
      baseUrl: fixture.url,
      request: {
        executionId: 'execution-1',
        scanRunId: 'scan-1',
        target: {targetFingerprintSha256: FINGERPRINT},
      },
      evidenceSha256: EVIDENCE,
      maxCandidates: 10,
    },
  );

  assert.equal(candidates.length, 2);
  assert.equal(candidates[0].rank, 1);
  assert.equal(
    candidates[0].canonicalUrl,
    'https://www.trendyol.com/acme/original-product-p-1001',
  );
  assert.match(
    candidates[0].observationId,
    /^[0-9a-f]{64}$/u,
  );
  assert.equal(candidates[0].evidenceSha256, EVIDENCE);
});

test('enforces the candidate limit', () => {
  const html = [
    '<a href="/a/product-p-1">One</a>',
    '<a href="/a/product-p-2">Two</a>',
    '<a href="/a/product-p-3">Three</a>',
  ].join('');
  const candidates = extractProductCandidates(
    html,
    {
      baseUrl: 'https://www.trendyol.com/sr?q=Acme',
      request: {
        executionId: 'execution-1',
        scanRunId: 'scan-1',
        target: {targetFingerprintSha256: FINGERPRINT},
      },
      evidenceSha256: EVIDENCE,
      maxCandidates: 2,
    },
  );
  assert.equal(candidates.length, 2);
});

test('reads a bounded arrayBuffer response', async () => {
  const body = await readResponseBodyBounded(
    {
      async arrayBuffer() {
        return Buffer.from('Acme');
      },
    },
    10,
  );
  assert.equal(body.toString('utf8'), 'Acme');
});

test('rejects oversized arrayBuffer responses', async () => {
  await assert.rejects(
    () => readResponseBodyBounded(
      {
        async arrayBuffer() {
          return Buffer.from('123456');
        },
      },
      5,
    ),
    /exceeds 5 bytes/u,
  );
});

test('acquires and maps public candidates', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  let capturedUrl = null;
  let capturedOptions = null;
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async (url, options) => {
      capturedUrl = url;
      capturedOptions = options;
      return fakeResponse(fixture);
    },
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());

  assert.equal(
    result.contractVersion,
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  );
  assert.equal(result.status, 'completed');
  assert.equal(result.summary.candidateCount, 2);
  assert.equal(
    result.acquisition.outcomeCode,
    'public_candidates_acquired',
  );
  assert.match(
    result.acquisition.evidenceSha256,
    /^[0-9a-f]{64}$/u,
  );
  assert.equal(
    capturedUrl,
    'https://www.trendyol.com/sr?q=Acme',
  );
  assert.equal(capturedOptions.credentials, 'omit');
  assert.equal(capturedOptions.redirect, 'follow');
  assert.equal(
    capturedOptions.headers.authorization,
    undefined,
  );
  assert.equal(capturedOptions.headers.cookie, undefined);
});

test('returns a real completed zero-candidate result', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(
      fixture,
      {body: '<html><body>No products</body></html>'},
    ),
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'completed');
  assert.equal(result.summary.candidateCount, 0);
  assert.equal(
    result.acquisition.outcomeCode,
    'public_search_completed_no_candidates',
  );
  assert.match(
    result.acquisition.evidenceSha256,
    /^[0-9a-f]{64}$/u,
  );
});

test('maps blocked HTML to dataUnavailable', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_blocked.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(fixture),
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'dataUnavailable');
  assert.equal(
    result.acquisition.outcomeCode,
    'access_policy_blocked',
  );
  assert.equal(result.observations.length, 0);
});

test('maps HTTP 429 to dataUnavailable', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(
      fixture,
      {status: 429, body: 'Too Many Requests'},
    ),
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'dataUnavailable');
  assert.equal(result.acquisition.outcomeCode, 'rate_limited');
  assert.equal(result.acquisition.retryable, true);
});

test('maps HTTP 503 to a retryable failure', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(
      fixture,
      {status: 503, body: 'Unavailable'},
    ),
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'failed');
  assert.equal(
    result.acquisition.outcomeCode,
    'upstream_server_error',
  );
  assert.equal(result.error.retryable, true);
});

test('rejects redirects outside Trendyol', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(
      fixture,
      {url: 'https://evil.example/result'},
    ),
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'failed');
  assert.equal(
    result.acquisition.outcomeCode,
    'redirect_host_not_allowed',
  );
});

test('maps network failures to retryable failures', async () => {
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => {
      throw new Error('network unavailable');
    },
    now: () => new Date('2026-08-04T00:00:00Z'),
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'failed');
  assert.equal(result.acquisition.outcomeCode, 'network_error');
  assert.equal(result.error.retryable, true);
});

test('maps response size violations to non-retryable failures', async () => {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(
      fixture,
      {body: 'x'.repeat(2048)},
    ),
    now: () => new Date('2026-08-04T00:00:00Z'),
    maxResponseBytes: 1024,
  });

  const result = await adapter.acquire(validInput());
  assert.equal(result.status, 'failed');
  assert.equal(
    result.acquisition.outcomeCode,
    'response_too_large',
  );
  assert.equal(result.error.retryable, false);
});

test('exposes an immutable public-only policy', () => {
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => {
      throw new Error('not called');
    },
  });
  assert.deepEqual(adapter.policy, {
    authenticationAllowed: false,
    captchaBypassAllowed: false,
    publicPagesOnly: true,
    timeoutMs: 15000,
    maxResponseBytes: 1024 * 1024,
    maxVisibleTextCharacters: 120000,
    maxCandidates: 20,
  });
  assert.equal(Object.isFrozen(adapter.policy), true);
});
