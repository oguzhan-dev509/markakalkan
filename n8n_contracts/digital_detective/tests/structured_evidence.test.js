"use strict";
const test = require("node:test"); const assert = require("node:assert/strict");
const {clone, fixture, validators} = require("./test_helpers");
const {validateStructuredEvidence} = require("../validators/validate_structured_evidence");
function context(scenario) { const candidates = fixture(scenario, "candidate_sources"); return {taskId: "TEST_FIXTURE_TASK_001", executionId: "TEST_FIXTURE_EXECUTION_001", candidates}; }

test("acquired and blocked fixtures validate", () => { const {evidence} = validators(); for (const scenario of ["no_signal", "synthetic_signal", "blocked"]) for (const value of fixture(scenario, "structured_evidence")) assert.equal(evidence(value), true, JSON.stringify(evidence.errors)); });
test("acquired empty text is rejected", () => { const {evidence} = validators(); const value = clone(fixture("no_signal", "structured_evidence")[0]); value.visibleText = ""; assert.equal(evidence(value), false); });
test("failed evidence with hash is rejected", () => { const {evidence} = validators(); const value = clone(fixture("blocked", "structured_evidence")[0]); value.acquisitionStatus = "failed"; value.contentHash = "a".repeat(64); assert.equal(evidence(value), false); });
test("semantic evidence rejects cross-execution and bad hash", () => { const value = clone(fixture("no_signal", "structured_evidence")[0]); value.executionId = "other"; value.contentHash = "a".repeat(64); const result = validateStructuredEvidence(value, context("no_signal")); assert.equal(result.valid, false); assert(result.errors.some((e) => e.code === "EVIDENCE_SCOPE_MISMATCH")); assert(result.errors.some((e) => e.code === "CONTENT_HASH_MISMATCH")); });
test("visible text character and byte limits are enforced", () => { const ctx = context("no_signal"); let value = clone(fixture("no_signal", "structured_evidence")[0]); value.visibleText = "a".repeat(50001); assert(validateStructuredEvidence(value, ctx).errors.some((e) => e.code === "SCHEMA_MAXLENGTH")); value = clone(fixture("no_signal", "structured_evidence")[0]); value.visibleText = "😀".repeat(33000); assert(validateStructuredEvidence(value, ctx).errors.some((e) => e.code === "VISIBLE_TEXT_BYTE_LIMIT")); });
