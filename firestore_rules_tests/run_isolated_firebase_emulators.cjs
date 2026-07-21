/* eslint-disable max-len */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");

const repo = path.resolve(__dirname, "..");
const modes = Object.freeze({
  "rst-1c": {projectId: "demo-markakalkan-rst-1c", only: "firestore",
    script: path.join(repo, "functions", "shared_risk", "promotion", "v1",
        "promotion_emulator.test.js")},
  "rst-1a": {projectId: "demo-markakalkan-rst-1a", only: "firestore",
    script: path.join(repo, "functions", "risk_operations", "v1",
        "risk_operations_emulator.test.js")},
  "rst-0l": {projectId: "demo-markakalkan-rst-0l",
    only: "auth,firestore,functions:provisionInternalTenantBrandPilot",
    script: path.join(repo, "firestore_rules_tests",
        "internal_provisioning_r2_suite.mjs")},
  "rst-0k": {projectId: "demo-markakalkan-rst-0k", only: "firestore",
    script: path.join(repo, "functions", "tenant_management",
        "internal_provisioning", "v1", "provisioning_emulator.test.js")},
  "rst-0j": {projectId: "demo-markakalkan-rst-0j", only: "firestore",
    script: path.join(repo, "functions", "shared_risk", "monitoring", "v1",
        "monitoring_callable_emulator.test.js")},
  "rst-0i": {projectId: "demo-markakalkan-rst-0i", only: "firestore",
    script: path.join(repo, "functions", "shared_risk", "monitoring", "v1",
        "monitoring_emulator.test.js")},
  "rst-0h": {projectId: "demo-markakalkan-rst-0h", only: "firestore",
    script: path.join(repo, "functions", "shared_risk", "persistence", "v1",
        "persistence_emulator.test.js")},
  rules: {projectId: "demo-markakalkan-rules", only: "firestore",
    script: path.join(repo, "firestore_rules_tests", "run_rules_suite.mjs")},
});
const modeName = process.argv[2] || "rst-0l";
const mode = modes[modeName];
assert.ok(mode, "unknown isolated emulator mode");
const {projectId} = mode;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "mk-rst-0l-r2-"));
const originalHome = os.homedir();
const originalAppData = process.env.APPDATA || "";
const firebaseCli = path.join(originalAppData, "npm", "node_modules",
    "firebase-tools", "lib", "bin", "firebase.js");
const cacheSource = path.join(originalHome, ".cache", "firebase", "emulators");
const cacheTarget = path.join(profile, ".cache", "firebase", "emulators");
const forbiddenEnvironment = ["FIREBASE_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS",
  "GOOGLE_CLOUD_QUOTA_PROJECT", "CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE",
  "CLOUDSDK_CORE_ACCOUNT", "CLOUDSDK_CORE_PROJECT"];

function run(args, env) {
  return spawnSync(process.execPath, [firebaseCli, ...args], {cwd: profile, env,
    encoding: "utf8", maxBuffer: 64 * 1024 * 1024, windowsHide: true});
}

try {
  assert.equal(fs.existsSync(firebaseCli), true, "Firebase CLI entrypoint missing");
  assert.equal(fs.existsSync(cacheSource), true, "emulator cache missing");
  fs.mkdirSync(cacheTarget, {recursive: true});
  fs.cpSync(cacheSource, cacheTarget, {recursive: true});
  for (const name of ["appdata", "localappdata", "gcloud", "xdg"]) {
    fs.mkdirSync(path.join(profile, name), {recursive: true});
  }
  const safePath = [path.dirname(process.execPath),
    process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, "bin") : null,
    path.join(process.env.SystemRoot || "C:\\Windows", "System32"),
    process.env.SystemRoot || "C:\\Windows"].filter(Boolean).join(path.delimiter);
  const env = {HOME: profile, USERPROFILE: profile,
    APPDATA: path.join(profile, "appdata"),
    LOCALAPPDATA: path.join(profile, "localappdata"),
    XDG_CONFIG_HOME: path.join(profile, "xdg"),
    CLOUDSDK_CONFIG: path.join(profile, "gcloud"),
    TEMP: profile, TMP: profile, PATH: safePath,
    SystemRoot: process.env.SystemRoot || "C:\\Windows",
    ComSpec: process.env.ComSpec || "C:\\Windows\\System32\\cmd.exe",
    PATHEXT: process.env.PATHEXT || ".COM;.EXE;.BAT;.CMD",
    JAVA_HOME: process.env.JAVA_HOME || "",
    GCLOUD_PROJECT: projectId, GOOGLE_CLOUD_PROJECT: projectId,
    FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
    FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
    FUNCTIONS_EMULATOR_HOST: "127.0.0.1:5001",
    FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:1",
    ADMIN_ENTRY_GATE_CODE: "isolated-emulator-placeholder",
    N8N_DIGITAL_DETECTIVE_WEBHOOK_TOKEN: "isolated-emulator-placeholder",
    N8N_DIGITAL_DETECTIVE_RESULT_TOKEN: "isolated-emulator-placeholder"};
  for (const name of forbiddenEnvironment) delete env[name];
  for (const name of forbiddenEnvironment) assert.equal(env[name], undefined);
  assert.equal(fs.readdirSync(env.CLOUDSDK_CONFIG).length, 0);
  assert.equal(fs.existsSync(path.join(env.APPDATA, "configstore",
      "firebase-tools.json")), false);

  const login = run(["login:list", "--json"], env);
  const loginOutput = `${login.stdout || ""}\n${login.stderr || ""}`;
  assert.equal(login.status, 0);
  assert.doesNotMatch(loginOutput, /@[a-z0-9.-]+/i);
  const loginJson = JSON.parse(login.stdout);
  assert.deepEqual(loginJson, {status: "success"});

  const command = `"${process.execPath}" "${mode.script}"`;
  const result = run(["emulators:exec", "--debug", "--only",
    mode.only,
    "--project", projectId, "--config", path.join(repo, "firebase.json"),
    command], env);
  const output = `${result.stdout || ""}\n${result.stderr || ""}`;
  if (result.status !== 0) process.stderr.write(output);
  assert.equal(result.status, 0, "isolated emulator suite failed");
  assert.match(output, /Detected demo project ID/);
  if (modeName === "rst-1a") {
    assert.match(output, /read-only application harness: PASS; writes 0/);
  } else if (modeName === "rst-0l") {
    assert.match(output, /provisionInternalTenantBrandPilot/);
    assert.match(output, /Accepted request POST \/demo-markakalkan-rst-0l\/europe-west3\/provisionInternalTenantBrandPilot/);
    assert.match(output, /negative App Check callable protocol: PASS \(3\/3\)/);
    assert.match(output, /application harness: PASS; writes 0\/0\/0\/0\/0/);
    assert.doesNotMatch(output, /internal_tenant_brand_provisioning_application_invoked/,
        "negative protocol request reached application handler");
  } else {
    assert.match(output, /PASS|pass [1-9]|tests [1-9]/i);
  }
  for (const pattern of [/Setting GAC to/i,
    /application_default_credentials\.json/i,
    /markakalkan-app/i,
    /access[_ -]?token/i,
    /refresh[_ -]?token/i,
    /BEGIN PRIVATE KEY/i]) assert.doesNotMatch(output, pattern);
  assert.equal(fs.existsSync(path.join(env.APPDATA, "configstore",
      "firebase-tools.json")), false);
  assert.equal(fs.readdirSync(env.CLOUDSDK_CONFIG).length, 0);
  console.log(`MK-RST-0L-R2 credential-isolated emulator ${modeName}: PASS`);
} finally {
  fs.rmSync(profile, {recursive: true, force: true});
  assert.equal(fs.existsSync(profile), false);
}
