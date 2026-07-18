"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {clone, fixture} = require("./test_helpers");
const {validateAcquisitionResult} = require("../validators/validate_acquisition_result");
const {validateCandidateSource} = require("../validators/validate_candidate_source");
const {validateStructuredEvidence} = require("../validators/validate_structured_evidence");
const {validateScannerResult} = require("../validators/validate_scanner_result");

test("public validators fail closed for null undefined and primitives", () => {
  for (const value of [null, undefined, "bad", 7]) {
    for (const validation of [
      validateAcquisitionResult(value),
      validateCandidateSource(value, {taskId:"t", executionId:"e"}),
      validateStructuredEvidence(value, {taskId:"t", executionId:"e", candidates:[]}),
      validateScannerResult(value, {taskId:"t", executionId:"e", candidates:[], evidences:[]}),
    ]) {
      assert.equal(validation.valid, false);
      assert(validation.errors.some((e) => e.code.startsWith("SCHEMA_")));
    }
  }
});

test("schema errors expose stable code and safe path", () => {
  const value = clone(fixture("no_signal", "acquisition_result"));
  delete value.taskId;
  const out = validateAcquisitionResult(value);
  assert.equal(out.valid, false);
  assert(out.errors.some((e) => e.code === "SCHEMA_REQUIRED" && e.path === "taskId"));
  assert(!JSON.stringify(out).includes(value.candidates[0].sourceUrl));
});

test("all semantic validators require complete context", () => {
  const candidate = fixture("no_signal", "candidate_sources")[0];
  const evidence = fixture("no_signal", "structured_evidence")[0];
  const scanner = fixture("no_signal", "scanner_result");
  assert(validateCandidateSource(candidate, {}).errors.some((e) => e.code === "CONTEXT_REQUIRED"));
  assert(validateStructuredEvidence(evidence, {taskId:evidence.taskId}).errors.some((e) => e.code === "CONTEXT_REQUIRED"));
  assert(validateScannerResult(scanner, {taskId:scanner.taskId}).errors.some((e) => e.code === "CONTEXT_REQUIRED"));
});

test("public validators execute schema before semantics", () => {
  const candidate = clone(fixture("no_signal", "candidate_sources")[0]);
  candidate.secret = "must-not-pass";
  const c = validateCandidateSource(candidate, {taskId:candidate.taskId, executionId:candidate.executionId});
  assert(c.errors.some((e) => e.code === "SCHEMA_ADDITIONALPROPERTIES" && e.path === "secret"));
  const evidence = clone(fixture("no_signal", "structured_evidence")[0]);
  evidence.contentType = "application/json";
  assert(validateStructuredEvidence(evidence, {taskId:evidence.taskId, executionId:evidence.executionId, candidates:fixture("no_signal", "candidate_sources")}).errors.some((e) => e.code === "SCHEMA_PATTERN"));
  const scanner = clone(fixture("no_signal", "scanner_result"));
  scanner.findings = "bad";
  const out = validateScannerResult(scanner, {taskId:scanner.taskId, executionId:scanner.executionId, candidates:[], evidences:[]});
  assert.equal(out.acceptedFindingCount, 0); assert.equal(out.rejectedFindingCount, 0);
});

test("content type accepts only the explicit text contract", () => {
  const candidates=fixture("no_signal","candidate_sources"),base=fixture("no_signal","structured_evidence")[0],ctx={taskId:base.taskId,executionId:base.executionId,candidates};
  for(const contentType of ["text/html","text/plain","text/html; charset=utf-8","text/plain; charset=UTF-8"]){const value=clone(base);value.contentType=contentType;assert.equal(validateStructuredEvidence(value,ctx).valid,true);}
  for(const contentType of ["application/json","text/html-malformed"]){const value=clone(base);value.contentType=contentType;assert(validateStructuredEvidence(value,ctx).errors.some((e)=>e.code==="SCHEMA_PATTERN"));}
});
