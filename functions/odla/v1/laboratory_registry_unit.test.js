/* eslint-disable */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const registry = require("./laboratory_registry");

const t = registry._test;

test("canonical hash is stable across object key order", () => {
  const a = {b: 2, a: 1, nested: {z: 9, y: 8}};
  const b = {nested: {y: 8, z: 9}, a: 1, b: 2};
  assert.equal(t.sha256Hex(a), t.sha256Hex(b));
});

test("entity hash excludes integrity carrier fields", () => {
  const a = {a: 1, recordSha256: "x", lastAuditEventSha256: "y"};
  const b = {a: 1, recordSha256: "z", lastAuditEventSha256: "q"};
  assert.equal(t.sha256Hex(a), t.sha256Hex(b));
});

test("laboratory legal transitions allow only locked transitions", () => {
  assert.doesNotThrow(() => {
    t.ensureStatusTransition(
        "ACTIVE",
        "SUSPENDED",
        t.LAB_TRANSITIONS,
        "ILLEGAL_STATUS_TRANSITION",
    );
  });
  assert.throws(() => {
    t.ensureStatusTransition(
        "RETIRED",
        "ACTIVE",
        t.LAB_TRANSITIONS,
        "ILLEGAL_STATUS_TRANSITION",
    );
  }, /ILLEGAL_STATUS_TRANSITION/);
});

test("accreditation verify decision maps to ACTIVE VERIFIED", () => {
  assert.deepEqual(t.reviewDecision("PENDING_VERIFICATION", "VERIFY_ACTIVE"), {
    targetStatus: "ACTIVE",
    verificationStatus: "VERIFIED",
  });
});

test("scope validation rejects empty, duplicate and >50 submissions", () => {
  assert.throws(() => t.validateScopeList([]), /EMPTY_SCOPE_SET/);
  assert.throws(
      () => t.validateScopeList([
        {testTypeCode: "CHEM", methodCode: "M1"},
        {testTypeCode: "CHEM", methodCode: "M1"},
      ]),
      /DUPLICATE_SCOPE_TUPLE/,
  );
  const tooMany = Array.from({length: 51}, (_, i) => ({
    testTypeCode: `T${i}`,
    methodCode: `M${i}`,
  }));
  assert.throws(() => t.validateScopeList(tooMany), /SCOPE_LIMIT_EXCEEDED/);
});

test("scope validation accepts the exact maximum of 50", () => {
  const exact = Array.from({length: 50}, (_, i) => ({
    testTypeCode: `T${i}`,
    methodCode: `M${i}`,
  }));
  assert.equal(t.validateScopeList(exact).length, 50);
});

test("coverage is fail-closed when accreditation is unverified", () => {
  const asOf = Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z"));
  const result = t.evaluateCoverage({
    status: "ACTIVE",
    verificationStatus: "UNVERIFIED",
    validFrom: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2027-01-01T00:00:00.000Z")),
  }, {
    scopeStatus: "ACTIVE",
    validFrom: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2027-01-01T00:00:00.000Z")),
  }, asOf);
  assert.equal(result.coverageStatus, "UNVERIFIED");
});

test("coverage detects expiration at result time", () => {
  const result = t.evaluateCoverage({
    status: "ACTIVE",
    verificationStatus: "VERIFIED",
    validFrom: Timestamp.fromDate(new Date("2024-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
  }, {
    scopeStatus: "ACTIVE",
    validFrom: Timestamp.fromDate(new Date("2024-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
  }, Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z")));
  assert.equal(result.coverageStatus, "EXPIRED_AT_RESULT_TIME");
});

test("coverage returns COVERED only for active verified in-window scope", () => {
  const result = t.evaluateCoverage({
    status: "ACTIVE",
    verificationStatus: "VERIFIED",
    validFrom: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2027-01-01T00:00:00.000Z")),
  }, {
    scopeStatus: "ACTIVE",
    validFrom: Timestamp.fromDate(new Date("2025-01-01T00:00:00.000Z")),
    validUntil: Timestamp.fromDate(new Date("2027-01-01T00:00:00.000Z")),
  }, Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z")));
  assert.equal(result.coverageStatus, "COVERED");
});

test("request hash ignores idempotency key but detects payload changes", () => {
  const a = t.stableRequestHash("x", {
    idempotencyKey: "one",
    legalName: "Lab A",
  });
  const b = t.stableRequestHash("x", {
    idempotencyKey: "two",
    legalName: "Lab A",
  });
  const c = t.stableRequestHash("x", {
    idempotencyKey: "two",
    legalName: "Lab B",
  });
  assert.equal(a, b);
  assert.notEqual(a, c);
});
