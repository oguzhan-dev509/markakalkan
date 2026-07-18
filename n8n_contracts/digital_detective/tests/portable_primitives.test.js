"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {createHash} = require("../build/crypto_shim");
const {canonicalizeUrl} = require("../validators/canonicalize_url");
const {hostnameToAscii, utf8ByteLength, utf8Bytes} =
  require("../runtime/portable_primitives");

function nativeCanonicalize(value) {
  const sensitive = new Set(["token", "access_token", "api_key", "apikey",
    "password", "session", "sessionid", "cookie"]);
  const url = new URL(value), errors = [];
  if (url.protocol !== "https:") errors.push("HTTPS_REQUIRED");
  if (url.username || url.password) errors.push("URL_CREDENTIALS_FORBIDDEN");
  for (const key of url.searchParams.keys()) {
    if (sensitive.has(key.toLowerCase())) errors.push("SENSITIVE_QUERY_FORBIDDEN");
  }
  if (errors.length) return {valid: false, canonicalUrl: null,
    errors: [...new Set(errors)]};
  url.protocol = url.protocol.toLowerCase(); url.hostname = url.hostname.toLowerCase();
  url.hash = ""; if (url.port === "443") url.port = "";
  const kept = [];
  for (const [key, val] of url.searchParams.entries()) {
    const lower = key.toLowerCase();
    if (lower.startsWith("utm_") || lower === "gclid" || lower === "fbclid") continue;
    kept.push([key, val]);
  }
  kept.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 :
    a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0);
  url.search = "";
  for (const [key, val] of kept) url.searchParams.append(key, val);
  return {valid: true, canonicalUrl: url.toString(), errors: []};
}

for (const [name, value] of [
  ["ASCII", "plain ASCII"], ["Turkish", "İstanbul şüpheli ürün"],
  ["Uyghur", "ئۇيغۇرچە"], ["emoji", "🔍🛡️"], ["CRLF", "a\r\nb"],
  ["CR", "a\rb"], ["LF", "a\nb"], ["NFC", "é"], ["NFD", "e\u0301"],
]) {
  test(`portable UTF-8 equals Buffer for ${name}`, () => {
    assert.deepEqual([...utf8Bytes(value)], [...Buffer.from(value, "utf8")]);
    assert.equal(utf8ByteLength(value), Buffer.byteLength(value, "utf8"));
  });
}

for (const value of ["plain ASCII", "İstanbul", "ئۇيغۇرچە", "🔍", "e\u0301"]) {
  test(`portable SHA-256 equals Node for ${JSON.stringify(value)}`, () => {
    assert.equal(createHash("sha256").update(value, "utf8").digest("hex"),
        crypto.createHash("sha256").update(value, "utf8").digest("hex"));
    assert.match(createHash("sha256").update(value).digest("hex"), /^[0-9a-f]{64}$/);
  });
}

for (const hostname of ["bücher.example", "مثال.إختبار", "İstanbul.example"]) {
  test(`portable IDN equals native URL for ${hostname}`, () => {
    assert.equal(hostnameToAscii(hostname), new URL(`https://${hostname}/`).hostname);
  });
}

for (const value of [
  "https://EXAMPLE.com:443/path?b=2&a=1#fragment",
  "https://bücher.example/ürün?q=şüpheli",
  "https://example.com/path?a=2&a=1&a=",
  "https://example.com//double//path?empty=&flag",
  "https://example.com/path?utm_source=x&b=2&gclid=y&a=1",
  "https://example.com/a/./b/../c",
]) {
  test(`portable canonical URL equals native behavior for ${value}`, () => {
    assert.deepEqual(canonicalizeUrl(value), nativeCanonicalize(value));
  });
}

for (const value of [
  "https://example.com/?token=x",
  "https://example.com/?%74oken=x",
  "https://example.com/?api%5Fkey=x",
]) {
  test(`encoded sensitive query is rejected for ${value}`, () => {
    assert.deepEqual(canonicalizeUrl(value), nativeCanonicalize(value));
    assert.equal(canonicalizeUrl(value).valid, false);
  });
}
