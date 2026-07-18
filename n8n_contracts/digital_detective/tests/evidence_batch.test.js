"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {clone, fixture} = require("./test_helpers");
const ids = require("../validators/deterministic_ids");
const {validateEvidenceBatch, MAX_TOTAL_VISIBLE_TEXT_BYTES} = require("../validators/validate_evidence_batch");

function batch(texts) {
  const baseCandidate = fixture("no_signal", "candidate_sources")[0];
  const baseEvidence = fixture("no_signal", "structured_evidence")[0];
  const candidates = [], evidences = [];
  texts.forEach((text, index) => {
    const candidate = clone(baseCandidate), evidence = clone(baseEvidence);
    candidate.sourceUrl = `https://example.com/test-fixture/budget-${index}`;
    candidate.canonicalUrl = candidate.sourceUrl;
    candidate.sourceId = ids.buildSourceId(candidate.taskId, candidate.executionId, candidate.canonicalUrl);
    evidence.sourceId = candidate.sourceId; evidence.sourceUrl = candidate.canonicalUrl;
    evidence.visibleText = text; evidence.contentHash = ids.buildContentHash(text);
    evidence.snapshotId = ids.buildSnapshotId(evidence.taskId, evidence.executionId, evidence.sourceId, evidence.contentHash);
    candidates.push(candidate); evidences.push(evidence);
  });
  return {evidences, context:{taskId:baseCandidate.taskId, executionId:baseCandidate.executionId, candidates}};
}

test("batch accepts below and exact total byte budget", () => {
  let value = batch(["a", "b", "c"]), out = validateEvidenceBatch(value.evidences, value.context);
  assert.equal(out.valid, true); assert.equal(out.acceptedEvidenceCount, 3);
  const exact = "漢".repeat(43690) + "é";
  value = batch([exact, exact, exact]); out = validateEvidenceBatch(value.evidences, value.context);
  assert.equal(out.totalVisibleTextBytes, MAX_TOTAL_VISIBLE_TEXT_BYTES);
  assert.equal(out.valid, true);
});

test("batch rejects 393217 bytes with stable code", () => {
  const exact = "漢".repeat(43690) + "é", value = batch([exact, exact, exact + "a"]);
  const out = validateEvidenceBatch(value.evidences, value.context);
  assert.equal(out.totalVisibleTextBytes, 393217);
  assert(out.errors.some((e) => e.code === "TOTAL_VISIBLE_TEXT_BYTES_EXCEEDED"));
});

test("duplicate snapshot is rejected once by document", () => {
  const value = batch(["a", "b"]); value.evidences[1] = clone(value.evidences[0]);
  const out = validateEvidenceBatch(value.evidences, value.context);
  assert(out.errors.some((e) => e.code === "DUPLICATE_SNAPSHOT_ID"));
  assert.equal(out.rejectedEvidenceCount, 1);
});

test("blocked evidence is excluded from byte total", () => {
  const evidence = fixture("blocked", "structured_evidence"), candidates = fixture("blocked", "candidate_sources");
  const out = validateEvidenceBatch(evidence, {taskId:evidence[0].taskId, executionId:evidence[0].executionId, candidates});
  assert.equal(out.valid, true); assert.equal(out.totalVisibleTextBytes, 0);
});

test("batch and nested inputs are not mutated", () => {
  const value = batch(["immutable"]), before = JSON.stringify(value);
  validateEvidenceBatch(value.evidences, value.context);
  assert.equal(JSON.stringify(value), before);
});

test("batch rejects candidate context above three", () => {
  const value=batch(["a"]); value.context.candidates.push(...Array(3).fill(clone(value.context.candidates[0])));
  const out=validateEvidenceBatch(value.evidences,value.context);
  assert(out.errors.some((e)=>e.code==="EVIDENCE_CANDIDATE_LIMIT_EXCEEDED"));
});
