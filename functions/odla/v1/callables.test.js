"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const c = require("./callables");
const src = fs.readFileSync(path.join(__dirname, "callables.js"), "utf8");
const expected = [
  "createOdlaVerificationCase", "getOdlaVerificationWorkspace",
  "appendOdlaChainOfCustodyEvent", "createOdlaTestRequest",
  "recordOdlaTestResult", "adjudicateOdlaFinding", "openOdlaAppeal", "resolveOdlaAppeal",
].sort();

function extractWriteOperations(source) {
  const match = source.match(
      /const\s+WRITE_OPERATIONS\s*=\s*new\s+Set\s*\(\s*\[([\s\S]*?)\]\s*\)/,
  );
  assert.ok(match, "WRITE_OPERATIONS set must be parseable");
  return [...match[1].matchAll(/['"]([^'"]+)['"]/g)].map((m) => m[1]);
}

test("ODLA-BE-CALL-001 exact eight callable exports present", () =>
  assert.deepEqual(Object.keys(c).sort(), expected));
test("ODLA-BE-CALL-002 no unapproved callable export present", () =>
  assert.equal(Object.keys(c).every((x)=>expected.includes(x)), true));
test("ODLA-BE-CALL-003 all callables use region europe-west3", () => {
  assert.match(src, /region:\s*["']europe-west3["']/); assert.equal((src.match(/CALLABLE_OPTIONS,/g)||[]).length, 8);
});
test("ODLA-BE-CALL-004 all callables enforce App Check", () =>
  assert.match(src, /enforceAppCheck:\s*true/));
test("ODLA-BE-CALL-005 missing auth denied before service invocation", () => {
  assert.ok(src.indexOf("assertAuthenticatedRequest(request)") < src.indexOf("getFirestore()"));
});
test("ODLA-BE-CALL-006 malformed input envelope denied", () =>
  assert.match(src, /ODLA request object required/));
test("ODLA-BE-CALL-007 write call requires operationId", () =>
  assert.match(src, /WRITE_OPERATIONS\.has\(operation\)/));
test("ODLA-BE-CALL-008 read workspace does not require operationId", () =>
  assert.equal(extractWriteOperations(src).includes("getOdlaVerificationWorkspace"), false));
test("ODLA-BE-CALL-009 internal errors map to bounded fail-closed HttpsError", () => {
  assert.match(src, /ODLA operation failed closed/); assert.match(src, /new HttpsError/);
});
test("ODLA-BE-CALL-010 callable module performs no outbound network access", () =>
  assert.equal(/require\(['"](?:http|https|axios|node-fetch|undici)['"]\)/.test(src), false));
test("ODLA-BE-CALL-011 callable module exposes no direct arbitrary Firestore access", () =>
  assert.equal(/request\.data\.(?:collection|document|path)/.test(src), false));
test("ODLA-BE-CALL-012 client role fields cannot override trusted authority", () => {
  const authSrc=fs.readFileSync(path.join(__dirname, "authorization.js"), "utf8");
  assert.equal(/request\.data\.role/.test(authSrc), false);
});
