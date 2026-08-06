"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  DEFAULT_OUTPUT,
  parseArgs,
  workflowOptions,
} = require("../tools/create_public_lite_gateway_workflow");
const {
  ACQUISITION_WORKFLOW_NAME,
  buildAcquisitionWorkflow,
  buildWorkflow,
  serializeWorkflow,
  writeAcquisitionWorkflow,
  writeWorkflow,
} = require("../src/workflow_factory");

test("generator default output is package workflow path", () => {
  assert.match(
    DEFAULT_OUTPUT.replaceAll("\\", "/"),
    /n8n_contracts\/public_lite\/workflows\/MarkaKalkan Public Lite Risk Scan Gateway - V1\.json$/,
  );
});

test("generator argument parser accepts check", () => {
  const options = parseArgs(["--check"]);
  assert.equal(options.check, true);
  assert.equal(options.output, DEFAULT_OUTPUT);
});

test("generator argument parser accepts output", () => {
  const options = parseArgs(["--output", "example.json"]);
  assert.equal(options.output, "example.json");
  assert.equal(options.check, false);
});

test("generator argument parser accepts credential metadata", () => {
  const options = parseArgs([
    "--webhook-credential-id",
    "webhook-id",
    "--webhook-credential-name",
    "Webhook Credential",
    "--result-credential-id",
    "result-id",
    "--result-credential-name",
    "Result Credential",
  ]);
  assert.equal(options.webhookCredentialId, "webhook-id");
  assert.equal(options.resultCredentialName, "Result Credential");
});

test("generator rejects unsupported argument", () => {
  assert.throws(
    () => parseArgs(["--secret-value", "forbidden"]),
    /unsupported argument/,
  );
});

test("generator rejects missing argument value", () => {
  assert.throws(
    () => parseArgs(["--output"]),
    /requires a value/,
  );
});

test("workflow options contain no unrelated parser state", () => {
  const options = workflowOptions({
    output: "ignored.json",
    check: true,
    webhookCredentialId: "webhook-id",
    webhookCredentialName: "Webhook Credential",
    resultCredentialId: "result-id",
    resultCredentialName: "Result Credential",
  });
  assert.deepEqual(options, {
    webhookCredentialId: "webhook-id",
    webhookCredentialName: "Webhook Credential",
    resultCredentialId: "result-id",
    resultCredentialName: "Result Credential",
  });
});

test("writeWorkflow creates deterministic import JSON", () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "public-lite-workflow-"),
  );
  const output = path.join(directory, "workflow.json");
  try {
    const workflow = writeWorkflow(output);
    const actual = fs.readFileSync(output, "utf8");
    assert.equal(actual, serializeWorkflow(workflow));
    assert.deepEqual(JSON.parse(actual), buildWorkflow());
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

test("parent generator binds ingress and excludes legacy result metadata", () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "public-lite-workflow-bound-"),
  );
  const output = path.join(directory, "workflow.json");
  try {
    writeWorkflow(output, {
      webhookCredentialId: "webhook-id",
      webhookCredentialName: "Webhook Credential",
      resultCredentialId: "legacy-result-id",
      resultCredentialName: "Legacy Result Credential",
    });
    const actual = fs.readFileSync(output, "utf8");
    assert.match(actual, /"id": "webhook-id"/);
    assert.doesNotMatch(actual, /legacy-result-id/u);
    assert.doesNotMatch(actual, /secret-value/u);
    assert.equal(JSON.parse(actual).active, false);
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

test("committed generated workflow equals factory output", () => {
  const actual = fs.readFileSync(DEFAULT_OUTPUT, "utf8");
  assert.equal(actual, serializeWorkflow(buildWorkflow()));
});


test("writeAcquisitionWorkflow creates deterministic child import JSON", () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "public-lite-acquisition-workflow-"),
  );
  const output = path.join(directory, "acquisition.json");
  try {
    const workflow = writeAcquisitionWorkflow(output);
    const actual = fs.readFileSync(output, "utf8");
    assert.equal(actual, serializeWorkflow(workflow));
    assert.deepEqual(
      JSON.parse(actual),
      buildAcquisitionWorkflow(),
    );
    assert.equal(workflow.name, ACQUISITION_WORKFLOW_NAME);
    assert.equal(workflow.active, false);
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

test("committed acquisition workflow equals factory output", () => {
  const output = path.join(
    path.dirname(DEFAULT_OUTPUT),
    "MarkaKalkan Public Lite Risk Scan Acquisition Worker - V1.json",
  );
  const actual = fs.readFileSync(output, "utf8");
  assert.equal(
    actual,
    serializeWorkflow(buildAcquisitionWorkflow()),
  );
});
