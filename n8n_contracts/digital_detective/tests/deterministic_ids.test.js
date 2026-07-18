"use strict";
const test = require("node:test"); const assert = require("node:assert/strict");
const {canonicalizeUrl} = require("../validators/canonicalize_url");
const ids = require("../validators/deterministic_ids");

test("canonical query order and tracking removal are deterministic", () => { const a = canonicalizeUrl("https://EXAMPLE.com/x?b=2&utm_source=z&a=1#f"); const b = canonicalizeUrl("https://example.com/x?a=1&b=2"); assert.equal(a.canonicalUrl, b.canonicalUrl); });
test("canonicalizer rejects HTTP, credentials and sensitive query", () => { for (const url of ["http://example.com", "https://u:p@example.com", "https://example.com?token=x"]) assert.equal(canonicalizeUrl(url).valid, false); });
test("source ID is stable and execution scoped", () => { const a = ids.buildSourceId("t", "e", "https://example.com/"); assert.equal(a, ids.buildSourceId("t", "e", "https://example.com/")); assert.notEqual(a, ids.buildSourceId("t", "e2", "https://example.com/")); });
test("content changes snapshot ID", () => { const s = ids.buildSourceId("t", "e", "https://example.com/"); const a = ids.buildSnapshotId("t", "e", s, ids.buildContentHash("a")); const b = ids.buildSnapshotId("t", "e", s, ids.buildContentHash("b")); assert.notEqual(a, b); });
test("evidence order and duplicates do not change finding key", () => { const a = ids.buildFindingKey("t", "e", "c", "other", ["b", "a", "a"]); const b = ids.buildFindingKey("t", "e", "c", "other", ["a", "b"]); assert.equal(a, b); });
test("required empty inputs throw", () => { assert.throws(() => ids.buildSourceId("", "e", "u")); assert.throws(() => ids.buildContentHash("")); });
