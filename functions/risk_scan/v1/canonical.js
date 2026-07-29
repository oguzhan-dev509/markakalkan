"use strict";

const crypto = require("node:crypto");
const {isPlainObject} = require("./contracts");

const CANONICAL_JSON_ALGORITHM_V1 = "sha256-canonical-json-v1";
const LENGTH_PREFIXED_ALGORITHM_V1 = "sha256-length-prefixed-v1";

function normalizeCanonical(value, path = "$") {
  if (value === null || typeof value === "string" ||
      typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new TypeError(`${path} contains a non-finite number`);
    }
    return Object.is(value, -0) ? 0 : value;
  }
  if (Array.isArray(value)) {
    return value.map((item, index) =>
      normalizeCanonical(item, `${path}[${index}]`));
  }
  if (isPlainObject(value)) {
    const output = {};
    for (const key of Object.keys(value).sort()) {
      const child = value[key];
      if (child === undefined || typeof child === "function" ||
          typeof child === "symbol" || typeof child === "bigint") {
        throw new TypeError(`${path}.${key} contains an unsupported value`);
      }
      output[key] = normalizeCanonical(child, `${path}.${key}`);
    }
    return output;
  }
  throw new TypeError(`${path} contains an unsupported value`);
}

function canonicalJson(value) {
  return JSON.stringify(normalizeCanonical(value));
}

function sha256Hex(value) {
  if (typeof value !== "string" && !Buffer.isBuffer(value)) {
    throw new TypeError("sha256Hex value must be a string or Buffer");
  }
  return crypto.createHash("sha256").update(value).digest("hex");
}

function canonicalJsonDigestSha256(value) {
  return sha256Hex(canonicalJson(value));
}

function encodeLengthPrefixed(parts) {
  if (!Array.isArray(parts) || parts.length === 0) {
    throw new TypeError("parts must be a non-empty array");
  }
  return parts.map((part, index) => {
    if (typeof part !== "string") {
      throw new TypeError(`parts[${index}] must be a string`);
    }
    return `${Buffer.byteLength(part, "utf8")}:${part}`;
  }).join("");
}

function lengthPrefixedDigestSha256(namespace, parts) {
  if (typeof namespace !== "string" || !namespace.trim()) {
    throw new TypeError("namespace must be a non-empty string");
  }
  return sha256Hex(encodeLengthPrefixed([
    LENGTH_PREFIXED_ALGORITHM_V1,
    namespace.trim(),
    ...parts,
  ]));
}

function timingSafeSha256Equal(left, right) {
  if (!/^[a-f0-9]{64}$/.test(left || "") ||
      !/^[a-f0-9]{64}$/.test(right || "")) {
    return false;
  }
  return crypto.timingSafeEqual(
      Buffer.from(left, "hex"), Buffer.from(right, "hex"));
}

module.exports = {
  CANONICAL_JSON_ALGORITHM_V1,
  LENGTH_PREFIXED_ALGORITHM_V1,
  canonicalJson,
  canonicalJsonDigestSha256,
  encodeLengthPrefixed,
  lengthPrefixedDigestSha256,
  normalizeCanonical,
  sha256Hex,
  timingSafeSha256Equal,
};
