/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const INDEX_PATH = path.resolve(__dirname, "..", "..", "index.js");
const CALLABLE_PATH = path.resolve(__dirname, "callable.js");

const EXPECTED_BINDINGS = Object.freeze([
  Object.freeze({
    exportedName: "createProfessionalServiceRequest",
    builderName: "buildCreateProfessionalServiceRequestCallable",
    aliasName: "phoBuildCreateProfessionalServiceRequestCallable",
  }),
  Object.freeze({
    exportedName: "transitionProfessionalServiceRequest",
    builderName: "buildTransitionProfessionalServiceRequestCallable",
    aliasName: "phoBuildTransitionProfessionalServiceRequestCallable",
  }),
  Object.freeze({
    exportedName: "createProfessionalServiceEngagement",
    builderName: "buildCreateProfessionalServiceEngagementCallable",
    aliasName: "phoBuildCreateProfessionalServiceEngagementCallable",
  }),
  Object.freeze({
    exportedName: "createProfessionalServiceAssignment",
    builderName: "buildCreateProfessionalServiceAssignmentCallable",
    aliasName: "phoBuildCreateProfessionalServiceAssignmentCallable",
  }),
  Object.freeze({
    exportedName: "startProfessionalAgentRun",
    builderName: "buildStartProfessionalAgentRunCallable",
    aliasName: "phoBuildStartProfessionalAgentRunCallable",
  }),
  Object.freeze({
    exportedName: "recordProfessionalAgentOutput",
    builderName: "buildRecordProfessionalAgentOutputCallable",
    aliasName: "phoBuildRecordProfessionalAgentOutputCallable",
  }),
  Object.freeze({
    exportedName: "recordProfessionalAgentReview",
    builderName: "buildRecordProfessionalAgentReviewCallable",
    aliasName: "phoBuildRecordProfessionalAgentReviewCallable",
  }),
  Object.freeze({
    exportedName: "publishProfessionalAgentOutput",
    builderName: "buildPublishProfessionalAgentOutputCallable",
    aliasName: "phoBuildPublishProfessionalAgentOutputCallable",
  }),
]);

const START_MARKER = "// BEGIN PHO-1C-4 CALLABLE EXPORTS";
const END_MARKER = "// END PHO-1C-4 CALLABLE EXPORTS";

function readSource(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function occurrences(source, fragment) {
  return source.split(fragment).length - 1;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function exportBlock(indexSource) {
  const start = indexSource.indexOf(START_MARKER);
  const end = indexSource.indexOf(END_MARKER);
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);
  return indexSource.slice(start, end + END_MARKER.length);
}

function callableNames(callableSource) {
  const match = callableSource.match(
      /const CALLABLE_NAMES = Object\.freeze\(\{([\s\S]*?)\}\);/,
  );
  assert.ok(match);
  return [...match[1].matchAll(/:\s*"([^"]+)"/g)]
      .map((item) => item[1]);
}

test("PHO export markers occur once and remain ordered", () => {
  const source = readSource(INDEX_PATH);
  assert.equal(occurrences(source, START_MARKER), 1);
  assert.equal(occurrences(source, END_MARKER), 1);
  assert.ok(source.indexOf(START_MARKER) < source.indexOf(END_MARKER));
});

test("PHO callable module is imported exactly once", () => {
  const source = readSource(INDEX_PATH);
  assert.equal(
      occurrences(
          source,
          "require(\"./professional_services/v1/callable\")",
      ),
      1,
  );
});

test("all eight builders are imported under PHO aliases", () => {
  const block = exportBlock(readSource(INDEX_PATH));
  for (const binding of EXPECTED_BINDINGS) {
    const pattern = new RegExp(
        `${escapeRegExp(binding.builderName)}:\\s*` +
        escapeRegExp(binding.aliasName),
    );
    assert.match(block, pattern);
  }
});

test("all eight callable exports invoke the matching alias", () => {
  const block = exportBlock(readSource(INDEX_PATH));
  for (const binding of EXPECTED_BINDINGS) {
    const pattern = new RegExp(
        `exports\\.${escapeRegExp(binding.exportedName)}\\s*=\\s*` +
        `${escapeRegExp(binding.aliasName)}\\(\\);`,
    );
    assert.match(block, pattern);
  }
});

test("callable contract names equal index export names", () => {
  const actual = callableNames(readSource(CALLABLE_PATH));
  const expected = EXPECTED_BINDINGS.map((item) => item.exportedName);
  assert.deepEqual(actual, expected);
});

test("PHO aliases and exports are globally unique", () => {
  const source = readSource(INDEX_PATH);
  for (const binding of EXPECTED_BINDINGS) {
    assert.equal(occurrences(source, binding.aliasName), 2);
    assert.equal(
        occurrences(source, `exports.${binding.exportedName}`),
        1,
    );
  }
});

test("PHO builders own their dependencies at export time", () => {
  const block = exportBlock(readSource(INDEX_PATH));
  for (const binding of EXPECTED_BINDINGS) {
    assert.equal(
        occurrences(block, `${binding.aliasName}();`),
        1,
    );
    assert.equal(
        occurrences(block, `${binding.aliasName}({`),
        0,
    );
  }
  assert.equal(/\bdb\b/.test(block), false);
  assert.equal(/\badmin\b/.test(block), false);
});

test("PHO export block is isolated after the MHL export block", () => {
  const source = readSource(INDEX_PATH);
  const mhlEnd = source.indexOf(
      "// END MHL-1B-1D-P4 CALLABLE EXPORTS",
  );
  const phoStart = source.indexOf(START_MARKER);
  assert.notEqual(mhlEnd, -1);
  assert.ok(phoStart > mhlEnd);
});
