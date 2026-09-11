"use strict";
const test=require("node:test"), assert=require("node:assert/strict");
const c=require("./contracts");
test("canonical stable", ()=>assert.equal(c.canonicalJson({b: 2, a: 1}), c.canonicalJson({a: 1, b: 2})));
test("ADV-004 payer pressure cannot mutate evidence", ()=>{
  const x=c.validateTestResult({testResultId: "r", testRequestId: "q", sampleId: "s", laboratoryId: "l", laboratoryReportId: "rep", reportSha256: "a".repeat(64), appendOnly: true}); assert.equal(Object.isFrozen(x), true);
});
test("ADV-025 result replacement needs new identity", ()=>assert.notEqual(c.deriveDeterministicId("r", ["a"]), c.deriveDeterministicId("r", ["b"])));
test("ADV-026 finding append-only versioned", ()=>assert.equal(c.validateFinding({findingId: "f2", findingVersion: 2, findingCode: "QUALITY_NONCONFORMING", supersedesFindingId: "f1", appendOnly: true}).findingVersion, 2));
test("ADV-029 escrow prohibited", ()=>assert.throws(()=>c.validateFundingAuthorization({fundingAuthorizationId: "x", markakalkanEscrowUsed: true})));
test("ADV-030 same identity different payload conflicts conceptually", ()=>{
  assert.equal(c.deriveDeterministicId("op", ["x"]), c.deriveDeterministicId("op", ["x"])); assert.notEqual(c.canonicalJson({x: 1}), c.canonicalJson({x: 2}));
});
