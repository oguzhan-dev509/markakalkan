"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const {ArtifactBuildError, compareStrings, createFileSystemAdapter,
  generateArtifacts} = require("../build/generate_n8n_runtime");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_NAME = "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json";
const REAL_PATHS = [
  path.join(ROOT, "generated", "n8n_contract_runtime.js"),
  path.join(ROOT, "generated", "n8n_contract_runtime.manifest.json"),
  path.join(ROOT, "workflows", WORKFLOW_NAME),
];
const hash = (location) => crypto.createHash("sha256")
    .update(fs.readFileSync(location)).digest("hex");
const hashes = (locations) => locations.map(hash);
const outputPaths = (root) => [
  path.join(root, "generated", "n8n_contract_runtime.js"),
  path.join(root, "generated", "n8n_contract_runtime.manifest.json"),
  path.join(root, "workflows", WORKFLOW_NAME),
];

async function withTemp(callback) {
  const location = fs.mkdtempSync(path.join(os.tmpdir(), "ddt-n8n-runtime-"));
  try { return await callback(location); } finally {
    fs.rmSync(location, {recursive: true, force: true});
  }
}

async function assertRollback(stage) {
  await withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    const paths = outputPaths(outputRoot);
    const before = hashes(paths);
    await assert.rejects(
        generateArtifacts({outputRoot,
          fileSystem: createFileSystemAdapter({faultAt: stage})}),
        (error) => error instanceof ArtifactBuildError &&
          error.code === "ARTIFACT_BUILD_FAILED" && error.stage === stage &&
          !error.message.includes(outputRoot));
    assert.deepEqual(hashes(paths), before);
    assert.equal(fs.existsSync(path.join(outputRoot,
        ".ddt-runtime-transaction")), false);
  });
}

test("generator accepts explicit absolute test output root", async () =>
  withTemp(async (outputRoot) => {
    const result = await generateArtifacts({outputRoot});
    assert.equal(result.outputRoot, path.resolve(outputRoot));
    assert.equal(outputPaths(outputRoot).every(fs.existsSync), true);
  }));
test("generator rejects relative output root", async () => {
  await assert.rejects(generateArtifacts({outputRoot: "relative-output"}),
      (error) => error instanceof ArtifactBuildError && error.stage === "output-root");
});
test("two OS-temp generations are byte-for-byte deterministic", async () => {
  await withTemp(async (first) => withTemp(async (second) => {
    await generateArtifacts({outputRoot: first});
    await generateArtifacts({outputRoot: second});
    assert.deepEqual(hashes(outputPaths(first)), hashes(outputPaths(second)));
  }));
});
test("temp bundle write failure preserves old artifacts", async () =>
  assertRollback("temp:bundle"));
test("temp manifest write failure preserves old artifacts", async () =>
  assertRollback("temp:manifest"));
test("temp workflow write failure preserves old artifacts", async () =>
  assertRollback("temp:workflow"));
test("first publish failure rolls back all artifacts", async () =>
  assertRollback("publish:bundle"));
test("second publish failure rolls back all artifacts", async () =>
  assertRollback("publish:workflow"));
test("third publish failure rolls back all artifacts", async () =>
  assertRollback("publish:manifest"));
test("successful publish leaves no transaction directory", async () =>
  withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    assert.equal(fs.existsSync(path.join(outputRoot,
        ".ddt-runtime-transaction")), false);
  }));
test("temp manifest uses sourceContractCommit only", async () =>
  withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    const manifest = JSON.parse(fs.readFileSync(outputPaths(outputRoot)[1], "utf8"));
    assert.equal(manifest.sourceContractCommit,
        "6362b6e0558d25e04da7cf5b366464f0538827fe");
    assert.equal("sourceCommit" in manifest, false);
  }));
test("temp manifest covers runtime and build provenance", async () =>
  withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    const manifest = JSON.parse(fs.readFileSync(outputPaths(outputRoot)[1], "utf8"));
    assert.deepEqual(Object.keys(manifest.runtimeSourceHashes),
        ["runtime/n8n_contract_runtime_entry.js", "runtime/portable_primitives.js"]);
    assert.deepEqual(Object.keys(manifest.buildSourceHashes),
        ["build/crypto_shim.js", "build/generate_n8n_runtime.js"]);
    assert.deepEqual(Object.keys(manifest.testProvenanceHashes),
        ["tests/helpers/isolated_n8n_vm.js"]);
    for (const group of [manifest.runtimeSourceHashes, manifest.buildSourceHashes,
      manifest.testProvenanceHashes]) {
      for (const [relative, expected] of Object.entries(group)) {
        assert.equal(hash(path.join(ROOT, relative)), expected);
      }
    }
  }));
test("temp workflow has import-safe root", async () =>
  withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    const workflow = JSON.parse(fs.readFileSync(outputPaths(outputRoot)[2], "utf8"));
    assert.deepEqual(Object.keys(workflow).sort(),
        ["active", "connections", "name", "nodes", "pinData", "settings"]);
  }));
test("temp bundle hash and bytes match manifest", async () =>
  withTemp(async (outputRoot) => {
    await generateArtifacts({outputRoot});
    const paths = outputPaths(outputRoot);
    const manifest = JSON.parse(fs.readFileSync(paths[1], "utf8"));
    assert.equal(manifest.bundleSha256, hash(paths[0]));
    assert.equal(manifest.bundleBytes, fs.statSync(paths[0]).size);
  }));
test("comparator is locale independent lexical ordering", () => {
  const values = ["z", "A", "a", "ä", "_"].sort(compareStrings);
  assert.deepEqual(values, ["A", "_", "a", "z", "ä"]);
});
test("generator source contains no locale or random ordering", () => {
  const source = fs.readFileSync(path.join(ROOT, "build",
      "generate_n8n_runtime.js"), "utf8");
  assert.doesNotMatch(source, /localeCompare|Math\.random|randomUUID/);
});
test("package engine matches noble minimum", () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
  const lock = JSON.parse(fs.readFileSync(path.join(ROOT, "package-lock.json"), "utf8"));
  assert.equal(pkg.engines.node, ">=20.19.0");
  assert.equal(lock.packages[""].engines.node, ">=20.19.0");
});
test("read-only scripts do not invoke build generator", () => {
  const scripts = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"),
      "utf8")).scripts;
  assert.doesNotMatch(scripts.test, /build:n8n-runtime|generate_n8n_runtime/);
  assert.doesNotMatch(scripts["verify:n8n-runtime"],
      /build:n8n-runtime|generate_n8n_runtime/);
});
test("regeneration script is isolated to transaction tests", () => {
  const scripts = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"),
      "utf8")).scripts;
  assert.equal(scripts["test:n8n-regeneration"],
      "node --test tests/n8n_generator_transaction.test.js");
});
test("temp generation never changes repository artifacts", async () => {
  const before = hashes(REAL_PATHS);
  await withTemp(async (outputRoot) => generateArtifacts({outputRoot}));
  assert.deepEqual(hashes(REAL_PATHS), before);
});
test("fault injection never changes repository artifacts", async () => {
  const before = hashes(REAL_PATHS);
  await assertRollback("publish:workflow");
  assert.deepEqual(hashes(REAL_PATHS), before);
});
