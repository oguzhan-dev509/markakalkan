"use strict";

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const vm = require("node:vm");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");
const standaloneCode = require("ajv/dist/standalone").default;
const esbuild = require("esbuild");

const ROOT = path.resolve(__dirname, "..");
const SOURCE_CONTRACT_COMMIT = "6362b6e0558d25e04da7cf5b366464f0538827fe";
const VERSION = "ddt-n8n-runtime-v1";
const WORKFLOW_NAME = "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json";
const SCHEMA_NAMES = ["acquisition_result", "candidate_source",
  "digital_field_scanner_result", "structured_evidence"];
const SCENARIOS = ["no_signal", "synthetic_signal", "blocked"];
const PUBLISH_ORDER = ["bundle", "workflow", "manifest"];

class ArtifactBuildError extends Error {
  constructor(stage) {
    super(`ARTIFACT_BUILD_FAILED:${stage}`);
    this.name = "ArtifactBuildError";
    this.code = "ARTIFACT_BUILD_FAILED";
    this.stage = stage;
  }
}

function compareStrings(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function createFileSystemAdapter({faultAt = null} = {}) {
  return {
    checkpoint(stage) {
      if (stage === faultAt) throw new ArtifactBuildError(stage);
    },
    existsSync: fs.existsSync,
    mkdirSync: fs.mkdirSync,
    readFileSync: fs.readFileSync,
    readdirSync: fs.readdirSync,
    writeFileSync: fs.writeFileSync,
    copyFileSync: fs.copyFileSync,
    rmSync: fs.rmSync,
  };
}

function readJson(location, fileSystem) {
  return JSON.parse(fileSystem.readFileSync(location, "utf8"));
}

function sortedFiles(directory, predicate, fileSystem) {
  const output = [];
  function visit(current) {
    const entries = fileSystem.readdirSync(current, {withFileTypes: true})
        .sort((a, b) => compareStrings(a.name, b.name));
    for (const entry of entries) {
      const location = path.join(current, entry.name);
      if (entry.isDirectory()) visit(location);
      else if (predicate(location)) output.push(location);
    }
  }
  visit(directory);
  return output;
}

function hashMap(directory, predicate, fileSystem) {
  return Object.fromEntries(sortedFiles(directory, predicate, fileSystem)
      .map((location) => [
        path.relative(ROOT, location).replace(/\\/g, "/"),
        sha256(fileSystem.readFileSync(location)),
      ]).sort(([a], [b]) => compareStrings(a, b)));
}

function safeHelpersSource() {
  return `
function safePath(error) {
  const base = String(error.instancePath || "").replace(/^\\//, "").replace(/\\//g, ".");
  if (error.keyword === "required") return [base, error.params && error.params.missingProperty].filter(Boolean).join(".");
  if (error.keyword === "additionalProperties") return [base, error.params && error.params.additionalProperty].filter(Boolean).join(".");
  return base || "$";
}
function safeMessage(keyword) {
  const messages = {required:"Zorunlu alan eksik.",type:"Alan tipi geçersiz.",additionalProperties:"Beklenmeyen alan.",format:"Alan biçimi geçersiz.",pattern:"Alan biçimi geçersiz.",const:"Alan değeri geçersiz.",enum:"Alan değeri izin verilen değerlerden biri değil.",minLength:"Alan çok kısa.",maxLength:"Alan çok uzun.",minItems:"Dizi yeterli öğe içermiyor.",maxItems:"Dizi çok fazla öğe içeriyor.",uniqueItems:"Dizi yinelenen öğe içeriyor.",minimum:"Sayısal değer alt sınırın altında.",maximum:"Sayısal değer üst sınırın üzerinde.",oneOf:"Alan sözleşmeyle eşleşmiyor.",if:"Koşullu sözleşme sağlanmıyor."};
  return messages[keyword] || "Schema doğrulaması başarısız.";
}`;
}

function generateStandaloneSchemas(tempDirectory, fileSystem) {
  const ajv = new Ajv2020({allErrors: true, strict: true, code: {source: true}});
  addFormats(ajv);
  for (const name of SCHEMA_NAMES) {
    ajv.addSchema(readJson(path.join(ROOT, "schemas", `${name}.schema.json`),
        fileSystem));
  }
  const exportsMap = Object.fromEntries(SCHEMA_NAMES.map((name) =>
    [name, `${name}.schema.json`]));
  fileSystem.checkpoint("temp:standalone");
  fileSystem.writeFileSync(path.join(tempDirectory, "standalone_validators.js"),
      standaloneCode(ajv, exportsMap));
  const adapter = `"use strict";
const validators = require("./standalone_validators");
const {issue, result} = require("ddt-validator-result");
${safeHelpersSource()}
function validateSchema(schemaName, value) {
  const validate = validators[schemaName];
  if (typeof validate !== "function") return result({errors:[issue("SCHEMA_NAME_UNSUPPORTED","$","Schema adı desteklenmiyor.")]});
  try {
    if (validate(value)) return result();
    return result({errors:(validate.errors || []).map((error) => issue("SCHEMA_" + String(error.keyword).toUpperCase(), safePath(error), safeMessage(error.keyword))) });
  } catch (_) {
    return result({errors:[issue("SCHEMA_VALIDATION_EXCEPTION","$","Schema doğrulaması güvenli biçimde tamamlanamadı.")]});
  }
}
module.exports = {validateSchema};\n`;
  fileSystem.writeFileSync(path.join(tempDirectory, "schema_engine.js"), adapter);
}

function fixtureCatalogSource(fileSystem) {
  const catalog = {};
  for (const scenario of SCENARIOS) {
    const directory = path.join(ROOT, "fixtures", scenario);
    catalog[scenario] = {
      acquisitionResult: readJson(path.join(directory, "acquisition_result.json"),
          fileSystem),
      candidates: readJson(path.join(directory, "candidate_sources.json"),
          fileSystem),
      evidences: readJson(path.join(directory, "structured_evidence.json"),
          fileSystem),
      scannerResult: readJson(path.join(directory, "scanner_result.json"),
          fileSystem),
      productionCallback: false,
    };
  }
  return `module.exports = ${JSON.stringify(catalog)};\n`;
}

function aliasPlugin(tempDirectory) {
  const schemaSource = path.resolve(ROOT, "validators", "schema_engine.js");
  return {name: "ddt-runtime-aliases", setup(build) {
    build.onResolve({filter: /^node:crypto$/}, () =>
      ({path: path.join(ROOT, "build", "crypto_shim.js")}));
    build.onResolve({filter: /schema_engine$/}, (args) => {
      const resolved = path.resolve(args.resolveDir,
          args.path + (path.extname(args.path) ? "" : ".js"));
      return resolved === schemaSource ?
        {path: path.join(tempDirectory, "schema_engine.js")} : null;
    });
    build.onResolve({filter: /^ddt-fixture-catalog$/}, () =>
      ({path: path.join(tempDirectory, "fixture_catalog.js")}));
    build.onResolve({filter: /^ddt-validator-result$/}, () =>
      ({path: path.join(ROOT, "validators", "validator_result.js")}));
    build.onResolve({filter: /^ajv\/dist\/runtime\/ucs2length$/}, () =>
      ({path: require.resolve("ajv/dist/runtime/ucs2length", {paths: [ROOT]})}));
    build.onResolve({filter: /^ajv-formats\/dist\/formats$/}, () =>
      ({path: require.resolve("ajv-formats/dist/formats", {paths: [ROOT]})}));
  }};
}

function workflowObject(bundle) {
  const prepareCode = `const inputItems = $input.all();
void inputItems;
return ["no_signal", "synthetic_signal", "blocked"].map((scenario) => ({json: {scenario}}));`;
  const harnessCode = `${bundle}
const inputItems = $input.all();
return inputItems.map((item) => {
  try {
    const scenario = typeof item?.json?.scenario === "string" ? item.json.scenario : "";
    const result = MarkaKalkanDdtRuntime.runFixtureScenario(scenario);
    return {json: {scenario, result}};
  } catch (_) {
    return {json: {scenario: "", result: {valid: false, errorCode: "FIXTURE_ITEM_EXCEPTION"}}};
  }
});`;
  const summaryCode = `const inputItems = $input.all();
return inputItems.map((item) => {
  try {
    const scenario = typeof item?.json?.scenario === "string" ? item.json.scenario : "";
    const result = item?.json?.result;
    if (!result || typeof result !== "object") throw new TypeError("invalid result");
    return {json: {
      scenario,
      valid: result.valid === true,
      guard: typeof result.scannerInvocation?.reason === "string" ? result.scannerInvocation.reason : "FIXTURE_RESULT_INVALID",
      findingCount: Number.isSafeInteger(result.findingCount) ? result.findingCount : 0,
    }};
  } catch (_) {
    return {json: {scenario: "", valid: false, guard: "FIXTURE_RESULT_INVALID", findingCount: 0}};
  }
});`;
  const guardCode = `const inputItems = $input.all();
return inputItems.map((item) => ({json: {
  scenario: typeof item?.json?.scenario === "string" ? item.json.scenario : "",
  valid: item?.json?.valid === true,
  guard: typeof item?.json?.guard === "string" ? item.json.guard : "FIXTURE_RESULT_INVALID",
  findingCount: Number.isSafeInteger(item?.json?.findingCount) ? item.json.findingCount : 0,
  productionAllowed: false,
  guardReason: "FIXTURE_HARNESS_HARD_FALSE",
}}));`;
  const mode = "runOnceForAllItems";
  const nodes = [
    {parameters: {}, id: "ddt-fixture-manual-trigger-v1", name: "Manual Trigger", type: "n8n-nodes-base.manualTrigger", typeVersion: 1, position: [0, 0]},
    {parameters: {mode, jsCode: prepareCode}, id: "ddt-fixture-prepare-v1", name: "Fixture Senaryolarını Hazırla", type: "n8n-nodes-base.code", typeVersion: 2, position: [220, 0]},
    {parameters: {mode, jsCode: harnessCode}, id: "ddt-fixture-runtime-v1", name: "Contract Runtime Harness", type: "n8n-nodes-base.code", typeVersion: 2, position: [460, 0]},
    {parameters: {mode, jsCode: summaryCode}, id: "ddt-fixture-summary-v1", name: "Sonuçları Özetle", type: "n8n-nodes-base.code", typeVersion: 2, position: [700, 0]},
    {parameters: {mode, jsCode: guardCode}, id: "ddt-fixture-production-guard-v1", name: "Production Guard — Hard False", type: "n8n-nodes-base.code", typeVersion: 2, position: [940, 0]},
    {parameters: {}, id: "ddt-fixture-callback-disabled-v1", name: "Callback Placeholder — Disabled", type: "n8n-nodes-base.noOp", typeVersion: 1, position: [1180, 0], disabled: true},
  ];
  const connections = {};
  for (let index = 0; index < nodes.length - 1; index++) {
    connections[nodes[index].name] = {main: [[{node: nodes[index + 1].name,
      type: "main", index: 0}]]};
  }
  return {
    name: "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1",
    nodes,
    connections,
    active: false,
    settings: {executionOrder: "v1"},
    pinData: {},
  };
}

function validateCandidates(contents) {
  new vm.Script(contents.bundle, {filename: "n8n_contract_runtime.js"});
  const manifest = JSON.parse(contents.manifest);
  const workflow = JSON.parse(contents.workflow);
  const bytes = Buffer.byteLength(contents.bundle, "utf8");
  if (manifest.bundleSha256 !== sha256(Buffer.from(contents.bundle, "utf8")) ||
      manifest.bundleBytes !== bytes) throw new ArtifactBuildError("validate:manifest");
  if (workflow.active !== false || Object.keys(workflow.pinData).length !== 0 ||
      workflow.nodes.length !== 6 || Object.keys(workflow.connections).length !== 5 ||
      Object.prototype.hasOwnProperty.call(workflow, "versionId")) {
    throw new ArtifactBuildError("validate:workflow");
  }
  const codeNodes = workflow.nodes.filter((node) =>
    node.type === "n8n-nodes-base.code");
  if (codeNodes.length !== 4 || codeNodes.some((node) =>
    node.parameters.mode !== "runOnceForAllItems" ||
    !node.parameters.jsCode.includes("$input.all()") ||
    /\bitems\s*\.\s*(?:map|forEach|filter|reduce)\s*\(/.test(
        node.parameters.jsCode))) {
    throw new ArtifactBuildError("validate:code-nodes");
  }
}

function artifactPaths(outputRoot, transactionRoot) {
  return {
    final: {
      bundle: path.join(outputRoot, "generated", "n8n_contract_runtime.js"),
      manifest: path.join(outputRoot, "generated", "n8n_contract_runtime.manifest.json"),
      workflow: path.join(outputRoot, "workflows", WORKFLOW_NAME),
    },
    candidate: {
      bundle: path.join(transactionRoot, "candidate", "n8n_contract_runtime.js"),
      manifest: path.join(transactionRoot, "candidate", "n8n_contract_runtime.manifest.json"),
      workflow: path.join(transactionRoot, "candidate", WORKFLOW_NAME),
    },
    backup: {
      bundle: path.join(transactionRoot, "backup", "n8n_contract_runtime.js"),
      manifest: path.join(transactionRoot, "backup", "n8n_contract_runtime.manifest.json"),
      workflow: path.join(transactionRoot, "backup", WORKFLOW_NAME),
    },
  };
}

function publishTransaction(paths, fileSystem) {
  const existed = {};
  fileSystem.mkdirSync(path.dirname(paths.backup.bundle), {recursive: true});
  for (const name of PUBLISH_ORDER) {
    existed[name] = fileSystem.existsSync(paths.final[name]);
    if (existed[name]) fileSystem.copyFileSync(paths.final[name], paths.backup[name]);
  }
  try {
    for (const name of PUBLISH_ORDER) {
      fileSystem.checkpoint(`publish:${name}`);
      fileSystem.mkdirSync(path.dirname(paths.final[name]), {recursive: true});
      fileSystem.copyFileSync(paths.candidate[name], paths.final[name]);
    }
  } catch (error) {
    for (const name of PUBLISH_ORDER) {
      if (existed[name] && fileSystem.existsSync(paths.backup[name])) {
        fileSystem.copyFileSync(paths.backup[name], paths.final[name]);
      } else if (!existed[name]) {
        fileSystem.rmSync(paths.final[name], {force: true});
      }
    }
    throw error;
  }
}

async function generateArtifacts({outputRoot = ROOT, publish = true,
  fileSystem = createFileSystemAdapter()} = {}) {
  if (!path.isAbsolute(outputRoot)) throw new ArtifactBuildError("output-root");
  const resolvedOutput = path.resolve(outputRoot);
  const transactionRoot = path.join(resolvedOutput, ".ddt-runtime-transaction");
  const tempDirectory = path.join(transactionRoot, "build");
  const paths = artifactPaths(resolvedOutput, transactionRoot);
  fileSystem.rmSync(transactionRoot, {recursive: true, force: true});
  fileSystem.mkdirSync(tempDirectory, {recursive: true});
  fileSystem.mkdirSync(path.dirname(paths.candidate.bundle), {recursive: true});
  try {
    generateStandaloneSchemas(tempDirectory, fileSystem);
    fileSystem.writeFileSync(path.join(tempDirectory, "fixture_catalog.js"),
        fixtureCatalogSource(fileSystem));
    const build = await esbuild.build({
      entryPoints: [path.join(ROOT, "runtime", "n8n_contract_runtime_entry.js")],
      bundle: true,
      write: false,
      format: "iife",
      globalName: "MarkaKalkanDdtRuntime",
      platform: "neutral",
      target: "es2022",
      minify: false,
      sourcemap: false,
      legalComments: "none",
      plugins: [aliasPlugin(tempDirectory)],
      charset: "utf8",
    });
    const normalizedTemp = tempDirectory.replace(/\\/g, "/");
    const relativeTemp = path.relative(ROOT, tempDirectory).replace(/\\/g, "/");
    const bundle = build.outputFiles[0].text.replace(/\r\n/g, "\n")
        .split(normalizedTemp).join(".build-tmp")
        .split(relativeTemp).join(".build-tmp")
        .replace(/module\.exports/g, 'module["exports"]')
        .replace(/__require/g, "__loadBundledModule")
        .replace(/require\(/g, "bundledModule(");
    const manifestObject = {
      artifactVersion: VERSION,
      generatedBy: "generate_n8n_runtime.js",
      sourceContractCommit: SOURCE_CONTRACT_COMMIT,
      sourceContractCommitPolicy: "Contract source baseline used to generate this runtime; not the future artifact-containing commit.",
      schemaHashes: hashMap(path.join(ROOT, "schemas"),
          (file) => file.endsWith(".json"), fileSystem),
      validatorHashes: hashMap(path.join(ROOT, "validators"),
          (file) => file.endsWith(".js"), fileSystem),
      fixtureHashes: hashMap(path.join(ROOT, "fixtures"),
          (file) => file.endsWith(".json"), fileSystem),
      runtimeSourceHashes: hashMap(path.join(ROOT, "runtime"),
          (file) => file.endsWith(".js"), fileSystem),
      buildSourceHashes: hashMap(path.join(ROOT, "build"),
          (file) => file.endsWith(".js"), fileSystem),
      testProvenanceHashes: hashMap(path.join(ROOT, "tests", "helpers"),
          (file) => file.endsWith(".js"), fileSystem),
      bundleSha256: sha256(Buffer.from(bundle, "utf8")),
      bundleBytes: Buffer.byteLength(bundle, "utf8"),
      generatedAtPolicy: "deterministic-no-wall-clock",
      externalRuntimeDependencies: [],
      containsCredentials: false,
      containsNetworkCalls: false,
    };
    const contents = {
      bundle,
      manifest: `${JSON.stringify(manifestObject, null, 2)}\n`,
      workflow: `${JSON.stringify(workflowObject(bundle), null, 2)}\n`,
    };
    for (const name of ["bundle", "manifest", "workflow"]) {
      fileSystem.checkpoint(`temp:${name}`);
      fileSystem.writeFileSync(paths.candidate[name], contents[name], "utf8");
    }
    validateCandidates(contents);
    if (publish) publishTransaction(paths, fileSystem);
    return {
      bundleSha256: manifestObject.bundleSha256,
      bundleBytes: manifestObject.bundleBytes,
      outputRoot: resolvedOutput,
    };
  } catch (error) {
    if (error instanceof ArtifactBuildError) throw error;
    throw new ArtifactBuildError("generation");
  } finally {
    fileSystem.rmSync(transactionRoot, {recursive: true, force: true});
  }
}

async function main() {
  const result = await generateArtifacts();
  process.stdout.write(`${JSON.stringify({bundleSha256: result.bundleSha256,
    bundleBytes: result.bundleBytes})}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    const code = error instanceof ArtifactBuildError ? error.message :
      "ARTIFACT_BUILD_FAILED:generation";
    process.stderr.write(`${code}\n`);
    process.exitCode = 1;
  });
}

module.exports = {ArtifactBuildError, compareStrings, createFileSystemAdapter,
  generateArtifacts, workflowObject};
