/* eslint-disable max-len */
const fs = require("node:fs");
const path = require("node:path");
const {createHash} = require("node:crypto");
const {PDFDocument, rgb} = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");
const {fingerprint} = require("./contracts");

const REGION = "europe-west3";
const BUCKET = "markakalkan-app-ktg-artifacts-1038407696535";
const MATERIALIZER_SERVICE_ACCOUNT =
  "ktg-artifact-materializer@markakalkan-app.iam.gserviceaccount.com";
const AUTHORIZER_SERVICE_ACCOUNT =
  "ktg-artifact-authorizer@markakalkan-app.iam.gserviceaccount.com";
const ARTIFACT_FORMAT_VERSION = "customs-submission-package-artifact-v1";
const FONT_SHA256 =
  "b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5";
const LICENSE_SHA256 =
  "3c05a56499a20ee045a6d36834b6a9e1108f359eede10d7c1613bc4524d01eef";
const FONT_POSTSCRIPT_NAME = "NotoSans-Regular";
const FONT_VERSION =
  "Version 2.008; ttfautohint (v1.8) -l 8 -r 50 -G 200 -x 14 -D latn -f none -a qsq -X \"\"";
const FONT_PATH = path.join(__dirname, "assets", "NotoSans-Regular.ttf");
const LICENSE_PATH = path.join(__dirname, "assets", "OFL.txt");
const MATERIALIZE_REQUEST =
  "customs-submission-package-artifact-materialize-request-v1";
const MATERIALIZE_RESULT =
  "customs-submission-package-artifact-materialize-result-v1";
const DOWNLOAD_REQUEST =
  "customs-submission-package-download-authorize-request-v1";
const DOWNLOAD_RESULT =
  "customs-submission-package-download-authorize-result-v1";
const SUBMISSION_COLLECTION = "customs_authority_submissions";
const PACKAGE_COLLECTION = "customs_submission_packages";
const EVENT_COLLECTION = "customs_submission_events";
const LEASE_MS = 5 * 60 * 1000;
const DOWNLOAD_TTL_MS = 5 * 60 * 1000;
const MAX_ARTIFACT_BYTES = 10 * 1024 * 1024;
const HEX_64 = /^[a-f0-9]{64}$/;
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const READY_STATUSES = new Set([
  "materialization_pending",
  "materializing",
  "ready",
  "failed_recoverable",
  "integrity_failed",
  "disabled",
]);
const sha256 = (value) => createHash("sha256").update(value).digest("hex");

class ArtifactError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ArtifactError";
    this.code = code;
  }
}
const fail = (code, message) => {
  throw new ArtifactError(code, message);
};
function object(value, field = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail("invalid-argument", `${field} object required`);
  }
  return value;
}
function text(value, field, minimum, maximum) {
  if (typeof value !== "string") fail("invalid-argument", `${field} invalid`);
  const clean = value.trim();
  if (clean.length < minimum || clean.length > maximum ||
      [...clean].some((character) => {
        const code = character.charCodeAt(0);
        return code === 127 || code < 32;
      })) {
    fail("invalid-argument", `${field} invalid`);
  }
  return clean;
}
function strict(raw, version, fields) {
  object(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  if (raw.contractVersion !== version ||
      Object.keys(raw).some((key) => !allowed.has(key))) {
    fail("invalid-argument", "request contract invalid");
  }
}
function id(value, field) {
  const clean = text(value, field, 64, 64).toLowerCase();
  if (!HEX_64.test(clean)) fail("invalid-argument", `${field} invalid`);
  return clean;
}
function requestId(value) {
  const clean = text(value, "requestId", 36, 36).toLowerCase();
  if (!UUID.test(clean)) fail("invalid-argument", "requestId invalid");
  return clean;
}
function materializeRequest(raw) {
  strict(raw, MATERIALIZE_REQUEST, [
    "tenantId",
    "canonicalBrandId",
    "submissionId",
    "packageId",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: text(raw.tenantId, "tenantId", 1, 128),
    canonicalBrandId: text(
        raw.canonicalBrandId,
        "canonicalBrandId",
        1,
        128,
    ),
    submissionId: id(raw.submissionId, "submissionId"),
    packageId: id(raw.packageId, "packageId"),
    requestId: requestId(raw.requestId),
  });
}
function downloadRequest(raw) {
  strict(raw, DOWNLOAD_REQUEST, [
    "tenantId",
    "canonicalBrandId",
    "submissionId",
    "packageId",
    "artifactType",
    "requestId",
  ]);
  const artifactType = text(raw.artifactType, "artifactType", 3, 20);
  if (!["pdf", "json_manifest"].includes(artifactType)) {
    fail("invalid-argument", "artifactType invalid");
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: text(raw.tenantId, "tenantId", 1, 128),
    canonicalBrandId: text(
        raw.canonicalBrandId,
        "canonicalBrandId",
        1,
        128,
    ),
    submissionId: id(raw.submissionId, "submissionId"),
    packageId: id(raw.packageId, "packageId"),
    artifactType,
    requestId: requestId(raw.requestId),
  });
}
function verifyAssetIdentity() {
  const font = fs.readFileSync(FONT_PATH);
  const license = fs.readFileSync(LICENSE_PATH);
  if (sha256(font) !== FONT_SHA256 || sha256(license) !== LICENSE_SHA256) {
    fail("failed-precondition", "artifact font identity mismatch");
  }
  return {font, license};
}
function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
        Object.keys(value).sort()
            .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}
function canonicalJson(value) {
  return Buffer.from(`${JSON.stringify(canonicalize(value))}\n`, "utf8");
}
function sourcePackageProjection(data) {
  const projection = structuredClone(data);
  delete projection.aggregateHash;
  delete projection.artifact;
  return projection;
}
function assertSourcePackage(data) {
  if (data.immutable !== true ||
      data.aggregateHashAlgorithm !== "SHA-256" ||
      !HEX_64.test(String(data.aggregateHash || ""))) {
    fail("failed-precondition", "package integrity unavailable");
  }
  const computed = fingerprint(sourcePackageProjection(data));
  if (computed !== data.aggregateHash) {
    fail("failed-precondition", "source package hash mismatch");
  }
  return computed;
}
function scopeHash(domain, value) {
  return sha256(Buffer.from(`${domain}|${value}`, "utf8")).slice(0, 32);
}
function artifactObjectNames(context, request, packageData) {
  const base = [
    "customs-authority-submissions",
    "artifact-formats",
    "v1",
    "tenants",
    scopeHash("ktg-artifact-tenant-v1", context.tenantId),
    "brands",
    scopeHash("ktg-artifact-brand-v1", context.brandId),
    "submissions",
    request.submissionId,
    "packages",
    request.packageId,
    `package-v${Number(packageData.version)}`,
    packageData.aggregateHash,
  ].join("/");
  return {
    pdf: `${base}/official-package.pdf`,
    jsonManifest: `${base}/canonical-manifest.json`,
  };
}
function safeFileToken(value) {
  const clean = String(value || "");
  if (!clean || /[\r\n/\\]/.test(clean) || clean.includes("..") ||
      !/^[A-Za-z0-9._-]+$/.test(clean)) {
    fail("failed-precondition", "submission number unsafe");
  }
  return clean;
}
function boundedFileName(prefix, submissionNumber, version, extension) {
  const token = safeFileToken(submissionNumber);
  let name = `${prefix}_${token}_v${Number(version)}.${extension}`;
  if (name.length > 140) {
    const suffix = sha256(Buffer.from(name, "utf8")).slice(0, 12);
    const budget = 140 - prefix.length - extension.length - suffix.length - 6;
    name = `${prefix}_${token.slice(0, Math.max(1, budget))}_${suffix}.${extension}`;
  }
  if (name.length > 140 || !/^[A-Za-z0-9._-]+$/.test(name)) {
    fail("internal", "safe file name unavailable");
  }
  return name;
}
function safeFileNames(submission, packageData) {
  return {
    pdf: boundedFileName(
        "MarkaKalkan_Gumruk_Basvuru_Paketi",
        submission.submissionNumber,
        packageData.version,
        "pdf",
    ),
    jsonManifest: boundedFileName(
        "MarkaKalkan_Gumruk_Basvuru_Manifesti",
        submission.submissionNumber,
        packageData.version,
        "json",
    ),
  };
}
function normalizeText(value) {
  return String(value == null ? "" : value).normalize("NFC")
      .replace(/\r\n?/g, "\n");
}
function projectionForArtifact(submission, packageId, packageData) {
  return {
    artifactFormatVersion: ARTIFACT_FORMAT_VERSION,
    packageId,
    packageVersion: Number(packageData.version),
    packageType: packageData.packageType,
    submissionId: packageData.submissionId,
    submissionNumber: submission.submissionNumber,
    targetAuthority: submission.targetAuthority,
    targetUnit: submission.targetUnit || null,
    sourcePackageHash: packageData.aggregateHash,
    aggregateHashAlgorithm: packageData.aggregateHashAlgorithm,
    packageGeneratedAt: packageData.generatedAt,
    sourceSnapshot: packageData.sourceSnapshot,
    documentManifest: packageData.documentManifest || [],
    evidenceManifest: packageData.evidenceManifest || [],
    redactionManifest: packageData.redactionManifest || [],
    coverLetterText: packageData.coverLetterText,
    authoritySummary: packageData.authoritySummary,
    legalNeutralityStatement: packageData.legalNeutralityStatement,
  };
}
function wrapText(font, value, size, width) {
  const lines = [];
  for (const paragraph of normalizeText(value).split("\n")) {
    const words = paragraph.split(/\s+/).filter(Boolean);
    if (!words.length) {
      lines.push("");
      continue;
    }
    let line = "";
    for (const word of words) {
      const candidate = line ? `${line} ${word}` : word;
      if (font.widthOfTextAtSize(candidate, size) <= width) {
        line = candidate;
      } else {
        if (line) lines.push(line);
        let remainder = word;
        while (font.widthOfTextAtSize(remainder, size) > width &&
               remainder.length > 1) {
          let cut = remainder.length - 1;
          while (cut > 1 &&
                 font.widthOfTextAtSize(remainder.slice(0, cut), size) >
                   width) cut--;
          lines.push(remainder.slice(0, cut));
          remainder = remainder.slice(cut);
        }
        line = remainder;
      }
    }
    if (line) lines.push(line);
  }
  return lines;
}
async function renderDeterministicPdf({
  submission,
  packageId,
  packageData,
  fontBytes = verifyAssetIdentity().font,
}) {
  const projection = projectionForArtifact(
      submission,
      packageId,
      packageData,
  );
  const document = await PDFDocument.create({updateMetadata: false});
  document.registerFontkit(fontkit);
  const font = await document.embedFont(fontBytes, {subset: false});
  const generatedAt = new Date(packageData.generatedAt);
  if (Number.isNaN(generatedAt.getTime())) {
    fail("failed-precondition", "package generatedAt invalid");
  }
  document.setTitle("MarkaKalkan Gümrük Başvuru Paketi");
  document.setAuthor("MarkaKalkan");
  document.setSubject("İnsan incelemeli resmî başvuru paketi");
  document.setCreator("MarkaKalkan Artifact Renderer v1");
  document.setProducer("MarkaKalkan Artifact Renderer v1");
  document.setCreationDate(generatedAt);
  document.setModificationDate(generatedAt);
  const width = 595.28;
  const height = 841.89;
  const margin = 48;
  const bodySize = 9;
  const lineHeight = 12;
  let page;
  let y;
  const nextPage = () => {
    page = document.addPage([width, height]);
    y = height - margin;
  };
  const line = (value, size = bodySize, color = rgb(0.08, 0.08, 0.08)) => {
    const wrapped = wrapText(font, value, size, width - margin * 2);
    for (const part of wrapped) {
      if (y < margin + lineHeight) nextPage();
      page.drawText(part, {x: margin, y, size, font, color});
      y -= lineHeight;
    }
  };
  const heading = (value) => {
    if (y < margin + 42) nextPage();
    y -= 6;
    line(value, 12, rgb(0.05, 0.20, 0.38));
    y -= 3;
  };
  nextPage();
  line("MarkaKalkan", 18, rgb(0.05, 0.20, 0.38));
  line("Gümrük Başvuru Paketi", 14);
  y -= 10;
  const rows = [
    ["Başvuru numarası", projection.submissionNumber],
    ["Paket kimliği", projection.packageId],
    ["Paket sürümü", projection.packageVersion],
    ["Hedef kurum", projection.targetAuthority],
    ["Hedef birim", projection.targetUnit || "Belirtilmedi"],
    ["Kaynak paket SHA-256", projection.sourcePackageHash],
    ["Artifact formatı", ARTIFACT_FORMAT_VERSION],
  ];
  for (const [label, value] of rows) line(`${label}: ${value}`);
  const sections = [
    ["Profil / müdahale kapsamı", projection.sourceSnapshot],
    ["Başvuru özeti", submission.authoritySummary || projection.authoritySummary],
    ["Üst yazı", projection.coverLetterText],
    ["Kurum özeti", projection.authoritySummary],
    ["Belge manifesti", projection.documentManifest],
    ["Delil manifesti", projection.evidenceManifest],
    ["Redaksiyon manifesti", projection.redactionManifest],
    ["Hukuki tarafsızlık beyanı", projection.legalNeutralityStatement],
  ];
  for (const [title, value] of sections) {
    heading(title);
    line(typeof value === "string" ? value : JSON.stringify(canonicalize(value)));
  }
  const bytes = Buffer.from(await document.save({
    useObjectStreams: false,
    addDefaultPage: false,
    objectsPerTick: Number.MAX_SAFE_INTEGER,
  }));
  if (!bytes.length || bytes.length > MAX_ARTIFACT_BYTES) {
    fail("resource-exhausted", "PDF artifact size limit exceeded");
  }
  return bytes;
}
function renderCanonicalManifest({
  submission,
  packageId,
  packageData,
  pdf,
}) {
  const projection = projectionForArtifact(
      submission,
      packageId,
      packageData,
  );
  const manifest = {
    aggregateHashAlgorithm: projection.aggregateHashAlgorithm,
    artifactFormatVersion: ARTIFACT_FORMAT_VERSION,
    businessSnapshot: {
      authoritySummary: projection.authoritySummary,
      coverLetterText: projection.coverLetterText,
      sourceSnapshot: projection.sourceSnapshot,
      targetAuthority: projection.targetAuthority,
      targetUnit: projection.targetUnit,
    },
    documentManifest: projection.documentManifest,
    evidenceManifest: projection.evidenceManifest,
    legalNeutralityStatement: projection.legalNeutralityStatement,
    packageGeneratedAt: projection.packageGeneratedAt,
    packageId: projection.packageId,
    packageType: projection.packageType,
    packageVersion: projection.packageVersion,
    pdf: {
      contentType: "application/pdf",
      safeFileName: pdf.safeFileName,
      sha256: pdf.sha256,
      sizeBytes: pdf.sizeBytes,
    },
    redactionManifest: projection.redactionManifest,
    schemaVersion: "customs-submission-package-artifact-manifest-v1",
    sourcePackageHash: projection.sourcePackageHash,
    submissionId: projection.submissionId,
    submissionNumber: projection.submissionNumber,
  };
  const bytes = canonicalJson(manifest);
  if (!bytes.length || bytes.length > MAX_ARTIFACT_BYTES) {
    fail("resource-exhausted", "JSON artifact size limit exceeded");
  }
  return bytes;
}
function customMetadata(packageId, packageData, digest) {
  return {
    "artifact-format-version": ARTIFACT_FORMAT_VERSION,
    "source-package-hash": packageData.aggregateHash,
    "sha256": digest,
    "package-id": packageId,
    "package-version": String(packageData.version),
    "font-sha256": FONT_SHA256,
  };
}
function metadataMatches(actual, expected) {
  return Object.entries(expected)
      .every(([key, value]) => actual?.[key] === value);
}
async function boundedStreamHash(file, expectedSize) {
  const hash = createHash("sha256");
  let size = 0;
  for await (const chunk of file.createReadStream({validation: false})) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > MAX_ARTIFACT_BYTES || size > expectedSize) {
      fail("failed-precondition", "artifact object size mismatch");
    }
    hash.update(buffer);
  }
  if (size !== expectedSize) {
    fail("failed-precondition", "artifact object size mismatch");
  }
  return hash.digest("hex");
}
function storageCode(error) {
  return Number(error?.code || error?.statusCode ||
    error?.response?.status || 0);
}
function createStorageAdapter(bucket) {
  async function verifyExpected({
    objectName,
    bytes,
    contentType,
    safeFileName,
    metadata,
  }) {
    const file = bucket.file(objectName);
    let actual;
    try {
      [actual] = await file.getMetadata();
    } catch (error) {
      if (storageCode(error) === 404) return null;
      throw error;
    }
    const generation = String(actual.generation || "");
    if (!/^[1-9][0-9]*$/.test(generation) ||
        actual.bucket !== bucket.name ||
        actual.name !== objectName ||
        actual.contentType !== contentType ||
        Number(actual.size) !== bytes.length ||
        actual.cacheControl !== "private, no-store, max-age=0" ||
        actual.contentDisposition !==
          `attachment; filename="${safeFileName}"` ||
        !metadataMatches(actual.metadata, metadata)) {
      fail("artifact.integrity_failed", "artifact metadata mismatch");
    }
    const versioned = bucket.file(objectName, {generation});
    const digest = await boundedStreamHash(versioned, bytes.length);
    if (digest !== sha256(bytes) || digest !== metadata.sha256) {
      fail("artifact.integrity_failed", "artifact byte hash mismatch");
    }
    return {
      recovered: true,
      bucket: bucket.name,
      objectName,
      generation,
      contentType,
      sizeBytes: bytes.length,
      sha256: digest,
      safeFileName,
    };
  }
  return {
    async createOrVerify({
      objectName,
      bytes,
      contentType,
      safeFileName,
      metadata,
    }, {preferExisting = false} = {}) {
      if (preferExisting) {
        const existing = await verifyExpected({
          objectName,
          bytes,
          contentType,
          safeFileName,
          metadata,
        });
        if (existing) return existing;
      }
      const file = bucket.file(objectName);
      let recovered = false;
      try {
        await file.save(bytes, {
          resumable: false,
          preconditionOpts: {ifGenerationMatch: 0},
          metadata: {
            contentType,
            cacheControl: "private, no-store, max-age=0",
            contentDisposition: `attachment; filename="${safeFileName}"`,
            metadata,
          },
        });
      } catch (error) {
        if (![409, 412].includes(storageCode(error))) throw error;
        recovered = true;
      }
      const verified = await verifyExpected({
        objectName,
        bytes,
        contentType,
        safeFileName,
        metadata,
      });
      if (!verified) fail("unavailable", "artifact object unavailable");
      return {...verified, recovered};
    },
    async verify(descriptor) {
      const file = bucket.file(
          descriptor.objectName,
          {generation: descriptor.generation},
      );
      const [actual] = await file.getMetadata();
      if (actual.bucket !== descriptor.bucket ||
          actual.name !== descriptor.objectName ||
          String(actual.generation || "") !== descriptor.generation ||
          actual.contentType !== descriptor.contentType ||
          Number(actual.size) !== descriptor.sizeBytes ||
          !metadataMatches(actual.metadata, {
            "artifact-format-version": ARTIFACT_FORMAT_VERSION,
            "source-package-hash": descriptor.sourcePackageHash,
            "sha256": descriptor.sha256,
            "package-id": descriptor.packageId,
            "package-version": String(descriptor.packageVersion),
            "font-sha256": FONT_SHA256,
          })) {
        fail("artifact.integrity_failed", "artifact verification failed");
      }
      const digest = await boundedStreamHash(file, descriptor.sizeBytes);
      if (digest !== descriptor.sha256) {
        fail("artifact.integrity_failed", "artifact verification failed");
      }
      return file;
    },
  };
}
function safeArtifactSummary(data) {
  const artifact = data?.artifact;
  const status = artifact?.status || "legacy_not_materialized";
  const safe = (descriptor) => ({
    ready: status === "ready" && Boolean(descriptor),
    contentType: descriptor?.contentType || null,
    sizeBytes: Number(descriptor?.sizeBytes || 0),
    sha256: descriptor?.sha256 || null,
    safeFileName: descriptor?.safeFileName || null,
  });
  return {
    artifactStatus: status,
    artifactFormatVersion: artifact?.formatVersion || null,
    sourcePackageHash: artifact?.sourcePackageHash || null,
    pdf: safe(artifact?.pdf),
    jsonManifest: safe(artifact?.jsonManifest),
  };
}
function safeMaterializeArtifact(artifact) {
  const summary = safeArtifactSummary({artifact});
  return {
    status: summary.artifactStatus,
    formatVersion: summary.artifactFormatVersion,
    sourcePackageHash: summary.sourcePackageHash,
    pdf: summary.pdf,
    jsonManifest: summary.jsonManifest,
  };
}
function assertScope(snapshot, context, request, kind) {
  const data = snapshot.data() || {};
  if (!snapshot.exists ||
      data.tenantId !== context.tenantId ||
      data.canonicalBrandId !== context.brandId ||
      (kind === "package" && data.submissionId !== request.submissionId)) {
    fail("not-found", `${kind} not found`);
  }
  return data;
}
async function ownerRequired(db, context) {
  const snapshot = await db.collection("tenant_memberships")
      .doc(context.membershipId).get();
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.status !== "active" || data.role !== "owner") {
    fail("permission-denied", "owner required");
  }
}
function clockDate(clock) {
  const value = clock.now();
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) fail("internal", "clock invalid");
  return date;
}
function eventId(context, submissionId, requestId) {
  return sha256(Buffer.from(
      `${context.tenantId}|customs-submission-event|${submissionId}|${requestId}`,
      "utf8",
  ));
}
function createArtifactService({
  db,
  storage,
  clock = {now: () => new Date()},
  resolveContext = resolveTenantContextV1,
  renderPdf = renderDeterministicPdf,
  signDownload,
}) {
  async function contextFor(request, uid) {
    if (!uid) fail("unauthenticated", "authentication required");
    const context = await resolveContext({
      db,
      uid,
      request: {
        tenantId: request.tenantId,
        canonicalBrandId: request.canonicalBrandId,
      },
    });
    await ownerRequired(db, context);
    return context;
  }
  return Object.freeze({
    async materialize(raw, invocation) {
      verifyAssetIdentity();
      const request = materializeRequest(raw);
      const context = await contextFor(request, invocation?.uid);
      const requestFingerprint = fingerprint(request);
      const submissionRef = db.collection(SUBMISSION_COLLECTION)
          .doc(request.submissionId);
      const packageRef = db.collection(PACKAGE_COLLECTION)
          .doc(request.packageId);
      const now = clockDate(clock);
      const reservation = await db.runTransaction(async (transaction) => {
        const [submissionSnapshot, packageSnapshot] = await Promise.all([
          transaction.get(submissionRef),
          transaction.get(packageRef),
        ]);
        const submission = assertScope(
            submissionSnapshot,
            context,
            request,
            "submission",
        );
        const packageData = assertScope(
            packageSnapshot,
            context,
            request,
            "package",
        );
        const sourceHash = assertSourcePackage(packageData);
        const existing = packageData.artifact || null;
        if (existing && !READY_STATUSES.has(existing.status)) {
          fail("failed-precondition", "artifact projection invalid");
        }
        if (existing?.status === "ready") {
          if (existing.sourcePackageHash !== sourceHash ||
              existing.formatVersion !== ARTIFACT_FORMAT_VERSION ||
              !existing.pdf || !existing.jsonManifest) {
            fail("artifact.integrity_failed", "ready artifact invalid");
          }
          return {
            ready: true,
            recovered: false,
            submission,
            packageData,
            artifact: existing,
          };
        }
        if (["integrity_failed", "disabled"].includes(existing?.status)) {
          fail("failed-precondition", "artifact unavailable");
        }
        let recovered = existing?.status === "failed_recoverable";
        if (existing?.status === "materializing") {
          if (existing.materializationRequestId === request.requestId) {
            if (existing.materializationRequestFingerprint !==
                requestFingerprint) {
              fail("already-exists", "request fingerprint conflict");
            }
            recovered = true;
          } else {
            const lease = Date.parse(existing.leaseExpiresAt || "");
            if (Number.isFinite(lease) && lease > now.getTime()) {
              fail("failed-precondition", "artifact lease active");
            }
            recovered = true;
          }
        }
        if (existing?.materializationRequestId === request.requestId &&
            existing.materializationRequestFingerprint !==
              requestFingerprint) {
          fail("already-exists", "request fingerprint conflict");
        }
        const names = artifactObjectNames(context, request, packageData);
        const leaseExpiresAt = new Date(now.getTime() + LEASE_MS).toISOString();
        const artifact = {
          status: "materializing",
          formatVersion: ARTIFACT_FORMAT_VERSION,
          sourcePackageHash: sourceHash,
          materializationRequestId: request.requestId,
          materializationRequestFingerprint: requestFingerprint,
          leaseRequestId: request.requestId,
          leaseExpiresAt,
          objectNames: names,
          lastFailureCode: null,
          lastFailureAt: null,
        };
        transaction.update(packageRef, {artifact});
        return {
          ready: false,
          recovered,
          submission,
          packageData,
          artifact,
        };
      });
      if (reservation.ready) {
        return {
          contractVersion: MATERIALIZE_RESULT,
          ok: true,
          duplicate: true,
          transactionApplied: false,
          recovered: false,
          artifactStatus: "ready",
          submissionId: request.submissionId,
          packageId: request.packageId,
          packageVersion: Number(reservation.packageData.version),
          sourcePackageHash: reservation.packageData.aggregateHash,
          artifact: safeMaterializeArtifact(reservation.artifact),
        };
      }
      let pdf;
      let jsonManifest;
      try {
        const names = reservation.artifact.objectNames;
        const files = safeFileNames(
            reservation.submission,
            reservation.packageData,
        );
        const pdfBytes = await renderPdf({
          submission: reservation.submission,
          packageId: request.packageId,
          packageData: reservation.packageData,
        });
        const pdfDigest = sha256(pdfBytes);
        pdf = await storage.createOrVerify({
          objectName: names.pdf,
          bytes: pdfBytes,
          contentType: "application/pdf",
          safeFileName: files.pdf,
          metadata: customMetadata(
              request.packageId,
              reservation.packageData,
              pdfDigest,
          ),
        }, {preferExisting: reservation.recovered});
        const jsonBytes = renderCanonicalManifest({
          submission: reservation.submission,
          packageId: request.packageId,
          packageData: reservation.packageData,
          pdf: {
            safeFileName: files.pdf,
            sizeBytes: pdfBytes.length,
            sha256: pdfDigest,
          },
        });
        const jsonDigest = sha256(jsonBytes);
        jsonManifest = await storage.createOrVerify({
          objectName: names.jsonManifest,
          bytes: jsonBytes,
          contentType: "application/json; charset=utf-8",
          safeFileName: files.jsonManifest,
          metadata: customMetadata(
              request.packageId,
              reservation.packageData,
              jsonDigest,
          ),
        }, {preferExisting: reservation.recovered});
      } catch (error) {
        const failureCode = error.code === "artifact.integrity_failed" ?
          "integrity_failed" : "storage_write_failed";
        await db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(packageRef);
          const data = assertScope(snapshot, context, request, "package");
          if (data.artifact?.materializationRequestId === request.requestId &&
              data.artifact?.materializationRequestFingerprint ===
                requestFingerprint) {
            transaction.update(packageRef, {
              artifact: {
                ...data.artifact,
                status: failureCode === "integrity_failed" ?
                  "integrity_failed" : "failed_recoverable",
                lastFailureCode: failureCode,
                lastFailureAt: clockDate(clock).toISOString(),
              },
            });
          }
        });
        if (error instanceof ArtifactError) throw error;
        fail("unavailable", "artifact storage unavailable");
      }
      const finalNow = clockDate(clock);
      const finalized = await db.runTransaction(async (transaction) => {
        const [submissionSnapshot, packageSnapshot] = await Promise.all([
          transaction.get(submissionRef),
          transaction.get(packageRef),
        ]);
        const submission = assertScope(
            submissionSnapshot,
            context,
            request,
            "submission",
        );
        const packageData = assertScope(
            packageSnapshot,
            context,
            request,
            "package",
        );
        if (assertSourcePackage(packageData) !==
              reservation.packageData.aggregateHash ||
            packageData.artifact?.status !== "materializing" ||
            packageData.artifact?.materializationRequestId !==
              request.requestId ||
            packageData.artifact?.materializationRequestFingerprint !==
              requestFingerprint ||
            Date.parse(packageData.artifact?.leaseExpiresAt || "") <
              finalNow.getTime()) {
          fail("failed-precondition", "artifact reservation changed");
        }
        const artifact = {
          status: "ready",
          formatVersion: ARTIFACT_FORMAT_VERSION,
          sourcePackageHash: packageData.aggregateHash,
          pdf,
          jsonManifest,
          materializedAt: finalNow.toISOString(),
          materializedByUid: invocation.uid,
          materializationRequestId: request.requestId,
          materializationRequestFingerprint: requestFingerprint,
          leaseRequestId: request.requestId,
          leaseExpiresAt: packageData.artifact.leaseExpiresAt,
          lastFailureCode: null,
          lastFailureAt: null,
        };
        const materializedEventId = eventId(
            context,
            request.submissionId,
            `${request.requestId}|artifact-materialized`,
        );
        const eventRef = db.collection(EVENT_COLLECTION)
            .doc(materializedEventId);
        const existingEvent = await transaction.get(eventRef);
        if (existingEvent.exists) {
          const eventData = existingEvent.data() || {};
          if (eventData.requestFingerprint !== requestFingerprint) {
            fail("already-exists", "event fingerprint conflict");
          }
          return {artifact, duplicate: true};
        }
        const sequence = Number(submission.eventCount || 0) + 1;
        transaction.update(packageRef, {artifact});
        transaction.create(eventRef, {
          contractVersion: "customs-submission-event-v1",
          schemaVersion: "customs-submission-event-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          submissionId: request.submissionId,
          sequence,
          eventType: "customs_submission_package_artifact_materialized",
          previousStatus: submission.status,
          nextStatus: submission.status,
          summary: `${submission.submissionNumber} paket artifact'ı üretildi.`,
          reason: "Doğrulanmış resmî paket artifact üretimi.",
          actorUid: invocation.uid,
          actorLabel: "Yetkili kullanıcı",
          recordedAt: finalNow.toISOString(),
          previousEventId: submission.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
          appendOnly: true,
          artifactMetadata: {
            packageId: request.packageId,
            packageVersion: Number(packageData.version),
            sourcePackageHash: packageData.aggregateHash,
            artifactFormatVersion: ARTIFACT_FORMAT_VERSION,
            pdf: {
              sha256: pdf.sha256,
              generation: pdf.generation,
              sizeBytes: pdf.sizeBytes,
            },
            jsonManifest: {
              sha256: jsonManifest.sha256,
              generation: jsonManifest.generation,
              sizeBytes: jsonManifest.sizeBytes,
            },
            materializedByUid: invocation.uid,
            recovered: reservation.recovered ||
              pdf.recovered || jsonManifest.recovered,
          },
        });
        transaction.update(submissionRef, {
          eventCount: sequence,
          lastEventId: materializedEventId,
          lastEventType:
            "customs_submission_package_artifact_materialized",
          lastEventAt: finalNow.toISOString(),
          updatedAt: finalNow.toISOString(),
          updatedByUid: invocation.uid,
        });
        return {artifact, duplicate: false};
      });
      return {
        contractVersion: MATERIALIZE_RESULT,
        ok: true,
        duplicate: finalized.duplicate,
        transactionApplied: !finalized.duplicate,
        recovered: reservation.recovered ||
          pdf.recovered || jsonManifest.recovered,
        artifactStatus: "ready",
        submissionId: request.submissionId,
        packageId: request.packageId,
        packageVersion: Number(reservation.packageData.version),
        sourcePackageHash: reservation.packageData.aggregateHash,
        artifact: safeMaterializeArtifact(finalized.artifact),
      };
    },
    async authorizeDownload(raw, invocation) {
      verifyAssetIdentity();
      const request = downloadRequest(raw);
      const context = await contextFor(request, invocation?.uid);
      const submissionSnapshot = await db.collection(SUBMISSION_COLLECTION)
          .doc(request.submissionId).get();
      assertScope(submissionSnapshot, context, request, "submission");
      const packageSnapshot = await db.collection(PACKAGE_COLLECTION)
          .doc(request.packageId).get();
      const packageData = assertScope(
          packageSnapshot,
          context,
          request,
          "package",
      );
      const sourceHash = assertSourcePackage(packageData);
      const artifact = packageData.artifact || {};
      if (artifact.status !== "ready" ||
          artifact.formatVersion !== ARTIFACT_FORMAT_VERSION ||
          artifact.sourcePackageHash !== sourceHash) {
        fail("failed-precondition", "artifact not ready");
      }
      const descriptor = request.artifactType === "pdf" ?
        artifact.pdf : artifact.jsonManifest;
      if (!descriptor || descriptor.bucket !== BUCKET ||
          !descriptor.objectName || !descriptor.generation ||
          !HEX_64.test(String(descriptor.sha256 || "")) ||
          descriptor.sizeBytes < 1 ||
          descriptor.sizeBytes > MAX_ARTIFACT_BYTES) {
        fail("failed-precondition", "artifact descriptor invalid");
      }
      try {
        await storage.verify({
          ...descriptor,
          sourcePackageHash: sourceHash,
          packageId: request.packageId,
          packageVersion: Number(packageData.version),
        });
      } catch (error) {
        if (error instanceof ArtifactError) throw error;
        fail("unavailable", "artifact verification unavailable");
      }
      const now = clockDate(clock);
      const expiresAt = new Date(now.getTime() + DOWNLOAD_TTL_MS);
      let downloadUrl;
      try {
        downloadUrl = await signDownload({
          descriptor,
          expiresAt,
          artifactType: request.artifactType,
        });
      } catch (_) {
        fail("unavailable", "download authorization unavailable");
      }
      if (typeof downloadUrl !== "string" || !downloadUrl.startsWith("https://")) {
        fail("unavailable", "download authorization unavailable");
      }
      return {
        contractVersion: DOWNLOAD_RESULT,
        ok: true,
        artifactType: request.artifactType,
        downloadUrl,
        expiresAt: expiresAt.toISOString(),
        safeFileName: descriptor.safeFileName,
        contentType: descriptor.contentType,
        sizeBytes: descriptor.sizeBytes,
        sha256: descriptor.sha256,
        generation: descriptor.generation,
        sourcePackageHash: sourceHash,
      };
    },
  });
}
const MATERIALIZER_OPTIONS = Object.freeze({
  region: REGION,
  enforceAppCheck: true,
  maxInstances: 1,
  timeoutSeconds: 300,
  memory: "1GiB",
  serviceAccount: MATERIALIZER_SERVICE_ACCOUNT,
});
const AUTHORIZER_OPTIONS = Object.freeze({
  region: REGION,
  enforceAppCheck: true,
  maxInstances: 3,
  timeoutSeconds: 60,
  memory: "256MiB",
  serviceAccount: AUTHORIZER_SERVICE_ACCOUNT,
});
function mapArtifactError(error) {
  if (error instanceof HttpsError) return error;
  const allowed = new Set([
    "invalid-argument",
    "unauthenticated",
    "permission-denied",
    "not-found",
    "failed-precondition",
    "already-exists",
    "resource-exhausted",
    "unavailable",
  ]);
  const code = error.code === "artifact.integrity_failed" ?
    "failed-precondition" :
    (allowed.has(error.code) ? error.code : "internal");
  const messages = {
    "invalid-argument": "Resmî paket artifact isteği geçersiz.",
    "unauthenticated": "Oturum açmanız gerekir.",
    "permission-denied": "Bu işlem için marka sahibi yetkisi gerekir.",
    "not-found": "Resmî başvuru veya paket bulunamadı.",
    "failed-precondition":
      "Resmî paket artifact işlemi mevcut durumda gerçekleştirilemiyor.",
    "already-exists": "Aynı istek kimliği farklı içerikle kullanılmış.",
    "resource-exhausted": "Resmî paket artifact boyut sınırını aşıyor.",
    "unavailable": "Resmî paket indirme hizmeti şu anda kullanılamıyor.",
    "internal": "Resmî paket artifact işlemi güvenli biçimde tamamlanamadı.",
  };
  return new HttpsError(code, messages[code]);
}
function artifactHandler(method, {
  service,
  appCheck = true,
  log = logger,
}) {
  return async (invocation) => {
    if (!invocation.auth?.uid) {
      throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    }
    if (appCheck && !invocation.app) {
      throw new HttpsError("failed-precondition", "Uygulama doğrulaması gerekir.");
    }
    try {
      const result = await service[method](invocation.data || {}, {
        uid: invocation.auth.uid,
      });
      log.info("customs package artifact callable completed", {
        method,
        duplicate: result.duplicate === true,
        artifactStatus: result.artifactStatus || null,
        artifactType: result.artifactType || null,
      });
      return result;
    } catch (error) {
      throw mapArtifactError(error);
    }
  };
}
function productionService({db, admin, clock, resolveContext}) {
  const bucket = admin.storage().bucket(BUCKET);
  const storage = createStorageAdapter(bucket);
  return createArtifactService({
    db,
    storage,
    clock,
    resolveContext,
    signDownload: async ({descriptor, expiresAt}) => {
      const file = bucket.file(
          descriptor.objectName,
          {generation: descriptor.generation},
      );
      const [url] = await file.getSignedUrl({
        version: "v4",
        action: "read",
        expires: expiresAt,
        promptSaveAs: descriptor.safeFileName,
        responseType: descriptor.contentType,
        queryParams: {generation: descriptor.generation},
      });
      return url;
    },
  });
}
function buildMaterializeCustomsSubmissionPackageArtifact({db, admin}) {
  const service = productionService({db, admin});
  return onCall(
      MATERIALIZER_OPTIONS,
      artifactHandler("materialize", {service}),
  );
}
function buildAuthorizeCustomsSubmissionPackageDownload({db, admin}) {
  const service = productionService({db, admin});
  return onCall(
      AUTHORIZER_OPTIONS,
      artifactHandler("authorizeDownload", {service}),
  );
}

module.exports = {
  ARTIFACT_FORMAT_VERSION,
  AUTHORIZER_OPTIONS,
  AUTHORIZER_SERVICE_ACCOUNT,
  BUCKET,
  DOWNLOAD_REQUEST,
  DOWNLOAD_RESULT,
  DOWNLOAD_TTL_MS,
  FONT_PATH,
  FONT_POSTSCRIPT_NAME,
  FONT_SHA256,
  FONT_VERSION,
  LEASE_MS,
  LICENSE_PATH,
  LICENSE_SHA256,
  MATERIALIZER_OPTIONS,
  MATERIALIZER_SERVICE_ACCOUNT,
  MATERIALIZE_REQUEST,
  MATERIALIZE_RESULT,
  MAX_ARTIFACT_BYTES,
  ArtifactError,
  artifactHandler,
  artifactObjectNames,
  assertSourcePackage,
  boundedFileName,
  buildAuthorizeCustomsSubmissionPackageDownload,
  buildMaterializeCustomsSubmissionPackageArtifact,
  canonicalJson,
  createArtifactService,
  createStorageAdapter,
  downloadRequest,
  mapArtifactError,
  materializeRequest,
  projectionForArtifact,
  productionService,
  renderCanonicalManifest,
  renderDeterministicPdf,
  safeArtifactSummary,
  safeMaterializeArtifact,
  safeFileNames,
  sourcePackageProjection,
  verifyAssetIdentity,
};
