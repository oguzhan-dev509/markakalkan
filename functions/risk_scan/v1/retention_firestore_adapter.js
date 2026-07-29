"use strict";

const {
  assertIsoTimestamp,
  assertPlainObject,
} = require("./contracts");
const {
  RETENTION_CONTRACT_VERSION_V1,
  buildRateLimitRetentionFields,
  buildRunRetentionFields,
} = require("./retention_contract");

const RETENTION_STORAGE_DERIVED_FIELDS = Object.freeze([
  "retentionContractVersion",
  "expiresAtTimestamp",
  "purgeAtTimestamp",
  "nativeTtlEligible",
  "cleanupStrategy",
  "ttlCollectionGroup",
  "ttlField",
]);

const firestoreDateTimestampFactory = Object.freeze({
  fromDate(date) {
    const milliseconds = date.getTime();
    return Object.freeze({
      toDate() {
        return new Date(milliseconds);
      },
    });
  },
});

function timestampToMillis(value, label) {
  if (value instanceof Date) {
    const milliseconds = value.getTime();
    if (!Number.isFinite(milliseconds)) {
      throw new TypeError(`${label} must be a valid timestamp`);
    }
    return milliseconds;
  }

  if (value && typeof value.toMillis === "function") {
    const milliseconds = value.toMillis();
    if (!Number.isFinite(milliseconds)) {
      throw new TypeError(`${label} must be a valid timestamp`);
    }
    return milliseconds;
  }

  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    if (!(date instanceof Date) || !Number.isFinite(date.getTime())) {
      throw new TypeError(`${label} must be a valid timestamp`);
    }
    return date.getTime();
  }

  if (value && typeof value === "object") {
    const seconds = value.seconds ?? value._seconds;
    const nanoseconds = value.nanoseconds ?? value._nanoseconds ?? 0;
    if (Number.isInteger(seconds) &&
        Number.isInteger(nanoseconds) &&
        nanoseconds >= 0 &&
        nanoseconds < 1000000000) {
      return (seconds * 1000) + Math.floor(nanoseconds / 1000000);
    }
  }

  throw new TypeError(`${label} must be a Firestore timestamp or Date`);
}

function assertTimestampMatchesIso(isoValue, timestampValue, label) {
  const normalized = assertIsoTimestamp(isoValue, `${label}.iso`);
  const expectedMilliseconds = Date.parse(normalized);
  const actualMilliseconds = timestampToMillis(
      timestampValue, `${label}.timestamp`);
  if (actualMilliseconds !== expectedMilliseconds) {
    throw new TypeError(`${label} timestamp does not match ISO value`);
  }
  return timestampValue;
}

function storageDate(timestampValue, label) {
  return new Date(timestampToMillis(timestampValue, label));
}

function withRunRetentionStorage(run, timestampFactory) {
  assertPlainObject(run, "run");
  const fields = buildRunRetentionFields(
      {expiresAt: run.expiresAt},
      timestampFactory ?? firestoreDateTimestampFactory);
  return {
    ...run,
    ...fields,
    expiresAtTimestamp: storageDate(
        fields.expiresAtTimestamp, "expiresAtTimestamp"),
  };
}

function withRateLimitRetentionStorage(record, timestampFactory) {
  assertPlainObject(record, "rateLimitRecord");
  const fields = buildRateLimitRetentionFields(
      {purgeAt: record.purgeAt},
      timestampFactory ?? firestoreDateTimestampFactory);
  return {
    ...record,
    ...fields,
    purgeAtTimestamp: storageDate(
        fields.purgeAtTimestamp, "purgeAtTimestamp"),
  };
}

function assertRunRetentionStorage(run) {
  assertPlainObject(run, "run");
  if (run.retentionContractVersion !== RETENTION_CONTRACT_VERSION_V1 ||
      run.nativeTtlEligible !== false ||
      run.cleanupStrategy !== "recursiveServerSide") {
    throw new TypeError("run retention storage metadata is invalid");
  }
  assertTimestampMatchesIso(
      run.expiresAt, run.expiresAtTimestamp, "run.expiresAt");
  return run;
}

function assertRateLimitRetentionStorage(record) {
  assertPlainObject(record, "rateLimitRecord");
  if (record.retentionContractVersion !== RETENTION_CONTRACT_VERSION_V1 ||
      record.nativeTtlEligible !== true ||
      record.ttlCollectionGroup !== "risk_scan_rate_limits" ||
      record.ttlField !== "purgeAtTimestamp") {
    throw new TypeError("rate-limit retention storage metadata is invalid");
  }
  assertTimestampMatchesIso(
      record.purgeAt, record.purgeAtTimestamp, "rateLimit.purgeAt");
  return record;
}

function splitRetentionStorageFields(document) {
  assertPlainObject(document, "document");
  const fingerprintDocument = {};
  const retentionStorageFields = {};

  for (const [key, value] of Object.entries(document)) {
    if (RETENTION_STORAGE_DERIVED_FIELDS.includes(key)) {
      retentionStorageFields[key] = value;
    } else {
      fingerprintDocument[key] = value;
    }
  }

  return {fingerprintDocument, retentionStorageFields};
}

module.exports = {
  RETENTION_STORAGE_DERIVED_FIELDS,
  assertRateLimitRetentionStorage,
  assertRunRetentionStorage,
  assertTimestampMatchesIso,
  firestoreDateTimestampFactory,
  splitRetentionStorageFields,
  timestampToMillis,
  withRateLimitRetentionStorage,
  withRunRetentionStorage,
};
