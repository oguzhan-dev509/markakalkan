"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {sha256Hex} = require("./canonical");
const {
  riskScanReportId,
} = require("./identifiers");
const contract = require("./public_lite_contract");
const port = require("./public_lite_firestore_port");
const callable = require("./public_lite_callable");

const secretKey = "k".repeat(48);
const now = new Date("2026-07-29T16:00:00.000Z");
const later = "2026-07-29T16:30:00.000Z";

function clone(value) {
  return structuredClone(value);
}

class FakeDocumentSnapshot {
  constructor(value) {
    this.value = value;
    this.exists = value !== undefined;
  }

  data() {
    return this.exists ? clone(this.value) : undefined;
  }
}

class FakeDocumentReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  collection(name) {
    return new FakeCollectionReference(this.db, `${this.path}/${name}`);
  }

  async get() {
    return new FakeDocumentSnapshot(this.db.data.get(this.path));
  }
}

class FakeCollectionReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(this.db, `${this.path}/${id}`);
  }
}

class FakeTransaction {
  constructor(data) {
    this.data = data;
  }

  async get(ref) {
    return new FakeDocumentSnapshot(this.data.get(ref.path));
  }

  create(ref, value) {
    if (this.data.has(ref.path)) {
      const error = new Error("already exists");
      error.code = "already-exists";
      throw error;
    }
    this.data.set(ref.path, clone(value));
  }

  update(ref, value) {
    if (!this.data.has(ref.path)) {
      const error = new Error("not found");
      error.code = "not-found";
      throw error;
    }
    this.data.set(ref.path, clone(value));
  }
}

class FakeFirestore {
  constructor() {
    this.data = new Map();
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  async runTransaction(callback) {
    const working = new Map();
    for (const [key, value] of this.data.entries()) {
      working.set(key, clone(value));
    }
    const result = await callback(new FakeTransaction(working));
    this.data = working;
    return result;
  }

  get(path) {
    const value = this.data.get(path);
    return value === undefined ? undefined : clone(value);
  }

  set(path, value) {
    this.data.set(path, clone(value));
  }
}

function startData(overrides = {}) {
  return {
    requestId: "public-request-1",
    brandName: "  Örnek   Marka  ",
    officialWebsiteUrl: "https://Example.COM/path?q=1#x",
    anonymousClientNonce: "browser-nonce-1",
    ...overrides,
  };
}

function command(overrides = {}) {
  return contract.buildPublicLiteStartCommand({
    data: startData(overrides.data),
    appId: overrides.appId || "1:123:web:abc",
    networkAddress: overrides.networkAddress || "203.0.113.10",
    secretKey,
    now: overrides.now || now,
    rateLimit: overrides.rateLimit,
  });
}

function callableRequest(data, overrides = {}) {
  return {
    data,
    app: {appId: "1:123:web:abc"},
    rawRequest: {ip: "203.0.113.10", socket: {}},
    ...overrides,
  };
}

function reportFor(run, channels) {
  const reportVersion = "1";
  return {
    scanRunId: run.scanRunId,
    reportId: riskScanReportId({
      scanRunId: run.scanRunId,
      reportVersion,
    }),
    reportVersion,
    generatedAt: "2026-07-29T16:20:00.000Z",
    status: "completed",
    coverageStatus: "complete",
    overallRiskLevel: "high",
    overallConfidenceLevel: "medium",
    recommendedAction: "reviewTopFindings",
    summary: "Tarama tamamlandı.",
    findingCount: 0,
    observationCount: 0,
    topFindingSnapshots: [],
    channelDistribution: channels.map((item) => ({
      channelCode: item.channelCode,
      status: "completed",
      coverageStatus: "complete",
      observationCount: 0,
      findingCount: 0,
    })),
    immutable: true,
  };
}

async function seed(db, options = {}) {
  const built = command(options);
  const result = await port.createPublicLiteRun(db, built);
  return {built, result};
}

// Contract and normalization: 21 tests.
test("public-lite callable contract version is stable", () => {
  assert.equal(
      contract.PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
      "risk-scan-public-lite-callable-v1");
});

test("brand normalization is Unicode and whitespace stable", () => {
  assert.equal(contract.normalizeBrandName("  ÖRNEK   Marka "), "örnek marka");
});

test("brand normalization rejects blanks", () => {
  assert.throws(() => contract.normalizeBrandName("   "));
});

test("official website becomes an origin", () => {
  assert.deepEqual(
      contract.normalizeOfficialWebsite("https://Example.com/a?q=1#x"),
      {
        officialHost: "example.com",
        officialWebsiteCanonicalUrl: "https://example.com/",
      });
});

test("official website removes default port", () => {
  assert.equal(
      contract.normalizeOfficialWebsite("https://example.com:443/a")
          .officialWebsiteCanonicalUrl,
      "https://example.com/");
});

test("official website preserves non-default port", () => {
  assert.equal(
      contract.normalizeOfficialWebsite("https://example.com:8443/a")
          .officialWebsiteCanonicalUrl,
      "https://example.com:8443/");
});

test("official website rejects credentials", () => {
  assert.throws(() =>
    contract.normalizeOfficialWebsite("https://user:pass@example.com/"));
});

test("official website rejects non-http scheme", () => {
  assert.throws(() => contract.normalizeOfficialWebsite("ftp://example.com"));
});

test("start data rejects extra keys", () => {
  assert.throws(() => contract.normalizeStartData({
    ...startData(),
    tenantId: "forbidden",
  }));
});

test("access data rejects extra keys", () => {
  assert.throws(() => contract.normalizeAccessData({
    accessKey: "x",
    scanRunId: "forbidden",
  }));
});

test("secret key requires at least 32 bytes", () => {
  assert.throws(() => contract.assertSecretKey("short"));
});

test("HMAC output is deterministic", () => {
  assert.equal(
      contract.hmacHex(secretKey, "n", ["a"]),
      contract.hmacHex(secretKey, "n", ["a"]));
});

test("HMAC output is namespace separated", () => {
  assert.notEqual(
      contract.hmacHex(secretKey, "n1", ["a"]),
      contract.hmacHex(secretKey, "n2", ["a"]));
});

test("window start rounds down to the hour", () => {
  assert.equal(
      contract.windowStart(new Date("2026-07-29T16:45:12Z")).toISOString(),
      "2026-07-29T16:00:00.000Z");
});

test("access key round-trips", () => {
  const built = command();
  const parsed = contract.parseAccessKey(built.accessKey);
  assert.equal(parsed.scanRunId, built.run.scanRunId);
  assert.equal(sha256Hex(parsed.accessSecret), built.accessSecretDigestSha256);
});

test("access key rejects an unknown prefix", () => {
  const invalid = `bad.${"a".repeat(64)}.${"b".repeat(43)}`;
  assert.throws(() => contract.parseAccessKey(invalid));
});

test("start command is deterministic for the same request", () => {
  assert.equal(command().accessKey, command().accessKey);
  assert.equal(command().run.scanRunId, command().run.scanRunId);
});

test("start command changes for a different request id", () => {
  assert.notEqual(
      command().run.scanRunId,
      command({data: {requestId: "public-request-2"}}).run.scanRunId);
});

test("start command contains no raw IP or client nonce", () => {
  const serialized = JSON.stringify(command());
  assert.equal(serialized.includes("203.0.113.10"), false);
  assert.equal(serialized.includes("browser-nonce-1"), false);
});

test("start command creates exactly three sibling channels", () => {
  assert.deepEqual(
      command().channels.map((item) => item.channelCode),
      ["similarDomains", "openWeb", "marketplaceLimited"]);
});

test("start command creates network and client rate buckets", () => {
  const records = command().rateLimitRecords;
  assert.equal(records.length, 2);
  assert.notEqual(records[0].bucketId, records[1].bucketId);
});

// Firestore port: 19 tests.
test("public start creates run channels and rate bucket", async () => {
  const db = new FakeFirestore();
  const {built, result} = await seed(db);
  assert.equal(result.outcome, "created");
  assert.ok(db.get(`risk_scan_runs/${built.run.scanRunId}`));
  const networkPath =
    `risk_scan_rate_limits/${built.rateLimitRecords[0].bucketId}`;
  const clientPath =
    `risk_scan_rate_limits/${built.rateLimitRecords[1].bucketId}`;
  assert.ok(db.get(networkPath));
  assert.ok(db.get(clientPath));
});

test("matching start replay is idempotent", async () => {
  const db = new FakeFirestore();
  const first = await seed(db);
  const second = await port.createPublicLiteRun(db, command({
    now: new Date("2026-07-29T16:10:00Z"),
  }));
  assert.equal(second.outcome, "idempotent_success");
  assert.equal(
      db.get(
          `risk_scan_rate_limits/${first.built.rateLimitRecords[0].bucketId}`)
          .count,
      1);
});

test("matching replay may observe advanced lifecycle state", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const path = `risk_scan_runs/${built.run.scanRunId}`;
  db.set(path, {...db.get(path), status: "queued"});
  const replay = await port.createPublicLiteRun(db, command({
    now: new Date("2026-07-29T16:05:00Z"),
  }));
  assert.equal(replay.run.status, "queued");
});

test("partial run bundle conflicts", async () => {
  const db = new FakeFirestore();
  const built = command();
  db.set(`risk_scan_runs/${built.run.scanRunId}`, built.run);
  await assert.rejects(
      () => port.createPublicLiteRun(db, built),
      (error) => error.code === "conflict");
});

test("conflicting replay is rejected", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const path = `risk_scan_runs/${built.run.scanRunId}`;
  db.set(path, {...db.get(path), requestFingerprintSha256: "f".repeat(64)});
  await assert.rejects(
      () => port.createPublicLiteRun(db, built),
      (error) => error.code === "conflict");
});

test("different requests in the same bucket increment once each", async () => {
  const db = new FakeFirestore();
  const first = await seed(db);
  await seed(db, {data: {requestId: "public-request-2"}});
  assert.equal(
      db.get(
          `risk_scan_rate_limits/${first.built.rateLimitRecords[0].bucketId}`)
          .count,
      2);
});

test("rate limit rejection creates no partial run", async () => {
  const db = new FakeFirestore();
  const first = await seed(db, {rateLimit: 1});
  const second = command({
    rateLimit: 1,
    data: {requestId: "public-request-2"},
  });
  await assert.rejects(
      () => port.createPublicLiteRun(db, second),
      (error) => error.code === "resource-exhausted");
  assert.equal(db.get(`risk_scan_runs/${second.run.scanRunId}`), undefined);
  assert.equal(
      db.get(
          `risk_scan_rate_limits/${first.built.rateLimitRecords[0].bucketId}`)
          .count,
      1);
});

test("status authorizes a valid access key", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const projection = await port.getPublicLiteStatus(db, {
    accessKey: built.accessKey,
    now: later,
  });
  assert.equal(projection.scanRunId, built.run.scanRunId);
});

test("status projection excludes access digest", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const projection = await port.getPublicLiteStatus(db, {
    accessKey: built.accessKey,
    now: later,
  });
  assert.equal(JSON.stringify(projection).includes("accessSecret"), false);
});

test("invalid access secret is not-found", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const parsed = contract.parseAccessKey(built.accessKey);
  const invalid = contract.buildAccessKey(
      parsed.scanRunId, "x".repeat(43));
  await assert.rejects(
      () => port.getPublicLiteStatus(db, {accessKey: invalid, now: later}),
      (error) => error.code === "not-found");
});

test("missing run is not-found", async () => {
  const built = command();
  await assert.rejects(
      () => port.getPublicLiteStatus(new FakeFirestore(), {
        accessKey: built.accessKey,
        now: later,
      }),
      (error) => error.code === "not-found");
});

test("expired access is rejected", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  await assert.rejects(
      () => port.getPublicLiteStatus(db, {
        accessKey: built.accessKey,
        now: "2026-08-01T16:00:00.000Z",
      }),
      (error) => error.code === "failed-precondition");
});

test("missing channel is a conflict", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  db.data.delete(
      `risk_scan_runs/${built.run.scanRunId}/channels/openWeb`);
  await assert.rejects(
      () => port.getPublicLiteStatus(db, {
        accessKey: built.accessKey,
        now: later,
      }),
      (error) => error.code === "conflict");
});

test("report is unavailable before completion", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  await assert.rejects(
      () => port.getPublicLiteReport(db, {
        accessKey: built.accessKey,
        now: later,
      }),
      (error) => error.code === "failed-precondition");
});

test("completed report returns a masked projection", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const root = `risk_scan_runs/${built.run.scanRunId}`;
  const channels = built.channels.map((item) => ({
    ...db.get(`${root}/channels/${item.channelCode}`),
    status: "completed",
    coverageStatus: "complete",
  }));
  channels.forEach((item) => db.set(
      `${root}/channels/${item.channelCode}`, item));
  const report = require("./storage_documents")
      .buildReportDocument(reportFor(built.run, channels));
  db.set(`risk_scan_reports/${report.reportId}`, report);
  db.set(root, {
    ...db.get(root),
    status: "completed",
    coverageStatus: "complete",
    latestReportId: report.reportId,
  });
  const projection = await port.getPublicLiteReport(db, {
    accessKey: built.accessKey,
    now: later,
  });
  assert.equal(projection.report.reportId, report.reportId);
  assert.equal(JSON.stringify(projection).includes("reportDigest"), false);
});

test("report scope mismatch conflicts", async () => {
  const db = new FakeFirestore();
  const {built} = await seed(db);
  const root = `risk_scan_runs/${built.run.scanRunId}`;
  db.set(root, {
    ...db.get(root),
    status: "completed",
    latestReportId: "report-x",
  });
  db.set("risk_scan_reports/report-x", {
    scanRunId: "other",
    reportId: "report-x",
    immutable: true,
  });
  await assert.rejects(
      () => port.getPublicLiteReport(db, {
        accessKey: built.accessKey,
        now: later,
      }),
      (error) => error.code === "conflict");
});

test("stored run replay accepts the same security identity", () => {
  const built = command();
  assert.equal(
      port.assertStoredRunReplay(built.run, built.run),
      built.run);
});

test("rate-limit scope rejects changed app id", () => {
  const built = command();
  const record = require("./rate_limit_contract")
      .createRateLimitRecord(built.rateLimitRecords[0]);
  assert.throws(() => port.assertRateLimitScope(
      {...record, appId: "other"}, record));
});

test("public collections are frozen and exact", () => {
  assert.deepEqual(port.PUBLIC_COLLECTIONS, {
    runs: "risk_scan_runs",
    reports: "risk_scan_reports",
    rateLimits: "risk_scan_rate_limits",
    channels: "channels",
  });
  assert.equal(Object.isFrozen(port.PUBLIC_COLLECTIONS), true);
});

// Callable boundary: 13 tests.
test("start callable requires App Check context", async () => {
  const handler = callable.createPublicLiteHandler("start", {
    db: new FakeFirestore(),
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  await assert.rejects(
      () => handler({...callableRequest(startData()), app: null}),
      (error) => error.code === "failed-precondition");
});

test("start callable requires network context", async () => {
  const handler = callable.createPublicLiteHandler("start", {
    db: new FakeFirestore(),
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  await assert.rejects(
      () => handler(callableRequest(startData(), {rawRequest: {}})),
      (error) => error.code === "internal");
});

test("start callable returns access key and safe projection", async () => {
  const handler = callable.createPublicLiteHandler("start", {
    db: new FakeFirestore(),
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  const result = await handler(callableRequest(startData()));
  assert.match(result.accessKey, /^hrt1\.[a-f0-9]{64}\.[A-Za-z0-9_-]{43}$/);
  assert.equal(result.projection.identityMode, "anonymous");
});

test("start callable exact replay returns the same key", async () => {
  const db = new FakeFirestore();
  const handler = callable.createPublicLiteHandler("start", {
    db,
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  const first = await handler(callableRequest(startData()));
  const second = await handler(callableRequest(startData()));
  assert.equal(second.outcome, "idempotent_success");
  assert.equal(first.accessKey, second.accessKey);
});

test("status callable returns a safe projection", async () => {
  const db = new FakeFirestore();
  const start = callable.createPublicLiteHandler("start", {
    db,
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  const started = await start(callableRequest(startData()));
  const status = callable.createPublicLiteHandler("status", {
    db,
    clock: {now: () => new Date(later)},
  });
  const result = await status(callableRequest({accessKey: started.accessKey}));
  assert.equal(result.projection.status, "created");
});

test("report callable maps not-ready to failed-precondition", async () => {
  const db = new FakeFirestore();
  const start = callable.createPublicLiteHandler("start", {
    db,
    clock: {now: () => now},
    secretKeyProvider: () => secretKey,
  });
  const started = await start(callableRequest(startData()));
  const report = callable.createPublicLiteHandler("report", {
    db,
    clock: {now: () => new Date(later)},
  });
  await assert.rejects(
      () => report(callableRequest({accessKey: started.accessKey})),
      (error) => error.code === "failed-precondition");
});

test("callable maps TypeError to invalid-argument", () => {
  const mapped = callable.mapPublicLiteError(new TypeError("bad input"));
  assert.equal(mapped.code, "invalid-argument");
});

test("callable maps conflict to aborted", () => {
  const error = new contract.RiskScanPublicLiteError("conflict", "conflict");
  assert.equal(callable.mapPublicLiteError(error).code, "aborted");
});

test("callable hides unknown internal messages", () => {
  const mapped = callable.mapPublicLiteError(new Error("sensitive detail"));
  assert.equal(mapped.code, "internal");
  assert.equal(mapped.message.includes("sensitive"), false);
});

test("start callable options enforce App Check and bind secret", () => {
  const options = callable.callableOptions("start");
  assert.equal(options.region, "europe-west3");
  assert.equal(options.enforceAppCheck, true);
  assert.equal(options.maxInstances, 1);
  assert.equal(options.secrets.length, 1);
});

test("read callable options enforce App Check", () => {
  assert.deepEqual(callable.callableOptions("status"), {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 3,
  });
});

test("callable function names are stable", () => {
  assert.deepEqual(callable.PUBLIC_LITE_FUNCTION_NAMES, {
    start: "startPublicLiteRiskScan",
    status: "getPublicLiteRiskScanStatus",
    report: "getPublicLiteRiskScanReport",
  });
});

test("callable builders return functions", () => {
  const db = new FakeFirestore();
  assert.equal(typeof callable.buildStartPublicLiteRiskScan({db}), "function");
  assert.equal(
      typeof callable.buildGetPublicLiteRiskScanStatus({db}),
      "function");
  assert.equal(
      typeof callable.buildGetPublicLiteRiskScanReport({db}),
      "function");
});
