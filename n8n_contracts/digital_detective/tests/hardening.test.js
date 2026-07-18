"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {clone, fixture} = require("./test_helpers");
const {canonicalizeUrl} = require("../validators/canonicalize_url");
const ids = require("../validators/deterministic_ids");
const {validateCandidateSource} = require("../validators/validate_candidate_source");
const {validateStructuredEvidence} = require("../validators/validate_structured_evidence");
const {validateScannerResult} = require("../validators/validate_scanner_result");
const {validateEvidenceBatch} = require("../validators/validate_evidence_batch");
const {evaluateScannerInvocation} = require("../validators/pipeline_guard");

function context(scenario) { const candidates=fixture(scenario,"candidate_sources"),evidences=fixture(scenario,"structured_evidence"),scanner=fixture(scenario,"scanner_result"); return {candidates,evidences,scanner,taskId:scanner.taskId,executionId:scanner.executionId}; }

test("canonicalization security and ordering edge cases", () => {
  for (const key of ["TOKEN", "Access_Token", "api%5Fkey"]) assert.equal(canonicalizeUrl(`https://example.com/?${key}=x`).valid, false);
  const a=canonicalizeUrl("https://example.com/x?UTM_Source=x&b=1&a=2&a=1#f");
  assert.equal(a.canonicalUrl,"https://example.com/x?a=1&a=2&b=1");
  assert.notEqual(canonicalizeUrl("https://example.com/a//b").canonicalUrl,canonicalizeUrl("https://example.com/a/b").canonicalUrl);
  assert.equal(canonicalizeUrl("https://münich.example").canonicalUrl,"https://xn--mnich-kva.example/");
  assert.equal(canonicalizeUrl("https://u:p@example.com").valid,false);
});

test("text normalization and domain separation are deterministic", () => {
  assert.equal(ids.buildContentHash("a\r\nb"),ids.buildContentHash("a\nb"));
  assert.equal(ids.buildContentHash("a\rb"),ids.buildContentHash("a\nb"));
  assert.equal(ids.buildContentHash("é"),ids.buildContentHash("e\u0301"));
  const refs=["b","a","a"], before=JSON.stringify(refs); ids.buildEvidenceFingerprint(refs); assert.equal(JSON.stringify(refs),before);
  const raw="same", namespaces=[ids.buildContentHash(raw),ids.buildEvidenceFingerprint([raw]),ids.buildSourceId(raw,raw,raw)];
  assert.equal(new Set(namespaces).size,namespaces.length);
});

test("scanner counts rejected findings by index", () => {
  const ctx=context("synthetic_signal"), finding=ctx.scanner.findings[0];
  finding.candidateId="f".repeat(64); finding.evidenceReferences=[]; finding.severity="critical"; finding.confidence=.1;
  const out=validateScannerResult(ctx.scanner,ctx);
  assert.equal(out.acceptedFindingCount,0); assert.equal(out.rejectedFindingCount,1);
});

test("one valid and one multiply invalid finding counts one each", () => {
  const ctx=context("synthetic_signal"), bad=clone(ctx.scanner.findings[0]);
  bad.findingKey="f".repeat(64); bad.candidateId="f".repeat(64); bad.evidenceReferences=[]; bad.severity="critical"; bad.confidence=.1;
  ctx.scanner.findings.push(bad); const out=validateScannerResult(ctx.scanner,ctx);
  assert.equal(out.acceptedFindingCount,1); assert.equal(out.rejectedFindingCount,1);
});

test("duplicate finding key rejects only the duplicate finding", () => {
  const ctx=context("synthetic_signal"); ctx.scanner.findings.push(clone(ctx.scanner.findings[0]));
  const out=validateScannerResult(ctx.scanner,ctx);
  assert.equal(out.acceptedFindingCount,1); assert.equal(out.rejectedFindingCount,1);
  assert(out.errors.some((e)=>e.code==="DUPLICATE_FINDING_KEY"));
});

test("public validators do not mutate inputs", () => {
  const ctx=context("synthetic_signal"), candidate=ctx.candidates[0], evidence=ctx.evidences[0];
  for(const [value,call] of [[candidate,()=>validateCandidateSource(candidate,ctx)],[evidence,()=>validateStructuredEvidence(evidence,ctx)],[ctx.scanner,()=>validateScannerResult(ctx.scanner,ctx)]]){const before=JSON.stringify(value);call();assert.equal(JSON.stringify(value),before);}
});

test("pipeline guard blocks invalid states and allows acquired evidence", () => {
  const no=context("no_signal"), noBatch=validateEvidenceBatch(no.evidences,no);
  assert.deepEqual(evaluateScannerInvocation({acquisitionResult:fixture("no_signal","acquisition_result"),evidenceBatchValidation:noBatch}),{allowed:true,reason:"READY"});
  const empty=clone(fixture("no_signal","acquisition_result")); empty.status="no_candidates"; empty.candidates=[];
  assert.equal(evaluateScannerInvocation({acquisitionResult:empty,evidenceBatchValidation:noBatch}).reason,"NO_CANDIDATES");
  assert.equal(evaluateScannerInvocation({acquisitionResult:fixture("no_signal","acquisition_result"),evidenceBatchValidation:{valid:false}}).reason,"EVIDENCE_BATCH_INVALID");
  const blocked=context("blocked"), blockedBatch=validateEvidenceBatch(blocked.evidences,blocked);
  assert.equal(evaluateScannerInvocation({acquisitionResult:fixture("blocked","acquisition_result"),evidenceBatchValidation:blockedBatch}).reason,"NO_ACQUIRED_EVIDENCE");
  assert.equal(evaluateScannerInvocation({acquisitionResult:fixture("synthetic_signal","acquisition_result"),evidenceBatchValidation:validateEvidenceBatch(context("synthetic_signal").evidences,context("synthetic_signal")),productionCallback:true}).reason,"TEST_FIXTURE_PRODUCTION_CALLBACK");
});

test("expected validation fixtures match public validator results", () => {
  for(const scenario of ["no_signal","synthetic_signal","blocked"]){const ctx=context(scenario),acquisition=fixture(scenario,"acquisition_result"),acquisitionValidation=require("../validators/validate_acquisition_result").validateAcquisitionResult(acquisition),batch=validateEvidenceBatch(ctx.evidences,ctx),out=validateScannerResult(ctx.scanner,ctx),expected=fixture(scenario,"expected_validation");assert.equal(acquisitionValidation.valid,true);assert.equal(batch.valid,true);for(const key of ["valid","errors","warnings","acceptedFindingCount","rejectedFindingCount"])assert.deepEqual(out[key],expected[key]);const guard=evaluateScannerInvocation({acquisitionResult:acquisition,evidenceBatchValidation:batch});assert.equal(guard.allowed,scenario!=="blocked");if(Object.hasOwn(expected,"productionCallbackAllowed")){ctx.productionCallback=true;assert.equal(validateScannerResult(ctx.scanner,ctx).valid,expected.productionCallbackAllowed);}}
});

test("fixture deterministic IDs and hashes recompute exactly", () => {
  for(const scenario of ["no_signal","synthetic_signal","blocked"]){const ctx=context(scenario);for(const candidate of ctx.candidates)assert.equal(candidate.sourceId,ids.buildSourceId(candidate.taskId,candidate.executionId,candidate.canonicalUrl));for(const evidence of ctx.evidences){if(evidence.contentHash)assert.equal(evidence.contentHash,ids.buildContentHash(evidence.visibleText));if(evidence.snapshotId)assert.equal(evidence.snapshotId,ids.buildSnapshotId(evidence.taskId,evidence.executionId,evidence.sourceId,evidence.contentHash));}for(const finding of ctx.scanner.findings)assert.equal(finding.findingKey,ids.buildFindingKey(ctx.scanner.taskId,ctx.scanner.executionId,finding.candidateId,finding.signalType,finding.evidenceReferences));}
});
