#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {
  serializeWorkflow,
  writeWorkflow,
} = require("../src/workflow_factory");

const PACKAGE_ROOT = path.resolve(__dirname, "..");
const DEFAULT_OUTPUT = path.join(
  PACKAGE_ROOT,
  "workflows",
  "MarkaKalkan Public Lite Risk Scan Gateway - V1.json",
);

function parseArgs(argv) {
  const options = {
    output: DEFAULT_OUTPUT,
    check: false,
    webhookCredentialId: "",
    webhookCredentialName: "",
    resultCredentialId: "",
    resultCredentialName: "",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--check") {
      options.check = true;
      continue;
    }
    const valueOptions = {
      "--output": "output",
      "--webhook-credential-id": "webhookCredentialId",
      "--webhook-credential-name": "webhookCredentialName",
      "--result-credential-id": "resultCredentialId",
      "--result-credential-name": "resultCredentialName",
    };
    const key = valueOptions[argument];
    if (!key) {
      throw new TypeError(`unsupported argument: ${argument}`);
    }
    index += 1;
    if (index >= argv.length || !argv[index]) {
      throw new TypeError(`${argument} requires a value`);
    }
    options[key] = argv[index];
  }
  return options;
}

function workflowOptions(options) {
  return {
    webhookCredentialId: options.webhookCredentialId,
    webhookCredentialName: options.webhookCredentialName,
    resultCredentialId: options.resultCredentialId,
    resultCredentialName: options.resultCredentialName,
  };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.check) {
    if (!fs.existsSync(options.output)) {
      throw new Error(`workflow output is missing: ${options.output}`);
    }
    const temporary = `${options.output}.check.tmp`;
    try {
      const generated = writeWorkflow(
        temporary,
        workflowOptions(options),
      );
      const expected = serializeWorkflow(generated);
      const actual = fs.readFileSync(options.output, "utf8");
      if (actual !== expected) {
        throw new Error(
          "committed workflow differs from deterministic generator output",
        );
      }
    } finally {
      fs.rmSync(temporary, {force: true});
    }
    process.stdout.write(
      `PUBLIC_LITE_WORKFLOW_GENERATOR_CHECK_PASS=${options.output}\n`,
    );
    return;
  }
  writeWorkflow(options.output, workflowOptions(options));
  process.stdout.write(
    `PUBLIC_LITE_WORKFLOW_GENERATED=${options.output}\n`,
  );
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    process.stderr.write(
      `PUBLIC_LITE_WORKFLOW_GENERATOR_STOP=${error.message}\n`,
    );
    process.exitCode = 1;
  }
}

module.exports = Object.freeze({
  DEFAULT_OUTPUT,
  main,
  parseArgs,
  workflowOptions,
});
