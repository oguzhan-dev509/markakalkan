/* eslint-disable max-len */
"use strict";

const {createHash} = require("node:crypto");

class ProfessionalServicesCanonicalError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ProfessionalServicesCanonicalError";
    this.code = code;
  }
}

function fail(message) {
  throw new ProfessionalServicesCanonicalError("canonical.invalid", message);
}

function isPlainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function normalize(value, path = "$", seen = new WeakSet()) {
  if (value === null || typeof value === "string" ||
      typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      fail(`${path} contains a non-finite number`);
    }
    return value;
  }
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      fail(`${path} contains an invalid date`);
    }
    return value.toISOString();
  }
  if (Array.isArray(value)) {
    if (seen.has(value)) {
      fail(`${path} contains a circular reference`);
    }
    seen.add(value);
    const result = value.map((item, index) =>
      normalize(item, `${path}[${index}]`, seen));
    seen.delete(value);
    return result;
  }
  if (!isPlainObject(value)) {
    fail(`${path} contains an unsupported value`);
  }
  if (seen.has(value)) {
    fail(`${path} contains a circular reference`);
  }
  seen.add(value);
  const result = {};
  for (const key of Object.keys(value).sort()) {
    if (["__proto__", "prototype", "constructor"].includes(key)) {
      fail(`${path} contains an unsafe key`);
    }
    if (value[key] === undefined) {
      fail(`${path}.${key} is undefined`);
    }
    result[key] = normalize(value[key], `${path}.${key}`, seen);
  }
  seen.delete(value);
  return result;
}

function deepFreeze(value) {
  if (!value || typeof value !== "object" || Object.isFrozen(value)) {
    return value;
  }
  for (const item of Object.values(value)) {
    deepFreeze(item);
  }
  return Object.freeze(value);
}

function immutableSnapshot(value) {
  return deepFreeze(normalize(value));
}

function canonicalJson(value) {
  return JSON.stringify(normalize(value));
}

function sha256(value) {
  return createHash("sha256").update(String(value)).digest("hex");
}

function canonicalDigestSha256(value) {
  return sha256(canonicalJson(value));
}

module.exports = Object.freeze({
  ProfessionalServicesCanonicalError,
  canonicalDigestSha256,
  canonicalJson,
  deepFreeze,
  immutableSnapshot,
  normalize,
  sha256,
});
