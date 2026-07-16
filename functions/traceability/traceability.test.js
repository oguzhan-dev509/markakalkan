const assert = require("node:assert/strict");

const {evaluateVerificationRisk} = require("./traceability");

const firstScan = evaluateVerificationRisk({
  found: true,
  status: "active",
  previousScanCount: 0,
  nextScanCount: 1,
  previousVerifiedAt: null,
  verifiedAt: Date.now(),
  previousPlatform: "",
  platform: "web",
  previousSource: "",
  source: "manual",
});

assert.equal(firstScan.suspicious, false);
assert.equal(firstScan.riskScore, 0);
assert.equal(firstScan.riskLevel, "none");

const rapidThirdScan = evaluateVerificationRisk({
  found: true,
  status: "active",
  previousScanCount: 2,
  nextScanCount: 3,
  previousVerifiedAt: Date.now() - 60 * 1000,
  verifiedAt: Date.now(),
  previousPlatform: "web",
  platform: "ios",
  previousSource: "manual",
  source: "qr",
});

assert.equal(rapidThirdScan.suspicious, true);
assert.ok(rapidThirdScan.riskReasons.includes("repeated_scan"));
assert.ok(rapidThirdScan.riskReasons.includes("rapid_repeat_scan"));
assert.ok(rapidThirdScan.riskReasons.includes("platform_changed"));

const revokedCode = evaluateVerificationRisk({
  found: true,
  status: "revoked",
  previousScanCount: 1,
  nextScanCount: 2,
  previousVerifiedAt: null,
  verifiedAt: Date.now(),
  previousPlatform: "web",
  platform: "web",
  previousSource: "manual",
  source: "manual",
});

assert.equal(revokedCode.suspicious, true);
assert.equal(revokedCode.riskScore, 100);
assert.equal(revokedCode.riskLevel, "critical");
assert.ok(revokedCode.riskReasons.includes("revoked_code"));

console.log("TRACEABILITY_RISK_TEST_OK");
