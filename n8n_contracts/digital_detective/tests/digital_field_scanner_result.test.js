"use strict";
const test = require("node:test"); const assert = require("node:assert/strict");
const {clone, fixture, validators} = require("./test_helpers");

test("all scanner fixtures satisfy schema", () => { const {scanner} = validators(); for (const scenario of ["no_signal", "synthetic_signal", "blocked"]) { const value = fixture(scenario, "scanner_result"); assert.equal(scanner(value), true, JSON.stringify(scanner.errors)); } });
test("failed scanner must have empty findings", () => { const {scanner} = validators(); const value = clone(fixture("synthetic_signal", "scanner_result")); value.status = "failed"; assert.equal(scanner(value), false); });
test("confirmed counterfeit enum-like conclusion is rejected", () => { const {scanner} = validators(); const value = clone(fixture("synthetic_signal", "scanner_result")); value.findings[0].automatedConclusion = "confirmed_counterfeit"; assert.equal(scanner(value), false); });
test("task and execution IDs reject slash", () => { const {scanner} = validators(); const value = clone(fixture("no_signal", "scanner_result")); value.taskId = "bad/id"; assert.equal(scanner(value), false); });
