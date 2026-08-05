'use strict';

const {
  createMarketplaceLimitedRequest,
  createChannelAdapterResult,
  hashParts,
  normalizeHttpUrl,
} = require('./marketplace_limited_contract');
const {
  buildResponseEvidence,
} = require('./response_evidence_bridge');

const TRENDYOL_PUBLIC_HOST = 'www.trendyol.com';
const DEFAULT_TIMEOUT_MS = 15000;
const DEFAULT_MAX_RESPONSE_BYTES = 1024 * 1024;
const DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS = 120000;
const DEFAULT_MAX_CANDIDATES = 20;

const BLOCK_MARKERS = Object.freeze([
  'access denied',
  'captcha',
  'robot olmadığınızı doğrulayın',
  'güvenlik kontrolü',
  'too many requests',
  'erişim engellendi',
]);

function normalizeInteger(
  value,
  label,
  fallback,
  minimum,
  maximum,
) {
  if (value === undefined || value === null) {
    return fallback;
  }
  if (
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new TypeError(
      `${label} must be an integer between ${minimum} and ${maximum}`,
    );
  }
  return value;
}

function assertFetch(fetchImpl) {
  if (typeof fetchImpl !== 'function') {
    throw new TypeError('fetchImpl must be a function');
  }
  return fetchImpl;
}

function assertNoSensitiveRequestHeaders(headers) {
  if (!headers) {
    return;
  }

  const entries = typeof headers.entries === 'function' ?
    [...headers.entries()] :
    Object.entries(headers);

  for (const [rawName] of entries) {
    const name = String(rawName).trim().toLowerCase();
    if (
      name === 'authorization' ||
      name === 'cookie' ||
      name === 'proxy-authorization' ||
      name === 'x-api-key'
    ) {
      throw new TypeError(
        `request header ${name} is forbidden for public acquisition`,
      );
    }
  }
}

function buildTrendyolSearchUrl(queryText) {
  const normalized = String(queryText || '')
    .replace(/\s+/gu, ' ')
    .trim();
  if (!normalized) {
    throw new TypeError('queryText must not be empty');
  }
  if (normalized.length > 240) {
    throw new RangeError(
      'queryText must be at most 240 characters',
    );
  }

  const url = new URL(`https://${TRENDYOL_PUBLIC_HOST}/sr`);
  url.searchParams.set('q', normalized);
  return url.toString();
}

function isAllowedTrendyolHost(hostname) {
  const normalized = String(hostname || '').toLowerCase();
  return (
    normalized === 'trendyol.com' ||
    normalized.endsWith('.trendyol.com')
  );
}

function normalizeTrendyolUrl(value, baseUrl) {
  let parsed;
  try {
    parsed = new URL(value, baseUrl);
  } catch {
    return null;
  }

  if (
    parsed.protocol !== 'https:' ||
    !isAllowedTrendyolHost(parsed.hostname) ||
    parsed.username ||
    parsed.password
  ) {
    return null;
  }

  parsed.hash = '';
  parsed.hostname = parsed.hostname.toLowerCase();
  if (parsed.port === '443') {
    parsed.port = '';
  }

  return parsed.toString();
}

function stripTags(value) {
  return String(value || '')
    .replace(/<[^>]+>/gu, ' ')
    .replace(/&nbsp;/giu, ' ')
    .replace(/&amp;/giu, '&')
    .replace(/&quot;/giu, '"')
    .replace(/&#39;/giu, '\'')
    .replace(/\s+/gu, ' ')
    .trim();
}

function isProductPath(pathname) {
  const normalized = String(pathname || '').toLowerCase();
  if (
    normalized === '/' ||
    normalized.startsWith('/sr') ||
    normalized.startsWith('/login') ||
    normalized.startsWith('/hesabim') ||
    normalized.startsWith('/sepet') ||
    normalized.startsWith('/yardim')
  ) {
    return false;
  }
  return (
    normalized.includes('-p-') ||
    /\/p-\d+(?:\/|$)/u.test(normalized)
  );
}

function extractProductCandidates(
  html,
  {
    baseUrl,
    request,
    evidenceSha256,
    maxCandidates,
  },
) {
  const candidates = [];
  const seen = new Set();
  const anchorPattern =
    /<a\b([^>]*?)href\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))([^>]*)>([\s\S]*?)<\/a\s*>/giu;

  let match;
  while (
    candidates.length < maxCandidates &&
    (match = anchorPattern.exec(html)) !== null
  ) {
    const href = match[2] || match[3] || match[4];
    const canonicalUrl = normalizeTrendyolUrl(
      href,
      baseUrl,
    );
    if (!canonicalUrl) {
      continue;
    }

    const parsed = new URL(canonicalUrl);
    if (!isProductPath(parsed.pathname)) {
      continue;
    }
    if (seen.has(canonicalUrl)) {
      continue;
    }

    const attributes = `${match[1] || ''} ${match[5] || ''}`;
    const titleMatch = attributes.match(
      /\b(?:title|aria-label)\s*=\s*(?:"([^"]+)"|'([^']+)')/iu,
    );
    const title = stripTags(
      titleMatch?.[1] ||
      titleMatch?.[2] ||
      match[6] ||
      parsed.pathname,
    );
    if (!title) {
      continue;
    }

    seen.add(canonicalUrl);
    candidates.push(Object.freeze({
      observationId: hashParts([
        request.executionId,
        request.scanRunId,
        request.target.targetFingerprintSha256,
        canonicalUrl,
      ]),
      rank: candidates.length + 1,
      title: title.slice(0, 500),
      canonicalUrl,
      sourceHost: parsed.hostname.toLowerCase(),
      evidenceSha256,
    }));
  }

  return Object.freeze(candidates);
}

function containsBlockMarker(value) {
  const normalized = String(value || '').toLocaleLowerCase('tr-TR');
  return BLOCK_MARKERS.some((marker) => normalized.includes(marker));
}

async function readResponseBodyBounded(
  response,
  maxResponseBytes,
) {
  if (
    response.body &&
    typeof response.body.getReader === 'function'
  ) {
    const reader = response.body.getReader();
    const chunks = [];
    let total = 0;
    try {
      while (true) {
        const {done, value} = await reader.read();
        if (done) {
          break;
        }
        const chunk = Buffer.from(value);
        total += chunk.length;
        if (total > maxResponseBytes) {
          throw new RangeError(
            `response body exceeds ${maxResponseBytes} bytes`,
          );
        }
        chunks.push(chunk);
      }
    } finally {
      reader.releaseLock();
    }
    return Buffer.concat(chunks, total);
  }

  if (typeof response.arrayBuffer !== 'function') {
    throw new TypeError(
      'response must expose body.getReader or arrayBuffer',
    );
  }

  const body = Buffer.from(await response.arrayBuffer());
  if (body.length > maxResponseBytes) {
    throw new RangeError(
      `response body exceeds ${maxResponseBytes} bytes`,
    );
  }
  return body;
}

function acquisitionRecord({
  attemptedUrl,
  finalUrl,
  httpStatus,
  acquiredAt,
  outcomeCode,
  evidenceSha256,
  responseBytes,
  retryable,
}) {
  return {
    attemptedUrl,
    finalUrl,
    httpStatus,
    acquiredAt,
    outcomeCode,
    evidenceSha256,
    responseBytes,
    retryable,
  };
}

function errorRecord(code, message, retryable) {
  return {
    code,
    message: String(message || code).slice(0, 1000),
    retryable,
  };
}

function classifyHttpStatus(status) {
  if (status === 401 || status === 403) {
    return {
      status: 'dataUnavailable',
      outcomeCode: 'access_policy_blocked',
      retryable: false,
    };
  }
  if (status === 404) {
    return {
      status: 'dataUnavailable',
      outcomeCode: 'public_page_not_found',
      retryable: false,
    };
  }
  if (status === 429) {
    return {
      status: 'dataUnavailable',
      outcomeCode: 'rate_limited',
      retryable: true,
    };
  }
  if (status >= 500) {
    return {
      status: 'failed',
      outcomeCode: 'upstream_server_error',
      retryable: true,
    };
  }
  if (status < 200 || status >= 300) {
    return {
      status: 'failed',
      outcomeCode: 'unexpected_http_status',
      retryable: false,
    };
  }
  return null;
}

function createTrendyolPublicListingAdapter({
  fetchImpl = globalThis.fetch,
  now = () => new Date(),
  timeoutMs = DEFAULT_TIMEOUT_MS,
  maxResponseBytes = DEFAULT_MAX_RESPONSE_BYTES,
  maxVisibleTextCharacters =
    DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS,
  maxCandidates = DEFAULT_MAX_CANDIDATES,
  requestHeaders = {},
} = {}) {
  const fetchFunction = assertFetch(fetchImpl);
  const normalizedTimeoutMs = normalizeInteger(
    timeoutMs,
    'timeoutMs',
    DEFAULT_TIMEOUT_MS,
    100,
    120000,
  );
  const normalizedMaxResponseBytes = normalizeInteger(
    maxResponseBytes,
    'maxResponseBytes',
    DEFAULT_MAX_RESPONSE_BYTES,
    1024,
    8 * 1024 * 1024,
  );
  const normalizedMaxVisibleTextCharacters = normalizeInteger(
    maxVisibleTextCharacters,
    'maxVisibleTextCharacters',
    DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS,
    100,
    500000,
  );
  const normalizedMaxCandidates = normalizeInteger(
    maxCandidates,
    'maxCandidates',
    DEFAULT_MAX_CANDIDATES,
    1,
    100,
  );

  assertNoSensitiveRequestHeaders(requestHeaders);

  async function acquire(input) {
    const request = createMarketplaceLimitedRequest(input);
    const attemptedUrl = buildTrendyolSearchUrl(
      request.queryText,
    );
    const acquiredAt = now().toISOString();
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      normalizedTimeoutMs,
    );

    let response;
    try {
      response = await fetchFunction(attemptedUrl, {
        method: 'GET',
        redirect: 'follow',
        signal: controller.signal,
        credentials: 'omit',
        headers: {
          accept: 'text/html,application/xhtml+xml',
          'accept-language': 'tr-TR,tr;q=0.9,en;q=0.5',
          'user-agent':
            'MarkaKalkan-Public-Lite-Acquisition/1.0',
          ...requestHeaders,
        },
      });
    } catch (error) {
      clearTimeout(timer);
      const timedOut = controller.signal.aborted ||
        error?.name === 'AbortError';
      const code = timedOut ?
        'acquisition_timeout' :
        'network_error';
      return createChannelAdapterResult({
        request,
        status: 'failed',
        acquisition: acquisitionRecord({
          attemptedUrl,
          finalUrl: null,
          httpStatus: null,
          acquiredAt,
          outcomeCode: code,
          evidenceSha256: null,
          responseBytes: null,
          retryable: true,
        }),
        observations: [],
        error: errorRecord(
          code,
          timedOut ?
            'Public acquisition timed out' :
            'Public acquisition network request failed',
          true,
        ),
      });
    }

    try {
      const finalUrl = normalizeHttpUrl(
        response.url || attemptedUrl,
        'response.url',
      );
      const finalHost = new URL(finalUrl).hostname;
      if (!isAllowedTrendyolHost(finalHost)) {
        return createChannelAdapterResult({
          request,
          status: 'failed',
          acquisition: acquisitionRecord({
            attemptedUrl,
            finalUrl,
            httpStatus: response.status,
            acquiredAt,
            outcomeCode: 'redirect_host_not_allowed',
            evidenceSha256: null,
            responseBytes: null,
            retryable: false,
          }),
          observations: [],
          error: errorRecord(
            'redirect_host_not_allowed',
            'Public acquisition redirected outside Trendyol',
            false,
          ),
        });
      }

      const body = await readResponseBodyBounded(
        response,
        normalizedMaxResponseBytes,
      );
      const evidence = buildResponseEvidence({
        url: finalUrl,
        status: response.status,
        headers: response.headers,
        body,
        acquiredAt,
        maxResponseBytes: normalizedMaxResponseBytes,
        maxVisibleTextCharacters:
          normalizedMaxVisibleTextCharacters,
      });

      const statusClassification = classifyHttpStatus(
        response.status,
      );
      if (statusClassification) {
        const failed =
          statusClassification.status === 'failed';
        return createChannelAdapterResult({
          request,
          status: statusClassification.status,
          acquisition: acquisitionRecord({
            attemptedUrl,
            finalUrl,
            httpStatus: response.status,
            acquiredAt,
            outcomeCode:
              statusClassification.outcomeCode,
            evidenceSha256: evidence.rawBodySha256,
            responseBytes: evidence.rawBodyBytes,
            retryable: statusClassification.retryable,
          }),
          observations: [],
          error: failed ?
            errorRecord(
              statusClassification.outcomeCode,
              `Unexpected Trendyol status ${response.status}`,
              statusClassification.retryable,
            ) :
            null,
        });
      }

      if (containsBlockMarker(evidence.visibleText)) {
        return createChannelAdapterResult({
          request,
          status: 'dataUnavailable',
          acquisition: acquisitionRecord({
            attemptedUrl,
            finalUrl,
            httpStatus: response.status,
            acquiredAt,
            outcomeCode: 'access_policy_blocked',
            evidenceSha256: evidence.rawBodySha256,
            responseBytes: evidence.rawBodyBytes,
            retryable: false,
          }),
          observations: [],
          error: null,
        });
      }

      const html = body.toString('utf8');
      const observations = extractProductCandidates(
        html,
        {
          baseUrl: finalUrl,
          request,
          evidenceSha256: evidence.rawBodySha256,
          maxCandidates: normalizedMaxCandidates,
        },
      );

      return createChannelAdapterResult({
        request,
        status: 'completed',
        acquisition: acquisitionRecord({
          attemptedUrl,
          finalUrl,
          httpStatus: response.status,
          acquiredAt,
          outcomeCode: observations.length > 0 ?
            'public_candidates_acquired' :
            'public_search_completed_no_candidates',
          evidenceSha256: evidence.rawBodySha256,
          responseBytes: evidence.rawBodyBytes,
          retryable: false,
        }),
        observations,
        truncated:
          observations.length === normalizedMaxCandidates,
        error: null,
      });
    } catch (error) {
      const tooLarge = error instanceof RangeError;
      return createChannelAdapterResult({
        request,
        status: 'failed',
        acquisition: acquisitionRecord({
          attemptedUrl,
          finalUrl: response.url || attemptedUrl,
          httpStatus: response.status,
          acquiredAt,
          outcomeCode: tooLarge ?
            'response_too_large' :
            'response_processing_failed',
          evidenceSha256: null,
          responseBytes: null,
          retryable: false,
        }),
        observations: [],
        error: errorRecord(
          tooLarge ?
            'response_too_large' :
            'response_processing_failed',
          error.message,
          false,
        ),
      });
    } finally {
      clearTimeout(timer);
    }
  }

  return Object.freeze({
    acquire,
    adapterCode: 'trendyol_public_listing_v1',
    channelCode: 'marketplaceLimited',
    policy: Object.freeze({
      authenticationAllowed: false,
      captchaBypassAllowed: false,
      publicPagesOnly: true,
      timeoutMs: normalizedTimeoutMs,
      maxResponseBytes: normalizedMaxResponseBytes,
      maxVisibleTextCharacters:
        normalizedMaxVisibleTextCharacters,
      maxCandidates: normalizedMaxCandidates,
    }),
  });
}

module.exports = {
  BLOCK_MARKERS,
  DEFAULT_MAX_CANDIDATES,
  DEFAULT_MAX_RESPONSE_BYTES,
  DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS,
  DEFAULT_TIMEOUT_MS,
  TRENDYOL_PUBLIC_HOST,
  assertNoSensitiveRequestHeaders,
  buildTrendyolSearchUrl,
  classifyHttpStatus,
  containsBlockMarker,
  createTrendyolPublicListingAdapter,
  extractProductCandidates,
  isAllowedTrendyolHost,
  normalizeTrendyolUrl,
  readResponseBodyBounded,
};
