"use strict";
var MarkaKalkanDdtRuntime = (() => {
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __commonJS = (cb, mod) => function __loadBundledModule() {
    try {
      return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
    } catch (e) {
      throw mod = 0, e;
    }
  };

  // validators/canonicalize_url.js
  var require_canonicalize_url = __commonJS({
    "validators/canonicalize_url.js"(exports, module) {
      "use strict";
      var SENSITIVE = /* @__PURE__ */ new Set([
        "token",
        "access_token",
        "api_key",
        "apikey",
        "password",
        "session",
        "sessionid",
        "cookie"
      ]);
      function canonicalizeUrl(value) {
        const errors = [];
        if (typeof value !== "string" || value.length === 0 || value.length > 2048) {
          return { valid: false, canonicalUrl: null, errors: ["URL_LENGTH_INVALID"] };
        }
        let url;
        try {
          url = new URL(value);
        } catch (_) {
          return { valid: false, canonicalUrl: null, errors: ["URL_INVALID"] };
        }
        if (url.protocol !== "https:") errors.push("HTTPS_REQUIRED");
        if (url.username || url.password) errors.push("URL_CREDENTIALS_FORBIDDEN");
        for (const key of url.searchParams.keys()) {
          if (SENSITIVE.has(key.toLowerCase())) errors.push("SENSITIVE_QUERY_FORBIDDEN");
        }
        if (errors.length) return {
          valid: false,
          canonicalUrl: null,
          errors: [...new Set(errors)]
        };
        url.protocol = url.protocol.toLowerCase();
        url.hostname = url.hostname.toLowerCase();
        url.hash = "";
        if (url.port === "443") url.port = "";
        const kept = [];
        for (const [key, val] of url.searchParams.entries()) {
          const lower = key.toLowerCase();
          if (lower.startsWith("utm_") || lower === "gclid" || lower === "fbclid") continue;
          kept.push([key, val]);
        }
        const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
        kept.sort((a, b) => compare(a[0], b[0]) || compare(a[1], b[1]));
        url.search = "";
        for (const [key, val] of kept) url.searchParams.append(key, val);
        const canonicalUrl = url.toString();
        if (canonicalUrl.length > 2048) return {
          valid: false,
          canonicalUrl: null,
          errors: ["URL_LENGTH_INVALID"]
        };
        return { valid: true, canonicalUrl, errors: [] };
      }
      module["exports"] = { canonicalizeUrl };
    }
  });

  // build/crypto_shim.js
  var require_crypto_shim = __commonJS({
    "build/crypto_shim.js"(exports, module) {
      "use strict";
      var INITIAL = [
        1779033703,
        3144134277,
        1013904242,
        2773480762,
        1359893119,
        2600822924,
        528734635,
        1541459225
      ];
      var ROUND = [
        1116352408,
        1899447441,
        3049323471,
        3921009573,
        961987163,
        1508970993,
        2453635748,
        2870763221,
        3624381080,
        310598401,
        607225278,
        1426881987,
        1925078388,
        2162078206,
        2614888103,
        3248222580,
        3835390401,
        4022224774,
        264347078,
        604807628,
        770255983,
        1249150122,
        1555081692,
        1996064986,
        2554220882,
        2821834349,
        2952996808,
        3210313671,
        3336571891,
        3584528711,
        113926993,
        338241895,
        666307205,
        773529912,
        1294757372,
        1396182291,
        1695183700,
        1986661051,
        2177026350,
        2456956037,
        2730485921,
        2820302411,
        3259730800,
        3345764771,
        3516065817,
        3600352804,
        4094571909,
        275423344,
        430227734,
        506948616,
        659060556,
        883997877,
        958139571,
        1322822218,
        1537002063,
        1747873779,
        1955562222,
        2024104815,
        2227730452,
        2361852424,
        2428436474,
        2756734187,
        3204031479,
        3329325298
      ];
      function rotateRight(value, shift) {
        return value >>> shift | value << 32 - shift;
      }
      function sha256Hex(text) {
        const input = new TextEncoder().encode(text);
        const bitLength = input.length * 8;
        const paddedLength = Math.ceil((input.length + 9) / 64) * 64;
        const bytes = new Uint8Array(paddedLength);
        bytes.set(input);
        bytes[input.length] = 128;
        const view = new DataView(bytes.buffer);
        view.setUint32(paddedLength - 8, Math.floor(bitLength / 4294967296));
        view.setUint32(paddedLength - 4, bitLength >>> 0);
        const state = INITIAL.slice();
        const words = new Uint32Array(64);
        for (let offset = 0; offset < paddedLength; offset += 64) {
          for (let index = 0; index < 16; index++) {
            words[index] = view.getUint32(offset + index * 4);
          }
          for (let index = 16; index < 64; index++) {
            const s0 = rotateRight(words[index - 15], 7) ^ rotateRight(words[index - 15], 18) ^ words[index - 15] >>> 3;
            const s1 = rotateRight(words[index - 2], 17) ^ rotateRight(words[index - 2], 19) ^ words[index - 2] >>> 10;
            words[index] = words[index - 16] + s0 + words[index - 7] + s1 >>> 0;
          }
          let [a, b, c, d, e, f, g, h] = state;
          for (let index = 0; index < 64; index++) {
            const sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
            const choice = e & f ^ ~e & g;
            const temp1 = h + sum1 + choice + ROUND[index] + words[index] >>> 0;
            const sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
            const majority = a & b ^ a & c ^ b & c;
            const temp2 = sum0 + majority >>> 0;
            h = g;
            g = f;
            f = e;
            e = d + temp1 >>> 0;
            d = c;
            c = b;
            b = a;
            a = temp1 + temp2 >>> 0;
          }
          state[0] = state[0] + a >>> 0;
          state[1] = state[1] + b >>> 0;
          state[2] = state[2] + c >>> 0;
          state[3] = state[3] + d >>> 0;
          state[4] = state[4] + e >>> 0;
          state[5] = state[5] + f >>> 0;
          state[6] = state[6] + g >>> 0;
          state[7] = state[7] + h >>> 0;
        }
        return state.map((value) => value.toString(16).padStart(8, "0")).join("");
      }
      function createHash(algorithm) {
        if (algorithm !== "sha256") throw new TypeError("Unsupported hash algorithm");
        const chunks = [];
        return {
          update(value, encoding = "utf8") {
            if (encoding !== "utf8") throw new TypeError("Unsupported hash encoding");
            chunks.push(String(value));
            return this;
          },
          digest(encoding) {
            if (encoding !== "hex") throw new TypeError("Unsupported digest encoding");
            return sha256Hex(chunks.join(""));
          }
        };
      }
      module["exports"] = { createHash };
    }
  });

  // validators/deterministic_ids.js
  var require_deterministic_ids = __commonJS({
    "validators/deterministic_ids.js"(exports, module) {
      "use strict";
      var crypto = require_crypto_shim();
      function required(value, name) {
        if (typeof value !== "string" || value.length === 0) throw new TypeError(`${name} is required`);
        return value;
      }
      function hash(parts) {
        return crypto.createHash("sha256").update(parts.join("|"), "utf8").digest("hex");
      }
      function normalizeVisibleText(value) {
        return required(value, "visibleText").replace(/\r\n?/g, "\n").normalize("NFC");
      }
      function buildSourceId(taskId, executionId, canonicalUrl) {
        return hash([
          "source-v1",
          required(taskId, "taskId"),
          required(executionId, "executionId"),
          required(canonicalUrl, "canonicalUrl")
        ]);
      }
      function buildContentHash(text) {
        return hash(["content-v1", normalizeVisibleText(text)]);
      }
      function buildSnapshotId(taskId, executionId, sourceId, contentHash) {
        return hash([
          "snapshot-v1",
          required(taskId, "taskId"),
          required(executionId, "executionId"),
          required(sourceId, "sourceId"),
          required(contentHash, "contentHash")
        ]);
      }
      function buildEvidenceFingerprint(references) {
        if (!Array.isArray(references)) throw new TypeError("evidenceReferences must be an array");
        const normalized = [...new Set(references.map((v) => required(v, "evidenceReference")))].sort();
        return hash(["evidence-fingerprint-v1", ...normalized]);
      }
      function buildFindingKey(taskId, executionId, candidateId, signalType, evidenceReferences) {
        return hash([
          "finding-v1",
          required(taskId, "taskId"),
          required(executionId, "executionId"),
          required(candidateId, "candidateId"),
          required(signalType, "signalType"),
          buildEvidenceFingerprint(evidenceReferences)
        ]);
      }
      module["exports"] = {
        buildSourceId,
        buildContentHash,
        buildSnapshotId,
        buildEvidenceFingerprint,
        buildFindingKey,
        normalizeVisibleText
      };
    }
  });

  // validators/validator_result.js
  var require_validator_result = __commonJS({
    "validators/validator_result.js"(exports, module) {
      "use strict";
      function issue(code, path, message) {
        return { code, path, message };
      }
      function isPlainRecord(value) {
        if (value === null || typeof value !== "object" || Array.isArray(value)) {
          return false;
        }
        const prototype = Object.getPrototypeOf(value);
        return prototype === Object.prototype || prototype === null;
      }
      function result({
        errors = [],
        warnings = [],
        acceptedFindingCount = 0,
        rejectedFindingCount = 0
      } = {}) {
        return {
          valid: errors.length === 0,
          errors,
          warnings,
          acceptedFindingCount,
          rejectedFindingCount
        };
      }
      module["exports"] = { isPlainRecord, issue, result };
    }
  });

  // node_modules/ajv/dist/runtime/ucs2length.js
  var require_ucs2length = __commonJS({
    "node_modules/ajv/dist/runtime/ucs2length.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      function ucs2length(str) {
        const len = str.length;
        let length = 0;
        let pos = 0;
        let value;
        while (pos < len) {
          length++;
          value = str.charCodeAt(pos++);
          if (value >= 55296 && value <= 56319 && pos < len) {
            value = str.charCodeAt(pos);
            if ((value & 64512) === 56320)
              pos++;
          }
        }
        return length;
      }
      exports.default = ucs2length;
      ucs2length.code = 'bundledModule("ajv/dist/runtime/ucs2length").default';
    }
  });

  // node_modules/ajv-formats/dist/formats.js
  var require_formats = __commonJS({
    "node_modules/ajv-formats/dist/formats.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.formatNames = exports.fastFormats = exports.fullFormats = void 0;
      function fmtDef(validate, compare) {
        return { validate, compare };
      }
      exports.fullFormats = {
        // date: http://tools.ietf.org/html/rfc3339#section-5.6
        date: fmtDef(date, compareDate),
        // date-time: http://tools.ietf.org/html/rfc3339#section-5.6
        time: fmtDef(getTime(true), compareTime),
        "date-time": fmtDef(getDateTime(true), compareDateTime),
        "iso-time": fmtDef(getTime(), compareIsoTime),
        "iso-date-time": fmtDef(getDateTime(), compareIsoDateTime),
        // duration: https://tools.ietf.org/html/rfc3339#appendix-A
        duration: /^P(?!$)((\d+Y)?(\d+M)?(\d+D)?(T(?=\d)(\d+H)?(\d+M)?(\d+S)?)?|(\d+W)?)$/,
        uri,
        "uri-reference": /^(?:[a-z][a-z0-9+\-.]*:)?(?:\/?\/(?:(?:[a-z0-9\-._~!$&'()*+,;=:]|%[0-9a-f]{2})*@)?(?:\[(?:(?:(?:(?:[0-9a-f]{1,4}:){6}|::(?:[0-9a-f]{1,4}:){5}|(?:[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){4}|(?:(?:[0-9a-f]{1,4}:){0,1}[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){3}|(?:(?:[0-9a-f]{1,4}:){0,2}[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){2}|(?:(?:[0-9a-f]{1,4}:){0,3}[0-9a-f]{1,4})?::[0-9a-f]{1,4}:|(?:(?:[0-9a-f]{1,4}:){0,4}[0-9a-f]{1,4})?::)(?:[0-9a-f]{1,4}:[0-9a-f]{1,4}|(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?))|(?:(?:[0-9a-f]{1,4}:){0,5}[0-9a-f]{1,4})?::[0-9a-f]{1,4}|(?:(?:[0-9a-f]{1,4}:){0,6}[0-9a-f]{1,4})?::)|[Vv][0-9a-f]+\.[a-z0-9\-._~!$&'()*+,;=:]+)\]|(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)|(?:[a-z0-9\-._~!$&'"()*+,;=]|%[0-9a-f]{2})*)(?::\d*)?(?:\/(?:[a-z0-9\-._~!$&'"()*+,;=:@]|%[0-9a-f]{2})*)*|\/(?:(?:[a-z0-9\-._~!$&'"()*+,;=:@]|%[0-9a-f]{2})+(?:\/(?:[a-z0-9\-._~!$&'"()*+,;=:@]|%[0-9a-f]{2})*)*)?|(?:[a-z0-9\-._~!$&'"()*+,;=:@]|%[0-9a-f]{2})+(?:\/(?:[a-z0-9\-._~!$&'"()*+,;=:@]|%[0-9a-f]{2})*)*)?(?:\?(?:[a-z0-9\-._~!$&'"()*+,;=:@/?]|%[0-9a-f]{2})*)?(?:#(?:[a-z0-9\-._~!$&'"()*+,;=:@/?]|%[0-9a-f]{2})*)?$/i,
        // uri-template: https://tools.ietf.org/html/rfc6570
        "uri-template": /^(?:(?:[^\x00-\x20"'<>%\\^`{|}]|%[0-9a-f]{2})|\{[+#./;?&=,!@|]?(?:[a-z0-9_]|%[0-9a-f]{2})+(?::[1-9][0-9]{0,3}|\*)?(?:,(?:[a-z0-9_]|%[0-9a-f]{2})+(?::[1-9][0-9]{0,3}|\*)?)*\})*$/i,
        // For the source: https://gist.github.com/dperini/729294
        // For test cases: https://mathiasbynens.be/demo/url-regex
        url: /^(?:https?|ftp):\/\/(?:\S+(?::\S*)?@)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z0-9\u{00a1}-\u{ffff}]+-)*[a-z0-9\u{00a1}-\u{ffff}]+)(?:\.(?:[a-z0-9\u{00a1}-\u{ffff}]+-)*[a-z0-9\u{00a1}-\u{ffff}]+)*(?:\.(?:[a-z\u{00a1}-\u{ffff}]{2,})))(?::\d{2,5})?(?:\/[^\s]*)?$/iu,
        email: /^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/i,
        hostname: /^(?=.{1,253}\.?$)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[-0-9a-z]{0,61}[0-9a-z])?)*\.?$/i,
        // optimized https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
        ipv4: /^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/,
        ipv6: /^((([0-9a-f]{1,4}:){7}([0-9a-f]{1,4}|:))|(([0-9a-f]{1,4}:){6}(:[0-9a-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9a-f]{1,4}:){5}(((:[0-9a-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9a-f]{1,4}:){4}(((:[0-9a-f]{1,4}){1,3})|((:[0-9a-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9a-f]{1,4}:){3}(((:[0-9a-f]{1,4}){1,4})|((:[0-9a-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9a-f]{1,4}:){2}(((:[0-9a-f]{1,4}){1,5})|((:[0-9a-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9a-f]{1,4}:){1}(((:[0-9a-f]{1,4}){1,6})|((:[0-9a-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9a-f]{1,4}){1,7})|((:[0-9a-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))$/i,
        regex,
        // uuid: http://tools.ietf.org/html/rfc4122
        uuid: /^(?:urn:uuid:)?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i,
        // JSON-pointer: https://tools.ietf.org/html/rfc6901
        // uri fragment: https://tools.ietf.org/html/rfc3986#appendix-A
        "json-pointer": /^(?:\/(?:[^~/]|~0|~1)*)*$/,
        "json-pointer-uri-fragment": /^#(?:\/(?:[a-z0-9_\-.!$&'()*+,;:=@]|%[0-9a-f]{2}|~0|~1)*)*$/i,
        // relative JSON-pointer: http://tools.ietf.org/html/draft-luff-relative-json-pointer-00
        "relative-json-pointer": /^(?:0|[1-9][0-9]*)(?:#|(?:\/(?:[^~/]|~0|~1)*)*)$/,
        // the following formats are used by the openapi specification: https://spec.openapis.org/oas/v3.0.0#data-types
        // byte: https://github.com/miguelmota/is-base64
        byte,
        // signed 32 bit integer
        int32: { type: "number", validate: validateInt32 },
        // signed 64 bit integer
        int64: { type: "number", validate: validateInt64 },
        // C-type float
        float: { type: "number", validate: validateNumber },
        // C-type double
        double: { type: "number", validate: validateNumber },
        // hint to the UI to hide input strings
        password: true,
        // unchecked string payload
        binary: true
      };
      exports.fastFormats = {
        ...exports.fullFormats,
        date: fmtDef(/^\d\d\d\d-[0-1]\d-[0-3]\d$/, compareDate),
        time: fmtDef(/^(?:[0-2]\d:[0-5]\d:[0-5]\d|23:59:60)(?:\.\d+)?(?:z|[+-]\d\d(?::?\d\d)?)$/i, compareTime),
        "date-time": fmtDef(/^\d\d\d\d-[0-1]\d-[0-3]\dt(?:[0-2]\d:[0-5]\d:[0-5]\d|23:59:60)(?:\.\d+)?(?:z|[+-]\d\d(?::?\d\d)?)$/i, compareDateTime),
        "iso-time": fmtDef(/^(?:[0-2]\d:[0-5]\d:[0-5]\d|23:59:60)(?:\.\d+)?(?:z|[+-]\d\d(?::?\d\d)?)?$/i, compareIsoTime),
        "iso-date-time": fmtDef(/^\d\d\d\d-[0-1]\d-[0-3]\d[t\s](?:[0-2]\d:[0-5]\d:[0-5]\d|23:59:60)(?:\.\d+)?(?:z|[+-]\d\d(?::?\d\d)?)?$/i, compareIsoDateTime),
        // uri: https://github.com/mafintosh/is-my-json-valid/blob/master/formats.js
        uri: /^(?:[a-z][a-z0-9+\-.]*:)(?:\/?\/)?[^\s]*$/i,
        "uri-reference": /^(?:(?:[a-z][a-z0-9+\-.]*:)?\/?\/)?(?:[^\\\s#][^\s#]*)?(?:#[^\\\s]*)?$/i,
        // email (sources from jsen validator):
        // http://stackoverflow.com/questions/201323/using-a-regular-expression-to-validate-an-email-address#answer-8829363
        // http://www.w3.org/TR/html5/forms.html#valid-e-mail-address (search for 'wilful violation')
        email: /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$/i
      };
      exports.formatNames = Object.keys(exports.fullFormats);
      function isLeapYear(year) {
        return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
      }
      var DATE = /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
      var DAYS = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      function date(str) {
        const matches = DATE.exec(str);
        if (!matches)
          return false;
        const year = +matches[1];
        const month = +matches[2];
        const day = +matches[3];
        return month >= 1 && month <= 12 && day >= 1 && day <= (month === 2 && isLeapYear(year) ? 29 : DAYS[month]);
      }
      function compareDate(d1, d2) {
        if (!(d1 && d2))
          return void 0;
        if (d1 > d2)
          return 1;
        if (d1 < d2)
          return -1;
        return 0;
      }
      var TIME = /^(\d\d):(\d\d):(\d\d(?:\.\d+)?)(z|([+-])(\d\d)(?::?(\d\d))?)?$/i;
      function getTime(strictTimeZone) {
        return function time(str) {
          const matches = TIME.exec(str);
          if (!matches)
            return false;
          const hr = +matches[1];
          const min = +matches[2];
          const sec = +matches[3];
          const tz = matches[4];
          const tzSign = matches[5] === "-" ? -1 : 1;
          const tzH = +(matches[6] || 0);
          const tzM = +(matches[7] || 0);
          if (tzH > 23 || tzM > 59 || strictTimeZone && !tz)
            return false;
          if (hr <= 23 && min <= 59 && sec < 60)
            return true;
          const utcMin = min - tzM * tzSign;
          const utcHr = hr - tzH * tzSign - (utcMin < 0 ? 1 : 0);
          return (utcHr === 23 || utcHr === -1) && (utcMin === 59 || utcMin === -1) && sec < 61;
        };
      }
      function compareTime(s1, s2) {
        if (!(s1 && s2))
          return void 0;
        const t1 = (/* @__PURE__ */ new Date("2020-01-01T" + s1)).valueOf();
        const t2 = (/* @__PURE__ */ new Date("2020-01-01T" + s2)).valueOf();
        if (!(t1 && t2))
          return void 0;
        return t1 - t2;
      }
      function compareIsoTime(t1, t2) {
        if (!(t1 && t2))
          return void 0;
        const a1 = TIME.exec(t1);
        const a2 = TIME.exec(t2);
        if (!(a1 && a2))
          return void 0;
        t1 = a1[1] + a1[2] + a1[3];
        t2 = a2[1] + a2[2] + a2[3];
        if (t1 > t2)
          return 1;
        if (t1 < t2)
          return -1;
        return 0;
      }
      var DATE_TIME_SEPARATOR = /t|\s/i;
      function getDateTime(strictTimeZone) {
        const time = getTime(strictTimeZone);
        return function date_time(str) {
          const dateTime = str.split(DATE_TIME_SEPARATOR);
          return dateTime.length === 2 && date(dateTime[0]) && time(dateTime[1]);
        };
      }
      function compareDateTime(dt1, dt2) {
        if (!(dt1 && dt2))
          return void 0;
        const d1 = new Date(dt1).valueOf();
        const d2 = new Date(dt2).valueOf();
        if (!(d1 && d2))
          return void 0;
        return d1 - d2;
      }
      function compareIsoDateTime(dt1, dt2) {
        if (!(dt1 && dt2))
          return void 0;
        const [d1, t1] = dt1.split(DATE_TIME_SEPARATOR);
        const [d2, t2] = dt2.split(DATE_TIME_SEPARATOR);
        const res = compareDate(d1, d2);
        if (res === void 0)
          return void 0;
        return res || compareTime(t1, t2);
      }
      var NOT_URI_FRAGMENT = /\/|:/;
      var URI = /^(?:[a-z][a-z0-9+\-.]*:)(?:\/?\/(?:(?:[a-z0-9\-._~!$&'()*+,;=:]|%[0-9a-f]{2})*@)?(?:\[(?:(?:(?:(?:[0-9a-f]{1,4}:){6}|::(?:[0-9a-f]{1,4}:){5}|(?:[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){4}|(?:(?:[0-9a-f]{1,4}:){0,1}[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){3}|(?:(?:[0-9a-f]{1,4}:){0,2}[0-9a-f]{1,4})?::(?:[0-9a-f]{1,4}:){2}|(?:(?:[0-9a-f]{1,4}:){0,3}[0-9a-f]{1,4})?::[0-9a-f]{1,4}:|(?:(?:[0-9a-f]{1,4}:){0,4}[0-9a-f]{1,4})?::)(?:[0-9a-f]{1,4}:[0-9a-f]{1,4}|(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?))|(?:(?:[0-9a-f]{1,4}:){0,5}[0-9a-f]{1,4})?::[0-9a-f]{1,4}|(?:(?:[0-9a-f]{1,4}:){0,6}[0-9a-f]{1,4})?::)|[Vv][0-9a-f]+\.[a-z0-9\-._~!$&'()*+,;=:]+)\]|(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)|(?:[a-z0-9\-._~!$&'()*+,;=]|%[0-9a-f]{2})*)(?::\d*)?(?:\/(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})*)*|\/(?:(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})+(?:\/(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})*)*)?|(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})+(?:\/(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})*)*)(?:\?(?:[a-z0-9\-._~!$&'()*+,;=:@/?]|%[0-9a-f]{2})*)?(?:#(?:[a-z0-9\-._~!$&'()*+,;=:@/?]|%[0-9a-f]{2})*)?$/i;
      function uri(str) {
        return NOT_URI_FRAGMENT.test(str) && URI.test(str);
      }
      var BYTE = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/gm;
      function byte(str) {
        BYTE.lastIndex = 0;
        return BYTE.test(str);
      }
      var MIN_INT32 = -(2 ** 31);
      var MAX_INT32 = 2 ** 31 - 1;
      function validateInt32(value) {
        return Number.isInteger(value) && value <= MAX_INT32 && value >= MIN_INT32;
      }
      function validateInt64(value) {
        return Number.isInteger(value);
      }
      function validateNumber() {
        return true;
      }
      var Z_ANCHOR = /[^\\]\\Z/;
      function regex(str) {
        if (Z_ANCHOR.test(str))
          return false;
        try {
          new RegExp(str);
          return true;
        } catch (e) {
          return false;
        }
      }
    }
  });

  // .build-tmp/standalone_validators.js
  var require_standalone_validators = __commonJS({
    ".build-tmp/standalone_validators.js"(exports) {
      "use strict";
      exports.acquisition_result = validate20;
      var schema31 = { "$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "acquisition_result.schema.json", "title": "AcquisitionResult v1", "type": "object", "additionalProperties": false, "required": ["contractVersion", "taskId", "executionId", "status", "candidates", "queriesAttempted", "errors", "limits", "fixtureMetadata"], "properties": { "contractVersion": { "const": "acquisition-result-v1" }, "taskId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "executionId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "status": { "enum": ["completed", "partial", "no_candidates", "failed"] }, "candidates": { "type": "array", "maxItems": 3, "items": { "$ref": "candidate_source.schema.json" } }, "queriesAttempted": { "type": "array", "maxItems": 20, "items": { "type": "string", "maxLength": 500 } }, "errors": { "type": "array", "maxItems": 20, "items": { "type": "object", "additionalProperties": false, "required": ["code", "message"], "properties": { "code": { "type": "string", "minLength": 1, "maxLength": 100 }, "message": { "type": "string", "minLength": 1, "maxLength": 500 } } } }, "limits": { "type": "object", "additionalProperties": false, "required": ["maximumCandidates", "maximumTotalVisibleTextBytes"], "properties": { "maximumCandidates": { "const": 3 }, "maximumTotalVisibleTextBytes": { "const": 393216 } } }, "fixtureMetadata": { "oneOf": [{ "type": "null" }, { "$ref": "candidate_source.schema.json#/$defs/fixtureMetadata" }] } }, "allOf": [{ "if": { "required": ["status"], "properties": { "status": { "const": "no_candidates" } } }, "then": { "properties": { "candidates": { "type": "array", "maxItems": 0 } } } }, { "if": { "required": ["status"], "properties": { "status": { "const": "completed" } } }, "then": { "properties": { "candidates": { "type": "array", "minItems": 1 } } } }] };
      var schema33 = { "type": "object", "additionalProperties": false, "required": ["marker", "isTestFixture", "productionEligible", "scenario"], "properties": { "marker": { "const": "TEST_FIXTURE" }, "isTestFixture": { "const": true }, "productionEligible": { "const": false }, "scenario": { "enum": ["no_signal", "synthetic_signal", "blocked"] } } };
      var func1 = Object.prototype.hasOwnProperty;
      var func2 = require_ucs2length().default;
      var pattern4 = new RegExp("^[^/]+$", "u");
      var schema32 = { "$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "candidate_source.schema.json", "title": "CandidateSource v1", "type": "object", "additionalProperties": false, "required": ["contractVersion", "taskId", "executionId", "sourceId", "sourceUrl", "canonicalUrl", "sourcePlatform", "pageTitle", "sellerName", "productTitle", "price", "currency", "country", "city", "searchQuery", "acquisitionMethod", "discoveredAt", "acquisitionStatus", "legalBasis", "robotsPolicy"], "properties": { "contractVersion": { "const": "candidate-source-v1" }, "taskId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "executionId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "sourceId": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "sourceUrl": { "type": "string", "format": "uri", "pattern": "^https://", "maxLength": 2048 }, "canonicalUrl": { "type": "string", "format": "uri", "pattern": "^https://", "maxLength": 2048 }, "sourcePlatform": { "type": "string", "minLength": 1, "maxLength": 100 }, "pageTitle": { "type": ["string", "null"], "maxLength": 500 }, "sellerName": { "type": ["string", "null"], "maxLength": 300 }, "productTitle": { "type": ["string", "null"], "maxLength": 500 }, "price": { "type": ["number", "null"], "minimum": 0 }, "currency": { "type": ["string", "null"], "pattern": "^[A-Z]{3}$" }, "country": { "type": ["string", "null"], "maxLength": 100 }, "city": { "type": ["string", "null"], "maxLength": 150 }, "searchQuery": { "type": ["string", "null"], "maxLength": 500 }, "acquisitionMethod": { "const": "manual_seed" }, "discoveredAt": { "type": "string", "format": "date-time" }, "acquisitionStatus": { "enum": ["pending", "acquired", "failed", "blocked"] }, "legalBasis": { "const": "public_source" }, "robotsPolicy": { "enum": ["allowed", "unknown", "blocked"] }, "errorCode": { "type": ["string", "null"], "enum": [null, "http_4xx", "http_5xx", "captcha", "login_required", "robots_blocked", "network_error"] }, "fixtureMetadata": { "$ref": "#/$defs/fixtureMetadata" } }, "$defs": { "fixtureMetadata": { "type": "object", "additionalProperties": false, "required": ["marker", "isTestFixture", "productionEligible", "scenario"], "properties": { "marker": { "const": "TEST_FIXTURE" }, "isTestFixture": { "const": true }, "productionEligible": { "const": false }, "scenario": { "enum": ["no_signal", "synthetic_signal", "blocked"] } } } } };
      var pattern8 = new RegExp("^[a-f0-9]{64}$", "u");
      var pattern9 = new RegExp("^https://", "u");
      var pattern11 = new RegExp("^[A-Z]{3}$", "u");
      var formats0 = require_formats().fullFormats.uri;
      var formats4 = require_formats().fullFormats["date-time"];
      function validate21(data, { instancePath = "", parentData, parentDataProperty, rootData = data, dynamicAnchors = {} } = {}) {
        ;
        let vErrors = null;
        let errors = 0;
        const evaluated0 = validate21.evaluated;
        if (evaluated0.dynamicProps) {
          evaluated0.props = void 0;
        }
        if (evaluated0.dynamicItems) {
          evaluated0.items = void 0;
        }
        if (data && typeof data == "object" && !Array.isArray(data)) {
          if (data.contractVersion === void 0) {
            const err0 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contractVersion" }, message: "must have required property 'contractVersion'" };
            if (vErrors === null) {
              vErrors = [err0];
            } else {
              vErrors.push(err0);
            }
            errors++;
          }
          if (data.taskId === void 0) {
            const err1 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "taskId" }, message: "must have required property 'taskId'" };
            if (vErrors === null) {
              vErrors = [err1];
            } else {
              vErrors.push(err1);
            }
            errors++;
          }
          if (data.executionId === void 0) {
            const err2 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "executionId" }, message: "must have required property 'executionId'" };
            if (vErrors === null) {
              vErrors = [err2];
            } else {
              vErrors.push(err2);
            }
            errors++;
          }
          if (data.sourceId === void 0) {
            const err3 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sourceId" }, message: "must have required property 'sourceId'" };
            if (vErrors === null) {
              vErrors = [err3];
            } else {
              vErrors.push(err3);
            }
            errors++;
          }
          if (data.sourceUrl === void 0) {
            const err4 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sourceUrl" }, message: "must have required property 'sourceUrl'" };
            if (vErrors === null) {
              vErrors = [err4];
            } else {
              vErrors.push(err4);
            }
            errors++;
          }
          if (data.canonicalUrl === void 0) {
            const err5 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "canonicalUrl" }, message: "must have required property 'canonicalUrl'" };
            if (vErrors === null) {
              vErrors = [err5];
            } else {
              vErrors.push(err5);
            }
            errors++;
          }
          if (data.sourcePlatform === void 0) {
            const err6 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sourcePlatform" }, message: "must have required property 'sourcePlatform'" };
            if (vErrors === null) {
              vErrors = [err6];
            } else {
              vErrors.push(err6);
            }
            errors++;
          }
          if (data.pageTitle === void 0) {
            const err7 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "pageTitle" }, message: "must have required property 'pageTitle'" };
            if (vErrors === null) {
              vErrors = [err7];
            } else {
              vErrors.push(err7);
            }
            errors++;
          }
          if (data.sellerName === void 0) {
            const err8 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sellerName" }, message: "must have required property 'sellerName'" };
            if (vErrors === null) {
              vErrors = [err8];
            } else {
              vErrors.push(err8);
            }
            errors++;
          }
          if (data.productTitle === void 0) {
            const err9 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "productTitle" }, message: "must have required property 'productTitle'" };
            if (vErrors === null) {
              vErrors = [err9];
            } else {
              vErrors.push(err9);
            }
            errors++;
          }
          if (data.price === void 0) {
            const err10 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "price" }, message: "must have required property 'price'" };
            if (vErrors === null) {
              vErrors = [err10];
            } else {
              vErrors.push(err10);
            }
            errors++;
          }
          if (data.currency === void 0) {
            const err11 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "currency" }, message: "must have required property 'currency'" };
            if (vErrors === null) {
              vErrors = [err11];
            } else {
              vErrors.push(err11);
            }
            errors++;
          }
          if (data.country === void 0) {
            const err12 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "country" }, message: "must have required property 'country'" };
            if (vErrors === null) {
              vErrors = [err12];
            } else {
              vErrors.push(err12);
            }
            errors++;
          }
          if (data.city === void 0) {
            const err13 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "city" }, message: "must have required property 'city'" };
            if (vErrors === null) {
              vErrors = [err13];
            } else {
              vErrors.push(err13);
            }
            errors++;
          }
          if (data.searchQuery === void 0) {
            const err14 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "searchQuery" }, message: "must have required property 'searchQuery'" };
            if (vErrors === null) {
              vErrors = [err14];
            } else {
              vErrors.push(err14);
            }
            errors++;
          }
          if (data.acquisitionMethod === void 0) {
            const err15 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "acquisitionMethod" }, message: "must have required property 'acquisitionMethod'" };
            if (vErrors === null) {
              vErrors = [err15];
            } else {
              vErrors.push(err15);
            }
            errors++;
          }
          if (data.discoveredAt === void 0) {
            const err16 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "discoveredAt" }, message: "must have required property 'discoveredAt'" };
            if (vErrors === null) {
              vErrors = [err16];
            } else {
              vErrors.push(err16);
            }
            errors++;
          }
          if (data.acquisitionStatus === void 0) {
            const err17 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "acquisitionStatus" }, message: "must have required property 'acquisitionStatus'" };
            if (vErrors === null) {
              vErrors = [err17];
            } else {
              vErrors.push(err17);
            }
            errors++;
          }
          if (data.legalBasis === void 0) {
            const err18 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "legalBasis" }, message: "must have required property 'legalBasis'" };
            if (vErrors === null) {
              vErrors = [err18];
            } else {
              vErrors.push(err18);
            }
            errors++;
          }
          if (data.robotsPolicy === void 0) {
            const err19 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "robotsPolicy" }, message: "must have required property 'robotsPolicy'" };
            if (vErrors === null) {
              vErrors = [err19];
            } else {
              vErrors.push(err19);
            }
            errors++;
          }
          for (const key0 in data) {
            if (!func1.call(schema32.properties, key0)) {
              const err20 = { instancePath, schemaPath: "#/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key0 }, message: "must NOT have additional properties" };
              if (vErrors === null) {
                vErrors = [err20];
              } else {
                vErrors.push(err20);
              }
              errors++;
            }
          }
          if (data.contractVersion !== void 0) {
            if ("candidate-source-v1" !== data.contractVersion) {
              const err21 = { instancePath: instancePath + "/contractVersion", schemaPath: "#/properties/contractVersion/const", keyword: "const", params: { allowedValue: "candidate-source-v1" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err21];
              } else {
                vErrors.push(err21);
              }
              errors++;
            }
          }
          if (data.taskId !== void 0) {
            let data1 = data.taskId;
            if (typeof data1 === "string") {
              if (func2(data1) > 200) {
                const err22 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err22];
                } else {
                  vErrors.push(err22);
                }
                errors++;
              }
              if (func2(data1) < 1) {
                const err23 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err23];
                } else {
                  vErrors.push(err23);
                }
                errors++;
              }
              if (!pattern4.test(data1)) {
                const err24 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err24];
                } else {
                  vErrors.push(err24);
                }
                errors++;
              }
            } else {
              const err25 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err25];
              } else {
                vErrors.push(err25);
              }
              errors++;
            }
          }
          if (data.executionId !== void 0) {
            let data2 = data.executionId;
            if (typeof data2 === "string") {
              if (func2(data2) > 200) {
                const err26 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err26];
                } else {
                  vErrors.push(err26);
                }
                errors++;
              }
              if (func2(data2) < 1) {
                const err27 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err27];
                } else {
                  vErrors.push(err27);
                }
                errors++;
              }
              if (!pattern4.test(data2)) {
                const err28 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err28];
                } else {
                  vErrors.push(err28);
                }
                errors++;
              }
            } else {
              const err29 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err29];
              } else {
                vErrors.push(err29);
              }
              errors++;
            }
          }
          if (data.sourceId !== void 0) {
            let data3 = data.sourceId;
            if (typeof data3 === "string") {
              if (!pattern8.test(data3)) {
                const err30 = { instancePath: instancePath + "/sourceId", schemaPath: "#/properties/sourceId/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                if (vErrors === null) {
                  vErrors = [err30];
                } else {
                  vErrors.push(err30);
                }
                errors++;
              }
            } else {
              const err31 = { instancePath: instancePath + "/sourceId", schemaPath: "#/properties/sourceId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err31];
              } else {
                vErrors.push(err31);
              }
              errors++;
            }
          }
          if (data.sourceUrl !== void 0) {
            let data4 = data.sourceUrl;
            if (typeof data4 === "string") {
              if (func2(data4) > 2048) {
                const err32 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/maxLength", keyword: "maxLength", params: { limit: 2048 }, message: "must NOT have more than 2048 characters" };
                if (vErrors === null) {
                  vErrors = [err32];
                } else {
                  vErrors.push(err32);
                }
                errors++;
              }
              if (!pattern9.test(data4)) {
                const err33 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/pattern", keyword: "pattern", params: { pattern: "^https://" }, message: 'must match pattern "^https://"' };
                if (vErrors === null) {
                  vErrors = [err33];
                } else {
                  vErrors.push(err33);
                }
                errors++;
              }
              if (!formats0(data4)) {
                const err34 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/format", keyword: "format", params: { format: "uri" }, message: 'must match format "uri"' };
                if (vErrors === null) {
                  vErrors = [err34];
                } else {
                  vErrors.push(err34);
                }
                errors++;
              }
            } else {
              const err35 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err35];
              } else {
                vErrors.push(err35);
              }
              errors++;
            }
          }
          if (data.canonicalUrl !== void 0) {
            let data5 = data.canonicalUrl;
            if (typeof data5 === "string") {
              if (func2(data5) > 2048) {
                const err36 = { instancePath: instancePath + "/canonicalUrl", schemaPath: "#/properties/canonicalUrl/maxLength", keyword: "maxLength", params: { limit: 2048 }, message: "must NOT have more than 2048 characters" };
                if (vErrors === null) {
                  vErrors = [err36];
                } else {
                  vErrors.push(err36);
                }
                errors++;
              }
              if (!pattern9.test(data5)) {
                const err37 = { instancePath: instancePath + "/canonicalUrl", schemaPath: "#/properties/canonicalUrl/pattern", keyword: "pattern", params: { pattern: "^https://" }, message: 'must match pattern "^https://"' };
                if (vErrors === null) {
                  vErrors = [err37];
                } else {
                  vErrors.push(err37);
                }
                errors++;
              }
              if (!formats0(data5)) {
                const err38 = { instancePath: instancePath + "/canonicalUrl", schemaPath: "#/properties/canonicalUrl/format", keyword: "format", params: { format: "uri" }, message: 'must match format "uri"' };
                if (vErrors === null) {
                  vErrors = [err38];
                } else {
                  vErrors.push(err38);
                }
                errors++;
              }
            } else {
              const err39 = { instancePath: instancePath + "/canonicalUrl", schemaPath: "#/properties/canonicalUrl/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err39];
              } else {
                vErrors.push(err39);
              }
              errors++;
            }
          }
          if (data.sourcePlatform !== void 0) {
            let data6 = data.sourcePlatform;
            if (typeof data6 === "string") {
              if (func2(data6) > 100) {
                const err40 = { instancePath: instancePath + "/sourcePlatform", schemaPath: "#/properties/sourcePlatform/maxLength", keyword: "maxLength", params: { limit: 100 }, message: "must NOT have more than 100 characters" };
                if (vErrors === null) {
                  vErrors = [err40];
                } else {
                  vErrors.push(err40);
                }
                errors++;
              }
              if (func2(data6) < 1) {
                const err41 = { instancePath: instancePath + "/sourcePlatform", schemaPath: "#/properties/sourcePlatform/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err41];
                } else {
                  vErrors.push(err41);
                }
                errors++;
              }
            } else {
              const err42 = { instancePath: instancePath + "/sourcePlatform", schemaPath: "#/properties/sourcePlatform/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err42];
              } else {
                vErrors.push(err42);
              }
              errors++;
            }
          }
          if (data.pageTitle !== void 0) {
            let data7 = data.pageTitle;
            if (typeof data7 !== "string" && data7 !== null) {
              const err43 = { instancePath: instancePath + "/pageTitle", schemaPath: "#/properties/pageTitle/type", keyword: "type", params: { type: schema32.properties.pageTitle.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err43];
              } else {
                vErrors.push(err43);
              }
              errors++;
            }
            if (typeof data7 === "string") {
              if (func2(data7) > 500) {
                const err44 = { instancePath: instancePath + "/pageTitle", schemaPath: "#/properties/pageTitle/maxLength", keyword: "maxLength", params: { limit: 500 }, message: "must NOT have more than 500 characters" };
                if (vErrors === null) {
                  vErrors = [err44];
                } else {
                  vErrors.push(err44);
                }
                errors++;
              }
            }
          }
          if (data.sellerName !== void 0) {
            let data8 = data.sellerName;
            if (typeof data8 !== "string" && data8 !== null) {
              const err45 = { instancePath: instancePath + "/sellerName", schemaPath: "#/properties/sellerName/type", keyword: "type", params: { type: schema32.properties.sellerName.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err45];
              } else {
                vErrors.push(err45);
              }
              errors++;
            }
            if (typeof data8 === "string") {
              if (func2(data8) > 300) {
                const err46 = { instancePath: instancePath + "/sellerName", schemaPath: "#/properties/sellerName/maxLength", keyword: "maxLength", params: { limit: 300 }, message: "must NOT have more than 300 characters" };
                if (vErrors === null) {
                  vErrors = [err46];
                } else {
                  vErrors.push(err46);
                }
                errors++;
              }
            }
          }
          if (data.productTitle !== void 0) {
            let data9 = data.productTitle;
            if (typeof data9 !== "string" && data9 !== null) {
              const err47 = { instancePath: instancePath + "/productTitle", schemaPath: "#/properties/productTitle/type", keyword: "type", params: { type: schema32.properties.productTitle.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err47];
              } else {
                vErrors.push(err47);
              }
              errors++;
            }
            if (typeof data9 === "string") {
              if (func2(data9) > 500) {
                const err48 = { instancePath: instancePath + "/productTitle", schemaPath: "#/properties/productTitle/maxLength", keyword: "maxLength", params: { limit: 500 }, message: "must NOT have more than 500 characters" };
                if (vErrors === null) {
                  vErrors = [err48];
                } else {
                  vErrors.push(err48);
                }
                errors++;
              }
            }
          }
          if (data.price !== void 0) {
            let data10 = data.price;
            if (!(typeof data10 == "number" && isFinite(data10)) && data10 !== null) {
              const err49 = { instancePath: instancePath + "/price", schemaPath: "#/properties/price/type", keyword: "type", params: { type: schema32.properties.price.type }, message: "must be number,null" };
              if (vErrors === null) {
                vErrors = [err49];
              } else {
                vErrors.push(err49);
              }
              errors++;
            }
            if (typeof data10 == "number" && isFinite(data10)) {
              if (data10 < 0 || isNaN(data10)) {
                const err50 = { instancePath: instancePath + "/price", schemaPath: "#/properties/price/minimum", keyword: "minimum", params: { comparison: ">=", limit: 0 }, message: "must be >= 0" };
                if (vErrors === null) {
                  vErrors = [err50];
                } else {
                  vErrors.push(err50);
                }
                errors++;
              }
            }
          }
          if (data.currency !== void 0) {
            let data11 = data.currency;
            if (typeof data11 !== "string" && data11 !== null) {
              const err51 = { instancePath: instancePath + "/currency", schemaPath: "#/properties/currency/type", keyword: "type", params: { type: schema32.properties.currency.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err51];
              } else {
                vErrors.push(err51);
              }
              errors++;
            }
            if (typeof data11 === "string") {
              if (!pattern11.test(data11)) {
                const err52 = { instancePath: instancePath + "/currency", schemaPath: "#/properties/currency/pattern", keyword: "pattern", params: { pattern: "^[A-Z]{3}$" }, message: 'must match pattern "^[A-Z]{3}$"' };
                if (vErrors === null) {
                  vErrors = [err52];
                } else {
                  vErrors.push(err52);
                }
                errors++;
              }
            }
          }
          if (data.country !== void 0) {
            let data12 = data.country;
            if (typeof data12 !== "string" && data12 !== null) {
              const err53 = { instancePath: instancePath + "/country", schemaPath: "#/properties/country/type", keyword: "type", params: { type: schema32.properties.country.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err53];
              } else {
                vErrors.push(err53);
              }
              errors++;
            }
            if (typeof data12 === "string") {
              if (func2(data12) > 100) {
                const err54 = { instancePath: instancePath + "/country", schemaPath: "#/properties/country/maxLength", keyword: "maxLength", params: { limit: 100 }, message: "must NOT have more than 100 characters" };
                if (vErrors === null) {
                  vErrors = [err54];
                } else {
                  vErrors.push(err54);
                }
                errors++;
              }
            }
          }
          if (data.city !== void 0) {
            let data13 = data.city;
            if (typeof data13 !== "string" && data13 !== null) {
              const err55 = { instancePath: instancePath + "/city", schemaPath: "#/properties/city/type", keyword: "type", params: { type: schema32.properties.city.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err55];
              } else {
                vErrors.push(err55);
              }
              errors++;
            }
            if (typeof data13 === "string") {
              if (func2(data13) > 150) {
                const err56 = { instancePath: instancePath + "/city", schemaPath: "#/properties/city/maxLength", keyword: "maxLength", params: { limit: 150 }, message: "must NOT have more than 150 characters" };
                if (vErrors === null) {
                  vErrors = [err56];
                } else {
                  vErrors.push(err56);
                }
                errors++;
              }
            }
          }
          if (data.searchQuery !== void 0) {
            let data14 = data.searchQuery;
            if (typeof data14 !== "string" && data14 !== null) {
              const err57 = { instancePath: instancePath + "/searchQuery", schemaPath: "#/properties/searchQuery/type", keyword: "type", params: { type: schema32.properties.searchQuery.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err57];
              } else {
                vErrors.push(err57);
              }
              errors++;
            }
            if (typeof data14 === "string") {
              if (func2(data14) > 500) {
                const err58 = { instancePath: instancePath + "/searchQuery", schemaPath: "#/properties/searchQuery/maxLength", keyword: "maxLength", params: { limit: 500 }, message: "must NOT have more than 500 characters" };
                if (vErrors === null) {
                  vErrors = [err58];
                } else {
                  vErrors.push(err58);
                }
                errors++;
              }
            }
          }
          if (data.acquisitionMethod !== void 0) {
            if ("manual_seed" !== data.acquisitionMethod) {
              const err59 = { instancePath: instancePath + "/acquisitionMethod", schemaPath: "#/properties/acquisitionMethod/const", keyword: "const", params: { allowedValue: "manual_seed" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err59];
              } else {
                vErrors.push(err59);
              }
              errors++;
            }
          }
          if (data.discoveredAt !== void 0) {
            let data16 = data.discoveredAt;
            if (typeof data16 === "string") {
              if (!formats4.validate(data16)) {
                const err60 = { instancePath: instancePath + "/discoveredAt", schemaPath: "#/properties/discoveredAt/format", keyword: "format", params: { format: "date-time" }, message: 'must match format "date-time"' };
                if (vErrors === null) {
                  vErrors = [err60];
                } else {
                  vErrors.push(err60);
                }
                errors++;
              }
            } else {
              const err61 = { instancePath: instancePath + "/discoveredAt", schemaPath: "#/properties/discoveredAt/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err61];
              } else {
                vErrors.push(err61);
              }
              errors++;
            }
          }
          if (data.acquisitionStatus !== void 0) {
            let data17 = data.acquisitionStatus;
            if (!(data17 === "pending" || data17 === "acquired" || data17 === "failed" || data17 === "blocked")) {
              const err62 = { instancePath: instancePath + "/acquisitionStatus", schemaPath: "#/properties/acquisitionStatus/enum", keyword: "enum", params: { allowedValues: schema32.properties.acquisitionStatus.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err62];
              } else {
                vErrors.push(err62);
              }
              errors++;
            }
          }
          if (data.legalBasis !== void 0) {
            if ("public_source" !== data.legalBasis) {
              const err63 = { instancePath: instancePath + "/legalBasis", schemaPath: "#/properties/legalBasis/const", keyword: "const", params: { allowedValue: "public_source" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err63];
              } else {
                vErrors.push(err63);
              }
              errors++;
            }
          }
          if (data.robotsPolicy !== void 0) {
            let data19 = data.robotsPolicy;
            if (!(data19 === "allowed" || data19 === "unknown" || data19 === "blocked")) {
              const err64 = { instancePath: instancePath + "/robotsPolicy", schemaPath: "#/properties/robotsPolicy/enum", keyword: "enum", params: { allowedValues: schema32.properties.robotsPolicy.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err64];
              } else {
                vErrors.push(err64);
              }
              errors++;
            }
          }
          if (data.errorCode !== void 0) {
            let data20 = data.errorCode;
            if (typeof data20 !== "string" && data20 !== null) {
              const err65 = { instancePath: instancePath + "/errorCode", schemaPath: "#/properties/errorCode/type", keyword: "type", params: { type: schema32.properties.errorCode.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err65];
              } else {
                vErrors.push(err65);
              }
              errors++;
            }
            if (!(data20 === null || data20 === "http_4xx" || data20 === "http_5xx" || data20 === "captcha" || data20 === "login_required" || data20 === "robots_blocked" || data20 === "network_error")) {
              const err66 = { instancePath: instancePath + "/errorCode", schemaPath: "#/properties/errorCode/enum", keyword: "enum", params: { allowedValues: schema32.properties.errorCode.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err66];
              } else {
                vErrors.push(err66);
              }
              errors++;
            }
          }
          if (data.fixtureMetadata !== void 0) {
            let data21 = data.fixtureMetadata;
            if (data21 && typeof data21 == "object" && !Array.isArray(data21)) {
              if (data21.marker === void 0) {
                const err67 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "marker" }, message: "must have required property 'marker'" };
                if (vErrors === null) {
                  vErrors = [err67];
                } else {
                  vErrors.push(err67);
                }
                errors++;
              }
              if (data21.isTestFixture === void 0) {
                const err68 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "isTestFixture" }, message: "must have required property 'isTestFixture'" };
                if (vErrors === null) {
                  vErrors = [err68];
                } else {
                  vErrors.push(err68);
                }
                errors++;
              }
              if (data21.productionEligible === void 0) {
                const err69 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "productionEligible" }, message: "must have required property 'productionEligible'" };
                if (vErrors === null) {
                  vErrors = [err69];
                } else {
                  vErrors.push(err69);
                }
                errors++;
              }
              if (data21.scenario === void 0) {
                const err70 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "scenario" }, message: "must have required property 'scenario'" };
                if (vErrors === null) {
                  vErrors = [err70];
                } else {
                  vErrors.push(err70);
                }
                errors++;
              }
              for (const key1 in data21) {
                if (!(key1 === "marker" || key1 === "isTestFixture" || key1 === "productionEligible" || key1 === "scenario")) {
                  const err71 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key1 }, message: "must NOT have additional properties" };
                  if (vErrors === null) {
                    vErrors = [err71];
                  } else {
                    vErrors.push(err71);
                  }
                  errors++;
                }
              }
              if (data21.marker !== void 0) {
                if ("TEST_FIXTURE" !== data21.marker) {
                  const err72 = { instancePath: instancePath + "/fixtureMetadata/marker", schemaPath: "#/$defs/fixtureMetadata/properties/marker/const", keyword: "const", params: { allowedValue: "TEST_FIXTURE" }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err72];
                  } else {
                    vErrors.push(err72);
                  }
                  errors++;
                }
              }
              if (data21.isTestFixture !== void 0) {
                if (true !== data21.isTestFixture) {
                  const err73 = { instancePath: instancePath + "/fixtureMetadata/isTestFixture", schemaPath: "#/$defs/fixtureMetadata/properties/isTestFixture/const", keyword: "const", params: { allowedValue: true }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err73];
                  } else {
                    vErrors.push(err73);
                  }
                  errors++;
                }
              }
              if (data21.productionEligible !== void 0) {
                if (false !== data21.productionEligible) {
                  const err74 = { instancePath: instancePath + "/fixtureMetadata/productionEligible", schemaPath: "#/$defs/fixtureMetadata/properties/productionEligible/const", keyword: "const", params: { allowedValue: false }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err74];
                  } else {
                    vErrors.push(err74);
                  }
                  errors++;
                }
              }
              if (data21.scenario !== void 0) {
                let data25 = data21.scenario;
                if (!(data25 === "no_signal" || data25 === "synthetic_signal" || data25 === "blocked")) {
                  const err75 = { instancePath: instancePath + "/fixtureMetadata/scenario", schemaPath: "#/$defs/fixtureMetadata/properties/scenario/enum", keyword: "enum", params: { allowedValues: schema33.properties.scenario.enum }, message: "must be equal to one of the allowed values" };
                  if (vErrors === null) {
                    vErrors = [err75];
                  } else {
                    vErrors.push(err75);
                  }
                  errors++;
                }
              }
            } else {
              const err76 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/$defs/fixtureMetadata/type", keyword: "type", params: { type: "object" }, message: "must be object" };
              if (vErrors === null) {
                vErrors = [err76];
              } else {
                vErrors.push(err76);
              }
              errors++;
            }
          }
        } else {
          const err77 = { instancePath, schemaPath: "#/type", keyword: "type", params: { type: "object" }, message: "must be object" };
          if (vErrors === null) {
            vErrors = [err77];
          } else {
            vErrors.push(err77);
          }
          errors++;
        }
        validate21.errors = vErrors;
        return errors === 0;
      }
      validate21.evaluated = { "props": true, "dynamicProps": false, "dynamicItems": false };
      function validate20(data, { instancePath = "", parentData, parentDataProperty, rootData = data, dynamicAnchors = {} } = {}) {
        ;
        let vErrors = null;
        let errors = 0;
        const evaluated0 = validate20.evaluated;
        if (evaluated0.dynamicProps) {
          evaluated0.props = void 0;
        }
        if (evaluated0.dynamicItems) {
          evaluated0.items = void 0;
        }
        const _errs2 = errors;
        let valid1 = true;
        const _errs3 = errors;
        if (data && typeof data == "object" && !Array.isArray(data)) {
          let missing0;
          if (data.status === void 0 && (missing0 = "status")) {
            const err0 = {};
            if (vErrors === null) {
              vErrors = [err0];
            } else {
              vErrors.push(err0);
            }
            errors++;
          } else {
            if (data.status !== void 0) {
              if ("no_candidates" !== data.status) {
                const err1 = {};
                if (vErrors === null) {
                  vErrors = [err1];
                } else {
                  vErrors.push(err1);
                }
                errors++;
              }
            }
          }
        }
        var _valid0 = _errs3 === errors;
        errors = _errs2;
        if (vErrors !== null) {
          if (_errs2) {
            vErrors.length = _errs2;
          } else {
            vErrors = null;
          }
        }
        if (_valid0) {
          const _errs5 = errors;
          if (data && typeof data == "object" && !Array.isArray(data)) {
            if (data.candidates !== void 0) {
              let data1 = data.candidates;
              if (Array.isArray(data1)) {
                if (data1.length > 0) {
                  const err2 = { instancePath: instancePath + "/candidates", schemaPath: "#/allOf/0/then/properties/candidates/maxItems", keyword: "maxItems", params: { limit: 0 }, message: "must NOT have more than 0 items" };
                  if (vErrors === null) {
                    vErrors = [err2];
                  } else {
                    vErrors.push(err2);
                  }
                  errors++;
                }
              } else {
                const err3 = { instancePath: instancePath + "/candidates", schemaPath: "#/allOf/0/then/properties/candidates/type", keyword: "type", params: { type: "array" }, message: "must be array" };
                if (vErrors === null) {
                  vErrors = [err3];
                } else {
                  vErrors.push(err3);
                }
                errors++;
              }
            }
          }
          var _valid0 = _errs5 === errors;
          valid1 = _valid0;
          if (valid1) {
            var props0 = {};
            props0.candidates = true;
            props0.status = true;
          }
        }
        if (!valid1) {
          const err4 = { instancePath, schemaPath: "#/allOf/0/if", keyword: "if", params: { failingKeyword: "then" }, message: 'must match "then" schema' };
          if (vErrors === null) {
            vErrors = [err4];
          } else {
            vErrors.push(err4);
          }
          errors++;
        }
        const _errs9 = errors;
        let valid4 = true;
        const _errs10 = errors;
        if (data && typeof data == "object" && !Array.isArray(data)) {
          let missing1;
          if (data.status === void 0 && (missing1 = "status")) {
            const err5 = {};
            if (vErrors === null) {
              vErrors = [err5];
            } else {
              vErrors.push(err5);
            }
            errors++;
          } else {
            if (data.status !== void 0) {
              if ("completed" !== data.status) {
                const err6 = {};
                if (vErrors === null) {
                  vErrors = [err6];
                } else {
                  vErrors.push(err6);
                }
                errors++;
              }
            }
          }
        }
        var _valid1 = _errs10 === errors;
        errors = _errs9;
        if (vErrors !== null) {
          if (_errs9) {
            vErrors.length = _errs9;
          } else {
            vErrors = null;
          }
        }
        if (_valid1) {
          const _errs12 = errors;
          if (data && typeof data == "object" && !Array.isArray(data)) {
            if (data.candidates !== void 0) {
              let data3 = data.candidates;
              if (Array.isArray(data3)) {
                if (data3.length < 1) {
                  const err7 = { instancePath: instancePath + "/candidates", schemaPath: "#/allOf/1/then/properties/candidates/minItems", keyword: "minItems", params: { limit: 1 }, message: "must NOT have fewer than 1 items" };
                  if (vErrors === null) {
                    vErrors = [err7];
                  } else {
                    vErrors.push(err7);
                  }
                  errors++;
                }
              } else {
                const err8 = { instancePath: instancePath + "/candidates", schemaPath: "#/allOf/1/then/properties/candidates/type", keyword: "type", params: { type: "array" }, message: "must be array" };
                if (vErrors === null) {
                  vErrors = [err8];
                } else {
                  vErrors.push(err8);
                }
                errors++;
              }
            }
          }
          var _valid1 = _errs12 === errors;
          valid4 = _valid1;
          if (valid4) {
            var props1 = {};
            props1.candidates = true;
            props1.status = true;
          }
        }
        if (!valid4) {
          const err9 = { instancePath, schemaPath: "#/allOf/1/if", keyword: "if", params: { failingKeyword: "then" }, message: 'must match "then" schema' };
          if (vErrors === null) {
            vErrors = [err9];
          } else {
            vErrors.push(err9);
          }
          errors++;
        }
        if (props0 !== true && props1 !== void 0) {
          if (props1 === true) {
            props0 = true;
          } else {
            props0 = props0 || {};
            Object.assign(props0, props1);
          }
        }
        if (data && typeof data == "object" && !Array.isArray(data)) {
          if (data.contractVersion === void 0) {
            const err10 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contractVersion" }, message: "must have required property 'contractVersion'" };
            if (vErrors === null) {
              vErrors = [err10];
            } else {
              vErrors.push(err10);
            }
            errors++;
          }
          if (data.taskId === void 0) {
            const err11 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "taskId" }, message: "must have required property 'taskId'" };
            if (vErrors === null) {
              vErrors = [err11];
            } else {
              vErrors.push(err11);
            }
            errors++;
          }
          if (data.executionId === void 0) {
            const err12 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "executionId" }, message: "must have required property 'executionId'" };
            if (vErrors === null) {
              vErrors = [err12];
            } else {
              vErrors.push(err12);
            }
            errors++;
          }
          if (data.status === void 0) {
            const err13 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "status" }, message: "must have required property 'status'" };
            if (vErrors === null) {
              vErrors = [err13];
            } else {
              vErrors.push(err13);
            }
            errors++;
          }
          if (data.candidates === void 0) {
            const err14 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "candidates" }, message: "must have required property 'candidates'" };
            if (vErrors === null) {
              vErrors = [err14];
            } else {
              vErrors.push(err14);
            }
            errors++;
          }
          if (data.queriesAttempted === void 0) {
            const err15 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "queriesAttempted" }, message: "must have required property 'queriesAttempted'" };
            if (vErrors === null) {
              vErrors = [err15];
            } else {
              vErrors.push(err15);
            }
            errors++;
          }
          if (data.errors === void 0) {
            const err16 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "errors" }, message: "must have required property 'errors'" };
            if (vErrors === null) {
              vErrors = [err16];
            } else {
              vErrors.push(err16);
            }
            errors++;
          }
          if (data.limits === void 0) {
            const err17 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "limits" }, message: "must have required property 'limits'" };
            if (vErrors === null) {
              vErrors = [err17];
            } else {
              vErrors.push(err17);
            }
            errors++;
          }
          if (data.fixtureMetadata === void 0) {
            const err18 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "fixtureMetadata" }, message: "must have required property 'fixtureMetadata'" };
            if (vErrors === null) {
              vErrors = [err18];
            } else {
              vErrors.push(err18);
            }
            errors++;
          }
          for (const key0 in data) {
            if (!func1.call(schema31.properties, key0)) {
              const err19 = { instancePath, schemaPath: "#/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key0 }, message: "must NOT have additional properties" };
              if (vErrors === null) {
                vErrors = [err19];
              } else {
                vErrors.push(err19);
              }
              errors++;
            }
          }
          if (data.contractVersion !== void 0) {
            if ("acquisition-result-v1" !== data.contractVersion) {
              const err20 = { instancePath: instancePath + "/contractVersion", schemaPath: "#/properties/contractVersion/const", keyword: "const", params: { allowedValue: "acquisition-result-v1" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err20];
              } else {
                vErrors.push(err20);
              }
              errors++;
            }
          }
          if (data.taskId !== void 0) {
            let data5 = data.taskId;
            if (typeof data5 === "string") {
              if (func2(data5) > 200) {
                const err21 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err21];
                } else {
                  vErrors.push(err21);
                }
                errors++;
              }
              if (func2(data5) < 1) {
                const err22 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err22];
                } else {
                  vErrors.push(err22);
                }
                errors++;
              }
              if (!pattern4.test(data5)) {
                const err23 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err23];
                } else {
                  vErrors.push(err23);
                }
                errors++;
              }
            } else {
              const err24 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err24];
              } else {
                vErrors.push(err24);
              }
              errors++;
            }
          }
          if (data.executionId !== void 0) {
            let data6 = data.executionId;
            if (typeof data6 === "string") {
              if (func2(data6) > 200) {
                const err25 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err25];
                } else {
                  vErrors.push(err25);
                }
                errors++;
              }
              if (func2(data6) < 1) {
                const err26 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err26];
                } else {
                  vErrors.push(err26);
                }
                errors++;
              }
              if (!pattern4.test(data6)) {
                const err27 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err27];
                } else {
                  vErrors.push(err27);
                }
                errors++;
              }
            } else {
              const err28 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err28];
              } else {
                vErrors.push(err28);
              }
              errors++;
            }
          }
          if (data.status !== void 0) {
            let data7 = data.status;
            if (!(data7 === "completed" || data7 === "partial" || data7 === "no_candidates" || data7 === "failed")) {
              const err29 = { instancePath: instancePath + "/status", schemaPath: "#/properties/status/enum", keyword: "enum", params: { allowedValues: schema31.properties.status.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err29];
              } else {
                vErrors.push(err29);
              }
              errors++;
            }
          }
          if (data.candidates !== void 0) {
            let data8 = data.candidates;
            if (Array.isArray(data8)) {
              if (data8.length > 3) {
                const err30 = { instancePath: instancePath + "/candidates", schemaPath: "#/properties/candidates/maxItems", keyword: "maxItems", params: { limit: 3 }, message: "must NOT have more than 3 items" };
                if (vErrors === null) {
                  vErrors = [err30];
                } else {
                  vErrors.push(err30);
                }
                errors++;
              }
              const len0 = data8.length;
              for (let i0 = 0; i0 < len0; i0++) {
                if (!validate21(data8[i0], { instancePath: instancePath + "/candidates/" + i0, parentData: data8, parentDataProperty: i0, rootData, dynamicAnchors })) {
                  vErrors = vErrors === null ? validate21.errors : vErrors.concat(validate21.errors);
                  errors = vErrors.length;
                }
              }
            } else {
              const err31 = { instancePath: instancePath + "/candidates", schemaPath: "#/properties/candidates/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err31];
              } else {
                vErrors.push(err31);
              }
              errors++;
            }
          }
          if (data.queriesAttempted !== void 0) {
            let data10 = data.queriesAttempted;
            if (Array.isArray(data10)) {
              if (data10.length > 20) {
                const err32 = { instancePath: instancePath + "/queriesAttempted", schemaPath: "#/properties/queriesAttempted/maxItems", keyword: "maxItems", params: { limit: 20 }, message: "must NOT have more than 20 items" };
                if (vErrors === null) {
                  vErrors = [err32];
                } else {
                  vErrors.push(err32);
                }
                errors++;
              }
              const len1 = data10.length;
              for (let i1 = 0; i1 < len1; i1++) {
                let data11 = data10[i1];
                if (typeof data11 === "string") {
                  if (func2(data11) > 500) {
                    const err33 = { instancePath: instancePath + "/queriesAttempted/" + i1, schemaPath: "#/properties/queriesAttempted/items/maxLength", keyword: "maxLength", params: { limit: 500 }, message: "must NOT have more than 500 characters" };
                    if (vErrors === null) {
                      vErrors = [err33];
                    } else {
                      vErrors.push(err33);
                    }
                    errors++;
                  }
                } else {
                  const err34 = { instancePath: instancePath + "/queriesAttempted/" + i1, schemaPath: "#/properties/queriesAttempted/items/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                  if (vErrors === null) {
                    vErrors = [err34];
                  } else {
                    vErrors.push(err34);
                  }
                  errors++;
                }
              }
            } else {
              const err35 = { instancePath: instancePath + "/queriesAttempted", schemaPath: "#/properties/queriesAttempted/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err35];
              } else {
                vErrors.push(err35);
              }
              errors++;
            }
          }
          if (data.errors !== void 0) {
            let data12 = data.errors;
            if (Array.isArray(data12)) {
              if (data12.length > 20) {
                const err36 = { instancePath: instancePath + "/errors", schemaPath: "#/properties/errors/maxItems", keyword: "maxItems", params: { limit: 20 }, message: "must NOT have more than 20 items" };
                if (vErrors === null) {
                  vErrors = [err36];
                } else {
                  vErrors.push(err36);
                }
                errors++;
              }
              const len2 = data12.length;
              for (let i2 = 0; i2 < len2; i2++) {
                let data13 = data12[i2];
                if (data13 && typeof data13 == "object" && !Array.isArray(data13)) {
                  if (data13.code === void 0) {
                    const err37 = { instancePath: instancePath + "/errors/" + i2, schemaPath: "#/properties/errors/items/required", keyword: "required", params: { missingProperty: "code" }, message: "must have required property 'code'" };
                    if (vErrors === null) {
                      vErrors = [err37];
                    } else {
                      vErrors.push(err37);
                    }
                    errors++;
                  }
                  if (data13.message === void 0) {
                    const err38 = { instancePath: instancePath + "/errors/" + i2, schemaPath: "#/properties/errors/items/required", keyword: "required", params: { missingProperty: "message" }, message: "must have required property 'message'" };
                    if (vErrors === null) {
                      vErrors = [err38];
                    } else {
                      vErrors.push(err38);
                    }
                    errors++;
                  }
                  for (const key1 in data13) {
                    if (!(key1 === "code" || key1 === "message")) {
                      const err39 = { instancePath: instancePath + "/errors/" + i2, schemaPath: "#/properties/errors/items/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key1 }, message: "must NOT have additional properties" };
                      if (vErrors === null) {
                        vErrors = [err39];
                      } else {
                        vErrors.push(err39);
                      }
                      errors++;
                    }
                  }
                  if (data13.code !== void 0) {
                    let data14 = data13.code;
                    if (typeof data14 === "string") {
                      if (func2(data14) > 100) {
                        const err40 = { instancePath: instancePath + "/errors/" + i2 + "/code", schemaPath: "#/properties/errors/items/properties/code/maxLength", keyword: "maxLength", params: { limit: 100 }, message: "must NOT have more than 100 characters" };
                        if (vErrors === null) {
                          vErrors = [err40];
                        } else {
                          vErrors.push(err40);
                        }
                        errors++;
                      }
                      if (func2(data14) < 1) {
                        const err41 = { instancePath: instancePath + "/errors/" + i2 + "/code", schemaPath: "#/properties/errors/items/properties/code/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                        if (vErrors === null) {
                          vErrors = [err41];
                        } else {
                          vErrors.push(err41);
                        }
                        errors++;
                      }
                    } else {
                      const err42 = { instancePath: instancePath + "/errors/" + i2 + "/code", schemaPath: "#/properties/errors/items/properties/code/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err42];
                      } else {
                        vErrors.push(err42);
                      }
                      errors++;
                    }
                  }
                  if (data13.message !== void 0) {
                    let data15 = data13.message;
                    if (typeof data15 === "string") {
                      if (func2(data15) > 500) {
                        const err43 = { instancePath: instancePath + "/errors/" + i2 + "/message", schemaPath: "#/properties/errors/items/properties/message/maxLength", keyword: "maxLength", params: { limit: 500 }, message: "must NOT have more than 500 characters" };
                        if (vErrors === null) {
                          vErrors = [err43];
                        } else {
                          vErrors.push(err43);
                        }
                        errors++;
                      }
                      if (func2(data15) < 1) {
                        const err44 = { instancePath: instancePath + "/errors/" + i2 + "/message", schemaPath: "#/properties/errors/items/properties/message/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                        if (vErrors === null) {
                          vErrors = [err44];
                        } else {
                          vErrors.push(err44);
                        }
                        errors++;
                      }
                    } else {
                      const err45 = { instancePath: instancePath + "/errors/" + i2 + "/message", schemaPath: "#/properties/errors/items/properties/message/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err45];
                      } else {
                        vErrors.push(err45);
                      }
                      errors++;
                    }
                  }
                } else {
                  const err46 = { instancePath: instancePath + "/errors/" + i2, schemaPath: "#/properties/errors/items/type", keyword: "type", params: { type: "object" }, message: "must be object" };
                  if (vErrors === null) {
                    vErrors = [err46];
                  } else {
                    vErrors.push(err46);
                  }
                  errors++;
                }
              }
            } else {
              const err47 = { instancePath: instancePath + "/errors", schemaPath: "#/properties/errors/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err47];
              } else {
                vErrors.push(err47);
              }
              errors++;
            }
          }
          if (data.limits !== void 0) {
            let data16 = data.limits;
            if (data16 && typeof data16 == "object" && !Array.isArray(data16)) {
              if (data16.maximumCandidates === void 0) {
                const err48 = { instancePath: instancePath + "/limits", schemaPath: "#/properties/limits/required", keyword: "required", params: { missingProperty: "maximumCandidates" }, message: "must have required property 'maximumCandidates'" };
                if (vErrors === null) {
                  vErrors = [err48];
                } else {
                  vErrors.push(err48);
                }
                errors++;
              }
              if (data16.maximumTotalVisibleTextBytes === void 0) {
                const err49 = { instancePath: instancePath + "/limits", schemaPath: "#/properties/limits/required", keyword: "required", params: { missingProperty: "maximumTotalVisibleTextBytes" }, message: "must have required property 'maximumTotalVisibleTextBytes'" };
                if (vErrors === null) {
                  vErrors = [err49];
                } else {
                  vErrors.push(err49);
                }
                errors++;
              }
              for (const key2 in data16) {
                if (!(key2 === "maximumCandidates" || key2 === "maximumTotalVisibleTextBytes")) {
                  const err50 = { instancePath: instancePath + "/limits", schemaPath: "#/properties/limits/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key2 }, message: "must NOT have additional properties" };
                  if (vErrors === null) {
                    vErrors = [err50];
                  } else {
                    vErrors.push(err50);
                  }
                  errors++;
                }
              }
              if (data16.maximumCandidates !== void 0) {
                if (3 !== data16.maximumCandidates) {
                  const err51 = { instancePath: instancePath + "/limits/maximumCandidates", schemaPath: "#/properties/limits/properties/maximumCandidates/const", keyword: "const", params: { allowedValue: 3 }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err51];
                  } else {
                    vErrors.push(err51);
                  }
                  errors++;
                }
              }
              if (data16.maximumTotalVisibleTextBytes !== void 0) {
                if (393216 !== data16.maximumTotalVisibleTextBytes) {
                  const err52 = { instancePath: instancePath + "/limits/maximumTotalVisibleTextBytes", schemaPath: "#/properties/limits/properties/maximumTotalVisibleTextBytes/const", keyword: "const", params: { allowedValue: 393216 }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err52];
                  } else {
                    vErrors.push(err52);
                  }
                  errors++;
                }
              }
            } else {
              const err53 = { instancePath: instancePath + "/limits", schemaPath: "#/properties/limits/type", keyword: "type", params: { type: "object" }, message: "must be object" };
              if (vErrors === null) {
                vErrors = [err53];
              } else {
                vErrors.push(err53);
              }
              errors++;
            }
          }
          if (data.fixtureMetadata !== void 0) {
            let data19 = data.fixtureMetadata;
            const _errs44 = errors;
            let valid16 = false;
            let passing0 = null;
            const _errs45 = errors;
            if (data19 !== null) {
              const err54 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/properties/fixtureMetadata/oneOf/0/type", keyword: "type", params: { type: "null" }, message: "must be null" };
              if (vErrors === null) {
                vErrors = [err54];
              } else {
                vErrors.push(err54);
              }
              errors++;
            }
            var _valid2 = _errs45 === errors;
            if (_valid2) {
              valid16 = true;
              passing0 = 0;
            }
            const _errs47 = errors;
            if (data19 && typeof data19 == "object" && !Array.isArray(data19)) {
              if (data19.marker === void 0) {
                const err55 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "marker" }, message: "must have required property 'marker'" };
                if (vErrors === null) {
                  vErrors = [err55];
                } else {
                  vErrors.push(err55);
                }
                errors++;
              }
              if (data19.isTestFixture === void 0) {
                const err56 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "isTestFixture" }, message: "must have required property 'isTestFixture'" };
                if (vErrors === null) {
                  vErrors = [err56];
                } else {
                  vErrors.push(err56);
                }
                errors++;
              }
              if (data19.productionEligible === void 0) {
                const err57 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "productionEligible" }, message: "must have required property 'productionEligible'" };
                if (vErrors === null) {
                  vErrors = [err57];
                } else {
                  vErrors.push(err57);
                }
                errors++;
              }
              if (data19.scenario === void 0) {
                const err58 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "scenario" }, message: "must have required property 'scenario'" };
                if (vErrors === null) {
                  vErrors = [err58];
                } else {
                  vErrors.push(err58);
                }
                errors++;
              }
              for (const key3 in data19) {
                if (!(key3 === "marker" || key3 === "isTestFixture" || key3 === "productionEligible" || key3 === "scenario")) {
                  const err59 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key3 }, message: "must NOT have additional properties" };
                  if (vErrors === null) {
                    vErrors = [err59];
                  } else {
                    vErrors.push(err59);
                  }
                  errors++;
                }
              }
              if (data19.marker !== void 0) {
                if ("TEST_FIXTURE" !== data19.marker) {
                  const err60 = { instancePath: instancePath + "/fixtureMetadata/marker", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/marker/const", keyword: "const", params: { allowedValue: "TEST_FIXTURE" }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err60];
                  } else {
                    vErrors.push(err60);
                  }
                  errors++;
                }
              }
              if (data19.isTestFixture !== void 0) {
                if (true !== data19.isTestFixture) {
                  const err61 = { instancePath: instancePath + "/fixtureMetadata/isTestFixture", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/isTestFixture/const", keyword: "const", params: { allowedValue: true }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err61];
                  } else {
                    vErrors.push(err61);
                  }
                  errors++;
                }
              }
              if (data19.productionEligible !== void 0) {
                if (false !== data19.productionEligible) {
                  const err62 = { instancePath: instancePath + "/fixtureMetadata/productionEligible", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/productionEligible/const", keyword: "const", params: { allowedValue: false }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err62];
                  } else {
                    vErrors.push(err62);
                  }
                  errors++;
                }
              }
              if (data19.scenario !== void 0) {
                let data23 = data19.scenario;
                if (!(data23 === "no_signal" || data23 === "synthetic_signal" || data23 === "blocked")) {
                  const err63 = { instancePath: instancePath + "/fixtureMetadata/scenario", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/scenario/enum", keyword: "enum", params: { allowedValues: schema33.properties.scenario.enum }, message: "must be equal to one of the allowed values" };
                  if (vErrors === null) {
                    vErrors = [err63];
                  } else {
                    vErrors.push(err63);
                  }
                  errors++;
                }
              }
            } else {
              const err64 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/type", keyword: "type", params: { type: "object" }, message: "must be object" };
              if (vErrors === null) {
                vErrors = [err64];
              } else {
                vErrors.push(err64);
              }
              errors++;
            }
            var _valid2 = _errs47 === errors;
            if (_valid2 && valid16) {
              valid16 = false;
              passing0 = [passing0, 1];
            } else {
              if (_valid2) {
                valid16 = true;
                passing0 = 1;
              }
            }
            if (!valid16) {
              const err65 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "#/properties/fixtureMetadata/oneOf", keyword: "oneOf", params: { passingSchemas: passing0 }, message: "must match exactly one schema in oneOf" };
              if (vErrors === null) {
                vErrors = [err65];
              } else {
                vErrors.push(err65);
              }
              errors++;
            } else {
              errors = _errs44;
              if (vErrors !== null) {
                if (_errs44) {
                  vErrors.length = _errs44;
                } else {
                  vErrors = null;
                }
              }
            }
          }
        } else {
          const err66 = { instancePath, schemaPath: "#/type", keyword: "type", params: { type: "object" }, message: "must be object" };
          if (vErrors === null) {
            vErrors = [err66];
          } else {
            vErrors.push(err66);
          }
          errors++;
        }
        validate20.errors = vErrors;
        return errors === 0;
      }
      validate20.evaluated = { "props": true, "dynamicProps": false, "dynamicItems": false };
      exports.candidate_source = validate21;
      exports.digital_field_scanner_result = validate23;
      var schema35 = { "$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "digital_field_scanner_result.schema.json", "title": "DigitalFieldScannerResult v1", "type": "object", "additionalProperties": false, "required": ["contractVersion", "agentCode", "status", "taskId", "executionId", "analyzedSourceIds", "findings", "rejectedCandidates", "notes"], "properties": { "contractVersion": { "const": "digital-field-scanner-result-v1" }, "agentCode": { "const": "digital_field_scanner" }, "status": { "enum": ["completed", "partial", "failed"] }, "taskId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "executionId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "analyzedSourceIds": { "type": "array", "maxItems": 3, "uniqueItems": true, "items": { "type": "string", "pattern": "^[a-f0-9]{64}$" } }, "findings": { "type": "array", "maxItems": 30, "items": { "$ref": "#/$defs/finding" } }, "rejectedCandidates": { "type": "array", "maxItems": 3, "items": { "type": "object", "additionalProperties": false, "required": ["candidateId", "reason"], "properties": { "candidateId": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "reason": { "enum": ["no_signal", "insufficient_evidence", "inaccessible", "out_of_scope"] } } } }, "notes": { "type": ["string", "null"], "maxLength": 2e3 }, "fixtureMetadata": { "$ref": "candidate_source.schema.json#/$defs/fixtureMetadata" } }, "$defs": { "finding": { "type": "object", "additionalProperties": false, "required": ["findingKey", "candidateId", "sourceUrl", "signalType", "description", "severity", "confidence", "evidenceReferences", "requiresHumanReview", "automatedConclusion"], "properties": { "findingKey": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "candidateId": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "sourceUrl": { "type": "string", "format": "uri", "pattern": "^https://", "maxLength": 2048 }, "signalType": { "enum": ["price_anomaly", "identity_mismatch", "copied_content", "external_payment", "seller_recurrence", "other"] }, "description": { "type": "string", "minLength": 10, "maxLength": 2e3 }, "severity": { "enum": ["low", "medium", "high", "critical"] }, "confidence": { "type": "number", "minimum": 0, "maximum": 1 }, "evidenceReferences": { "type": "array", "maxItems": 20, "uniqueItems": true, "items": { "type": "string", "pattern": "^[a-f0-9]{64}$" } }, "requiresHumanReview": { "const": true }, "automatedConclusion": { "const": "suspected_signal" } } } }, "allOf": [{ "if": { "required": ["status"], "properties": { "status": { "const": "failed" } } }, "then": { "properties": { "findings": { "type": "array", "maxItems": 0 } } } }] };
      var schema36 = { "type": "object", "additionalProperties": false, "required": ["findingKey", "candidateId", "sourceUrl", "signalType", "description", "severity", "confidence", "evidenceReferences", "requiresHumanReview", "automatedConclusion"], "properties": { "findingKey": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "candidateId": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "sourceUrl": { "type": "string", "format": "uri", "pattern": "^https://", "maxLength": 2048 }, "signalType": { "enum": ["price_anomaly", "identity_mismatch", "copied_content", "external_payment", "seller_recurrence", "other"] }, "description": { "type": "string", "minLength": 10, "maxLength": 2e3 }, "severity": { "enum": ["low", "medium", "high", "critical"] }, "confidence": { "type": "number", "minimum": 0, "maximum": 1 }, "evidenceReferences": { "type": "array", "maxItems": 20, "uniqueItems": true, "items": { "type": "string", "pattern": "^[a-f0-9]{64}$" } }, "requiresHumanReview": { "const": true }, "automatedConclusion": { "const": "suspected_signal" } } };
      function validate23(data, { instancePath = "", parentData, parentDataProperty, rootData = data, dynamicAnchors = {} } = {}) {
        ;
        let vErrors = null;
        let errors = 0;
        const evaluated0 = validate23.evaluated;
        if (evaluated0.dynamicProps) {
          evaluated0.props = void 0;
        }
        if (evaluated0.dynamicItems) {
          evaluated0.items = void 0;
        }
        const _errs2 = errors;
        let valid1 = true;
        const _errs3 = errors;
        if (data && typeof data == "object" && !Array.isArray(data)) {
          let missing0;
          if (data.status === void 0 && (missing0 = "status")) {
            const err0 = {};
            if (vErrors === null) {
              vErrors = [err0];
            } else {
              vErrors.push(err0);
            }
            errors++;
          } else {
            if (data.status !== void 0) {
              if ("failed" !== data.status) {
                const err1 = {};
                if (vErrors === null) {
                  vErrors = [err1];
                } else {
                  vErrors.push(err1);
                }
                errors++;
              }
            }
          }
        }
        var _valid0 = _errs3 === errors;
        errors = _errs2;
        if (vErrors !== null) {
          if (_errs2) {
            vErrors.length = _errs2;
          } else {
            vErrors = null;
          }
        }
        if (_valid0) {
          const _errs5 = errors;
          if (data && typeof data == "object" && !Array.isArray(data)) {
            if (data.findings !== void 0) {
              let data1 = data.findings;
              if (Array.isArray(data1)) {
                if (data1.length > 0) {
                  const err2 = { instancePath: instancePath + "/findings", schemaPath: "#/allOf/0/then/properties/findings/maxItems", keyword: "maxItems", params: { limit: 0 }, message: "must NOT have more than 0 items" };
                  if (vErrors === null) {
                    vErrors = [err2];
                  } else {
                    vErrors.push(err2);
                  }
                  errors++;
                }
              } else {
                const err3 = { instancePath: instancePath + "/findings", schemaPath: "#/allOf/0/then/properties/findings/type", keyword: "type", params: { type: "array" }, message: "must be array" };
                if (vErrors === null) {
                  vErrors = [err3];
                } else {
                  vErrors.push(err3);
                }
                errors++;
              }
            }
          }
          var _valid0 = _errs5 === errors;
          valid1 = _valid0;
          if (valid1) {
            var props0 = {};
            props0.findings = true;
            props0.status = true;
          }
        }
        if (!valid1) {
          const err4 = { instancePath, schemaPath: "#/allOf/0/if", keyword: "if", params: { failingKeyword: "then" }, message: 'must match "then" schema' };
          if (vErrors === null) {
            vErrors = [err4];
          } else {
            vErrors.push(err4);
          }
          errors++;
        }
        if (data && typeof data == "object" && !Array.isArray(data)) {
          if (data.contractVersion === void 0) {
            const err5 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contractVersion" }, message: "must have required property 'contractVersion'" };
            if (vErrors === null) {
              vErrors = [err5];
            } else {
              vErrors.push(err5);
            }
            errors++;
          }
          if (data.agentCode === void 0) {
            const err6 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "agentCode" }, message: "must have required property 'agentCode'" };
            if (vErrors === null) {
              vErrors = [err6];
            } else {
              vErrors.push(err6);
            }
            errors++;
          }
          if (data.status === void 0) {
            const err7 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "status" }, message: "must have required property 'status'" };
            if (vErrors === null) {
              vErrors = [err7];
            } else {
              vErrors.push(err7);
            }
            errors++;
          }
          if (data.taskId === void 0) {
            const err8 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "taskId" }, message: "must have required property 'taskId'" };
            if (vErrors === null) {
              vErrors = [err8];
            } else {
              vErrors.push(err8);
            }
            errors++;
          }
          if (data.executionId === void 0) {
            const err9 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "executionId" }, message: "must have required property 'executionId'" };
            if (vErrors === null) {
              vErrors = [err9];
            } else {
              vErrors.push(err9);
            }
            errors++;
          }
          if (data.analyzedSourceIds === void 0) {
            const err10 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "analyzedSourceIds" }, message: "must have required property 'analyzedSourceIds'" };
            if (vErrors === null) {
              vErrors = [err10];
            } else {
              vErrors.push(err10);
            }
            errors++;
          }
          if (data.findings === void 0) {
            const err11 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "findings" }, message: "must have required property 'findings'" };
            if (vErrors === null) {
              vErrors = [err11];
            } else {
              vErrors.push(err11);
            }
            errors++;
          }
          if (data.rejectedCandidates === void 0) {
            const err12 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "rejectedCandidates" }, message: "must have required property 'rejectedCandidates'" };
            if (vErrors === null) {
              vErrors = [err12];
            } else {
              vErrors.push(err12);
            }
            errors++;
          }
          if (data.notes === void 0) {
            const err13 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "notes" }, message: "must have required property 'notes'" };
            if (vErrors === null) {
              vErrors = [err13];
            } else {
              vErrors.push(err13);
            }
            errors++;
          }
          for (const key0 in data) {
            if (!func1.call(schema35.properties, key0)) {
              const err14 = { instancePath, schemaPath: "#/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key0 }, message: "must NOT have additional properties" };
              if (vErrors === null) {
                vErrors = [err14];
              } else {
                vErrors.push(err14);
              }
              errors++;
            }
          }
          if (data.contractVersion !== void 0) {
            if ("digital-field-scanner-result-v1" !== data.contractVersion) {
              const err15 = { instancePath: instancePath + "/contractVersion", schemaPath: "#/properties/contractVersion/const", keyword: "const", params: { allowedValue: "digital-field-scanner-result-v1" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err15];
              } else {
                vErrors.push(err15);
              }
              errors++;
            }
          }
          if (data.agentCode !== void 0) {
            if ("digital_field_scanner" !== data.agentCode) {
              const err16 = { instancePath: instancePath + "/agentCode", schemaPath: "#/properties/agentCode/const", keyword: "const", params: { allowedValue: "digital_field_scanner" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err16];
              } else {
                vErrors.push(err16);
              }
              errors++;
            }
          }
          if (data.status !== void 0) {
            let data4 = data.status;
            if (!(data4 === "completed" || data4 === "partial" || data4 === "failed")) {
              const err17 = { instancePath: instancePath + "/status", schemaPath: "#/properties/status/enum", keyword: "enum", params: { allowedValues: schema35.properties.status.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err17];
              } else {
                vErrors.push(err17);
              }
              errors++;
            }
          }
          if (data.taskId !== void 0) {
            let data5 = data.taskId;
            if (typeof data5 === "string") {
              if (func2(data5) > 200) {
                const err18 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err18];
                } else {
                  vErrors.push(err18);
                }
                errors++;
              }
              if (func2(data5) < 1) {
                const err19 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err19];
                } else {
                  vErrors.push(err19);
                }
                errors++;
              }
              if (!pattern4.test(data5)) {
                const err20 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err20];
                } else {
                  vErrors.push(err20);
                }
                errors++;
              }
            } else {
              const err21 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err21];
              } else {
                vErrors.push(err21);
              }
              errors++;
            }
          }
          if (data.executionId !== void 0) {
            let data6 = data.executionId;
            if (typeof data6 === "string") {
              if (func2(data6) > 200) {
                const err22 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err22];
                } else {
                  vErrors.push(err22);
                }
                errors++;
              }
              if (func2(data6) < 1) {
                const err23 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err23];
                } else {
                  vErrors.push(err23);
                }
                errors++;
              }
              if (!pattern4.test(data6)) {
                const err24 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err24];
                } else {
                  vErrors.push(err24);
                }
                errors++;
              }
            } else {
              const err25 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err25];
              } else {
                vErrors.push(err25);
              }
              errors++;
            }
          }
          if (data.analyzedSourceIds !== void 0) {
            let data7 = data.analyzedSourceIds;
            if (Array.isArray(data7)) {
              if (data7.length > 3) {
                const err26 = { instancePath: instancePath + "/analyzedSourceIds", schemaPath: "#/properties/analyzedSourceIds/maxItems", keyword: "maxItems", params: { limit: 3 }, message: "must NOT have more than 3 items" };
                if (vErrors === null) {
                  vErrors = [err26];
                } else {
                  vErrors.push(err26);
                }
                errors++;
              }
              const len0 = data7.length;
              for (let i0 = 0; i0 < len0; i0++) {
                let data8 = data7[i0];
                if (typeof data8 === "string") {
                  if (!pattern8.test(data8)) {
                    const err27 = { instancePath: instancePath + "/analyzedSourceIds/" + i0, schemaPath: "#/properties/analyzedSourceIds/items/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                    if (vErrors === null) {
                      vErrors = [err27];
                    } else {
                      vErrors.push(err27);
                    }
                    errors++;
                  }
                } else {
                  const err28 = { instancePath: instancePath + "/analyzedSourceIds/" + i0, schemaPath: "#/properties/analyzedSourceIds/items/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                  if (vErrors === null) {
                    vErrors = [err28];
                  } else {
                    vErrors.push(err28);
                  }
                  errors++;
                }
              }
              let i1 = data7.length;
              let j0;
              if (i1 > 1) {
                const indices0 = {};
                for (; i1--; ) {
                  let item0 = data7[i1];
                  if (typeof item0 !== "string") {
                    continue;
                  }
                  if (typeof indices0[item0] == "number") {
                    j0 = indices0[item0];
                    const err29 = { instancePath: instancePath + "/analyzedSourceIds", schemaPath: "#/properties/analyzedSourceIds/uniqueItems", keyword: "uniqueItems", params: { i: i1, j: j0 }, message: "must NOT have duplicate items (items ## " + j0 + " and " + i1 + " are identical)" };
                    if (vErrors === null) {
                      vErrors = [err29];
                    } else {
                      vErrors.push(err29);
                    }
                    errors++;
                    break;
                  }
                  indices0[item0] = i1;
                }
              }
            } else {
              const err30 = { instancePath: instancePath + "/analyzedSourceIds", schemaPath: "#/properties/analyzedSourceIds/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err30];
              } else {
                vErrors.push(err30);
              }
              errors++;
            }
          }
          if (data.findings !== void 0) {
            let data9 = data.findings;
            if (Array.isArray(data9)) {
              if (data9.length > 30) {
                const err31 = { instancePath: instancePath + "/findings", schemaPath: "#/properties/findings/maxItems", keyword: "maxItems", params: { limit: 30 }, message: "must NOT have more than 30 items" };
                if (vErrors === null) {
                  vErrors = [err31];
                } else {
                  vErrors.push(err31);
                }
                errors++;
              }
              const len1 = data9.length;
              for (let i2 = 0; i2 < len1; i2++) {
                let data10 = data9[i2];
                if (data10 && typeof data10 == "object" && !Array.isArray(data10)) {
                  if (data10.findingKey === void 0) {
                    const err32 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "findingKey" }, message: "must have required property 'findingKey'" };
                    if (vErrors === null) {
                      vErrors = [err32];
                    } else {
                      vErrors.push(err32);
                    }
                    errors++;
                  }
                  if (data10.candidateId === void 0) {
                    const err33 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "candidateId" }, message: "must have required property 'candidateId'" };
                    if (vErrors === null) {
                      vErrors = [err33];
                    } else {
                      vErrors.push(err33);
                    }
                    errors++;
                  }
                  if (data10.sourceUrl === void 0) {
                    const err34 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "sourceUrl" }, message: "must have required property 'sourceUrl'" };
                    if (vErrors === null) {
                      vErrors = [err34];
                    } else {
                      vErrors.push(err34);
                    }
                    errors++;
                  }
                  if (data10.signalType === void 0) {
                    const err35 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "signalType" }, message: "must have required property 'signalType'" };
                    if (vErrors === null) {
                      vErrors = [err35];
                    } else {
                      vErrors.push(err35);
                    }
                    errors++;
                  }
                  if (data10.description === void 0) {
                    const err36 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "description" }, message: "must have required property 'description'" };
                    if (vErrors === null) {
                      vErrors = [err36];
                    } else {
                      vErrors.push(err36);
                    }
                    errors++;
                  }
                  if (data10.severity === void 0) {
                    const err37 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "severity" }, message: "must have required property 'severity'" };
                    if (vErrors === null) {
                      vErrors = [err37];
                    } else {
                      vErrors.push(err37);
                    }
                    errors++;
                  }
                  if (data10.confidence === void 0) {
                    const err38 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "confidence" }, message: "must have required property 'confidence'" };
                    if (vErrors === null) {
                      vErrors = [err38];
                    } else {
                      vErrors.push(err38);
                    }
                    errors++;
                  }
                  if (data10.evidenceReferences === void 0) {
                    const err39 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "evidenceReferences" }, message: "must have required property 'evidenceReferences'" };
                    if (vErrors === null) {
                      vErrors = [err39];
                    } else {
                      vErrors.push(err39);
                    }
                    errors++;
                  }
                  if (data10.requiresHumanReview === void 0) {
                    const err40 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "requiresHumanReview" }, message: "must have required property 'requiresHumanReview'" };
                    if (vErrors === null) {
                      vErrors = [err40];
                    } else {
                      vErrors.push(err40);
                    }
                    errors++;
                  }
                  if (data10.automatedConclusion === void 0) {
                    const err41 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/required", keyword: "required", params: { missingProperty: "automatedConclusion" }, message: "must have required property 'automatedConclusion'" };
                    if (vErrors === null) {
                      vErrors = [err41];
                    } else {
                      vErrors.push(err41);
                    }
                    errors++;
                  }
                  for (const key1 in data10) {
                    if (!func1.call(schema36.properties, key1)) {
                      const err42 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key1 }, message: "must NOT have additional properties" };
                      if (vErrors === null) {
                        vErrors = [err42];
                      } else {
                        vErrors.push(err42);
                      }
                      errors++;
                    }
                  }
                  if (data10.findingKey !== void 0) {
                    let data11 = data10.findingKey;
                    if (typeof data11 === "string") {
                      if (!pattern8.test(data11)) {
                        const err43 = { instancePath: instancePath + "/findings/" + i2 + "/findingKey", schemaPath: "#/$defs/finding/properties/findingKey/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                        if (vErrors === null) {
                          vErrors = [err43];
                        } else {
                          vErrors.push(err43);
                        }
                        errors++;
                      }
                    } else {
                      const err44 = { instancePath: instancePath + "/findings/" + i2 + "/findingKey", schemaPath: "#/$defs/finding/properties/findingKey/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err44];
                      } else {
                        vErrors.push(err44);
                      }
                      errors++;
                    }
                  }
                  if (data10.candidateId !== void 0) {
                    let data12 = data10.candidateId;
                    if (typeof data12 === "string") {
                      if (!pattern8.test(data12)) {
                        const err45 = { instancePath: instancePath + "/findings/" + i2 + "/candidateId", schemaPath: "#/$defs/finding/properties/candidateId/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                        if (vErrors === null) {
                          vErrors = [err45];
                        } else {
                          vErrors.push(err45);
                        }
                        errors++;
                      }
                    } else {
                      const err46 = { instancePath: instancePath + "/findings/" + i2 + "/candidateId", schemaPath: "#/$defs/finding/properties/candidateId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err46];
                      } else {
                        vErrors.push(err46);
                      }
                      errors++;
                    }
                  }
                  if (data10.sourceUrl !== void 0) {
                    let data13 = data10.sourceUrl;
                    if (typeof data13 === "string") {
                      if (func2(data13) > 2048) {
                        const err47 = { instancePath: instancePath + "/findings/" + i2 + "/sourceUrl", schemaPath: "#/$defs/finding/properties/sourceUrl/maxLength", keyword: "maxLength", params: { limit: 2048 }, message: "must NOT have more than 2048 characters" };
                        if (vErrors === null) {
                          vErrors = [err47];
                        } else {
                          vErrors.push(err47);
                        }
                        errors++;
                      }
                      if (!pattern9.test(data13)) {
                        const err48 = { instancePath: instancePath + "/findings/" + i2 + "/sourceUrl", schemaPath: "#/$defs/finding/properties/sourceUrl/pattern", keyword: "pattern", params: { pattern: "^https://" }, message: 'must match pattern "^https://"' };
                        if (vErrors === null) {
                          vErrors = [err48];
                        } else {
                          vErrors.push(err48);
                        }
                        errors++;
                      }
                      if (!formats0(data13)) {
                        const err49 = { instancePath: instancePath + "/findings/" + i2 + "/sourceUrl", schemaPath: "#/$defs/finding/properties/sourceUrl/format", keyword: "format", params: { format: "uri" }, message: 'must match format "uri"' };
                        if (vErrors === null) {
                          vErrors = [err49];
                        } else {
                          vErrors.push(err49);
                        }
                        errors++;
                      }
                    } else {
                      const err50 = { instancePath: instancePath + "/findings/" + i2 + "/sourceUrl", schemaPath: "#/$defs/finding/properties/sourceUrl/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err50];
                      } else {
                        vErrors.push(err50);
                      }
                      errors++;
                    }
                  }
                  if (data10.signalType !== void 0) {
                    let data14 = data10.signalType;
                    if (!(data14 === "price_anomaly" || data14 === "identity_mismatch" || data14 === "copied_content" || data14 === "external_payment" || data14 === "seller_recurrence" || data14 === "other")) {
                      const err51 = { instancePath: instancePath + "/findings/" + i2 + "/signalType", schemaPath: "#/$defs/finding/properties/signalType/enum", keyword: "enum", params: { allowedValues: schema36.properties.signalType.enum }, message: "must be equal to one of the allowed values" };
                      if (vErrors === null) {
                        vErrors = [err51];
                      } else {
                        vErrors.push(err51);
                      }
                      errors++;
                    }
                  }
                  if (data10.description !== void 0) {
                    let data15 = data10.description;
                    if (typeof data15 === "string") {
                      if (func2(data15) > 2e3) {
                        const err52 = { instancePath: instancePath + "/findings/" + i2 + "/description", schemaPath: "#/$defs/finding/properties/description/maxLength", keyword: "maxLength", params: { limit: 2e3 }, message: "must NOT have more than 2000 characters" };
                        if (vErrors === null) {
                          vErrors = [err52];
                        } else {
                          vErrors.push(err52);
                        }
                        errors++;
                      }
                      if (func2(data15) < 10) {
                        const err53 = { instancePath: instancePath + "/findings/" + i2 + "/description", schemaPath: "#/$defs/finding/properties/description/minLength", keyword: "minLength", params: { limit: 10 }, message: "must NOT have fewer than 10 characters" };
                        if (vErrors === null) {
                          vErrors = [err53];
                        } else {
                          vErrors.push(err53);
                        }
                        errors++;
                      }
                    } else {
                      const err54 = { instancePath: instancePath + "/findings/" + i2 + "/description", schemaPath: "#/$defs/finding/properties/description/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err54];
                      } else {
                        vErrors.push(err54);
                      }
                      errors++;
                    }
                  }
                  if (data10.severity !== void 0) {
                    let data16 = data10.severity;
                    if (!(data16 === "low" || data16 === "medium" || data16 === "high" || data16 === "critical")) {
                      const err55 = { instancePath: instancePath + "/findings/" + i2 + "/severity", schemaPath: "#/$defs/finding/properties/severity/enum", keyword: "enum", params: { allowedValues: schema36.properties.severity.enum }, message: "must be equal to one of the allowed values" };
                      if (vErrors === null) {
                        vErrors = [err55];
                      } else {
                        vErrors.push(err55);
                      }
                      errors++;
                    }
                  }
                  if (data10.confidence !== void 0) {
                    let data17 = data10.confidence;
                    if (typeof data17 == "number" && isFinite(data17)) {
                      if (data17 > 1 || isNaN(data17)) {
                        const err56 = { instancePath: instancePath + "/findings/" + i2 + "/confidence", schemaPath: "#/$defs/finding/properties/confidence/maximum", keyword: "maximum", params: { comparison: "<=", limit: 1 }, message: "must be <= 1" };
                        if (vErrors === null) {
                          vErrors = [err56];
                        } else {
                          vErrors.push(err56);
                        }
                        errors++;
                      }
                      if (data17 < 0 || isNaN(data17)) {
                        const err57 = { instancePath: instancePath + "/findings/" + i2 + "/confidence", schemaPath: "#/$defs/finding/properties/confidence/minimum", keyword: "minimum", params: { comparison: ">=", limit: 0 }, message: "must be >= 0" };
                        if (vErrors === null) {
                          vErrors = [err57];
                        } else {
                          vErrors.push(err57);
                        }
                        errors++;
                      }
                    } else {
                      const err58 = { instancePath: instancePath + "/findings/" + i2 + "/confidence", schemaPath: "#/$defs/finding/properties/confidence/type", keyword: "type", params: { type: "number" }, message: "must be number" };
                      if (vErrors === null) {
                        vErrors = [err58];
                      } else {
                        vErrors.push(err58);
                      }
                      errors++;
                    }
                  }
                  if (data10.evidenceReferences !== void 0) {
                    let data18 = data10.evidenceReferences;
                    if (Array.isArray(data18)) {
                      if (data18.length > 20) {
                        const err59 = { instancePath: instancePath + "/findings/" + i2 + "/evidenceReferences", schemaPath: "#/$defs/finding/properties/evidenceReferences/maxItems", keyword: "maxItems", params: { limit: 20 }, message: "must NOT have more than 20 items" };
                        if (vErrors === null) {
                          vErrors = [err59];
                        } else {
                          vErrors.push(err59);
                        }
                        errors++;
                      }
                      const len2 = data18.length;
                      for (let i3 = 0; i3 < len2; i3++) {
                        let data19 = data18[i3];
                        if (typeof data19 === "string") {
                          if (!pattern8.test(data19)) {
                            const err60 = { instancePath: instancePath + "/findings/" + i2 + "/evidenceReferences/" + i3, schemaPath: "#/$defs/finding/properties/evidenceReferences/items/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                            if (vErrors === null) {
                              vErrors = [err60];
                            } else {
                              vErrors.push(err60);
                            }
                            errors++;
                          }
                        } else {
                          const err61 = { instancePath: instancePath + "/findings/" + i2 + "/evidenceReferences/" + i3, schemaPath: "#/$defs/finding/properties/evidenceReferences/items/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                          if (vErrors === null) {
                            vErrors = [err61];
                          } else {
                            vErrors.push(err61);
                          }
                          errors++;
                        }
                      }
                      let i4 = data18.length;
                      let j1;
                      if (i4 > 1) {
                        const indices1 = {};
                        for (; i4--; ) {
                          let item1 = data18[i4];
                          if (typeof item1 !== "string") {
                            continue;
                          }
                          if (typeof indices1[item1] == "number") {
                            j1 = indices1[item1];
                            const err62 = { instancePath: instancePath + "/findings/" + i2 + "/evidenceReferences", schemaPath: "#/$defs/finding/properties/evidenceReferences/uniqueItems", keyword: "uniqueItems", params: { i: i4, j: j1 }, message: "must NOT have duplicate items (items ## " + j1 + " and " + i4 + " are identical)" };
                            if (vErrors === null) {
                              vErrors = [err62];
                            } else {
                              vErrors.push(err62);
                            }
                            errors++;
                            break;
                          }
                          indices1[item1] = i4;
                        }
                      }
                    } else {
                      const err63 = { instancePath: instancePath + "/findings/" + i2 + "/evidenceReferences", schemaPath: "#/$defs/finding/properties/evidenceReferences/type", keyword: "type", params: { type: "array" }, message: "must be array" };
                      if (vErrors === null) {
                        vErrors = [err63];
                      } else {
                        vErrors.push(err63);
                      }
                      errors++;
                    }
                  }
                  if (data10.requiresHumanReview !== void 0) {
                    if (true !== data10.requiresHumanReview) {
                      const err64 = { instancePath: instancePath + "/findings/" + i2 + "/requiresHumanReview", schemaPath: "#/$defs/finding/properties/requiresHumanReview/const", keyword: "const", params: { allowedValue: true }, message: "must be equal to constant" };
                      if (vErrors === null) {
                        vErrors = [err64];
                      } else {
                        vErrors.push(err64);
                      }
                      errors++;
                    }
                  }
                  if (data10.automatedConclusion !== void 0) {
                    if ("suspected_signal" !== data10.automatedConclusion) {
                      const err65 = { instancePath: instancePath + "/findings/" + i2 + "/automatedConclusion", schemaPath: "#/$defs/finding/properties/automatedConclusion/const", keyword: "const", params: { allowedValue: "suspected_signal" }, message: "must be equal to constant" };
                      if (vErrors === null) {
                        vErrors = [err65];
                      } else {
                        vErrors.push(err65);
                      }
                      errors++;
                    }
                  }
                } else {
                  const err66 = { instancePath: instancePath + "/findings/" + i2, schemaPath: "#/$defs/finding/type", keyword: "type", params: { type: "object" }, message: "must be object" };
                  if (vErrors === null) {
                    vErrors = [err66];
                  } else {
                    vErrors.push(err66);
                  }
                  errors++;
                }
              }
            } else {
              const err67 = { instancePath: instancePath + "/findings", schemaPath: "#/properties/findings/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err67];
              } else {
                vErrors.push(err67);
              }
              errors++;
            }
          }
          if (data.rejectedCandidates !== void 0) {
            let data22 = data.rejectedCandidates;
            if (Array.isArray(data22)) {
              if (data22.length > 3) {
                const err68 = { instancePath: instancePath + "/rejectedCandidates", schemaPath: "#/properties/rejectedCandidates/maxItems", keyword: "maxItems", params: { limit: 3 }, message: "must NOT have more than 3 items" };
                if (vErrors === null) {
                  vErrors = [err68];
                } else {
                  vErrors.push(err68);
                }
                errors++;
              }
              const len3 = data22.length;
              for (let i5 = 0; i5 < len3; i5++) {
                let data23 = data22[i5];
                if (data23 && typeof data23 == "object" && !Array.isArray(data23)) {
                  if (data23.candidateId === void 0) {
                    const err69 = { instancePath: instancePath + "/rejectedCandidates/" + i5, schemaPath: "#/properties/rejectedCandidates/items/required", keyword: "required", params: { missingProperty: "candidateId" }, message: "must have required property 'candidateId'" };
                    if (vErrors === null) {
                      vErrors = [err69];
                    } else {
                      vErrors.push(err69);
                    }
                    errors++;
                  }
                  if (data23.reason === void 0) {
                    const err70 = { instancePath: instancePath + "/rejectedCandidates/" + i5, schemaPath: "#/properties/rejectedCandidates/items/required", keyword: "required", params: { missingProperty: "reason" }, message: "must have required property 'reason'" };
                    if (vErrors === null) {
                      vErrors = [err70];
                    } else {
                      vErrors.push(err70);
                    }
                    errors++;
                  }
                  for (const key2 in data23) {
                    if (!(key2 === "candidateId" || key2 === "reason")) {
                      const err71 = { instancePath: instancePath + "/rejectedCandidates/" + i5, schemaPath: "#/properties/rejectedCandidates/items/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key2 }, message: "must NOT have additional properties" };
                      if (vErrors === null) {
                        vErrors = [err71];
                      } else {
                        vErrors.push(err71);
                      }
                      errors++;
                    }
                  }
                  if (data23.candidateId !== void 0) {
                    let data24 = data23.candidateId;
                    if (typeof data24 === "string") {
                      if (!pattern8.test(data24)) {
                        const err72 = { instancePath: instancePath + "/rejectedCandidates/" + i5 + "/candidateId", schemaPath: "#/properties/rejectedCandidates/items/properties/candidateId/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                        if (vErrors === null) {
                          vErrors = [err72];
                        } else {
                          vErrors.push(err72);
                        }
                        errors++;
                      }
                    } else {
                      const err73 = { instancePath: instancePath + "/rejectedCandidates/" + i5 + "/candidateId", schemaPath: "#/properties/rejectedCandidates/items/properties/candidateId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                      if (vErrors === null) {
                        vErrors = [err73];
                      } else {
                        vErrors.push(err73);
                      }
                      errors++;
                    }
                  }
                  if (data23.reason !== void 0) {
                    let data25 = data23.reason;
                    if (!(data25 === "no_signal" || data25 === "insufficient_evidence" || data25 === "inaccessible" || data25 === "out_of_scope")) {
                      const err74 = { instancePath: instancePath + "/rejectedCandidates/" + i5 + "/reason", schemaPath: "#/properties/rejectedCandidates/items/properties/reason/enum", keyword: "enum", params: { allowedValues: schema35.properties.rejectedCandidates.items.properties.reason.enum }, message: "must be equal to one of the allowed values" };
                      if (vErrors === null) {
                        vErrors = [err74];
                      } else {
                        vErrors.push(err74);
                      }
                      errors++;
                    }
                  }
                } else {
                  const err75 = { instancePath: instancePath + "/rejectedCandidates/" + i5, schemaPath: "#/properties/rejectedCandidates/items/type", keyword: "type", params: { type: "object" }, message: "must be object" };
                  if (vErrors === null) {
                    vErrors = [err75];
                  } else {
                    vErrors.push(err75);
                  }
                  errors++;
                }
              }
            } else {
              const err76 = { instancePath: instancePath + "/rejectedCandidates", schemaPath: "#/properties/rejectedCandidates/type", keyword: "type", params: { type: "array" }, message: "must be array" };
              if (vErrors === null) {
                vErrors = [err76];
              } else {
                vErrors.push(err76);
              }
              errors++;
            }
          }
          if (data.notes !== void 0) {
            let data26 = data.notes;
            if (typeof data26 !== "string" && data26 !== null) {
              const err77 = { instancePath: instancePath + "/notes", schemaPath: "#/properties/notes/type", keyword: "type", params: { type: schema35.properties.notes.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err77];
              } else {
                vErrors.push(err77);
              }
              errors++;
            }
            if (typeof data26 === "string") {
              if (func2(data26) > 2e3) {
                const err78 = { instancePath: instancePath + "/notes", schemaPath: "#/properties/notes/maxLength", keyword: "maxLength", params: { limit: 2e3 }, message: "must NOT have more than 2000 characters" };
                if (vErrors === null) {
                  vErrors = [err78];
                } else {
                  vErrors.push(err78);
                }
                errors++;
              }
            }
          }
          if (data.fixtureMetadata !== void 0) {
            let data27 = data.fixtureMetadata;
            if (data27 && typeof data27 == "object" && !Array.isArray(data27)) {
              if (data27.marker === void 0) {
                const err79 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "marker" }, message: "must have required property 'marker'" };
                if (vErrors === null) {
                  vErrors = [err79];
                } else {
                  vErrors.push(err79);
                }
                errors++;
              }
              if (data27.isTestFixture === void 0) {
                const err80 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "isTestFixture" }, message: "must have required property 'isTestFixture'" };
                if (vErrors === null) {
                  vErrors = [err80];
                } else {
                  vErrors.push(err80);
                }
                errors++;
              }
              if (data27.productionEligible === void 0) {
                const err81 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "productionEligible" }, message: "must have required property 'productionEligible'" };
                if (vErrors === null) {
                  vErrors = [err81];
                } else {
                  vErrors.push(err81);
                }
                errors++;
              }
              if (data27.scenario === void 0) {
                const err82 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "scenario" }, message: "must have required property 'scenario'" };
                if (vErrors === null) {
                  vErrors = [err82];
                } else {
                  vErrors.push(err82);
                }
                errors++;
              }
              for (const key3 in data27) {
                if (!(key3 === "marker" || key3 === "isTestFixture" || key3 === "productionEligible" || key3 === "scenario")) {
                  const err83 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key3 }, message: "must NOT have additional properties" };
                  if (vErrors === null) {
                    vErrors = [err83];
                  } else {
                    vErrors.push(err83);
                  }
                  errors++;
                }
              }
              if (data27.marker !== void 0) {
                if ("TEST_FIXTURE" !== data27.marker) {
                  const err84 = { instancePath: instancePath + "/fixtureMetadata/marker", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/marker/const", keyword: "const", params: { allowedValue: "TEST_FIXTURE" }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err84];
                  } else {
                    vErrors.push(err84);
                  }
                  errors++;
                }
              }
              if (data27.isTestFixture !== void 0) {
                if (true !== data27.isTestFixture) {
                  const err85 = { instancePath: instancePath + "/fixtureMetadata/isTestFixture", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/isTestFixture/const", keyword: "const", params: { allowedValue: true }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err85];
                  } else {
                    vErrors.push(err85);
                  }
                  errors++;
                }
              }
              if (data27.productionEligible !== void 0) {
                if (false !== data27.productionEligible) {
                  const err86 = { instancePath: instancePath + "/fixtureMetadata/productionEligible", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/productionEligible/const", keyword: "const", params: { allowedValue: false }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err86];
                  } else {
                    vErrors.push(err86);
                  }
                  errors++;
                }
              }
              if (data27.scenario !== void 0) {
                let data31 = data27.scenario;
                if (!(data31 === "no_signal" || data31 === "synthetic_signal" || data31 === "blocked")) {
                  const err87 = { instancePath: instancePath + "/fixtureMetadata/scenario", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/scenario/enum", keyword: "enum", params: { allowedValues: schema33.properties.scenario.enum }, message: "must be equal to one of the allowed values" };
                  if (vErrors === null) {
                    vErrors = [err87];
                  } else {
                    vErrors.push(err87);
                  }
                  errors++;
                }
              }
            } else {
              const err88 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/type", keyword: "type", params: { type: "object" }, message: "must be object" };
              if (vErrors === null) {
                vErrors = [err88];
              } else {
                vErrors.push(err88);
              }
              errors++;
            }
          }
        } else {
          const err89 = { instancePath, schemaPath: "#/type", keyword: "type", params: { type: "object" }, message: "must be object" };
          if (vErrors === null) {
            vErrors = [err89];
          } else {
            vErrors.push(err89);
          }
          errors++;
        }
        validate23.errors = vErrors;
        return errors === 0;
      }
      validate23.evaluated = { "props": true, "dynamicProps": false, "dynamicItems": false };
      exports.structured_evidence = validate24;
      var schema38 = { "$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "structured_evidence.schema.json", "title": "StructuredEvidence v1", "type": "object", "additionalProperties": false, "required": ["contractVersion", "taskId", "executionId", "sourceId", "snapshotId", "sourceUrl", "retrievedAt", "httpStatus", "contentType", "visibleText", "contentHash", "snapshotReference", "acquisitionStatus", "errorCode"], "properties": { "contractVersion": { "const": "structured-evidence-v1" }, "taskId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "executionId": { "type": "string", "minLength": 1, "maxLength": 200, "pattern": "^[^/]+$" }, "sourceId": { "type": "string", "pattern": "^[a-f0-9]{64}$" }, "snapshotId": { "type": ["string", "null"], "pattern": "^[a-f0-9]{64}$" }, "sourceUrl": { "type": "string", "format": "uri", "pattern": "^https://", "maxLength": 2048 }, "retrievedAt": { "type": ["string", "null"], "format": "date-time" }, "httpStatus": { "type": ["integer", "null"], "minimum": 100, "maximum": 599 }, "contentType": { "type": ["string", "null"], "maxLength": 100 }, "visibleText": { "type": "string", "maxLength": 5e4 }, "contentHash": { "type": ["string", "null"], "pattern": "^[a-f0-9]{64}$" }, "snapshotReference": { "type": ["string", "null"], "maxLength": 2048, "pattern": "^(https://|gs://|evidence://)" }, "acquisitionStatus": { "enum": ["acquired", "failed", "blocked"] }, "errorCode": { "type": ["string", "null"], "enum": [null, "http_4xx", "http_5xx", "captcha", "login_required", "robots_blocked", "network_error", "unsupported_content", "content_too_large"] }, "fixtureMetadata": { "$ref": "candidate_source.schema.json#/$defs/fixtureMetadata" } }, "allOf": [{ "if": { "required": ["acquisitionStatus"], "properties": { "acquisitionStatus": { "const": "acquired" } } }, "then": { "properties": { "httpStatus": { "const": 200 }, "contentType": { "type": "string", "pattern": "^(?:text/html|text/plain)(?:;\\s*charset=[Uu][Tt][Ff]-8)?$" }, "visibleText": { "type": "string", "minLength": 1 }, "contentHash": { "type": "string" }, "snapshotId": { "type": "string" }, "errorCode": { "const": null } } } }, { "if": { "required": ["acquisitionStatus"], "properties": { "acquisitionStatus": { "enum": ["failed", "blocked"] } } }, "then": { "properties": { "visibleText": { "const": "" }, "contentHash": { "const": null }, "snapshotId": { "const": null }, "errorCode": { "type": "string" } } } }] };
      var pattern20 = new RegExp("^(?:text/html|text/plain)(?:;\\s*charset=[Uu][Tt][Ff]-8)?$", "u");
      var pattern27 = new RegExp("^(https://|gs://|evidence://)", "u");
      function validate24(data, { instancePath = "", parentData, parentDataProperty, rootData = data, dynamicAnchors = {} } = {}) {
        ;
        let vErrors = null;
        let errors = 0;
        const evaluated0 = validate24.evaluated;
        if (evaluated0.dynamicProps) {
          evaluated0.props = void 0;
        }
        if (evaluated0.dynamicItems) {
          evaluated0.items = void 0;
        }
        const _errs2 = errors;
        let valid1 = true;
        const _errs3 = errors;
        if (data && typeof data == "object" && !Array.isArray(data)) {
          let missing0;
          if (data.acquisitionStatus === void 0 && (missing0 = "acquisitionStatus")) {
            const err0 = {};
            if (vErrors === null) {
              vErrors = [err0];
            } else {
              vErrors.push(err0);
            }
            errors++;
          } else {
            if (data.acquisitionStatus !== void 0) {
              if ("acquired" !== data.acquisitionStatus) {
                const err1 = {};
                if (vErrors === null) {
                  vErrors = [err1];
                } else {
                  vErrors.push(err1);
                }
                errors++;
              }
            }
          }
        }
        var _valid0 = _errs3 === errors;
        errors = _errs2;
        if (vErrors !== null) {
          if (_errs2) {
            vErrors.length = _errs2;
          } else {
            vErrors = null;
          }
        }
        if (_valid0) {
          const _errs5 = errors;
          if (data && typeof data == "object" && !Array.isArray(data)) {
            if (data.httpStatus !== void 0) {
              if (200 !== data.httpStatus) {
                const err2 = { instancePath: instancePath + "/httpStatus", schemaPath: "#/allOf/0/then/properties/httpStatus/const", keyword: "const", params: { allowedValue: 200 }, message: "must be equal to constant" };
                if (vErrors === null) {
                  vErrors = [err2];
                } else {
                  vErrors.push(err2);
                }
                errors++;
              }
            }
            if (data.contentType !== void 0) {
              let data2 = data.contentType;
              if (typeof data2 === "string") {
                if (!pattern20.test(data2)) {
                  const err3 = { instancePath: instancePath + "/contentType", schemaPath: "#/allOf/0/then/properties/contentType/pattern", keyword: "pattern", params: { pattern: "^(?:text/html|text/plain)(?:;\\s*charset=[Uu][Tt][Ff]-8)?$" }, message: 'must match pattern "^(?:text/html|text/plain)(?:;\\s*charset=[Uu][Tt][Ff]-8)?$"' };
                  if (vErrors === null) {
                    vErrors = [err3];
                  } else {
                    vErrors.push(err3);
                  }
                  errors++;
                }
              } else {
                const err4 = { instancePath: instancePath + "/contentType", schemaPath: "#/allOf/0/then/properties/contentType/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                if (vErrors === null) {
                  vErrors = [err4];
                } else {
                  vErrors.push(err4);
                }
                errors++;
              }
            }
            if (data.visibleText !== void 0) {
              let data3 = data.visibleText;
              if (typeof data3 === "string") {
                if (func2(data3) < 1) {
                  const err5 = { instancePath: instancePath + "/visibleText", schemaPath: "#/allOf/0/then/properties/visibleText/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                  if (vErrors === null) {
                    vErrors = [err5];
                  } else {
                    vErrors.push(err5);
                  }
                  errors++;
                }
              } else {
                const err6 = { instancePath: instancePath + "/visibleText", schemaPath: "#/allOf/0/then/properties/visibleText/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                if (vErrors === null) {
                  vErrors = [err6];
                } else {
                  vErrors.push(err6);
                }
                errors++;
              }
            }
            if (data.contentHash !== void 0) {
              if (typeof data.contentHash !== "string") {
                const err7 = { instancePath: instancePath + "/contentHash", schemaPath: "#/allOf/0/then/properties/contentHash/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                if (vErrors === null) {
                  vErrors = [err7];
                } else {
                  vErrors.push(err7);
                }
                errors++;
              }
            }
            if (data.snapshotId !== void 0) {
              if (typeof data.snapshotId !== "string") {
                const err8 = { instancePath: instancePath + "/snapshotId", schemaPath: "#/allOf/0/then/properties/snapshotId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                if (vErrors === null) {
                  vErrors = [err8];
                } else {
                  vErrors.push(err8);
                }
                errors++;
              }
            }
            if (data.errorCode !== void 0) {
              if (null !== data.errorCode) {
                const err9 = { instancePath: instancePath + "/errorCode", schemaPath: "#/allOf/0/then/properties/errorCode/const", keyword: "const", params: { allowedValue: schema38.allOf[0].then.properties.errorCode.const }, message: "must be equal to constant" };
                if (vErrors === null) {
                  vErrors = [err9];
                } else {
                  vErrors.push(err9);
                }
                errors++;
              }
            }
          }
          var _valid0 = _errs5 === errors;
          valid1 = _valid0;
          if (valid1) {
            var props0 = {};
            props0.httpStatus = true;
            props0.contentType = true;
            props0.visibleText = true;
            props0.contentHash = true;
            props0.snapshotId = true;
            props0.errorCode = true;
            props0.acquisitionStatus = true;
          }
        }
        if (!valid1) {
          const err10 = { instancePath, schemaPath: "#/allOf/0/if", keyword: "if", params: { failingKeyword: "then" }, message: 'must match "then" schema' };
          if (vErrors === null) {
            vErrors = [err10];
          } else {
            vErrors.push(err10);
          }
          errors++;
        }
        const _errs17 = errors;
        let valid4 = true;
        const _errs18 = errors;
        if (data && typeof data == "object" && !Array.isArray(data)) {
          let missing1;
          if (data.acquisitionStatus === void 0 && (missing1 = "acquisitionStatus")) {
            const err11 = {};
            if (vErrors === null) {
              vErrors = [err11];
            } else {
              vErrors.push(err11);
            }
            errors++;
          } else {
            if (data.acquisitionStatus !== void 0) {
              let data7 = data.acquisitionStatus;
              if (!(data7 === "failed" || data7 === "blocked")) {
                const err12 = {};
                if (vErrors === null) {
                  vErrors = [err12];
                } else {
                  vErrors.push(err12);
                }
                errors++;
              }
            }
          }
        }
        var _valid1 = _errs18 === errors;
        errors = _errs17;
        if (vErrors !== null) {
          if (_errs17) {
            vErrors.length = _errs17;
          } else {
            vErrors = null;
          }
        }
        if (_valid1) {
          const _errs20 = errors;
          if (data && typeof data == "object" && !Array.isArray(data)) {
            if (data.visibleText !== void 0) {
              if ("" !== data.visibleText) {
                const err13 = { instancePath: instancePath + "/visibleText", schemaPath: "#/allOf/1/then/properties/visibleText/const", keyword: "const", params: { allowedValue: "" }, message: "must be equal to constant" };
                if (vErrors === null) {
                  vErrors = [err13];
                } else {
                  vErrors.push(err13);
                }
                errors++;
              }
            }
            if (data.contentHash !== void 0) {
              if (null !== data.contentHash) {
                const err14 = { instancePath: instancePath + "/contentHash", schemaPath: "#/allOf/1/then/properties/contentHash/const", keyword: "const", params: { allowedValue: schema38.allOf[1].then.properties.contentHash.const }, message: "must be equal to constant" };
                if (vErrors === null) {
                  vErrors = [err14];
                } else {
                  vErrors.push(err14);
                }
                errors++;
              }
            }
            if (data.snapshotId !== void 0) {
              if (null !== data.snapshotId) {
                const err15 = { instancePath: instancePath + "/snapshotId", schemaPath: "#/allOf/1/then/properties/snapshotId/const", keyword: "const", params: { allowedValue: schema38.allOf[1].then.properties.snapshotId.const }, message: "must be equal to constant" };
                if (vErrors === null) {
                  vErrors = [err15];
                } else {
                  vErrors.push(err15);
                }
                errors++;
              }
            }
            if (data.errorCode !== void 0) {
              if (typeof data.errorCode !== "string") {
                const err16 = { instancePath: instancePath + "/errorCode", schemaPath: "#/allOf/1/then/properties/errorCode/type", keyword: "type", params: { type: "string" }, message: "must be string" };
                if (vErrors === null) {
                  vErrors = [err16];
                } else {
                  vErrors.push(err16);
                }
                errors++;
              }
            }
          }
          var _valid1 = _errs20 === errors;
          valid4 = _valid1;
          if (valid4) {
            var props1 = {};
            props1.visibleText = true;
            props1.contentHash = true;
            props1.snapshotId = true;
            props1.errorCode = true;
            props1.acquisitionStatus = true;
          }
        }
        if (!valid4) {
          const err17 = { instancePath, schemaPath: "#/allOf/1/if", keyword: "if", params: { failingKeyword: "then" }, message: 'must match "then" schema' };
          if (vErrors === null) {
            vErrors = [err17];
          } else {
            vErrors.push(err17);
          }
          errors++;
        }
        if (props0 !== true && props1 !== void 0) {
          if (props1 === true) {
            props0 = true;
          } else {
            props0 = props0 || {};
            Object.assign(props0, props1);
          }
        }
        if (data && typeof data == "object" && !Array.isArray(data)) {
          if (data.contractVersion === void 0) {
            const err18 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contractVersion" }, message: "must have required property 'contractVersion'" };
            if (vErrors === null) {
              vErrors = [err18];
            } else {
              vErrors.push(err18);
            }
            errors++;
          }
          if (data.taskId === void 0) {
            const err19 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "taskId" }, message: "must have required property 'taskId'" };
            if (vErrors === null) {
              vErrors = [err19];
            } else {
              vErrors.push(err19);
            }
            errors++;
          }
          if (data.executionId === void 0) {
            const err20 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "executionId" }, message: "must have required property 'executionId'" };
            if (vErrors === null) {
              vErrors = [err20];
            } else {
              vErrors.push(err20);
            }
            errors++;
          }
          if (data.sourceId === void 0) {
            const err21 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sourceId" }, message: "must have required property 'sourceId'" };
            if (vErrors === null) {
              vErrors = [err21];
            } else {
              vErrors.push(err21);
            }
            errors++;
          }
          if (data.snapshotId === void 0) {
            const err22 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "snapshotId" }, message: "must have required property 'snapshotId'" };
            if (vErrors === null) {
              vErrors = [err22];
            } else {
              vErrors.push(err22);
            }
            errors++;
          }
          if (data.sourceUrl === void 0) {
            const err23 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "sourceUrl" }, message: "must have required property 'sourceUrl'" };
            if (vErrors === null) {
              vErrors = [err23];
            } else {
              vErrors.push(err23);
            }
            errors++;
          }
          if (data.retrievedAt === void 0) {
            const err24 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "retrievedAt" }, message: "must have required property 'retrievedAt'" };
            if (vErrors === null) {
              vErrors = [err24];
            } else {
              vErrors.push(err24);
            }
            errors++;
          }
          if (data.httpStatus === void 0) {
            const err25 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "httpStatus" }, message: "must have required property 'httpStatus'" };
            if (vErrors === null) {
              vErrors = [err25];
            } else {
              vErrors.push(err25);
            }
            errors++;
          }
          if (data.contentType === void 0) {
            const err26 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contentType" }, message: "must have required property 'contentType'" };
            if (vErrors === null) {
              vErrors = [err26];
            } else {
              vErrors.push(err26);
            }
            errors++;
          }
          if (data.visibleText === void 0) {
            const err27 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "visibleText" }, message: "must have required property 'visibleText'" };
            if (vErrors === null) {
              vErrors = [err27];
            } else {
              vErrors.push(err27);
            }
            errors++;
          }
          if (data.contentHash === void 0) {
            const err28 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "contentHash" }, message: "must have required property 'contentHash'" };
            if (vErrors === null) {
              vErrors = [err28];
            } else {
              vErrors.push(err28);
            }
            errors++;
          }
          if (data.snapshotReference === void 0) {
            const err29 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "snapshotReference" }, message: "must have required property 'snapshotReference'" };
            if (vErrors === null) {
              vErrors = [err29];
            } else {
              vErrors.push(err29);
            }
            errors++;
          }
          if (data.acquisitionStatus === void 0) {
            const err30 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "acquisitionStatus" }, message: "must have required property 'acquisitionStatus'" };
            if (vErrors === null) {
              vErrors = [err30];
            } else {
              vErrors.push(err30);
            }
            errors++;
          }
          if (data.errorCode === void 0) {
            const err31 = { instancePath, schemaPath: "#/required", keyword: "required", params: { missingProperty: "errorCode" }, message: "must have required property 'errorCode'" };
            if (vErrors === null) {
              vErrors = [err31];
            } else {
              vErrors.push(err31);
            }
            errors++;
          }
          for (const key0 in data) {
            if (!func1.call(schema38.properties, key0)) {
              const err32 = { instancePath, schemaPath: "#/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key0 }, message: "must NOT have additional properties" };
              if (vErrors === null) {
                vErrors = [err32];
              } else {
                vErrors.push(err32);
              }
              errors++;
            }
          }
          if (data.contractVersion !== void 0) {
            if ("structured-evidence-v1" !== data.contractVersion) {
              const err33 = { instancePath: instancePath + "/contractVersion", schemaPath: "#/properties/contractVersion/const", keyword: "const", params: { allowedValue: "structured-evidence-v1" }, message: "must be equal to constant" };
              if (vErrors === null) {
                vErrors = [err33];
              } else {
                vErrors.push(err33);
              }
              errors++;
            }
          }
          if (data.taskId !== void 0) {
            let data13 = data.taskId;
            if (typeof data13 === "string") {
              if (func2(data13) > 200) {
                const err34 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err34];
                } else {
                  vErrors.push(err34);
                }
                errors++;
              }
              if (func2(data13) < 1) {
                const err35 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err35];
                } else {
                  vErrors.push(err35);
                }
                errors++;
              }
              if (!pattern4.test(data13)) {
                const err36 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err36];
                } else {
                  vErrors.push(err36);
                }
                errors++;
              }
            } else {
              const err37 = { instancePath: instancePath + "/taskId", schemaPath: "#/properties/taskId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err37];
              } else {
                vErrors.push(err37);
              }
              errors++;
            }
          }
          if (data.executionId !== void 0) {
            let data14 = data.executionId;
            if (typeof data14 === "string") {
              if (func2(data14) > 200) {
                const err38 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/maxLength", keyword: "maxLength", params: { limit: 200 }, message: "must NOT have more than 200 characters" };
                if (vErrors === null) {
                  vErrors = [err38];
                } else {
                  vErrors.push(err38);
                }
                errors++;
              }
              if (func2(data14) < 1) {
                const err39 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/minLength", keyword: "minLength", params: { limit: 1 }, message: "must NOT have fewer than 1 characters" };
                if (vErrors === null) {
                  vErrors = [err39];
                } else {
                  vErrors.push(err39);
                }
                errors++;
              }
              if (!pattern4.test(data14)) {
                const err40 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/pattern", keyword: "pattern", params: { pattern: "^[^/]+$" }, message: 'must match pattern "^[^/]+$"' };
                if (vErrors === null) {
                  vErrors = [err40];
                } else {
                  vErrors.push(err40);
                }
                errors++;
              }
            } else {
              const err41 = { instancePath: instancePath + "/executionId", schemaPath: "#/properties/executionId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err41];
              } else {
                vErrors.push(err41);
              }
              errors++;
            }
          }
          if (data.sourceId !== void 0) {
            let data15 = data.sourceId;
            if (typeof data15 === "string") {
              if (!pattern8.test(data15)) {
                const err42 = { instancePath: instancePath + "/sourceId", schemaPath: "#/properties/sourceId/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                if (vErrors === null) {
                  vErrors = [err42];
                } else {
                  vErrors.push(err42);
                }
                errors++;
              }
            } else {
              const err43 = { instancePath: instancePath + "/sourceId", schemaPath: "#/properties/sourceId/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err43];
              } else {
                vErrors.push(err43);
              }
              errors++;
            }
          }
          if (data.snapshotId !== void 0) {
            let data16 = data.snapshotId;
            if (typeof data16 !== "string" && data16 !== null) {
              const err44 = { instancePath: instancePath + "/snapshotId", schemaPath: "#/properties/snapshotId/type", keyword: "type", params: { type: schema38.properties.snapshotId.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err44];
              } else {
                vErrors.push(err44);
              }
              errors++;
            }
            if (typeof data16 === "string") {
              if (!pattern8.test(data16)) {
                const err45 = { instancePath: instancePath + "/snapshotId", schemaPath: "#/properties/snapshotId/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                if (vErrors === null) {
                  vErrors = [err45];
                } else {
                  vErrors.push(err45);
                }
                errors++;
              }
            }
          }
          if (data.sourceUrl !== void 0) {
            let data17 = data.sourceUrl;
            if (typeof data17 === "string") {
              if (func2(data17) > 2048) {
                const err46 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/maxLength", keyword: "maxLength", params: { limit: 2048 }, message: "must NOT have more than 2048 characters" };
                if (vErrors === null) {
                  vErrors = [err46];
                } else {
                  vErrors.push(err46);
                }
                errors++;
              }
              if (!pattern9.test(data17)) {
                const err47 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/pattern", keyword: "pattern", params: { pattern: "^https://" }, message: 'must match pattern "^https://"' };
                if (vErrors === null) {
                  vErrors = [err47];
                } else {
                  vErrors.push(err47);
                }
                errors++;
              }
              if (!formats0(data17)) {
                const err48 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/format", keyword: "format", params: { format: "uri" }, message: 'must match format "uri"' };
                if (vErrors === null) {
                  vErrors = [err48];
                } else {
                  vErrors.push(err48);
                }
                errors++;
              }
            } else {
              const err49 = { instancePath: instancePath + "/sourceUrl", schemaPath: "#/properties/sourceUrl/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err49];
              } else {
                vErrors.push(err49);
              }
              errors++;
            }
          }
          if (data.retrievedAt !== void 0) {
            let data18 = data.retrievedAt;
            if (typeof data18 !== "string" && data18 !== null) {
              const err50 = { instancePath: instancePath + "/retrievedAt", schemaPath: "#/properties/retrievedAt/type", keyword: "type", params: { type: schema38.properties.retrievedAt.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err50];
              } else {
                vErrors.push(err50);
              }
              errors++;
            }
            if (typeof data18 === "string") {
              if (!formats4.validate(data18)) {
                const err51 = { instancePath: instancePath + "/retrievedAt", schemaPath: "#/properties/retrievedAt/format", keyword: "format", params: { format: "date-time" }, message: 'must match format "date-time"' };
                if (vErrors === null) {
                  vErrors = [err51];
                } else {
                  vErrors.push(err51);
                }
                errors++;
              }
            }
          }
          if (data.httpStatus !== void 0) {
            let data19 = data.httpStatus;
            if (!(typeof data19 == "number" && (!(data19 % 1) && !isNaN(data19)) && isFinite(data19)) && data19 !== null) {
              const err52 = { instancePath: instancePath + "/httpStatus", schemaPath: "#/properties/httpStatus/type", keyword: "type", params: { type: schema38.properties.httpStatus.type }, message: "must be integer,null" };
              if (vErrors === null) {
                vErrors = [err52];
              } else {
                vErrors.push(err52);
              }
              errors++;
            }
            if (typeof data19 == "number" && isFinite(data19)) {
              if (data19 > 599 || isNaN(data19)) {
                const err53 = { instancePath: instancePath + "/httpStatus", schemaPath: "#/properties/httpStatus/maximum", keyword: "maximum", params: { comparison: "<=", limit: 599 }, message: "must be <= 599" };
                if (vErrors === null) {
                  vErrors = [err53];
                } else {
                  vErrors.push(err53);
                }
                errors++;
              }
              if (data19 < 100 || isNaN(data19)) {
                const err54 = { instancePath: instancePath + "/httpStatus", schemaPath: "#/properties/httpStatus/minimum", keyword: "minimum", params: { comparison: ">=", limit: 100 }, message: "must be >= 100" };
                if (vErrors === null) {
                  vErrors = [err54];
                } else {
                  vErrors.push(err54);
                }
                errors++;
              }
            }
          }
          if (data.contentType !== void 0) {
            let data20 = data.contentType;
            if (typeof data20 !== "string" && data20 !== null) {
              const err55 = { instancePath: instancePath + "/contentType", schemaPath: "#/properties/contentType/type", keyword: "type", params: { type: schema38.properties.contentType.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err55];
              } else {
                vErrors.push(err55);
              }
              errors++;
            }
            if (typeof data20 === "string") {
              if (func2(data20) > 100) {
                const err56 = { instancePath: instancePath + "/contentType", schemaPath: "#/properties/contentType/maxLength", keyword: "maxLength", params: { limit: 100 }, message: "must NOT have more than 100 characters" };
                if (vErrors === null) {
                  vErrors = [err56];
                } else {
                  vErrors.push(err56);
                }
                errors++;
              }
            }
          }
          if (data.visibleText !== void 0) {
            let data21 = data.visibleText;
            if (typeof data21 === "string") {
              if (func2(data21) > 5e4) {
                const err57 = { instancePath: instancePath + "/visibleText", schemaPath: "#/properties/visibleText/maxLength", keyword: "maxLength", params: { limit: 5e4 }, message: "must NOT have more than 50000 characters" };
                if (vErrors === null) {
                  vErrors = [err57];
                } else {
                  vErrors.push(err57);
                }
                errors++;
              }
            } else {
              const err58 = { instancePath: instancePath + "/visibleText", schemaPath: "#/properties/visibleText/type", keyword: "type", params: { type: "string" }, message: "must be string" };
              if (vErrors === null) {
                vErrors = [err58];
              } else {
                vErrors.push(err58);
              }
              errors++;
            }
          }
          if (data.contentHash !== void 0) {
            let data22 = data.contentHash;
            if (typeof data22 !== "string" && data22 !== null) {
              const err59 = { instancePath: instancePath + "/contentHash", schemaPath: "#/properties/contentHash/type", keyword: "type", params: { type: schema38.properties.contentHash.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err59];
              } else {
                vErrors.push(err59);
              }
              errors++;
            }
            if (typeof data22 === "string") {
              if (!pattern8.test(data22)) {
                const err60 = { instancePath: instancePath + "/contentHash", schemaPath: "#/properties/contentHash/pattern", keyword: "pattern", params: { pattern: "^[a-f0-9]{64}$" }, message: 'must match pattern "^[a-f0-9]{64}$"' };
                if (vErrors === null) {
                  vErrors = [err60];
                } else {
                  vErrors.push(err60);
                }
                errors++;
              }
            }
          }
          if (data.snapshotReference !== void 0) {
            let data23 = data.snapshotReference;
            if (typeof data23 !== "string" && data23 !== null) {
              const err61 = { instancePath: instancePath + "/snapshotReference", schemaPath: "#/properties/snapshotReference/type", keyword: "type", params: { type: schema38.properties.snapshotReference.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err61];
              } else {
                vErrors.push(err61);
              }
              errors++;
            }
            if (typeof data23 === "string") {
              if (func2(data23) > 2048) {
                const err62 = { instancePath: instancePath + "/snapshotReference", schemaPath: "#/properties/snapshotReference/maxLength", keyword: "maxLength", params: { limit: 2048 }, message: "must NOT have more than 2048 characters" };
                if (vErrors === null) {
                  vErrors = [err62];
                } else {
                  vErrors.push(err62);
                }
                errors++;
              }
              if (!pattern27.test(data23)) {
                const err63 = { instancePath: instancePath + "/snapshotReference", schemaPath: "#/properties/snapshotReference/pattern", keyword: "pattern", params: { pattern: "^(https://|gs://|evidence://)" }, message: 'must match pattern "^(https://|gs://|evidence://)"' };
                if (vErrors === null) {
                  vErrors = [err63];
                } else {
                  vErrors.push(err63);
                }
                errors++;
              }
            }
          }
          if (data.acquisitionStatus !== void 0) {
            let data24 = data.acquisitionStatus;
            if (!(data24 === "acquired" || data24 === "failed" || data24 === "blocked")) {
              const err64 = { instancePath: instancePath + "/acquisitionStatus", schemaPath: "#/properties/acquisitionStatus/enum", keyword: "enum", params: { allowedValues: schema38.properties.acquisitionStatus.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err64];
              } else {
                vErrors.push(err64);
              }
              errors++;
            }
          }
          if (data.errorCode !== void 0) {
            let data25 = data.errorCode;
            if (typeof data25 !== "string" && data25 !== null) {
              const err65 = { instancePath: instancePath + "/errorCode", schemaPath: "#/properties/errorCode/type", keyword: "type", params: { type: schema38.properties.errorCode.type }, message: "must be string,null" };
              if (vErrors === null) {
                vErrors = [err65];
              } else {
                vErrors.push(err65);
              }
              errors++;
            }
            if (!(data25 === null || data25 === "http_4xx" || data25 === "http_5xx" || data25 === "captcha" || data25 === "login_required" || data25 === "robots_blocked" || data25 === "network_error" || data25 === "unsupported_content" || data25 === "content_too_large")) {
              const err66 = { instancePath: instancePath + "/errorCode", schemaPath: "#/properties/errorCode/enum", keyword: "enum", params: { allowedValues: schema38.properties.errorCode.enum }, message: "must be equal to one of the allowed values" };
              if (vErrors === null) {
                vErrors = [err66];
              } else {
                vErrors.push(err66);
              }
              errors++;
            }
          }
          if (data.fixtureMetadata !== void 0) {
            let data26 = data.fixtureMetadata;
            if (data26 && typeof data26 == "object" && !Array.isArray(data26)) {
              if (data26.marker === void 0) {
                const err67 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "marker" }, message: "must have required property 'marker'" };
                if (vErrors === null) {
                  vErrors = [err67];
                } else {
                  vErrors.push(err67);
                }
                errors++;
              }
              if (data26.isTestFixture === void 0) {
                const err68 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "isTestFixture" }, message: "must have required property 'isTestFixture'" };
                if (vErrors === null) {
                  vErrors = [err68];
                } else {
                  vErrors.push(err68);
                }
                errors++;
              }
              if (data26.productionEligible === void 0) {
                const err69 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "productionEligible" }, message: "must have required property 'productionEligible'" };
                if (vErrors === null) {
                  vErrors = [err69];
                } else {
                  vErrors.push(err69);
                }
                errors++;
              }
              if (data26.scenario === void 0) {
                const err70 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/required", keyword: "required", params: { missingProperty: "scenario" }, message: "must have required property 'scenario'" };
                if (vErrors === null) {
                  vErrors = [err70];
                } else {
                  vErrors.push(err70);
                }
                errors++;
              }
              for (const key1 in data26) {
                if (!(key1 === "marker" || key1 === "isTestFixture" || key1 === "productionEligible" || key1 === "scenario")) {
                  const err71 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/additionalProperties", keyword: "additionalProperties", params: { additionalProperty: key1 }, message: "must NOT have additional properties" };
                  if (vErrors === null) {
                    vErrors = [err71];
                  } else {
                    vErrors.push(err71);
                  }
                  errors++;
                }
              }
              if (data26.marker !== void 0) {
                if ("TEST_FIXTURE" !== data26.marker) {
                  const err72 = { instancePath: instancePath + "/fixtureMetadata/marker", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/marker/const", keyword: "const", params: { allowedValue: "TEST_FIXTURE" }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err72];
                  } else {
                    vErrors.push(err72);
                  }
                  errors++;
                }
              }
              if (data26.isTestFixture !== void 0) {
                if (true !== data26.isTestFixture) {
                  const err73 = { instancePath: instancePath + "/fixtureMetadata/isTestFixture", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/isTestFixture/const", keyword: "const", params: { allowedValue: true }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err73];
                  } else {
                    vErrors.push(err73);
                  }
                  errors++;
                }
              }
              if (data26.productionEligible !== void 0) {
                if (false !== data26.productionEligible) {
                  const err74 = { instancePath: instancePath + "/fixtureMetadata/productionEligible", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/productionEligible/const", keyword: "const", params: { allowedValue: false }, message: "must be equal to constant" };
                  if (vErrors === null) {
                    vErrors = [err74];
                  } else {
                    vErrors.push(err74);
                  }
                  errors++;
                }
              }
              if (data26.scenario !== void 0) {
                let data30 = data26.scenario;
                if (!(data30 === "no_signal" || data30 === "synthetic_signal" || data30 === "blocked")) {
                  const err75 = { instancePath: instancePath + "/fixtureMetadata/scenario", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/properties/scenario/enum", keyword: "enum", params: { allowedValues: schema33.properties.scenario.enum }, message: "must be equal to one of the allowed values" };
                  if (vErrors === null) {
                    vErrors = [err75];
                  } else {
                    vErrors.push(err75);
                  }
                  errors++;
                }
              }
            } else {
              const err76 = { instancePath: instancePath + "/fixtureMetadata", schemaPath: "candidate_source.schema.json#/$defs/fixtureMetadata/type", keyword: "type", params: { type: "object" }, message: "must be object" };
              if (vErrors === null) {
                vErrors = [err76];
              } else {
                vErrors.push(err76);
              }
              errors++;
            }
          }
        } else {
          const err77 = { instancePath, schemaPath: "#/type", keyword: "type", params: { type: "object" }, message: "must be object" };
          if (vErrors === null) {
            vErrors = [err77];
          } else {
            vErrors.push(err77);
          }
          errors++;
        }
        validate24.errors = vErrors;
        return errors === 0;
      }
      validate24.evaluated = { "props": true, "dynamicProps": false, "dynamicItems": false };
    }
  });

  // .build-tmp/schema_engine.js
  var require_schema_engine = __commonJS({
    ".build-tmp/schema_engine.js"(exports, module) {
      "use strict";
      var validators = require_standalone_validators();
      var { issue, result } = require_validator_result();
      function safePath(error) {
        const base = String(error.instancePath || "").replace(/^\//, "").replace(/\//g, ".");
        if (error.keyword === "required") return [base, error.params && error.params.missingProperty].filter(Boolean).join(".");
        if (error.keyword === "additionalProperties") return [base, error.params && error.params.additionalProperty].filter(Boolean).join(".");
        return base || "$";
      }
      function safeMessage(keyword) {
        const messages = { required: "Zorunlu alan eksik.", type: "Alan tipi geçersiz.", additionalProperties: "Beklenmeyen alan.", format: "Alan biçimi geçersiz.", pattern: "Alan biçimi geçersiz.", const: "Alan değeri geçersiz.", enum: "Alan değeri izin verilen değerlerden biri değil.", minLength: "Alan çok kısa.", maxLength: "Alan çok uzun.", minItems: "Dizi yeterli öğe içermiyor.", maxItems: "Dizi çok fazla öğe içeriyor.", uniqueItems: "Dizi yinelenen öğe içeriyor.", minimum: "Sayısal değer alt sınırın altında.", maximum: "Sayısal değer üst sınırın üzerinde.", oneOf: "Alan sözleşmeyle eşleşmiyor.", if: "Koşullu sözleşme sağlanmıyor." };
        return messages[keyword] || "Schema doğrulaması başarısız.";
      }
      function validateSchema(schemaName, value) {
        const validate = validators[schemaName];
        if (typeof validate !== "function") return result({ errors: [issue("SCHEMA_NAME_UNSUPPORTED", "$", "Schema adı desteklenmiyor.")] });
        try {
          if (validate(value)) return result();
          return result({ errors: (validate.errors || []).map((error) => issue("SCHEMA_" + String(error.keyword).toUpperCase(), safePath(error), safeMessage(error.keyword))) });
        } catch (_) {
          return result({ errors: [issue("SCHEMA_VALIDATION_EXCEPTION", "$", "Schema doğrulaması güvenli biçimde tamamlanamadı.")] });
        }
      }
      module["exports"] = { validateSchema };
    }
  });

  // validators/validate_candidate_source.js
  var require_validate_candidate_source = __commonJS({
    "validators/validate_candidate_source.js"(exports, module) {
      "use strict";
      var { canonicalizeUrl } = require_canonicalize_url();
      var { buildSourceId } = require_deterministic_ids();
      var { isPlainRecord, issue, result } = require_validator_result();
      var { validateSchema } = require_schema_engine();
      function validateCandidateSourceInternal(candidate, context) {
        const schema = validateSchema("candidate_source", candidate);
        if (!schema.valid) return schema;
        const errors = [];
        if (!isPlainRecord(context) || typeof context.taskId !== "string" || !context.taskId || typeof context.executionId !== "string" || !context.executionId) {
          return result({ errors: [issue(
            "CONTEXT_REQUIRED",
            "$",
            "Task ve execution context zorunludur."
          )] });
        }
        const canonical = canonicalizeUrl(candidate.sourceUrl);
        if (!canonical.valid) errors.push(issue("CANDIDATE_URL_INVALID", "sourceUrl", canonical.errors.join(",")));
        if (canonical.valid && candidate.canonicalUrl !== canonical.canonicalUrl) errors.push(issue("CANONICAL_URL_MISMATCH", "canonicalUrl", "Canonical URL does not match."));
        if (canonical.valid && candidate.sourceId !== buildSourceId(candidate.taskId, candidate.executionId, canonical.canonicalUrl)) errors.push(issue("SOURCE_ID_MISMATCH", "sourceId", "Source ID does not match."));
        if (candidate.taskId !== context.taskId) errors.push(issue("TASK_ID_MISMATCH", "taskId", "Task ID mismatch."));
        if (candidate.executionId !== context.executionId) errors.push(issue("EXECUTION_ID_MISMATCH", "executionId", "Execution ID mismatch."));
        if (candidate.robotsPolicy === "blocked" && candidate.acquisitionStatus !== "blocked") errors.push(issue("ROBOTS_STATUS_MISMATCH", "acquisitionStatus", "Blocked robots policy requires blocked status."));
        if (["captcha", "login_required"].includes(candidate.errorCode) && candidate.acquisitionStatus === "acquired") errors.push(issue("ACCESS_BARRIER_ACQUIRED", "acquisitionStatus", "Access barrier cannot be acquired."));
        return result({ errors });
      }
      function validateCandidateSource(candidate, context) {
        try {
          return validateCandidateSourceInternal(candidate, context);
        } catch (_) {
          return result({ errors: [issue(
            "CANDIDATE_VALIDATION_EXCEPTION",
            "$",
            "Doğrulama güvenli biçimde tamamlanamadı."
          )] });
        }
      }
      module["exports"] = { validateCandidateSource };
    }
  });

  // validators/validate_acquisition_result.js
  var require_validate_acquisition_result = __commonJS({
    "validators/validate_acquisition_result.js"(exports, module) {
      "use strict";
      var { validateCandidateSource } = require_validate_candidate_source();
      var { issue, result } = require_validator_result();
      var { validateSchema } = require_schema_engine();
      function validateAcquisitionResultInternal(envelope, { productionCallback = false } = {}) {
        const schema = validateSchema("acquisition_result", envelope);
        if (!schema.valid) return schema;
        const errors = [], seenUrls = /* @__PURE__ */ new Set(), seenIds = /* @__PURE__ */ new Set();
        if (envelope.candidates.length > 3) errors.push(issue("CANDIDATE_LIMIT_EXCEEDED", "candidates", "Maximum three candidates."));
        for (let i = 0; i < envelope.candidates.length; i++) {
          const candidate = envelope.candidates[i];
          const child = validateCandidateSource(candidate, {
            taskId: envelope.taskId,
            executionId: envelope.executionId
          });
          errors.push(...child.errors.map((e) => ({ ...e, path: `candidates[${i}].${e.path}` })));
          if (seenUrls.has(candidate.canonicalUrl)) errors.push(issue("DUPLICATE_CANONICAL_URL", `candidates[${i}].canonicalUrl`, "Duplicate canonical URL."));
          if (seenIds.has(candidate.sourceId)) errors.push(issue("DUPLICATE_SOURCE_ID", `candidates[${i}].sourceId`, "Duplicate source ID."));
          seenUrls.add(candidate.canonicalUrl);
          seenIds.add(candidate.sourceId);
        }
        const fixture = envelope.fixtureMetadata || envelope.candidates.some((c) => c.fixtureMetadata);
        if (fixture && productionCallback) errors.push(issue("TEST_FIXTURE_PRODUCTION_CALLBACK", "fixtureMetadata", "Test fixture cannot use production callback."));
        return result({ errors });
      }
      function validateAcquisitionResult(envelope, options) {
        try {
          return validateAcquisitionResultInternal(envelope, options);
        } catch (_) {
          return result({ errors: [issue(
            "ACQUISITION_VALIDATION_EXCEPTION",
            "$",
            "Doğrulama güvenli biçimde tamamlanamadı."
          )] });
        }
      }
      module["exports"] = { validateAcquisitionResult };
    }
  });

  // validators/context_validation.js
  var require_context_validation = __commonJS({
    "validators/context_validation.js"(exports, module) {
      "use strict";
      var { isPlainRecord, issue } = require_validator_result();
      function nonEmptyString(value) {
        return typeof value === "string" && value.length > 0;
      }
      function candidateEntryValid(candidate) {
        return isPlainRecord(candidate) && nonEmptyString(candidate.sourceId) && nonEmptyString(candidate.taskId) && nonEmptyString(candidate.executionId) && nonEmptyString(candidate.acquisitionStatus) && (nonEmptyString(candidate.canonicalUrl) || nonEmptyString(candidate.sourceUrl));
      }
      function evidenceEntryValid(evidence) {
        return isPlainRecord(evidence) && nonEmptyString(evidence.sourceId) && nonEmptyString(evidence.taskId) && nonEmptyString(evidence.executionId) && nonEmptyString(evidence.acquisitionStatus) && (typeof evidence.snapshotId === "string" || evidence.snapshotId === null) && nonEmptyString(evidence.sourceUrl);
      }
      function invalidCandidateIssue(candidates) {
        const index = candidates.findIndex((entry) => !candidateEntryValid(entry));
        return index === -1 ? null : issue(
          "CONTEXT_CANDIDATE_INVALID",
          `candidates[${index}]`,
          "Candidate context öğesi geçersiz."
        );
      }
      function invalidEvidenceIssue(evidences) {
        const index = evidences.findIndex((entry) => !evidenceEntryValid(entry));
        return index === -1 ? null : issue(
          "CONTEXT_EVIDENCE_INVALID",
          `evidences[${index}]`,
          "Evidence context öğesi geçersiz."
        );
      }
      module["exports"] = {
        candidateEntryValid,
        evidenceEntryValid,
        invalidCandidateIssue,
        invalidEvidenceIssue
      };
    }
  });

  // validators/validate_structured_evidence.js
  var require_validate_structured_evidence = __commonJS({
    "validators/validate_structured_evidence.js"(exports, module) {
      "use strict";
      var { buildContentHash, buildSnapshotId } = require_deterministic_ids();
      var { isPlainRecord, issue, result } = require_validator_result();
      var { validateSchema } = require_schema_engine();
      var { invalidCandidateIssue } = require_context_validation();
      function validateStructuredEvidenceInternal(evidence, context) {
        const schema = validateSchema("structured_evidence", evidence);
        if (!schema.valid) return schema;
        const errors = [], warnings = [];
        if (!isPlainRecord(context) || typeof context.taskId !== "string" || !context.taskId || typeof context.executionId !== "string" || !context.executionId || !Array.isArray(context.candidates)) {
          return result({ errors: [issue(
            "CONTEXT_REQUIRED",
            "$",
            "Task, execution ve candidates context zorunludur."
          )] });
        }
        const { candidates } = context;
        const invalidCandidate = invalidCandidateIssue(candidates);
        if (invalidCandidate) return result({ errors: [invalidCandidate] });
        const candidate = candidates.find((c) => c.sourceId === evidence.sourceId);
        if (!candidate) errors.push(issue("EVIDENCE_CANDIDATE_NOT_FOUND", "sourceId", "Candidate not found."));
        if (evidence.taskId !== context.taskId || evidence.executionId !== context.executionId || candidate && (candidate.taskId !== evidence.taskId || candidate.executionId !== evidence.executionId)) {
          errors.push(issue("EVIDENCE_SCOPE_MISMATCH", "executionId", "Evidence scope mismatch."));
        }
        if (candidate && candidate.canonicalUrl !== evidence.sourceUrl) errors.push(issue("EVIDENCE_URL_MISMATCH", "sourceUrl", "Evidence URL mismatch."));
        const bytes = Buffer.byteLength(evidence.visibleText || "", "utf8");
        if ((evidence.visibleText || "").length > 5e4) errors.push(issue("VISIBLE_TEXT_CHAR_LIMIT", "visibleText", "Visible text exceeds character limit."));
        if (bytes > 131072) errors.push(issue("VISIBLE_TEXT_BYTE_LIMIT", "visibleText", "Visible text exceeds byte limit."));
        if (evidence.acquisitionStatus === "acquired") {
          const contentHash = evidence.visibleText ? buildContentHash(evidence.visibleText) : null;
          if (!evidence.visibleText) errors.push(issue("ACQUIRED_TEXT_EMPTY", "visibleText", "Acquired evidence must have text."));
          if (evidence.contentHash !== contentHash) errors.push(issue("CONTENT_HASH_MISMATCH", "contentHash", "Content hash mismatch."));
          if (contentHash && evidence.snapshotId !== buildSnapshotId(evidence.taskId, evidence.executionId, evidence.sourceId, contentHash)) errors.push(issue("SNAPSHOT_ID_MISMATCH", "snapshotId", "Snapshot ID mismatch."));
        } else if (evidence.visibleText || evidence.contentHash || evidence.snapshotId) {
          errors.push(issue("INACTIVE_EVIDENCE_HAS_CONTENT", "visibleText", "Failed or blocked evidence cannot carry content."));
        }
        if (/<script\b|<style\b/i.test(evidence.visibleText || "")) errors.push(issue("ACTIVE_CONTENT_IN_VISIBLE_TEXT", "visibleText", "Script/style content forbidden."));
        else if (/<[a-z][\s\S]*>/i.test(evidence.visibleText || "")) warnings.push(issue("HTML_IN_VISIBLE_TEXT", "visibleText", "HTML-like text detected."));
        if (/data:[^;]+;base64,|[A-Za-z0-9+/]{500,}={0,2}/.test(evidence.visibleText || "")) errors.push(issue("BINARY_CONTENT_SIGNAL", "visibleText", "Base64/binary signal forbidden."));
        return result({ errors, warnings });
      }
      function validateStructuredEvidence(evidence, context) {
        try {
          return validateStructuredEvidenceInternal(evidence, context);
        } catch (_) {
          return result({ errors: [issue(
            "EVIDENCE_VALIDATION_EXCEPTION",
            "$",
            "Doğrulama güvenli biçimde tamamlanamadı."
          )] });
        }
      }
      module["exports"] = { validateStructuredEvidence };
    }
  });

  // validators/validate_evidence_batch.js
  var require_validate_evidence_batch = __commonJS({
    "validators/validate_evidence_batch.js"(exports, module) {
      "use strict";
      var { isPlainRecord, issue } = require_validator_result();
      var { validateStructuredEvidence } = require_validate_structured_evidence();
      var { invalidCandidateIssue } = require_context_validation();
      var { validateSchema } = require_schema_engine();
      var MAX_TOTAL_VISIBLE_TEXT_BYTES = 393216;
      function batchResult(errors, warnings, rejected, total, length) {
        return {
          valid: errors.length === 0,
          errors,
          warnings,
          acceptedEvidenceCount: Math.max(0, length - rejected.size),
          rejectedEvidenceCount: rejected.size,
          totalVisibleTextBytes: total
        };
      }
      function validateEvidenceBatchInternal(evidences, context) {
        const errors = [], warnings = [], rejected = /* @__PURE__ */ new Set();
        if (!Array.isArray(evidences)) {
          errors.push(issue(
            "EVIDENCE_BATCH_ARRAY_REQUIRED",
            "$",
            "Evidence batch dizi olmalıdır."
          ));
          return batchResult(errors, warnings, rejected, 0, 0);
        }
        if (!isPlainRecord(context) || typeof context.taskId !== "string" || !context.taskId || typeof context.executionId !== "string" || !context.executionId || !Array.isArray(context.candidates)) {
          errors.push(issue(
            "CONTEXT_REQUIRED",
            "$",
            "Task, execution ve candidates context zorunludur."
          ));
          return batchResult(errors, warnings, rejected, 0, 0);
        }
        const invalidCandidate = invalidCandidateIssue(context.candidates);
        if (invalidCandidate) {
          errors.push(invalidCandidate);
          return batchResult(errors, warnings, rejected, 0, 0);
        }
        const sourceIds = /* @__PURE__ */ new Set();
        const snapshots = /* @__PURE__ */ new Map();
        let totalVisibleTextBytes = 0;
        if (context.candidates.length > 3) {
          errors.push(issue(
            "EVIDENCE_CANDIDATE_LIMIT_EXCEEDED",
            "candidates",
            "En fazla üç candidate kullanılabilir."
          ));
        }
        evidences.forEach((evidence, index) => {
          const schema = validateSchema("structured_evidence", evidence);
          let validation;
          try {
            validation = validateStructuredEvidence(evidence, context);
          } catch (_) {
            validation = { valid: false, warnings: [], errors: [issue(
              "EVIDENCE_VALIDATION_EXCEPTION",
              "$",
              "Doğrulama güvenli biçimde tamamlanamadı."
            )] };
          }
          if (!validation.valid) rejected.add(index);
          errors.push(...validation.errors.map((entry) => ({
            ...entry,
            path: `evidences[${index}].${entry.path}`
          })));
          warnings.push(...validation.warnings.map((entry) => ({
            ...entry,
            path: `evidences[${index}].${entry.path}`
          })));
          if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) return;
          if (typeof evidence.sourceId === "string") sourceIds.add(evidence.sourceId);
          if (schema.valid && evidence.acquisitionStatus === "acquired" && typeof evidence.visibleText === "string") {
            totalVisibleTextBytes += Buffer.byteLength(evidence.visibleText, "utf8");
          }
          if (typeof evidence.snapshotId === "string") {
            if (snapshots.has(evidence.snapshotId)) {
              rejected.add(index);
              errors.push(issue(
                "DUPLICATE_SNAPSHOT_ID",
                `evidences[${index}].snapshotId`,
                "Snapshot ID yinelenemez."
              ));
            } else snapshots.set(evidence.snapshotId, index);
          }
        });
        if (sourceIds.size > 3) {
          errors.push(issue(
            "EVIDENCE_SOURCE_LIMIT_EXCEEDED",
            "evidences",
            "En fazla üç source kullanılabilir."
          ));
        }
        if (totalVisibleTextBytes > MAX_TOTAL_VISIBLE_TEXT_BYTES) {
          errors.push(issue(
            "TOTAL_VISIBLE_TEXT_BYTES_EXCEEDED",
            "evidences",
            "Toplam görünür metin byte bütçesini aşıyor."
          ));
        }
        return batchResult(
          errors,
          warnings,
          rejected,
          totalVisibleTextBytes,
          evidences.length
        );
      }
      function validateEvidenceBatch(evidences, context) {
        try {
          return validateEvidenceBatchInternal(evidences, context);
        } catch (_) {
          return batchResult([issue(
            "EVIDENCE_BATCH_VALIDATION_EXCEPTION",
            "$",
            "Doğrulama güvenli biçimde tamamlanamadı."
          )], [], /* @__PURE__ */ new Set(), 0, 0);
        }
      }
      module["exports"] = { MAX_TOTAL_VISIBLE_TEXT_BYTES, validateEvidenceBatch };
    }
  });

  // validators/validate_scanner_result.js
  var require_validate_scanner_result = __commonJS({
    "validators/validate_scanner_result.js"(exports, module) {
      "use strict";
      var { canonicalizeUrl } = require_canonicalize_url();
      var { buildFindingKey } = require_deterministic_ids();
      var { isPlainRecord, issue, result } = require_validator_result();
      var { validateSchema } = require_schema_engine();
      var { invalidCandidateIssue, invalidEvidenceIssue } = require_context_validation();
      var CONCLUSIVE = /(?:kesin|doğrulanmış)\s+(?:sahte|taklit)|confirmed[_ -]?counterfeit/i;
      var META = /\b(?:örnek|varsayımsal|demo|template|şablon|metodoloji)\b/i;
      function validateScannerResultInternal(scanner, context) {
        const schema = validateSchema("digital_field_scanner_result", scanner);
        if (!schema.valid) return result({
          errors: schema.errors,
          acceptedFindingCount: 0,
          rejectedFindingCount: 0
        });
        if (!isPlainRecord(context) || typeof context.taskId !== "string" || !context.taskId || typeof context.executionId !== "string" || !context.executionId || !Array.isArray(context.candidates) || !Array.isArray(context.evidences)) {
          return result({
            errors: [issue(
              "CONTEXT_REQUIRED",
              "$",
              "Task, execution, candidates ve evidences context zorunludur."
            )],
            acceptedFindingCount: 0,
            rejectedFindingCount: 0
          });
        }
        const { candidates, evidences: evidence, productionCallback = false } = context;
        const invalidCandidate = invalidCandidateIssue(candidates);
        if (invalidCandidate) return result({
          errors: [invalidCandidate],
          acceptedFindingCount: 0,
          rejectedFindingCount: 0
        });
        const invalidEvidence = invalidEvidenceIssue(evidence);
        if (invalidEvidence) return result({
          errors: [invalidEvidence],
          acceptedFindingCount: 0,
          rejectedFindingCount: 0
        });
        const errors = [], warnings = [], seen = /* @__PURE__ */ new Set(), rejected = /* @__PURE__ */ new Set();
        if (scanner.taskId !== context.taskId || scanner.executionId !== context.executionId) {
          errors.push(issue("SCANNER_SCOPE_MISMATCH", "executionId", "Scanner scope mismatch."));
        }
        const acquired = candidates.filter((c) => c.acquisitionStatus === "acquired");
        for (const id of scanner.analyzedSourceIds) if (!acquired.some((c) => c.sourceId === id)) errors.push(issue("ANALYZED_SOURCE_NOT_ACQUIRED", "analyzedSourceIds", "Analyzed source is not acquired."));
        scanner.findings.forEach((finding, i) => {
          const path = `findings[${i}]`, candidate = acquired.find((c) => c.sourceId === finding.candidateId);
          const reject = (entry) => {
            errors.push(entry);
            rejected.add(i);
          };
          if (!candidate) reject(issue("FINDING_CANDIDATE_NOT_FOUND", `${path}.candidateId`, "Acquired candidate not found."));
          const canonical = canonicalizeUrl(finding.sourceUrl);
          if (candidate && (!canonical.valid || canonical.canonicalUrl !== candidate.canonicalUrl)) reject(issue("FINDING_URL_MISMATCH", `${path}.sourceUrl`, "Finding URL mismatch."));
          const refs = finding.evidenceReferences.map((id) => evidence.find((e) => e.snapshotId === id));
          if (refs.some((e) => !e)) reject(issue("EVIDENCE_REFERENCE_NOT_FOUND", `${path}.evidenceReferences`, "Evidence reference not found."));
          if (candidate && refs.some((e) => e && (e.taskId !== scanner.taskId || e.executionId !== scanner.executionId || e.sourceId !== candidate.sourceId))) reject(issue("FINDING_EVIDENCE_SCOPE_MISMATCH", `${path}.evidenceReferences`, "Evidence scope mismatch."));
          const expected = buildFindingKey(scanner.taskId, scanner.executionId, finding.candidateId, finding.signalType, finding.evidenceReferences);
          if (finding.findingKey !== expected) reject(issue("FINDING_KEY_MISMATCH", `${path}.findingKey`, "Finding key mismatch."));
          if (seen.has(finding.findingKey)) reject(issue("DUPLICATE_FINDING_KEY", `${path}.findingKey`, "Duplicate finding key."));
          seen.add(finding.findingKey);
          if (finding.severity === "critical" && finding.evidenceReferences.length === 0) reject(issue("CRITICAL_EVIDENCE_REQUIRED", `${path}.evidenceReferences`, "Critical finding requires evidence."));
          if (finding.severity === "critical" && finding.confidence < 0.8) reject(issue("CRITICAL_CONFIDENCE_LOW", `${path}.confidence`, "Critical confidence must be >= 0.80."));
          if (CONCLUSIVE.test(finding.description)) reject(issue("CONCLUSIVE_COUNTERFEIT_LANGUAGE", `${path}.description`, "Conclusive counterfeit language forbidden."));
          if (!candidate && finding.evidenceReferences.length === 0 && META.test(finding.description)) reject(issue("METHODOLOGY_AS_FINDING", `${path}.description`, "Methodology/example cannot become a finding."));
        });
        const fixture = scanner.fixtureMetadata || candidates.some((c) => c.fixtureMetadata);
        if (fixture && productionCallback) errors.push(issue("TEST_FIXTURE_PRODUCTION_CALLBACK", "fixtureMetadata", "Test fixture cannot use production callback."));
        return result({
          errors,
          warnings,
          acceptedFindingCount: scanner.findings.length - rejected.size,
          rejectedFindingCount: rejected.size
        });
      }
      function validateScannerResult(scanner, context) {
        try {
          return validateScannerResultInternal(scanner, context);
        } catch (_) {
          return result({
            errors: [issue(
              "SCANNER_VALIDATION_EXCEPTION",
              "$",
              "Doğrulama güvenli biçimde tamamlanamadı."
            )],
            acceptedFindingCount: 0,
            rejectedFindingCount: 0
          });
        }
      }
      module["exports"] = { validateScannerResult };
    }
  });

  // validators/pipeline_guard.js
  var require_pipeline_guard = __commonJS({
    "validators/pipeline_guard.js"(exports, module) {
      "use strict";
      var { validateAcquisitionResult } = require_validate_acquisition_result();
      function evaluateScannerInvocation({
        acquisitionResult,
        evidenceBatchValidation,
        productionCallback = false
      } = {}) {
        const acquisition = validateAcquisitionResult(
          acquisitionResult,
          { productionCallback }
        );
        if (!acquisition.valid) return {
          allowed: false,
          reason: acquisition.errors.some((e) => e.code === "TEST_FIXTURE_PRODUCTION_CALLBACK") ? "TEST_FIXTURE_PRODUCTION_CALLBACK" : "ACQUISITION_INVALID"
        };
        if (acquisitionResult.status === "no_candidates") {
          return { allowed: false, reason: "NO_CANDIDATES" };
        }
        if (acquisitionResult.candidates.length === 0) {
          return { allowed: false, reason: "NO_CANDIDATES" };
        }
        if (!evidenceBatchValidation || evidenceBatchValidation.valid !== true) {
          return { allowed: false, reason: "EVIDENCE_BATCH_INVALID" };
        }
        if (!(evidenceBatchValidation.totalVisibleTextBytes > 0) || !(evidenceBatchValidation.acceptedEvidenceCount > 0)) {
          return { allowed: false, reason: "NO_ACQUIRED_EVIDENCE" };
        }
        return { allowed: true, reason: "READY" };
      }
      module["exports"] = { evaluateScannerInvocation };
    }
  });

  // .build-tmp/fixture_catalog.js
  var require_fixture_catalog = __commonJS({
    ".build-tmp/fixture_catalog.js"(exports, module) {
      module["exports"] = { "no_signal": { "acquisitionResult": { "contractVersion": "acquisition-result-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "status": "completed", "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "d5de69370b7149be1cd81da0a204e6b32df3433f92376bbac3c805b562d946d5", "sourceUrl": "https://example.com/test-fixture/no-signal?utm_source=test", "canonicalUrl": "https://example.com/test-fixture/no-signal", "sourcePlatform": "example_fixture", "pageTitle": "TEST_FIXTURE no signal page", "sellerName": null, "productTitle": "Synthetic product", "price": 100, "currency": "TRY", "country": "TR", "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "acquired", "legalBasis": "public_source", "robotsPolicy": "allowed", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "no_signal" } }], "queriesAttempted": [], "errors": [], "limits": { "maximumCandidates": 3, "maximumTotalVisibleTextBytes": 393216 }, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "no_signal" } }, "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "d5de69370b7149be1cd81da0a204e6b32df3433f92376bbac3c805b562d946d5", "sourceUrl": "https://example.com/test-fixture/no-signal?utm_source=test", "canonicalUrl": "https://example.com/test-fixture/no-signal", "sourcePlatform": "example_fixture", "pageTitle": "TEST_FIXTURE no signal page", "sellerName": null, "productTitle": "Synthetic product", "price": 100, "currency": "TRY", "country": "TR", "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "acquired", "legalBasis": "public_source", "robotsPolicy": "allowed", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "no_signal" } }], "evidences": [{ "contractVersion": "structured-evidence-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "d5de69370b7149be1cd81da0a204e6b32df3433f92376bbac3c805b562d946d5", "snapshotId": "de170f605d070465c4436ca22e0c159a4d73cdbe3324a286bb4555c58bb7830d", "sourceUrl": "https://example.com/test-fixture/no-signal", "retrievedAt": "2026-07-18T00:01:00.000Z", "httpStatus": 200, "contentType": "text/plain", "visibleText": "TEST_FIXTURE normal public product page with no suspicious signal.", "contentHash": "a38fb29432230db965e1f2d315d0a88b3cb3bcd7c4b06bb10687e04a77ab186c", "snapshotReference": "evidence://TEST_FIXTURE/no-signal", "acquisitionStatus": "acquired", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "no_signal" } }], "scannerResult": { "contractVersion": "digital-field-scanner-result-v1", "agentCode": "digital_field_scanner", "status": "completed", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "analyzedSourceIds": ["d5de69370b7149be1cd81da0a204e6b32df3433f92376bbac3c805b562d946d5"], "findings": [], "rejectedCandidates": [{ "candidateId": "d5de69370b7149be1cd81da0a204e6b32df3433f92376bbac3c805b562d946d5", "reason": "no_signal" }], "notes": "TEST_FIXTURE: no signal detected.", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "no_signal" } }, "productionCallback": false }, "synthetic_signal": { "acquisitionResult": { "contractVersion": "acquisition-result-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "status": "completed", "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "ebb44e0c32c3f182accfeb93e80c9a4ae386d062842e5f075a2815deeeaa8e58", "sourceUrl": "https://example.com/test-fixture/synthetic-price-signal?b=2&a=1", "canonicalUrl": "https://example.com/test-fixture/synthetic-price-signal?a=1&b=2", "sourcePlatform": "example_fixture", "pageTitle": "TEST_FIXTURE synthetic price signal", "sellerName": null, "productTitle": "Synthetic product", "price": 50, "currency": "TRY", "country": "TR", "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "acquired", "legalBasis": "public_source", "robotsPolicy": "allowed", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "synthetic_signal" } }], "queriesAttempted": [], "errors": [], "limits": { "maximumCandidates": 3, "maximumTotalVisibleTextBytes": 393216 }, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "synthetic_signal" } }, "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "ebb44e0c32c3f182accfeb93e80c9a4ae386d062842e5f075a2815deeeaa8e58", "sourceUrl": "https://example.com/test-fixture/synthetic-price-signal?b=2&a=1", "canonicalUrl": "https://example.com/test-fixture/synthetic-price-signal?a=1&b=2", "sourcePlatform": "example_fixture", "pageTitle": "TEST_FIXTURE synthetic price signal", "sellerName": null, "productTitle": "Synthetic product", "price": 50, "currency": "TRY", "country": "TR", "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "acquired", "legalBasis": "public_source", "robotsPolicy": "allowed", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "synthetic_signal" } }], "evidences": [{ "contractVersion": "structured-evidence-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "ebb44e0c32c3f182accfeb93e80c9a4ae386d062842e5f075a2815deeeaa8e58", "snapshotId": "f5553a00b973c1a0e9ffb54ccf6dad61c0189862ff1d0d842f25b8d8f5404430", "sourceUrl": "https://example.com/test-fixture/synthetic-price-signal?a=1&b=2", "retrievedAt": "2026-07-18T00:01:00.000Z", "httpStatus": 200, "contentType": "text/plain", "visibleText": "TEST_FIXTURE synthetic listing price is 50 TRY while reference price is 100 TRY.", "contentHash": "7a0a9dfd2a68dfe7d4d1472b80433e09ba5b4dafb263f695380c27af001bb818", "snapshotReference": "evidence://TEST_FIXTURE/synthetic-signal", "acquisitionStatus": "acquired", "errorCode": null, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "synthetic_signal" } }], "scannerResult": { "contractVersion": "digital-field-scanner-result-v1", "agentCode": "digital_field_scanner", "status": "completed", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "analyzedSourceIds": ["ebb44e0c32c3f182accfeb93e80c9a4ae386d062842e5f075a2815deeeaa8e58"], "findings": [{ "findingKey": "f9120a3d800a90c678d754d1258f8a057e77f8f88785572c093c30b75b31c373", "candidateId": "ebb44e0c32c3f182accfeb93e80c9a4ae386d062842e5f075a2815deeeaa8e58", "sourceUrl": "https://example.com/test-fixture/synthetic-price-signal?a=1&b=2", "signalType": "price_anomaly", "description": "TEST_FIXTURE sentetik fiyat farkı insan incelemesi gerektiren bir sinyaldir.", "severity": "medium", "confidence": 0.8, "evidenceReferences": ["f5553a00b973c1a0e9ffb54ccf6dad61c0189862ff1d0d842f25b8d8f5404430"], "requiresHumanReview": true, "automatedConclusion": "suspected_signal" }], "rejectedCandidates": [], "notes": "TEST_FIXTURE only.", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "synthetic_signal" } }, "productionCallback": false }, "blocked": { "acquisitionResult": { "contractVersion": "acquisition-result-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "status": "partial", "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "34991052e3058acd369672f5e4d7715391c6f66c4615c2761345664ea01e3224", "sourceUrl": "https://example.com/test-fixture/blocked", "canonicalUrl": "https://example.com/test-fixture/blocked", "sourcePlatform": "example_fixture", "pageTitle": null, "sellerName": null, "productTitle": null, "price": null, "currency": null, "country": null, "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "blocked", "legalBasis": "public_source", "robotsPolicy": "blocked", "errorCode": "robots_blocked", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "blocked" } }], "queriesAttempted": [], "errors": [{ "code": "robots_blocked", "message": "TEST_FIXTURE source is blocked by policy." }], "limits": { "maximumCandidates": 3, "maximumTotalVisibleTextBytes": 393216 }, "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "blocked" } }, "candidates": [{ "contractVersion": "candidate-source-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "34991052e3058acd369672f5e4d7715391c6f66c4615c2761345664ea01e3224", "sourceUrl": "https://example.com/test-fixture/blocked", "canonicalUrl": "https://example.com/test-fixture/blocked", "sourcePlatform": "example_fixture", "pageTitle": null, "sellerName": null, "productTitle": null, "price": null, "currency": null, "country": null, "city": null, "searchQuery": null, "acquisitionMethod": "manual_seed", "discoveredAt": "2026-07-18T00:00:00.000Z", "acquisitionStatus": "blocked", "legalBasis": "public_source", "robotsPolicy": "blocked", "errorCode": "robots_blocked", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "blocked" } }], "evidences": [{ "contractVersion": "structured-evidence-v1", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "sourceId": "34991052e3058acd369672f5e4d7715391c6f66c4615c2761345664ea01e3224", "snapshotId": null, "sourceUrl": "https://example.com/test-fixture/blocked", "retrievedAt": null, "httpStatus": null, "contentType": null, "visibleText": "", "contentHash": null, "snapshotReference": null, "acquisitionStatus": "blocked", "errorCode": "robots_blocked", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "blocked" } }], "scannerResult": { "contractVersion": "digital-field-scanner-result-v1", "agentCode": "digital_field_scanner", "status": "completed", "taskId": "TEST_FIXTURE_TASK_001", "executionId": "TEST_FIXTURE_EXECUTION_001", "analyzedSourceIds": [], "findings": [], "rejectedCandidates": [{ "candidateId": "34991052e3058acd369672f5e4d7715391c6f66c4615c2761345664ea01e3224", "reason": "inaccessible" }], "notes": "TEST_FIXTURE blocked source was not analyzed.", "fixtureMetadata": { "marker": "TEST_FIXTURE", "isTestFixture": true, "productionEligible": false, "scenario": "blocked" } }, "productionCallback": false } };
    }
  });

  // runtime/n8n_contract_runtime_entry.js
  var require_n8n_contract_runtime_entry = __commonJS({
    "runtime/n8n_contract_runtime_entry.js"(exports, module) {
      var { validateAcquisitionResult } = require_validate_acquisition_result();
      var { validateCandidateSource } = require_validate_candidate_source();
      var { validateEvidenceBatch } = require_validate_evidence_batch();
      var { validateScannerResult } = require_validate_scanner_result();
      var { evaluateScannerInvocation } = require_pipeline_guard();
      var fixtureCatalog = require_fixture_catalog();
      var RUNTIME_VERSION = "ddt-n8n-runtime-v1";
      function safeFailure(errorCode) {
        return {
          contractRuntimeVersion: RUNTIME_VERSION,
          valid: false,
          errorCode,
          acquisitionValidation: null,
          candidateValidations: [],
          evidenceBatchValidation: null,
          scannerValidation: null,
          scannerInvocation: { allowed: false, reason: errorCode },
          findingCount: 0
        };
      }
      function runContractPipeline(input) {
        try {
          if (!input || typeof input !== "object" || Array.isArray(input)) {
            return safeFailure("PIPELINE_INPUT_INVALID");
          }
          const { acquisitionResult, candidates, evidences, scannerResult } = input;
          const productionCallback = input.productionCallback === true;
          const context = acquisitionResult && typeof acquisitionResult === "object" ? {
            taskId: acquisitionResult.taskId,
            executionId: acquisitionResult.executionId,
            candidates
          } : {};
          const acquisitionValidation = validateAcquisitionResult(
            acquisitionResult,
            { productionCallback }
          );
          const candidateValidations = Array.isArray(candidates) ? candidates.map((candidate) => validateCandidateSource(candidate, context)) : [];
          const evidenceBatchValidation = validateEvidenceBatch(evidences, context);
          const scannerValidation = validateScannerResult(scannerResult, {
            ...context,
            evidences,
            productionCallback
          });
          const scannerInvocation = evaluateScannerInvocation({
            acquisitionResult,
            evidenceBatchValidation,
            productionCallback
          });
          const candidatesValid = Array.isArray(candidates) && candidateValidations.every((validation) => validation.valid === true);
          const valid = acquisitionValidation.valid === true && candidatesValid && evidenceBatchValidation.valid === true && scannerValidation.valid === true;
          const findingCount = valid && scannerInvocation.allowed === true ? scannerValidation.acceptedFindingCount : 0;
          return {
            contractRuntimeVersion: RUNTIME_VERSION,
            valid,
            acquisitionValidation,
            candidateValidations,
            evidenceBatchValidation,
            scannerValidation,
            scannerInvocation,
            findingCount
          };
        } catch (_) {
          return safeFailure("CONTRACT_PIPELINE_EXCEPTION");
        }
      }
      function runFixtureScenario(scenarioName) {
        try {
          if (!Object.prototype.hasOwnProperty.call(fixtureCatalog, scenarioName)) {
            return { valid: false, errorCode: "FIXTURE_SCENARIO_UNSUPPORTED" };
          }
          return runContractPipeline(fixtureCatalog[scenarioName]);
        } catch (_) {
          return { valid: false, errorCode: "FIXTURE_SCENARIO_EXCEPTION" };
        }
      }
      module["exports"] = { runContractPipeline, runFixtureScenario };
    }
  });
  return require_n8n_contract_runtime_entry();
})();
