"use strict";

const {parseAbsoluteUrl, serializeUrl} =
  require("../runtime/portable_primitives");

const INVALID = Object.freeze({valid: false, reason: "URL_POLICY_INVALID",
  normalizedUrl: null});

function ownData(value, key) {
  try {
    if (!Object.prototype.hasOwnProperty.call(value, key)) return null;
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor,
        "value")) return null;
    return {value: descriptor.value};
  } catch (_) {
    return null;
  }
}

function validateOpenWebUrl(input) {
  try {
    if (input === null || typeof input !== "object" || Array.isArray(input)) {
      return INVALID;
    }
    const property = ownData(input, "url");
    if (!property || typeof property.value !== "string" ||
        property.value.length === 0 || property.value.length > 2048) {
      return INVALID;
    }
    const source = property.value;
    if (source.trim() !== source || source.includes("#")) return INVALID;
    const authority = /^https:\/\/([^/?#]+)/i.exec(source)?.[1] || "";
    if (!authority || authority.includes("%")) return INVALID;
    const parsed = parseAbsoluteUrl(source);
    if (parsed.scheme !== "https" || parsed.credentials ||
        parsed.hostname !== "example.com" ||
        (parsed.port !== "" && parsed.port !== "443")) return INVALID;
    const normalizedUrl = serializeUrl(parsed, parsed.query);
    if (typeof globalThis.URL === "function") {
      const native = new globalThis.URL(source);
      if (native.protocol !== "https:" || native.hostname !== "example.com" ||
          native.username || native.password || native.hash ||
          (native.port && native.port !== "443")) return INVALID;
      if (native.hostname.endsWith(".")) return INVALID;
    }
    return {valid: true, reason: "URL_POLICY_READY", normalizedUrl};
  } catch (_) {
    return INVALID;
  }
}

module.exports = {validateOpenWebUrl};
