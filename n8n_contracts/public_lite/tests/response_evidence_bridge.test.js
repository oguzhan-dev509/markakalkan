'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  SAFE_RESPONSE_HEADERS,
  buildResponseEvidence,
  decodeHtmlEntities,
  htmlToVisibleText,
  normalizeEvidenceUrl,
  normalizeHeaders,
  sha256,
} = require('../src/acquisition/response_evidence_bridge');

test('normalizes and allowlists response headers', () => {
  const headers = normalizeHeaders({
    'Content-Type': 'text/html; charset=utf-8',
    'Set-Cookie': 'secret=1',
    ETag: '"abc"',
  });

  assert.equal(
    headers['content-type'],
    'text/html; charset=utf-8',
  );
  assert.equal(headers.etag, '"abc"');
  assert.equal(headers['set-cookie'], undefined);
  assert.ok(SAFE_RESPONSE_HEADERS.includes('content-type'));
});

test('supports Headers-compatible values', () => {
  const headers = new Headers({
    'content-type': 'text/plain',
    'cache-control': 'no-cache',
  });
  const normalized = normalizeHeaders(headers);
  assert.equal(normalized['content-type'], 'text/plain');
  assert.equal(normalized['cache-control'], 'no-cache');
});

test('decodes named and numeric HTML entities', () => {
  assert.equal(
    decodeHtmlEntities(
      '&lt;Acme&gt;&nbsp;&#65;&#x42;&amp;',
    ),
    '<Acme> AB&',
  );
});

test('extracts visible text and removes scripts and styles', () => {
  const visible = htmlToVisibleText(
    '<style>hidden</style><script>secret</script>' +
      '<p>Acme&nbsp;Ürün</p>',
    100,
  );
  assert.equal(visible, 'Acme Ürün');
});

test('truncates visible text deterministically', () => {
  assert.equal(
    htmlToVisibleText('<p>abcdefgh</p>', 5),
    'abcde',
  );
});

test('normalizes evidence URLs', () => {
  assert.equal(
    normalizeEvidenceUrl(
      'HTTPS://Example.COM:443/path#fragment',
    ),
    'https://example.com/path',
  );
});

test('rejects non-HTTP evidence URLs', () => {
  assert.throws(
    () => normalizeEvidenceUrl('file:///tmp/value'),
    /must use http or https/u,
  );
});

test('builds HTML response evidence', () => {
  const evidence = buildResponseEvidence({
    url: 'https://www.trendyol.com/sr?q=Acme',
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'set-cookie': 'must-not-be-recorded',
    },
    body: '<html><body><b>Acme</b> Product</body></html>',
    acquiredAt: '2026-08-04T00:00:00Z',
  });

  assert.equal(evidence.httpStatus, 200);
  assert.equal(evidence.visibleText, 'Acme Product');
  assert.equal(evidence.selectedHeaders['set-cookie'], undefined);
  assert.match(evidence.rawBodySha256, /^[0-9a-f]{64}$/u);
  assert.match(evidence.visibleTextSha256, /^[0-9a-f]{64}$/u);
  assert.equal(
    evidence.rawBodySha256,
    sha256(
      Buffer.from(
        '<html><body><b>Acme</b> Product</body></html>',
      ),
    ),
  );
});

test('builds plain-text response evidence', () => {
  const evidence = buildResponseEvidence({
    url: 'https://www.trendyol.com/robots.txt',
    status: 200,
    headers: {'content-type': 'text/plain'},
    body: 'User-agent: *\nDisallow: /private',
    acquiredAt: new Date('2026-08-04T00:00:00Z'),
  });
  assert.equal(
    evidence.visibleText,
    'User-agent: * Disallow: /private',
  );
});

test('rejects invalid HTTP status values', () => {
  assert.throws(
    () => buildResponseEvidence({
      url: 'https://example.com/',
      status: 99,
      headers: {},
      body: '',
      acquiredAt: '2026-08-04T00:00:00Z',
    }),
    /valid HTTP status/u,
  );
});

test('rejects oversized response bodies', () => {
  assert.throws(
    () => buildResponseEvidence({
      url: 'https://example.com/',
      status: 200,
      headers: {'content-type': 'text/plain'},
      body: '123456',
      acquiredAt: '2026-08-04T00:00:00Z',
      maxResponseBytes: 5,
    }),
    /exceeds 5 bytes/u,
  );
});

test('rejects invalid timestamps', () => {
  assert.throws(
    () => buildResponseEvidence({
      url: 'https://example.com/',
      status: 200,
      headers: {'content-type': 'text/plain'},
      body: 'ok',
      acquiredAt: 'not-a-date',
    }),
    /valid timestamp/u,
  );
});

test('reports visible text truncation', () => {
  const evidence = buildResponseEvidence({
    url: 'https://example.com/',
    status: 200,
    headers: {'content-type': 'text/html'},
    body: '<p>abcdefgh</p>',
    acquiredAt: '2026-08-04T00:00:00Z',
    maxVisibleTextCharacters: 5,
  });
  assert.equal(evidence.visibleText, 'abcde');
  assert.equal(evidence.visibleTextTruncated, true);
});

test('accepts Uint8Array bodies', () => {
  const evidence = buildResponseEvidence({
    url: 'https://example.com/',
    status: 200,
    headers: {'content-type': 'text/plain'},
    body: new Uint8Array([65, 99, 109, 101]),
    acquiredAt: '2026-08-04T00:00:00Z',
  });
  assert.equal(evidence.visibleText, 'Acme');
});
