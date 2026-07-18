"use strict";

function utf8Bytes(value) {
  const bytes = [], text = String(value);
  for (let index = 0; index < text.length; index++) {
    let point = text.charCodeAt(index);
    if (point >= 0xD800 && point <= 0xDBFF) {
      const next = text.charCodeAt(index + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        point = 0x10000 + ((point - 0xD800) << 10) + next - 0xDC00;
        index++;
      } else point = 0xFFFD;
    } else if (point >= 0xDC00 && point <= 0xDFFF) point = 0xFFFD;
    if (point <= 0x7F) bytes.push(point);
    else if (point <= 0x7FF) bytes.push(0xC0 | point >> 6,
        0x80 | point & 0x3F);
    else if (point <= 0xFFFF) bytes.push(0xE0 | point >> 12,
        0x80 | point >> 6 & 0x3F, 0x80 | point & 0x3F);
    else bytes.push(0xF0 | point >> 18, 0x80 | point >> 12 & 0x3F,
        0x80 | point >> 6 & 0x3F, 0x80 | point & 0x3F);
  }
  return new Uint8Array(bytes);
}
const utf8ByteLength = (value) => utf8Bytes(value).length;

const BASE = 36, TMIN = 1, TMAX = 26, SKEW = 38, DAMP = 700;
function adapt(delta, points, first) {
  delta = first ? Math.floor(delta / DAMP) : delta >> 1;
  delta += Math.floor(delta / points);
  let k = 0;
  while (delta > Math.floor((BASE - TMIN) * TMAX / 2)) {
    delta = Math.floor(delta / (BASE - TMIN)); k += BASE;
  }
  return k + Math.floor((BASE - TMIN + 1) * delta / (delta + SKEW));
}
const digit = (value) => String.fromCharCode(value + 22 + 75 * (value < 26));
function codePoints(value) {
  const output = [];
  for (let index = 0; index < value.length; index++) {
    const first = value.charCodeAt(index), second = value.charCodeAt(index + 1);
    if (first >= 0xD800 && first <= 0xDBFF &&
        second >= 0xDC00 && second <= 0xDFFF) {
      output.push(0x10000 + ((first - 0xD800) << 10) + second - 0xDC00);
      index++;
    } else output.push(first >= 0xD800 && first <= 0xDFFF ? 0xFFFD : first);
  }
  return output;
}
function punycodeLabel(label) {
  const input = codePoints(label.toLowerCase().normalize("NFC"));
  let output = input.filter((point) => point < 0x80)
      .map((point) => String.fromCharCode(point)).join("");
  let handled = output.length;
  if (handled === input.length) return output.toLowerCase();
  if (handled) output += "-";
  let n = 128, delta = 0, bias = 72;
  while (handled < input.length) {
    let next = Infinity;
    for (const point of input) if (point >= n && point < next) next = point;
    delta += (next - n) * (handled + 1); n = next;
    for (const point of input) {
      if (point < n) delta++;
      if (point !== n) continue;
      let q = delta;
      for (let k = BASE; ; k += BASE) {
        const threshold = k <= bias ? TMIN : k >= bias + TMAX ? TMAX : k - bias;
        if (q < threshold) break;
        output += digit(threshold + (q - threshold) % (BASE - threshold));
        q = Math.floor((q - threshold) / (BASE - threshold));
      }
      output += digit(q); bias = adapt(delta, handled + 1, handled === 0);
      delta = 0; handled++;
    }
    delta++; n++;
  }
  return `xn--${output.toLowerCase()}`;
}
function hostnameToAscii(hostname) {
  return hostname.split(".").map((label) => !label || /^[\x00-\x7F]+$/.test(label) ?
    label.toLowerCase() : punycodeLabel(label)).join(".");
}
function decodeForm(value) {
  try { return decodeURIComponent(value.replace(/\+/g, " ")); } catch (_) {
    throw new TypeError("Invalid percent encoding");
  }
}
function encodeForm(value) {
  return encodeURIComponent(value).replace(/[!'()~]/g, (character) =>
    `%${character.charCodeAt(0).toString(16).toUpperCase()}`).replace(/%20/g, "+");
}
function normalizePath(path) {
  const source = path || "/", output = [];
  for (const segment of source.split("/")) {
    if (segment === ".") continue;
    if (segment === "..") { if (output.length > 1) output.pop(); continue; }
    output.push(segment);
  }
  let normalized = output.join("/");
  if (!normalized.startsWith("/")) normalized = `/${normalized}`;
  if ((source.endsWith("/.") || source.endsWith("/..")) &&
      !normalized.endsWith("/")) normalized += "/";
  return encodeURI(decodeURI(normalized)).replace(/[?#]/g, (character) =>
    character === "?" ? "%3F" : "%23");
}
function parseAbsoluteUrl(value) {
  const match = /^([A-Za-z][A-Za-z0-9+.-]*):\/\/([^/?#]*)([^?#]*)(?:\?([^#]*))?(?:#.*)?$/.exec(value);
  if (!match || !match[2]) throw new TypeError("Invalid absolute URL");
  const scheme = match[1].toLowerCase();
  let authority = match[2], credentials = false;
  const at = authority.lastIndexOf("@");
  if (at >= 0) { credentials = true; authority = authority.slice(at + 1); }
  let hostname = authority, port = "";
  if (authority.startsWith("[")) {
    const close = authority.indexOf("]");
    if (close < 0) throw new TypeError("Invalid IPv6 host");
    hostname = authority.slice(0, close + 1);
    if (authority.length > close + 1) {
      if (authority[close + 1] !== ":") throw new TypeError("Invalid port");
      port = authority.slice(close + 2);
    }
  } else {
    const colon = authority.lastIndexOf(":");
    if (colon >= 0) { hostname = authority.slice(0, colon); port = authority.slice(colon + 1); }
    hostname = hostnameToAscii(decodeURIComponent(hostname));
  }
  if (!hostname || (port && !/^\d+$/.test(port))) throw new TypeError("Invalid host");
  const query = match[4] === undefined || match[4] === "" ? [] :
    match[4].split("&").map((part) => {
      const equals = part.indexOf("=");
      return equals < 0 ? [decodeForm(part), ""] :
        [decodeForm(part.slice(0, equals)), decodeForm(part.slice(equals + 1))];
    });
  return {scheme, credentials, hostname: hostname.toLowerCase(), port,
    path: normalizePath(match[3]), query};
}
function serializeUrl(parsed, query) {
  const port = parsed.port && !(parsed.scheme === "https" && parsed.port === "443") ?
    `:${parsed.port}` : "";
  const suffix = query.length ? `?${query.map(([key, value]) =>
    `${encodeForm(key)}=${encodeForm(value)}`).join("&")}` : "";
  return `${parsed.scheme}://${parsed.hostname}${port}${parsed.path}${suffix}`;
}

module.exports = {hostnameToAscii, parseAbsoluteUrl, serializeUrl,
  utf8ByteLength, utf8Bytes};
