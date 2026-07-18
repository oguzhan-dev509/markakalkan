"use strict";
const test = require("node:test"); const assert = require("node:assert/strict");
const {clone, fixture, validators} = require("./test_helpers");
const {validateCandidateSource} = require("../validators/validate_candidate_source");

test("candidate schema accepts fixture", () => { const {candidate} = validators(); assert.equal(candidate(fixture("no_signal", "candidate_sources")[0]), true, JSON.stringify(candidate.errors)); });
test("candidate schema rejects HTTP and additional fields", () => { const {candidate} = validators(); const value = clone(fixture("no_signal", "candidate_sources")[0]); value.sourceUrl = "http://example.com/x"; value.secret = "forbidden"; assert.equal(candidate(value), false); });
test("candidate schema rejects invalid date", () => { const {candidate} = validators(); const value = clone(fixture("no_signal", "candidate_sources")[0]); value.discoveredAt = "not-a-date"; assert.equal(candidate(value), false); });
test("semantic candidate detects scope mismatch", () => { const value = fixture("no_signal", "candidate_sources")[0]; const out = validateCandidateSource(value, {taskId: "other", executionId: value.executionId}); assert.equal(out.valid, false); assert(out.errors.some((e) => e.code === "TASK_ID_MISMATCH" && e.path === "taskId")); });
