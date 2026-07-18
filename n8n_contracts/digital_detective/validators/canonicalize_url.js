"use strict";
const {parseAbsoluteUrl, serializeUrl} = require("../runtime/portable_primitives");

const SENSITIVE = new Set(["token", "access_token", "api_key", "apikey",
  "password", "session", "sessionid", "cookie"]);

function canonicalizeUrl(value) {
  const errors = [];
  if (typeof value !== "string" || value.length === 0 || value.length > 2048) {
    return {valid: false, canonicalUrl: null, errors: ["URL_LENGTH_INVALID"]};
  }
  let url;
  try { url = parseAbsoluteUrl(value); } catch (_) {
    return {valid: false, canonicalUrl: null, errors: ["URL_INVALID"]};
  }
  if (url.scheme !== "https") errors.push("HTTPS_REQUIRED");
  if (url.credentials) errors.push("URL_CREDENTIALS_FORBIDDEN");
  for (const [key] of url.query) {
    if (SENSITIVE.has(key.toLowerCase())) errors.push("SENSITIVE_QUERY_FORBIDDEN");
  }
  if (errors.length) return {valid: false, canonicalUrl: null,
    errors: [...new Set(errors)]};
  const kept = [];
  for (const [key, val] of url.query) {
    const lower = key.toLowerCase();
    if (lower.startsWith("utm_") || lower === "gclid" || lower === "fbclid") continue;
    kept.push([key, val]);
  }
  const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
  kept.sort((a, b) => compare(a[0], b[0]) || compare(a[1], b[1]));
  const canonicalUrl = serializeUrl(url, kept);
  if (canonicalUrl.length > 2048) return {valid: false, canonicalUrl: null,
    errors: ["URL_LENGTH_INVALID"]};
  return {valid: true, canonicalUrl, errors: []};
}

module.exports = {canonicalizeUrl};
