'use strict';

const crypto = require('node:crypto');

const DEFAULT_MAX_RESPONSE_BYTES = 1024 * 1024;
const DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS = 120000;

const SAFE_RESPONSE_HEADERS = Object.freeze([
  'cache-control',
  'content-length',
  'content-type',
  'date',
  'etag',
  'last-modified',
  'server',
  'vary',
]);

function normalizeTimestamp(value) {
  const candidate = value instanceof Date ?
    value.toISOString() :
    String(value || '').trim();

  const parsed = new Date(candidate);
  if (Number.isNaN(parsed.valueOf())) {
    throw new TypeError('acquiredAt must be a valid timestamp');
  }
  return parsed.toISOString();
}

function bodyToBuffer(body) {
  if (Buffer.isBuffer(body)) {
    return body;
  }
  if (body instanceof Uint8Array) {
    return Buffer.from(body);
  }
  if (typeof body === 'string') {
    return Buffer.from(body, 'utf8');
  }
  throw new TypeError(
    'body must be a string, Buffer, or Uint8Array',
  );
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function normalizeHeaders(headers) {
  const output = {};

  if (!headers) {
    return Object.freeze(output);
  }

  let entries;
  if (
    typeof headers.entries === 'function'
  ) {
    entries = [...headers.entries()];
  } else if (
    typeof headers === 'object' &&
    !Array.isArray(headers)
  ) {
    entries = Object.entries(headers);
  } else {
    throw new TypeError(
      'headers must be an object or Headers-compatible value',
    );
  }

  for (const [rawName, rawValue] of entries) {
    const name = String(rawName).trim().toLowerCase();
    if (!SAFE_RESPONSE_HEADERS.includes(name)) {
      continue;
    }

    const value = Array.isArray(rawValue) ?
      rawValue.join(', ') :
      String(rawValue ?? '').trim();
    if (!value) {
      continue;
    }
    output[name] = value.slice(0, 1000);
  }

  return Object.freeze(output);
}

function decodeHtmlEntities(value) {
  const named = {
    amp: '&',
    apos: '\'',
    gt: '>',
    lt: '<',
    nbsp: ' ',
    quot: '"',
  };

  return value
    .replace(
      /&(#\d+|#x[0-9a-f]+|amp|apos|gt|lt|nbsp|quot);/giu,
      (match, entity) => {
        const normalized = entity.toLowerCase();
        if (normalized.startsWith('#x')) {
          const codePoint = Number.parseInt(
            normalized.slice(2),
            16,
          );
          return Number.isFinite(codePoint) ?
            String.fromCodePoint(codePoint) :
            match;
        }
        if (normalized.startsWith('#')) {
          const codePoint = Number.parseInt(
            normalized.slice(1),
            10,
          );
          return Number.isFinite(codePoint) ?
            String.fromCodePoint(codePoint) :
            match;
        }
        return named[normalized] ?? match;
      },
    );
}

function htmlToVisibleText(html, maxCharacters) {
  const withoutNonVisible = html
    .replace(/<!--[\s\S]*?-->/gu, ' ')
    .replace(/<script\b[\s\S]*?<\/script\s*>/giu, ' ')
    .replace(/<style\b[\s\S]*?<\/style\s*>/giu, ' ')
    .replace(/<noscript\b[\s\S]*?<\/noscript\s*>/giu, ' ')
    .replace(/<svg\b[\s\S]*?<\/svg\s*>/giu, ' ')
    .replace(/<[^>]+>/gu, ' ');

  const normalized = decodeHtmlEntities(withoutNonVisible)
    .replace(/\s+/gu, ' ')
    .trim();

  return normalized.slice(0, maxCharacters);
}

function normalizeEvidenceUrl(value) {
  let parsed;
  try {
    parsed = new URL(String(value));
  } catch (error) {
    throw new TypeError('url must be an absolute URL', {
      cause: error,
    });
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new TypeError('url must use http or https');
  }
  if (parsed.username || parsed.password) {
    throw new TypeError('url must not contain credentials');
  }

  parsed.hash = '';
  parsed.hostname = parsed.hostname.toLowerCase();
  if (
    (parsed.protocol === 'https:' && parsed.port === '443') ||
    (parsed.protocol === 'http:' && parsed.port === '80')
  ) {
    parsed.port = '';
  }

  return parsed.toString();
}

function buildResponseEvidence({
  url,
  status,
  headers,
  body,
  acquiredAt,
  maxResponseBytes = DEFAULT_MAX_RESPONSE_BYTES,
  maxVisibleTextCharacters =
    DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS,
}) {
  if (
    !Number.isSafeInteger(status) ||
    status < 100 ||
    status > 599
  ) {
    throw new TypeError('status must be a valid HTTP status');
  }
  if (
    !Number.isSafeInteger(maxResponseBytes) ||
    maxResponseBytes < 1
  ) {
    throw new TypeError(
      'maxResponseBytes must be a positive integer',
    );
  }
  if (
    !Number.isSafeInteger(maxVisibleTextCharacters) ||
    maxVisibleTextCharacters < 1
  ) {
    throw new TypeError(
      'maxVisibleTextCharacters must be a positive integer',
    );
  }

  const rawBody = bodyToBuffer(body);
  if (rawBody.length > maxResponseBytes) {
    throw new RangeError(
      `response body exceeds ${maxResponseBytes} bytes`,
    );
  }

  const selectedHeaders = normalizeHeaders(headers);
  const contentType = (
    selectedHeaders['content-type'] || ''
  ).toLowerCase();
  const rawText = rawBody.toString('utf8');

  const visibleText = contentType.includes('text/html') ?
    htmlToVisibleText(
      rawText,
      maxVisibleTextCharacters,
    ) :
    rawText
      .replace(/\s+/gu, ' ')
      .trim()
      .slice(0, maxVisibleTextCharacters);

  const visibleTextBytes = Buffer.byteLength(
    visibleText,
    'utf8',
  );

  return Object.freeze({
    canonicalUrl: normalizeEvidenceUrl(url),
    httpStatus: status,
    acquiredAt: normalizeTimestamp(acquiredAt),
    contentType: selectedHeaders['content-type'] || null,
    selectedHeaders,
    rawBodyBytes: rawBody.length,
    rawBodySha256: sha256(rawBody),
    visibleText,
    visibleTextBytes,
    visibleTextSha256: sha256(
      Buffer.from(visibleText, 'utf8'),
    ),
    visibleTextTruncated:
      visibleText.length >= maxVisibleTextCharacters,
  });
}

module.exports = {
  DEFAULT_MAX_RESPONSE_BYTES,
  DEFAULT_MAX_VISIBLE_TEXT_CHARACTERS,
  SAFE_RESPONSE_HEADERS,
  buildResponseEvidence,
  decodeHtmlEntities,
  htmlToVisibleText,
  normalizeEvidenceUrl,
  normalizeHeaders,
  sha256,
};
