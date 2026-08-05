'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  PROVIDER_RESULT_VERSION,
  normalizeChannelResult,
  normalizeProviderResult,
} = require('../src/contracts');
const {
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  DISPATCH_ENVELOPE_CONTRACT_VERSION,
  normalizeChannelAdapterResult,
} = require('../src/acquisition/marketplace_limited_contract');
const {
  createTrendyolPublicListingAdapter,
} = require('../src/acquisition/trendyol_public_listing_adapter');
const {
  SOURCE_TYPE,
  mapMarketplaceLimitedResultToChannelResult,
  normalizeIsoTimestamp,
} = require('../src/acquisition/marketplace_limited_result_mapper');

const FIXTURES = path.join(__dirname, '..', 'fixtures');
const FINGERPRINT = 'a'.repeat(64);

function loadFixture(name) {
  return JSON.parse(
    fs.readFileSync(path.join(FIXTURES, name), 'utf8'),
  );
}

function validInput() {
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

async function completedAdapterResult() {
  const fixture = loadFixture(
    'trendyol_public_listing_success.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(fixture),
    now: () => new Date('2026-08-04T00:00:00.000Z'),
  });
  return adapter.acquire(validInput());
}

async function dataUnavailableAdapterResult() {
  const fixture = loadFixture(
    'trendyol_public_listing_blocked.json',
  );
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => fakeResponse(fixture),
    now: () => new Date('2026-08-04T00:00:00.000Z'),
  });
  return adapter.acquire(validInput());
}

async function failedAdapterResult() {
  const adapter = createTrendyolPublicListingAdapter({
    fetchImpl: async () => {
      throw new Error('network unavailable');
    },
    now: () => new Date('2026-08-04T00:00:00.000Z'),
  });
  return adapter.acquire(validInput());
}

function providerResultWithMarketplace(channel) {
  const empty = (channelCode) => ({
    channelCode,
    status: 'dataUnavailable',
    startedAt: '2026-08-04T00:00:00.000Z',
    completedAt: '2026-08-04T00:00:01.000Z',
    observations: [],
    diagnostics: {
      testHarnessOnly: true,
      reason: 'channel_not_under_test',
    },
  });
  const channels = [
    empty('similarDomains'),
    empty('openWeb'),
    channel,
  ];
  return {
    contractVersion: PROVIDER_RESULT_VERSION,
    executionStatus: 'partial',
    channels,
    summary: {
      completedChannelCount: 1,
      dataUnavailableChannelCount: 2,
      failedChannelCount: 0,
      observationCount: channel.observations.length,
    },
    engine: {
      engineCode: 'public_lite_contract_test',
      engineVersion: '1.0.0',
    },
  };
}

test('uses a distinct channel adapter result contract version', () => {
  assert.equal(
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    'risk-scan-public-lite-channel-adapter-result-v1',
  );
  assert.notEqual(
    CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    PROVIDER_RESULT_VERSION,
  );
});

test('normalizes canonical completion timestamps', () => {
  assert.equal(
    normalizeIsoTimestamp(
      '2026-08-04T00:00:01.000Z',
      'completedAt',
    ),
    '2026-08-04T00:00:01.000Z',
  );
});

test('rejects non-canonical completion timestamps', () => {
  assert.throws(
    () => normalizeIsoTimestamp(
      '2026-08-04T00:00:01Z',
      'completedAt',
    ),
    /canonical ISO-8601/u,
  );
});

test('maps a completed adapter result to a canonical channel result',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(channel.channelCode, 'marketplaceLimited');
    assert.equal(channel.status, 'completed');
    assert.equal(channel.observations.length, 2);
    assert.equal(Object.isFrozen(channel), true);
  });

test('maps adapter observations without inventing image data',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    const observation = channel.observations[0];
    assert.equal(
      observation.sourceType,
      SOURCE_TYPE,
    );
    assert.equal(
      observation.sourceUrl,
      adapterResult.observations[0].canonicalUrl,
    );
    assert.equal(
      observation.snippet,
      adapterResult.observations[0].title,
    );
    assert.deepEqual(observation.imageUrls, []);
  });

test('preserves deterministic observation identifiers',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(
      channel.observations[0].observationId,
      adapterResult.observations[0].observationId,
    );
  });

test('maps acquisition evidence into canonical evidence',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(
      channel.observations[0].evidence.sha256,
      adapterResult.observations[0].evidenceSha256,
    );
    assert.equal(
      channel.observations[0].evidence.acquisitionOutcomeCode,
      'public_candidates_acquired',
    );
  });

test('maps adapter diagnostics without secrets',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(
      channel.diagnostics.channelAdapterContractVersion,
      CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
    );
    assert.equal(
      channel.diagnostics.idempotencyKey,
      adapterResult.idempotencyKey,
    );
    assert.equal(channel.diagnostics.error, null);
    assert.equal(
      Object.hasOwn(channel.diagnostics, 'authorization'),
      false,
    );
    assert.equal(
      Object.hasOwn(channel.diagnostics, 'cookie'),
      false,
    );
  });

test('maps dataUnavailable without observations',
  async () => {
    const adapterResult = await dataUnavailableAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(channel.status, 'dataUnavailable');
    assert.deepEqual(channel.observations, []);
    assert.equal(
      channel.diagnostics.acquisitionOutcomeCode,
      'access_policy_blocked',
    );
  });

test('maps failed results without observations',
  async () => {
    const adapterResult = await failedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.equal(channel.status, 'failed');
    assert.deepEqual(channel.observations, []);
    assert.equal(
      channel.diagnostics.error.code,
      'network_error',
    );
  });

test('rejects completion before acquisition start',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.throws(
      () => mapMarketplaceLimitedResultToChannelResult(
        adapterResult,
        {completedAt: '2026-08-03T23:59:59.999Z'},
      ),
      /must not precede/u,
    );
  });

test('rejects missing completion timestamps',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.throws(
      () => mapMarketplaceLimitedResultToChannelResult(
        adapterResult,
      ),
      /must be a string/u,
    );
  });

test('rejects the legacy provider result version',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.throws(
      () => mapMarketplaceLimitedResultToChannelResult(
        {
          ...adapterResult,
          contractVersion: PROVIDER_RESULT_VERSION,
        },
        {completedAt: '2026-08-04T00:00:01.000Z'},
      ),
      /contractVersion is unsupported/u,
    );
  });

test('rejects adapter result key drift',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.throws(
      () => mapMarketplaceLimitedResultToChannelResult(
        {
          ...adapterResult,
          providerCode: 'not-allowed',
        },
        {completedAt: '2026-08-04T00:00:01.000Z'},
      ),
      /keys are invalid/u,
    );
  });

test('rejects candidate count drift',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.throws(
      () => mapMarketplaceLimitedResultToChannelResult(
        {
          ...adapterResult,
          summary: {
            ...adapterResult.summary,
            candidateCount: 999,
          },
        },
        {completedAt: '2026-08-04T00:00:01.000Z'},
      ),
      /candidateCount is invalid/u,
    );
  });

test('produces deterministic output for deterministic inputs',
  async () => {
    const adapterResult = await completedAdapterResult();
    const options = {
      completedAt: '2026-08-04T00:00:01.000Z',
    };
    assert.deepEqual(
      mapMarketplaceLimitedResultToChannelResult(
        adapterResult,
        options,
      ),
      mapMarketplaceLimitedResultToChannelResult(
        adapterResult,
        options,
      ),
    );
  });

test('is directly accepted by the gateway channel normalizer',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    assert.deepEqual(
      normalizeChannelResult(channel, 2),
      channel,
    );
  });

test('can participate in a canonical provider result',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    const provider = normalizeProviderResult(
      providerResultWithMarketplace(channel),
    );
    assert.equal(provider.channels[2].channelCode, 'marketplaceLimited');
    assert.equal(provider.summary.observationCount, 2);
  });

test('does not add tenant or brand scope fields',
  async () => {
    const adapterResult = await completedAdapterResult();
    const channel = mapMarketplaceLimitedResultToChannelResult(
      adapterResult,
      {completedAt: '2026-08-04T00:00:01.000Z'},
    );
    const serialized = JSON.stringify(channel);
    assert.equal(serialized.includes('"tenantId"'), false);
    assert.equal(serialized.includes('"brandId"'), false);
    assert.equal(serialized.includes('"actorUid"'), false);
  });

test('normalizes an adapter result before mapping',
  async () => {
    const adapterResult = await completedAdapterResult();
    assert.deepEqual(
      normalizeChannelAdapterResult(adapterResult),
      adapterResult,
    );
  });
