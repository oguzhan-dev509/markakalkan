/* eslint-disable max-len */
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const {spawnSync} = require("node:child_process");
const test = require("node:test");
const {
  ARTIFACT_FORMAT_VERSION,
  AUTHORIZER_OPTIONS,
  AUTHORIZER_SERVICE_ACCOUNT,
  BUCKET,
  DOWNLOAD_REQUEST,
  DOWNLOAD_TTL_MS,
  FONT_POSTSCRIPT_NAME,
  FONT_SHA256,
  FONT_VERSION,
  LICENSE_SHA256,
  MATERIALIZER_OPTIONS,
  MATERIALIZER_SERVICE_ACCOUNT,
  MATERIALIZE_REQUEST,
  artifactHandler,
  artifactObjectNames,
  assertSourcePackage,
  boundedFileName,
  canonicalJson,
  createArtifactService,
  createStorageAdapter,
  downloadRequest,
  materializeRequest,
  productionService,
  renderCanonicalManifest,
  renderDeterministicPdf,
  safeArtifactSummary,
  safeFileNames,
  verifyAssetIdentity,
} = require("./artifact");
const {fingerprint} = require("./contracts");
const {safePackage} = require("./service");

const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const packageId = "a".repeat(64);
const submissionId = "b".repeat(64);
const requestId = "00000000-0000-4000-8000-000000000001";
const context = {
  tenantId: "tenant-1",
  brandId: "brand-1",
  membershipId: "membership-1",
};
const submission = {
  tenantId: context.tenantId,
  canonicalBrandId: context.brandId,
  submissionNumber: "GB-2026-0001",
  targetAuthority: "customs_enforcement",
  targetUnit: "İstanbul Gümrük Müdürlüğü",
  authoritySummary: "Türkçe resmî başvuru özeti.",
  status: "package_generated",
  eventCount: 2,
  lastEventId: "previous-event",
};
function packageFixture(overrides = {}) {
  const value = {
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    submissionId,
    version: 1,
    packageType: "fsmh_application_package",
    sourceSnapshot: {profileName: "İşaretli ürün", intervention: "Şüpheli ürün – koli"},
    documentManifest: [{type: "başvuru", label: "Üst yazı"}],
    evidenceManifest: [{type: "fotoğraf", label: "Görsel kanıt"}],
    redactionManifest: [{field: "actorUid", action: "remove"}],
    coverLetterText: "Sayın Yetkili,\nGereğini arz ederiz.",
    authoritySummary: "Kaçakçılık şüphesi için insan incelemeli bildirim.",
    legalNeutralityStatement: "Bu paket hukuki karar veya elektronik imza iddiası içermez.",
    aggregateHashAlgorithm: "SHA-256",
    generatedAt: "2026-07-25T12:00:00.000Z",
    generatedByUid: "user-1",
    immutable: true,
    ...overrides,
  };
  value.aggregateHash = fingerprint(value);
  return value;
}
function materializePayload(overrides = {}) {
  return {
    contractVersion: MATERIALIZE_REQUEST,
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    submissionId,
    packageId,
    requestId,
    ...overrides,
  };
}
function downloadPayload(overrides = {}) {
  return {
    contractVersion: DOWNLOAD_REQUEST,
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    submissionId,
    packageId,
    artifactType: "pdf",
    requestId,
    ...overrides,
  };
}

test("font/license identity, pinned renderer and callable options are exact", () => {
  const assets = verifyAssetIdentity();
  assert.equal(hash(assets.font), FONT_SHA256);
  assert.equal(hash(assets.license), LICENSE_SHA256);
  assert.equal(FONT_POSTSCRIPT_NAME, "NotoSans-Regular");
  assert.match(FONT_VERSION, /^Version 2\.008/);
  assert.deepEqual(MATERIALIZER_OPTIONS, {
    region: "europe-west3", enforceAppCheck: true, maxInstances: 1,
    timeoutSeconds: 300, memory: "1GiB",
    serviceAccount: MATERIALIZER_SERVICE_ACCOUNT,
  });
  assert.deepEqual(AUTHORIZER_OPTIONS, {
    region: "europe-west3", enforceAppCheck: true, maxInstances: 3,
    timeoutSeconds: 60, memory: "256MiB",
    serviceAccount: AUTHORIZER_SERVICE_ACCOUNT,
  });
});

test("strict contracts reject unknown fields and unsafe artifact types", () => {
  assert.equal(materializeRequest(materializePayload()).packageId, packageId);
  assert.equal(downloadRequest(downloadPayload()).artifactType, "pdf");
  assert.throws(() => materializeRequest(materializePayload({bucket: BUCKET})),
      {code: "invalid-argument"});
  assert.throws(() => downloadRequest(downloadPayload({artifactType: "zip"})),
      {code: "invalid-argument"});
});

test("source package is immutable, scoped and hash protected", () => {
  const value = packageFixture();
  assert.equal(assertSourcePackage(value), value.aggregateHash);
  assert.throws(() => assertSourcePackage({...value, immutable: false}),
      {code: "failed-precondition"});
  assert.throws(() => assertSourcePackage({...value, coverLetterText: "tampered"}),
      {code: "failed-precondition"});
});

test("path and safe filenames are deterministic and injection resistant", () => {
  const value = packageFixture();
  const names1 = artifactObjectNames(context, materializePayload(), value);
  const names2 = artifactObjectNames(context, materializePayload(), value);
  assert.deepEqual(names1, names2);
  assert.match(names1.pdf, /^customs-authority-submissions\/artifact-formats\/v1\/tenants\/[a-f0-9]{32}\/brands\/[a-f0-9]{32}\//);
  assert.equal(names1.pdf.endsWith("/official-package.pdf"), true);
  assert.equal(names1.jsonManifest.endsWith("/canonical-manifest.json"), true);
  assert.deepEqual(safeFileNames(submission, value), {
    pdf: "MarkaKalkan_Gumruk_Basvuru_Paketi_GB-2026-0001_v1.pdf",
    jsonManifest: "MarkaKalkan_Gumruk_Basvuru_Manifesti_GB-2026-0001_v1.json",
  });
  for (const token of ["../x", "x/y", "x\\y", "x\r\nY"]) {
    assert.throws(() => boundedFileName("prefix", token, 1, "pdf"));
  }
});

test("PDF is deterministic in-process and across Node processes with Turkish glyphs", async () => {
  const value = packageFixture();
  const one = await renderDeterministicPdf({submission, packageId, packageData: value});
  const two = await renderDeterministicPdf({submission, packageId, packageData: value});
  assert.deepEqual(one, two);
  assert.equal(one.subarray(0, 5).toString(), "%PDF-");
  assert.ok(one.length < 10 * 1024 * 1024);
  const script = `
    const a=require(${JSON.stringify(require.resolve("./artifact"))});
    const c=require(${JSON.stringify(require.resolve("./contracts"))});
    const p=${JSON.stringify({...value, aggregateHash: undefined})};
    delete p.aggregateHash;p.aggregateHash=c.fingerprint(p);
    a.renderDeterministicPdf({submission:${JSON.stringify(submission)},packageId:${JSON.stringify(packageId)},packageData:p})
      .then(b=>process.stdout.write(require("node:crypto").createHash("sha256").update(b).digest("hex")));
  `;
  const child = spawnSync(process.execPath, ["-e", script], {encoding: "utf8"});
  assert.equal(child.status, 0, child.stderr);
  assert.equal(child.stdout, hash(one));
});

test("canonical manifest is stable UTF-8 without BOM or operation metadata", () => {
  const value = packageFixture();
  const pdf = {safeFileName: "safe.pdf", sizeBytes: 123, sha256: "c".repeat(64)};
  const one = renderCanonicalManifest({submission, packageId, packageData: value, pdf});
  const two = renderCanonicalManifest({submission, packageId, packageData: value, pdf});
  assert.deepEqual(one, two);
  assert.notDeepEqual([...one.subarray(0, 3)], [0xef, 0xbb, 0xbf]);
  assert.equal(one.at(-1), 10);
  const parsed = JSON.parse(one.toString("utf8"));
  assert.equal(parsed.artifactFormatVersion, ARTIFACT_FORMAT_VERSION);
  assert.equal(parsed.sourcePackageHash, value.aggregateHash);
  for (const forbidden of ["materializedAt", "materializedByUid",
    "materializationRequestId", "lease", "signedUrl"]) {
    assert.equal(one.includes(Buffer.from(forbidden)), false);
  }
  assert.deepEqual(canonicalJson({z: 1, a: {z: 2, a: 3}}),
      Buffer.from("{\"a\":{\"a\":3,\"z\":2},\"z\":1}\n"));
});

test("legacy and ready package summaries expose no storage internals", () => {
  assert.equal(safeArtifactSummary({}).artifactStatus, "legacy_not_materialized");
  const summary = safeArtifactSummary({artifact: {
    status: "ready", formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: "a".repeat(64),
    pdf: {bucket: "secret", objectName: "secret", generation: "4",
      contentType: "application/pdf", sizeBytes: 7, sha256: "b".repeat(64),
      safeFileName: "safe.pdf"},
  }});
  assert.equal(summary.pdf.ready, true);
  assert.equal(JSON.stringify(summary).includes("secret"), false);
  assert.equal(JSON.stringify(summary).includes("generation"), false);
});

test("storage adapter uses create-only precondition and verifies bytes", async () => {
  const bytes = Buffer.from("artifact");
  const calls = [];
  const metadata = {
    "artifact-format-version": ARTIFACT_FORMAT_VERSION,
    "source-package-hash": "a".repeat(64),
    "sha256": hash(bytes), "package-id": packageId,
    "package-version": "1", "font-sha256": FONT_SHA256,
  };
  const actual = {bucket: BUCKET, name: "object", generation: "1",
    contentType: "application/pdf", size: String(bytes.length),
    cacheControl: "private, no-store, max-age=0",
    contentDisposition: "attachment; filename=\"safe.pdf\"", metadata};
  const file = {
    save: async (_bytes, options) => calls.push(options),
    getMetadata: async () => [actual],
    createReadStream: () => require("node:stream").Readable.from([bytes]),
  };
  const bucket = {name: BUCKET, file: () => file};
  const result = await createStorageAdapter(bucket).createOrVerify({
    objectName: "object", bytes, contentType: "application/pdf",
    safeFileName: "safe.pdf", metadata,
  });
  assert.equal(calls[0].preconditionOpts.ifGenerationMatch, 0);
  assert.equal(result.sha256, hash(bytes));
});

test("callable gates Auth and App Check before invocation", async () => {
  let calls = 0;
  const handler = artifactHandler("materialize", {
    service: {materialize: async () => {
      calls++; return {ok: true};
    }},
    log: {info() {}},
  });
  await assert.rejects(() => handler({data: {}}), {code: "unauthenticated"});
  await assert.rejects(() => handler({auth: {uid: "u"}, data: {}}),
      {code: "failed-precondition"});
  assert.equal(calls, 0);
  await handler({auth: {uid: "u"}, app: {appId: "a"}, data: {}});
  assert.equal(calls, 1);
});

test("authorizer is read-only, binds exact generation and five-minute TTL", async () => {
  const value = packageFixture();
  const descriptor = {
    bucket: BUCKET, objectName: "safe/object.pdf", generation: "9",
    contentType: "application/pdf", sizeBytes: 7, sha256: "d".repeat(64),
    safeFileName: "safe.pdf",
  };
  value.artifact = {status: "ready", formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: value.aggregateHash, pdf: descriptor,
    jsonManifest: {...descriptor, objectName: "safe/object.json",
      contentType: "application/json; charset=utf-8", safeFileName: "safe.json"}};
  const reads = {tenant_memberships: {"membership-1": {
    status: "active", role: "owner"}}, customs_authority_submissions: {
    [submissionId]: submission}, customs_submission_packages: {[packageId]: value}};
  let writes = 0;
  const db = {
    collection: (name) => ({doc: (id) => ({get: async () => ({
      exists: Boolean(reads[name]?.[id]), data: () => structuredClone(reads[name]?.[id]),
    })})}),
    runTransaction: async () => {
      writes++;
    },
  };
  let signed;
  const service = createArtifactService({
    db, clock: {now: () => new Date("2026-07-26T00:00:00.000Z")},
    resolveContext: async () => context,
    storage: {verify: async (input) => assert.equal(input.generation, "9")},
    signDownload: async (input) => {
      signed = input; return "https://signed.invalid/object";
    },
  });
  const result = await service.authorizeDownload(downloadPayload(), {uid: "u"});
  assert.equal(writes, 0);
  assert.equal(result.generation, "9");
  assert.equal(Date.parse(result.expiresAt) - Date.parse("2026-07-26T00:00:00.000Z"),
      DOWNLOAD_TTL_MS);
  assert.equal(signed.descriptor.generation, "9");
  assert.equal(JSON.stringify(reads).includes("signed.invalid"), false);
});

class Snapshot {
  constructor(id, value) {
    this.id = id;
    this.value = value;
    this.exists = value != null;
  }
  data() {
    return this.value == null ? undefined : structuredClone(this.value);
  }
}
class Ref {
  constructor(db, collection, id) {
    this.db = db;
    this.collectionName = collection;
    this.id = id;
  }
  async get() {
    return this.db.snapshot(this.collectionName, this.id);
  }
}
class Collection {
  constructor(db, name) {
    this.db = db;
    this.name = name;
  }
  doc(id) {
    return new Ref(this.db, this.name, id);
  }
}
class Transaction {
  constructor(db) {
    this.db = db;
    this.operations = [];
  }
  async get(ref) {
    return this.db.snapshot(ref.collectionName, ref.id);
  }
  update(ref, data) {
    this.operations.push({type: "update", ref, data: structuredClone(data)});
  }
  create(ref, data) {
    this.operations.push({type: "create", ref, data: structuredClone(data)});
  }
  commit() {
    for (const operation of this.operations) {
      const values = this.db.values[operation.ref.collectionName];
      if (operation.type === "create") {
        if (values[operation.ref.id]) throw new Error("already exists");
        values[operation.ref.id] = operation.data;
      } else {
        if (!values[operation.ref.id]) throw new Error("not found");
        values[operation.ref.id] = {
          ...values[operation.ref.id],
          ...operation.data,
        };
      }
    }
  }
}
class FakeDb {
  constructor(packageData) {
    this.values = {
      tenant_memberships: {"membership-1": {status: "active", role: "owner"}},
      customs_authority_submissions: {[submissionId]: structuredClone(submission)},
      customs_submission_packages: {[packageId]: structuredClone(packageData)},
      customs_submission_events: {},
    };
    this.transactions = 0;
    this.failOnTransaction = null;
  }
  collection(name) {
    if (!this.values[name]) this.values[name] = {};
    return new Collection(this, name);
  }
  snapshot(collection, id) {
    return new Snapshot(id, this.values[collection]?.[id] || null);
  }
  async runTransaction(callback) {
    this.transactions++;
    const transaction = new Transaction(this);
    const result = await callback(transaction);
    if (this.transactions === this.failOnTransaction) {
      throw new Error("simulated transaction failure");
    }
    transaction.commit();
    return result;
  }
}
function memoryStorage() {
  const objects = new Map();
  let writes = 0;
  return {
    get writes() {
      return writes;
    },
    async createOrVerify(input) {
      const digest = hash(input.bytes);
      const existing = objects.get(input.objectName);
      if (existing && !existing.bytes.equals(input.bytes)) {
        const error = new Error("integrity");
        error.code = "artifact.integrity_failed";
        throw error;
      }
      if (!existing) {
        writes++;
        objects.set(input.objectName, {...input, bytes: Buffer.from(input.bytes)});
      }
      return {
        recovered: Boolean(existing),
        bucket: BUCKET,
        objectName: input.objectName,
        generation: "1",
        contentType: input.contentType,
        sizeBytes: input.bytes.length,
        sha256: digest,
        safeFileName: input.safeFileName,
      };
    },
    async verify() {},
  };
}

test("materialization is atomic, event chained and ready retry avoids Storage writes", async () => {
  const value = packageFixture();
  const db = new FakeDb(value);
  const storage = memoryStorage();
  const service = createArtifactService({
    db,
    storage,
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
    signDownload: async () => "https://signed.invalid",
  });
  const first = await service.materialize(materializePayload(), {uid: "user-1"});
  assert.equal(first.ok, true);
  assert.equal(first.duplicate, false);
  assert.equal(first.transactionApplied, true);
  assert.equal(first.artifactStatus, "ready");
  assert.equal(JSON.stringify(first.artifact).includes("objectName"), false);
  assert.equal(JSON.stringify(first.artifact).includes("generation"), false);
  assert.equal(JSON.stringify(first.artifact).includes("lease"), false);
  assert.equal(storage.writes, 2);
  const storedPackage = db.values.customs_submission_packages[packageId];
  assert.equal(storedPackage.aggregateHash, value.aggregateHash);
  assert.equal(storedPackage.artifact.status, "ready");
  const events = Object.values(db.values.customs_submission_events);
  assert.equal(events.length, 1);
  assert.equal(events[0].previousEventId, "previous-event");
  assert.equal(events[0].sequence, 3);
  assert.equal(events[0].eventType,
      "customs_submission_package_artifact_materialized");
  assert.equal(JSON.stringify(events[0]).includes("signed.invalid"), false);

  const second = await service.materialize(materializePayload(), {uid: "user-1"});
  assert.equal(second.duplicate, true);
  assert.equal(second.transactionApplied, false);
  assert.equal(storage.writes, 2);
  assert.equal(Object.values(db.values.customs_submission_events).length, 1);
});

test("active lease rejects another request and stale lease recovers", async () => {
  const active = packageFixture();
  active.artifact = {
    status: "materializing",
    formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: active.aggregateHash,
    materializationRequestId: requestId,
    materializationRequestFingerprint: fingerprint(materializePayload()),
    leaseRequestId: requestId,
    leaseExpiresAt: "2026-07-26T10:04:00.000Z",
  };
  const other = materializePayload({
    requestId: "00000000-0000-4000-8000-000000000002",
  });
  const activeService = createArtifactService({
    db: new FakeDb(active),
    storage: memoryStorage(),
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
  });
  await assert.rejects(() => activeService.materialize(other, {uid: "u"}),
      {code: "failed-precondition"});

  active.artifact.leaseExpiresAt = "2026-07-26T09:59:00.000Z";
  const staleService = createArtifactService({
    db: new FakeDb(active),
    storage: memoryStorage(),
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
  });
  const recovered = await staleService.materialize(other, {uid: "u"});
  assert.equal(recovered.recovered, true);
  assert.equal(recovered.artifactStatus, "ready");
});

function storageBucketFixture({
  bytes = Buffer.from("artifact"),
  metadataOverrides = {},
  generation = "7",
  notFound = false,
} = {}) {
  const saves = [];
  const custom = {
    "artifact-format-version": ARTIFACT_FORMAT_VERSION,
    "source-package-hash": "a".repeat(64),
    "sha256": hash(bytes),
    "package-id": packageId,
    "package-version": "1",
    "font-sha256": FONT_SHA256,
    ...(metadataOverrides.metadata || {}),
  };
  const actual = {
    bucket: BUCKET,
    name: "object",
    generation,
    contentType: "application/pdf",
    size: String(bytes.length),
    cacheControl: "private, no-store, max-age=0",
    contentDisposition: "attachment; filename=\"safe.pdf\"",
    ...metadataOverrides,
    metadata: custom,
  };
  const file = {
    save: async (value, options) => {
      saves.push({value, options});
      notFound = false;
    },
    getMetadata: async () => {
      if (notFound) {
        const error = new Error("not found");
        error.code = 404;
        throw error;
      }
      return [actual];
    },
    createReadStream: () => require("node:stream").Readable.from([bytes]),
  };
  return {
    bucket: {name: BUCKET, file: () => file},
    saves,
    expected: {
      objectName: "object",
      bytes: Buffer.from("artifact"),
      contentType: "application/pdf",
      safeFileName: "safe.pdf",
      metadata: {
        "artifact-format-version": ARTIFACT_FORMAT_VERSION,
        "source-package-hash": "a".repeat(64),
        "sha256": hash(Buffer.from("artifact")),
        "package-id": packageId,
        "package-version": "1",
        "font-sha256": FONT_SHA256,
      },
    },
  };
}

test("existing Storage object accepts exact bytes without a write", async () => {
  const fixture = storageBucketFixture();
  const result = await createStorageAdapter(fixture.bucket)
      .createOrVerify(fixture.expected, {preferExisting: true});
  assert.equal(result.recovered, true);
  assert.equal(fixture.saves.length, 0);
});

test("existing Storage object fails closed for byte and metadata mismatches", async () => {
  const cases = [
    storageBucketFixture({
      bytes: Buffer.from("artifacx"),
      metadataOverrides: {metadata: {
        sha256: hash(Buffer.from("artifact")),
      }},
    }),
    storageBucketFixture({metadataOverrides: {metadata: {
      sha256: "f".repeat(64),
    }}}),
    storageBucketFixture({metadataOverrides: {contentType: "text/plain"}}),
    storageBucketFixture({metadataOverrides: {size: "99"}}),
    storageBucketFixture({metadataOverrides: {metadata: {
      "source-package-hash": "f".repeat(64),
    }}}),
    storageBucketFixture({metadataOverrides: {metadata: {
      "font-sha256": "f".repeat(64),
    }}}),
  ];
  for (const fixture of cases) {
    await assert.rejects(
        () => createStorageAdapter(fixture.bucket)
            .createOrVerify(fixture.expected, {preferExisting: true}),
        {code: "artifact.integrity_failed"},
    );
    assert.equal(fixture.saves.length, 0);
  }
});

test("Storage descriptor verification rejects generation mismatch", async () => {
  const fixture = storageBucketFixture({generation: "8"});
  await assert.rejects(
      () => createStorageAdapter(fixture.bucket).verify({
        bucket: BUCKET,
        objectName: "object",
        generation: "7",
        contentType: "application/pdf",
        sizeBytes: Buffer.byteLength("artifact"),
        sha256: hash(Buffer.from("artifact")),
        sourcePackageHash: "a".repeat(64),
        packageId,
        packageVersion: 1,
      }),
      {code: "artifact.integrity_failed"},
  );
});

test("recovery verifies existing PDF and creates only missing JSON", async () => {
  const value = packageFixture();
  value.artifact = {
    status: "materializing",
    formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: value.aggregateHash,
    materializationRequestId: requestId,
    materializationRequestFingerprint: fingerprint(materializePayload()),
    leaseRequestId: requestId,
    leaseExpiresAt: "2026-07-26T10:04:00.000Z",
  };
  const writes = {pdf: 0, json: 0};
  const seen = new Set();
  const storage = {
    async createOrVerify(input, options) {
      assert.equal(options.preferExisting, true);
      const kind = input.contentType === "application/pdf" ? "pdf" : "json";
      if (kind === "json" && !seen.has("json")) writes.json++;
      seen.add(kind);
      return {
        recovered: kind === "pdf",
        bucket: BUCKET,
        objectName: input.objectName,
        generation: "1",
        contentType: input.contentType,
        sizeBytes: input.bytes.length,
        sha256: hash(input.bytes),
        safeFileName: input.safeFileName,
      };
    },
  };
  const service = createArtifactService({
    db: new FakeDb(value),
    storage,
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
  });
  const result = await service.materialize(materializePayload(), {uid: "u"});
  assert.equal(result.recovered, true);
  assert.deepEqual(writes, {pdf: 0, json: 1});
});

test("existing PDF and JSON finalize without object writes", async () => {
  const value = packageFixture();
  value.artifact = {
    status: "materializing",
    formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: value.aggregateHash,
    materializationRequestId: requestId,
    materializationRequestFingerprint: fingerprint(materializePayload()),
    leaseRequestId: requestId,
    leaseExpiresAt: "2026-07-26T10:04:00.000Z",
  };
  const service = createArtifactService({
    db: new FakeDb(value),
    storage: {
      async createOrVerify(input, options) {
        assert.equal(options.preferExisting, true);
        return {
          recovered: true,
          bucket: BUCKET,
          objectName: input.objectName,
          generation: "1",
          contentType: input.contentType,
          sizeBytes: input.bytes.length,
          sha256: hash(input.bytes),
          safeFileName: input.safeFileName,
        };
      },
    },
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
  });
  const result = await service.materialize(materializePayload(), {uid: "u"});
  assert.equal(result.artifactStatus, "ready");
});

test("finalize transaction failure leaves no ready projection or event", async () => {
  const db = new FakeDb(packageFixture());
  db.failOnTransaction = 2;
  const service = createArtifactService({
    db,
    storage: memoryStorage(),
    clock: {now: () => new Date("2026-07-26T10:00:00.000Z")},
    resolveContext: async () => context,
  });
  await assert.rejects(
      () => service.materialize(materializePayload(), {uid: "u"}),
      /simulated transaction failure/,
  );
  assert.equal(
      db.values.customs_submission_packages[packageId].artifact.status,
      "materializing",
  );
  assert.equal(Object.values(db.values.customs_submission_events).length, 0);
});

test("scope and owner gates reject tenant, brand and submission mismatches", async () => {
  for (const mutation of [
    (db) => {
      db.values.customs_authority_submissions[submissionId].tenantId = "other";
    },
    (db) => {
      db.values.customs_authority_submissions[submissionId].canonicalBrandId =
        "other";
    },
    (db) => {
      db.values.customs_submission_packages[packageId].submissionId =
        "c".repeat(64);
    },
    (db) => {
      db.values.tenant_memberships["membership-1"].role = "member";
    },
  ]) {
    const db = new FakeDb(packageFixture());
    mutation(db);
    const service = createArtifactService({
      db,
      storage: memoryStorage(),
      resolveContext: async () => context,
    });
    await assert.rejects(
        () => service.materialize(materializePayload(), {uid: "u"}),
    );
  }
});

test("not-ready and cross-scope artifacts cannot authorize a URL", async () => {
  for (const mutation of [
    (db) => {
      db.values.customs_submission_packages[packageId].artifact = {
        status: "materializing",
      };
    },
    (db) => {
      db.values.customs_submission_packages[packageId].canonicalBrandId =
        "other";
    },
  ]) {
    const db = new FakeDb(packageFixture());
    mutation(db);
    let signed = 0;
    const service = createArtifactService({
      db,
      storage: {verify: async () => {}},
      resolveContext: async () => context,
      signDownload: async () => {
        signed++;
        return "https://signed.invalid";
      },
    });
    await assert.rejects(
        () => service.authorizeDownload(downloadPayload(), {uid: "u"}),
    );
    assert.equal(signed, 0);
  }
});

test("authorizer rejects another tenant, brand and package scope", async () => {
  for (const mutation of [
    (db) => {
      db.values.customs_authority_submissions[submissionId].tenantId = "other";
    },
    (db) => {
      db.values.customs_authority_submissions[submissionId].canonicalBrandId =
        "other";
    },
    (db) => {
      db.values.customs_submission_packages[packageId].submissionId =
        "c".repeat(64);
    },
  ]) {
    const value = packageFixture();
    value.artifact = {
      status: "ready",
      formatVersion: ARTIFACT_FORMAT_VERSION,
      sourcePackageHash: value.aggregateHash,
      pdf: {
        bucket: BUCKET,
        objectName: "object",
        generation: "7",
        contentType: "application/pdf",
        sizeBytes: 8,
        sha256: hash(Buffer.from("artifact")),
        safeFileName: "safe.pdf",
      },
    };
    const db = new FakeDb(value);
    mutation(db);
    let verified = 0;
    let signed = 0;
    const service = createArtifactService({
      db,
      storage: {verify: async () => {
        verified++;
      }},
      resolveContext: async () => context,
      signDownload: async () => {
        signed++;
        return "https://signed.invalid";
      },
    });
    await assert.rejects(
        () => service.authorizeDownload(downloadPayload(), {uid: "u"}),
    );
    assert.equal(verified, 0);
    assert.equal(signed, 0);
  }
});

test("signed URL production config is V4, generation-bound and errors are safe", async () => {
  const value = packageFixture();
  const descriptor = {
    bucket: BUCKET,
    objectName: "object",
    generation: "7",
    contentType: "application/pdf",
    sizeBytes: Buffer.byteLength("artifact"),
    sha256: hash(Buffer.from("artifact")),
    safeFileName: "safe.pdf",
  };
  value.artifact = {
    status: "ready",
    formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: value.aggregateHash,
    pdf: descriptor,
  };
  const db = new FakeDb(value);
  let config;
  const fixture = storageBucketFixture();
  fixture.bucket.file = (_name, options) => ({
    ...fixture.bucket.file,
    getMetadata: async () => [{
      bucket: BUCKET,
      name: "object",
      generation: "7",
      contentType: "application/pdf",
      size: String(Buffer.byteLength("artifact")),
      metadata: {
        "artifact-format-version": ARTIFACT_FORMAT_VERSION,
        "source-package-hash": value.aggregateHash,
        "sha256": descriptor.sha256,
        "package-id": packageId,
        "package-version": "1",
        "font-sha256": FONT_SHA256,
      },
    }],
    createReadStream: () =>
      require("node:stream").Readable.from([Buffer.from("artifact")]),
    getSignedUrl: async (input) => {
      assert.equal(options.generation, "7");
      config = input;
      return ["https://signed.invalid/value"];
    },
  });
  const admin = {storage: () => ({bucket: () => fixture.bucket})};
  const service = productionService({
    db,
    admin,
    clock: {now: () => new Date("2026-07-26T00:00:00.000Z")},
    resolveContext: async () => context,
  });
  const result = await service.authorizeDownload(downloadPayload(), {uid: "u"});
  assert.deepEqual(config, {
    version: "v4",
    action: "read",
    expires: new Date("2026-07-26T00:05:00.000Z"),
    promptSaveAs: "safe.pdf",
    responseType: "application/pdf",
    queryParams: {generation: "7"},
  });
  assert.equal(result.downloadUrl, "https://signed.invalid/value");

  fixture.bucket.file = () => ({
    getMetadata: async () => {
      throw new Error("IAM details must not escape");
    },
  });
  await assert.rejects(
      () => service.authorizeDownload(downloadPayload(), {uid: "u"}),
      (error) => {
        assert.equal(JSON.stringify(error).includes("IAM details"), false);
        assert.equal(JSON.stringify(error).includes(BUCKET), false);
        return error.code === "unavailable";
      },
  );
});

test("safe responses, events and logs never persist or expose signed URLs", async () => {
  const value = packageFixture();
  value.artifact = {
    status: "ready",
    formatVersion: ARTIFACT_FORMAT_VERSION,
    sourcePackageHash: value.aggregateHash,
    pdf: {
      bucket: BUCKET,
      objectName: "secret",
      generation: "2",
      contentType: "application/pdf",
      sizeBytes: 2,
      sha256: "a".repeat(64),
      safeFileName: "safe.pdf",
    },
  };
  const detail = safePackage(packageId, value);
  const encoded = JSON.stringify(detail);
  for (const secret of [BUCKET, "objectName", "generation"]) {
    assert.equal(encoded.includes(secret), false);
  }
  const logs = [];
  const handler = artifactHandler("authorizeDownload", {
    service: {authorizeDownload: async () => ({
      ok: true,
      downloadUrl: "https://signed.invalid/secret",
    })},
    log: {info: (...items) => logs.push(items)},
  });
  await handler({auth: {uid: "u"}, app: {}, data: {}});
  assert.equal(JSON.stringify(logs).includes("signed.invalid"), false);
});

test("filename rejects every injection form and deterministically bounds length", () => {
  for (const token of [
    "x\ry", "x\ny", "x/y", "x\\y", "x..y", "x%0dy", "x%0ay",
    `x${String.fromCharCode(0x7f)}y`,
  ]) {
    assert.throws(() => boundedFileName("prefix", token, 1, "pdf"));
  }
  const long = "A".repeat(300);
  const one = boundedFileName("prefix", long, 1, "pdf");
  const two = boundedFileName("prefix", long, 1, "pdf");
  assert.equal(one, two);
  assert.ok(one.length <= 140);
  assert.match(one, /^[A-Za-z0-9._-]+$/);
});

test("two child processes produce byte-for-byte equal PDF buffers", () => {
  const value = packageFixture();
  const script = `
    const a=require(${JSON.stringify(require.resolve("./artifact"))});
    const p=${JSON.stringify(value)};
    a.renderDeterministicPdf({
      submission:${JSON.stringify(submission)},
      packageId:${JSON.stringify(packageId)},
      packageData:p
    }).then(b=>process.stdout.write(Buffer.from(b).toString("base64")));
  `;
  const run = () => spawnSync(process.execPath, ["-e", script], {
    encoding: "utf8",
    maxBuffer: 12 * 1024 * 1024,
  });
  const first = run();
  const second = run();
  assert.equal(first.status, 0, first.stderr);
  assert.equal(second.status, 0, second.stderr);
  const bufferA = Buffer.from(first.stdout, "base64");
  const bufferB = Buffer.from(second.stdout, "base64");
  assert.equal(bufferA.equals(bufferB), true);
});
