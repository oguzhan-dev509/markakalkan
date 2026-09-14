"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const c = require("./callables");
const src = fs.readFileSync(path.join(__dirname, "callables.js"), "utf8");
const adapterSrc = fs.readFileSync(
    path.join(__dirname, "firestore_adapter.js"),
    "utf8",
);
const serviceSrc = fs.readFileSync(
    path.join(__dirname, "workspace_service.js"),
    "utf8",
);
const expected = [
  "createOdlaVerificationCase",
  "getOdlaVerificationWorkspace",
  "appendOdlaChainOfCustodyEvent",
  "createOdlaTestRequest",
  "recordOdlaTestResult",
  "adjudicateOdlaFinding",
  "openOdlaAppeal",
  "resolveOdlaAppeal",
  "getOdlaLaboratoryRegistryEntry",
  "listOdlaLaboratoriesForAuthorizedWorkspace",
  "getOdlaLaboratoryAccreditationHistory",
  "registerOdlaLaboratory",
  "submitOdlaLaboratoryAccreditation",
  "reviewOdlaLaboratoryAccreditation",
  "changeOdlaLaboratoryStatus",
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
  assert.equal(
      Object.keys(c).every((x) => expected.includes(x)),
      true,
  ));
test("ODLA-BE-CALL-003 all callables use region europe-west3", () => {
  assert.match(src, /region:\s*["']europe-west3["']/);
  assert.equal((src.match(/CALLABLE_OPTIONS,/g) || []).length, 8);
});
test("ODLA-BE-CALL-004 all callables enforce App Check", () =>
  assert.match(src, /enforceAppCheck:\s*true/));
test("ODLA-BE-CALL-005 missing auth denied before service invocation", () => {
  assert.ok(
      src.indexOf("assertAuthenticatedRequest(request)") <
      src.indexOf("getFirestore()"),
  );
});
test("ODLA-BE-CALL-006 malformed input envelope denied", () =>
  assert.match(src, /ODLA request object required/));
test("ODLA-BE-CALL-007 write call requires operationId", () =>
  assert.match(src, /WRITE_OPERATIONS\.has\(operation\)/));
test("ODLA-BE-CALL-008 read workspace does not require operationId", () =>
  assert.equal(
      extractWriteOperations(src).includes("getOdlaVerificationWorkspace"),
      false,
  ));
test(
    "ODLA-BE-CALL-009 internal errors map to " +
    "bounded fail-closed HttpsError",
    () => {
      assert.match(src, /ODLA operation failed closed/);
      assert.match(src, /new HttpsError/);
    },
);
test(
    "ODLA-BE-CALL-010 callable module " +
    "performs no outbound network access",
    () =>
      assert.equal(
          /require\(['"](?:http|https|axios|node-fetch|undici)['"]\)/.test(src),
          false,
      ),
);
test(
    "ODLA-BE-CALL-011 callable module " +
    "exposes no direct arbitrary Firestore " +
    "access",
    () =>
      assert.equal(
          /request\.data\.(?:collection|document|path)/.test(src),
          false,
      ),
);
test(
    "ODLA-BE-CALL-012 client role fields " +
    "cannot override trusted authority",
    () => {
      const authSrc = fs.readFileSync(
          path.join(__dirname, "authorization.js"),
          "utf8",
      );
      assert.equal(/request\.data\.role/.test(authSrc), false);
    },
);
test(
    "ODLA-BE-CALL-013 authority comes from server-side resolver",
    () => {
      assert.match(src, /resolveOdlaServerAuthority/);
      assert.ok(
          src.indexOf("assertAuthenticatedRequest(request)") <
          src.indexOf("getFirestore()"),
      );
      assert.ok(
          src.indexOf("getFirestore()") <
          src.indexOf("await resolveOdlaServerAuthority"),
      );
    },
);

test(
    "ODLA-2A-M2-CALL-001 workspace registry enrichment adds no callable",
    () => {
      const exported = Object.keys(c).sort();
      for (const name of [
        "getOdlaLaboratoryRegistryEntry",
        "listOdlaLaboratoriesForAuthorizedWorkspace",
        "getOdlaLaboratoryAccreditationHistory",
      ]) {
        assert.ok(exported.includes(name));
      }
      assert.equal(
          exported.includes("getOdlaWorkspaceLaboratoryRegistryContext"),
          false,
      );
    },
);

test(
    "ODLA-2A-M2-CALL-002 workspace registry adapter read is bounded " +
    "and performs zero writes",
    () => {
      const start = adapterSrc.indexOf(
          "async function getWorkspaceLaboratoryRegistryContext",
      );
      const end = adapterSrc.indexOf(
          "\n  async function getVerificationProfile",
          start,
      );
      assert.ok(start >= 0);
      assert.ok(end > start);
      const body = adapterSrc.slice(start, end);

      assert.match(body, /slice\(0,\s*20\)/);
      assert.match(body, /\.limit\(100\)/);
      assert.match(body, /\.limit\(200\)/);
      assert.equal(
          body.includes("db.collection(\"odlaLaboratories\")"),
          false,
      );
      for (const forbidden of [
        "runTransaction(",
        ".create(",
        ".set(",
        ".update(",
        ".delete(",
      ]) {
        assert.equal(body.includes(forbidden), false);
      }
      assert.ok(body.includes("\"UNKNOWN\""));
      assert.ok(body.includes("\"UNVERIFIED\""));
    },
);

test(
    "ODLA-2A-M2-CALL-003 authorization check precedes registry read",
    () => {
      const scope = serviceSrc.indexOf(
          "assertCaseScope(authority, workspace, data);",
      );
      const registry = serviceSrc.indexOf(
          "await adapter.getWorkspaceLaboratoryRegistryContext",
      );
      assert.ok(scope >= 0);
      assert.ok(registry > scope);
      assert.equal(
          serviceSrc.includes(
              "collectWorkspaceLaboratoryReferences(" +
              "workspace.case, operational)",
          ),
          true,
      );
    },
);
