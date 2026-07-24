/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const MAX_MANIFEST_BYTES = 650000;
const MAX_PACKAGES_PER_CASE = 50;
const PURPOSES = new Set(["legal_review", "regulatory_submission", "internal_investigation", "customer_response", "other"]);
const SECTION_LIMITS = Object.freeze({
  case_events: 500,
  case_evidence_refs: 200,
  case_audit_events: 500,
  case_evidence_chain_events: 1000,
  case_review_tasks: 200,
  case_review_task_events: 1000,
  case_parties: 300,
  case_relationships: 500,
  case_graph_events: 1000,
  case_legal_holds: 100,
  case_legal_hold_events: 300,
  case_retention_records: 5,
  case_retention_events: 300,
});

class CaseExportError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CaseExportError";
    this.code = code;
  }
}

const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

function objectRequired(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CaseExportError("invalid-argument", "request object required");
  }
}
function strict(raw, contractVersion, fields) {
  objectRequired(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  if (raw.contractVersion !== contractVersion) throw new CaseExportError("invalid-argument", "contractVersion invalid");
  if (Object.keys(raw).some((key) => !allowed.has(key))) throw new CaseExportError("invalid-argument", "unsupported request fields");
}
function text(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== "string") throw new CaseExportError("invalid-argument", `${field} invalid`);
  const clean = value.trim();
  if (clean.length < minimum || clean.length > maximum) throw new CaseExportError("invalid-argument", `${field} invalid`);
  return clean;
}
function requestId(value) {
  const clean = text(value, "requestId", 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(clean)) throw new CaseExportError("invalid-argument", "requestId invalid");
  return clean.toLowerCase();
}
function digest(value, field) {
  const clean = text(value, field, 64, 64).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(clean)) throw new CaseExportError("invalid-argument", `${field} invalid`);
  return clean;
}
function readinessRequest(raw) {
  strict(raw, "case-export-readiness-request-v1", ["caseId"]);
  return {caseId: text(raw.caseId, "caseId", 1, 128)};
}
function listRequest(raw) {
  strict(raw, "case-export-package-list-request-v1", ["caseId", "pageSize"]);
  const pageSize = raw.pageSize == null ? 25 : raw.pageSize;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) throw new CaseExportError("invalid-argument", "pageSize invalid");
  return {caseId: text(raw.caseId, "caseId", 1, 128), pageSize};
}
function createRequest(raw) {
  strict(raw, "case-export-package-create-request-v1", ["caseId", "purpose", "note", "expectedManifestDigestSha256", "requestId"]);
  const purpose = text(raw.purpose, "purpose", 1, 80);
  if (!PURPOSES.has(purpose)) throw new CaseExportError("invalid-argument", "purpose invalid");
  return {
    caseId: text(raw.caseId, "caseId", 1, 128),
    purpose,
    note: text(raw.note, "note", 1, 2000, true),
    expectedManifestDigestSha256: digest(raw.expectedManifestDigestSha256, "expectedManifestDigestSha256"),
    requestId: requestId(raw.requestId),
  };
}
function detailRequest(raw) {
  strict(raw, "case-export-package-detail-request-v1", ["packageId"]);
  return {packageId: digest(raw.packageId, "packageId")};
}

function normalized(value) {
  if (value === undefined) return undefined;
  if (value === null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new CaseExportError("failed-precondition", "non-finite number in export source");
    return value;
  }
  if (value instanceof Date) return value.toISOString();
  if (typeof value?.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(normalized).filter((item) => item !== undefined);
  if (typeof value === "object") {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      if (["__proto__", "prototype", "constructor"].includes(key)) throw new CaseExportError("failed-precondition", "unsafe export source key");
      const item = normalized(value[key]);
      if (item !== undefined) result[key] = item;
    }
    return result;
  }
  throw new CaseExportError("failed-precondition", "unsupported export source value");
}
function canonicalJson(value) {
  return JSON.stringify(normalized(value));
}
function snapshotOf(snapshot) {
  return {id: snapshot.id, data: snapshot.data() || {}};
}
function recordSnapshot(collection, item) {
  const data = normalized(item.data);
  return Object.freeze({
    recordId: item.id,
    digestSha256: sha256(canonicalJson({collection, recordId: item.id, data})),
    data,
  });
}
function packageSummary(data) {
  return {
    packageId: data.packageId,
    caseId: data.caseId,
    caseNumber: data.caseNumber,
    purpose: data.purpose,
    status: data.status,
    manifestDigestSha256: data.manifestDigestSha256,
    manifestBytes: data.manifestBytes,
    totalRecordCount: data.totalRecordCount,
    binaryEvidenceIncluded: false,
    createdAt: data.createdAt,
    duplicate: false,
  };
}
function exportPackageId(context, request) {
  return sha256(`${context.tenantId}|case-export|${request.caseId}|${request.requestId}`);
}
function requestFingerprint(request) {
  return sha256(canonicalJson({
    caseId: request.caseId,
    purpose: request.purpose,
    note: request.note,
    expectedManifestDigestSha256: request.expectedManifestDigestSha256,
  }));
}

async function ownerRequired({db, context}) {
  const snapshot = await db.collection("tenant_memberships").where("tenantId", "==", context.tenantId).where("uid", "==", context.uid).limit(2).get();
  const memberships = snapshot.docs.map(snapshotOf).filter((item) => item.data.status === "active");
  if (memberships.length !== 1 || memberships[0].data.role !== "owner") throw new CaseExportError("permission-denied", "owner required");
}
async function scopedCase({db, context, caseId, transaction = null}) {
  const ref = db.collection("case_files").doc(caseId);
  const snapshot = transaction ? await transaction.get(ref) : await ref.get();
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseExportError("not-found", "case not found");
  return {ref, id: snapshot.id, data};
}
async function readSection({db, context, caseId, collection, maximum, transaction = null}) {
  const query = db.collection(collection).where("caseId", "==", caseId).limit(maximum + 1);
  const snapshot = transaction ? await transaction.get(query) : await query.get();
  const items = snapshot.docs.map(snapshotOf);
  if (items.some((item) => item.data.tenantId !== context.tenantId || item.data.canonicalBrandId !== context.brandId)) throw new CaseExportError("failed-precondition", `${collection} scope mismatch`);
  if (items.length > maximum) throw new CaseExportError("resource-exhausted", `${collection} export limit exceeded`);
  return items.sort((a, b) => a.id.localeCompare(b.id)).map((item) => recordSnapshot(collection, item));
}
function legalHoldSnapshot(caseData) {
  const value = caseData.legalHold || {};
  return normalized({
    active: value.active === true,
    activeCount: Number(value.activeCount || 0),
    latestHoldId: value.latestHoldId || null,
    startedAt: value.startedAt || null,
    releasedAt: value.releasedAt || null,
    lastChangedAt: value.lastChangedAt || null,
  });
}
function retentionSnapshot(caseData) {
  const value = caseData.retention || {};
  return normalized({
    active: value.active === true,
    recordId: value.recordId || null,
    policyCode: value.policyCode || null,
    policyName: value.policyName || null,
    policyVersion: Number(value.policyVersion || 0),
    anchorType: value.anchorType || null,
    anchorAt: value.anchorAt || null,
    retainUntil: value.retainUntil || null,
    dispositionStatus: value.dispositionStatus || null,
    dispositionEligible: value.dispositionEligible === true,
    blockedReason: value.blockedReason || null,
    lastAssessedAt: value.lastAssessedAt || null,
    lastChangedAt: value.lastChangedAt || null,
  });
}
async function buildManifest({db, context, caseId, transaction = null}) {
  const linkedCase = await scopedCase({db, context, caseId, transaction});
  const sections = [];
  for (const [collection, maximum] of Object.entries(SECTION_LIMITS)) {
    const records = await readSection({db, context, caseId, collection, maximum, transaction});
    sections.push(Object.freeze({collection, recordCount: records.length, records}));
  }
  const caseRecord = recordSnapshot("case_files", {id: linkedCase.id, data: linkedCase.data});
  const totalRecordCount = 1 + sections.reduce((sum, section) => sum + section.recordCount, 0);
  const manifest = Object.freeze({
    contractVersion: "case-export-manifest-v1",
    schemaVersion: "case-export-manifest-schema-v1",
    packageFormat: "application/vnd.markakalkan.case-evidence+json",
    exportMode: "metadata_snapshot",
    case: caseRecord,
    caseIdentity: normalized({
      caseId: linkedCase.id,
      caseNumber: linkedCase.data.caseNumber || null,
      title: linkedCase.data.title || null,
      status: linkedCase.data.status || null,
      stage: linkedCase.data.stage || null,
    }),
    tenantScope: {tenantId: context.tenantId, canonicalBrandId: context.brandId},
    legalHold: legalHoldSnapshot(linkedCase.data),
    retention: retentionSnapshot(linkedCase.data),
    binaryEvidence: {
      included: false,
      reason: "case_evidence_records_have_no_server_managed_storage_object_binding",
    },
    snapshotBoundary: "consistent_firestore_transaction_before_export_audit_commit",
    sections,
    totalRecordCount,
  });
  const manifestJson = canonicalJson(manifest);
  const manifestBytes = Buffer.byteLength(manifestJson, "utf8");
  if (manifestBytes > MAX_MANIFEST_BYTES) throw new CaseExportError("resource-exhausted", "export manifest byte limit exceeded");
  return {
    linkedCase,
    manifest,
    manifestJson,
    manifestBytes,
    manifestDigestSha256: sha256(manifestJson),
    sectionCounts: Object.fromEntries(sections.map((section) => [section.collection, section.recordCount])),
    totalRecordCount,
  };
}

function createCaseExportService({db, clock = {now: () => new Date().toISOString()}, resolveContext = resolveTenantContextV1}) {
  return Object.freeze({
    async readiness(raw, invocation) {
      const request = readinessRequest(raw);
      if (!invocation?.uid) throw new CaseExportError("unauthenticated", "authentication required");
      const context = {...await resolveContext({db, uid: invocation.uid, request: {}}), uid: invocation.uid};
      await ownerRequired({db, context});
      const built = await db.runTransaction((transaction) => buildManifest({db, context, caseId: request.caseId, transaction}));
      return {
        contractVersion: "case-export-readiness-v1",
        caseId: built.linkedCase.id,
        caseNumber: built.linkedCase.data.caseNumber,
        ready: true,
        manifestDigestSha256: built.manifestDigestSha256,
        estimatedManifestBytes: built.manifestBytes,
        maximumManifestBytes: MAX_MANIFEST_BYTES,
        totalRecordCount: built.totalRecordCount,
        sectionCounts: built.sectionCounts,
        legalHold: built.manifest.legalHold,
        retention: built.manifest.retention,
        binaryEvidenceIncluded: false,
        binaryEvidenceExclusionReason: built.manifest.binaryEvidence.reason,
        readOnly: true,
        writesPerformed: 0,
      };
    },
    async listPackages(raw, invocation) {
      const request = listRequest(raw);
      if (!invocation?.uid) throw new CaseExportError("unauthenticated", "authentication required");
      const context = {...await resolveContext({db, uid: invocation.uid, request: {}}), uid: invocation.uid};
      await ownerRequired({db, context});
      await scopedCase({db, context, caseId: request.caseId});
      const snapshot = await db.collection("case_export_packages").where("caseId", "==", request.caseId).limit(MAX_PACKAGES_PER_CASE + 1).get();
      const items = snapshot.docs.map(snapshotOf);
      if (items.some((item) => item.data.tenantId !== context.tenantId || item.data.canonicalBrandId !== context.brandId || item.data.packageId !== item.id)) throw new CaseExportError("failed-precondition", "export package scope or identity mismatch");
      if (items.length > MAX_PACKAGES_PER_CASE) throw new CaseExportError("resource-exhausted", "case export package limit exceeded");
      const ordered = items.map((item) => packageSummary(item.data)).sort((a, b) => {
        const byCreatedAt = String(b.createdAt || "").localeCompare(String(a.createdAt || ""));
        return byCreatedAt || String(b.packageId || "").localeCompare(String(a.packageId || ""));
      });
      const hasMore = ordered.length > request.pageSize;
      const packages = ordered.slice(0, request.pageSize);
      return {
        contractVersion: "case-export-package-list-v1",
        caseId: request.caseId,
        packages,
        hasMore,
        totalPackageCount: ordered.length,
        maximumPackagesPerCase: MAX_PACKAGES_PER_CASE,
        readOnly: true,
        writesPerformed: 0,
      };
    },
    async createPackage(raw, invocation) {
      const request = createRequest(raw);
      if (!invocation?.uid) throw new CaseExportError("unauthenticated", "authentication required");
      const context = {...await resolveContext({db, uid: invocation.uid, request: {}}), uid: invocation.uid};
      await ownerRequired({db, context});
      const packageId = exportPackageId(context, request);
      const packageRef = db.collection("case_export_packages").doc(packageId);
      const fingerprint = requestFingerprint(request);
      const createdAt = clock.now();
      const eventId = sha256(`${packageId}|created`);
      return db.runTransaction(async (transaction) => {
        const existing = await transaction.get(packageRef);
        if (existing.exists) {
          const data = existing.data() || {};
          if (data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId || data.caseId !== request.caseId || data.packageId !== packageId) throw new CaseExportError("failed-precondition", "export package identity mismatch");
          if (data.requestFingerprint !== fingerprint) throw new CaseExportError("already-exists", "requestId conflict");
          return {...packageSummary(data), duplicate: true};
        }
        const packageSnapshot = await transaction.get(db.collection("case_export_packages").where("caseId", "==", request.caseId).limit(MAX_PACKAGES_PER_CASE + 1));
        const packageItems = packageSnapshot.docs.map(snapshotOf);
        if (packageItems.some((item) => item.data.tenantId !== context.tenantId || item.data.canonicalBrandId !== context.brandId || item.data.packageId !== item.id)) throw new CaseExportError("failed-precondition", "export package scope or identity mismatch");
        if (packageItems.length >= MAX_PACKAGES_PER_CASE) throw new CaseExportError("resource-exhausted", "case export package limit exceeded");
        const built = await buildManifest({db, context, caseId: request.caseId, transaction});
        if (built.manifestDigestSha256 !== request.expectedManifestDigestSha256) throw new CaseExportError("failed-precondition", "export snapshot changed");
        const packageData = {
          contractVersion: "case-export-package-v1",
          schemaVersion: "case-export-package-schema-v1",
          packageId,
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: request.caseId,
          caseNumber: built.linkedCase.data.caseNumber,
          purpose: request.purpose,
          note: request.note,
          status: "ready",
          packageFormat: built.manifest.packageFormat,
          exportMode: built.manifest.exportMode,
          manifestDigestSha256: built.manifestDigestSha256,
          manifestBytes: built.manifestBytes,
          manifestJson: built.manifestJson,
          totalRecordCount: built.totalRecordCount,
          sectionCounts: built.sectionCounts,
          binaryEvidenceIncluded: false,
          binaryEvidenceExclusionReason: built.manifest.binaryEvidence.reason,
          legalHoldSnapshot: built.manifest.legalHold,
          retentionSnapshot: built.manifest.retention,
          requestId: request.requestId,
          requestFingerprint: fingerprint,
          createdByUid: invocation.uid,
          createdAt,
          appendOnly: true,
        };
        transaction.create(packageRef, packageData);
        transaction.create(db.collection("case_export_events").doc(eventId), {
          contractVersion: "case-export-event-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: request.caseId,
          packageId,
          eventType: "package_created",
          manifestDigestSha256: built.manifestDigestSha256,
          manifestBytes: built.manifestBytes,
          totalRecordCount: built.totalRecordCount,
          actorUid: invocation.uid,
          occurredAt: createdAt,
          appendOnly: true,
        });
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {
          contractVersion: "case-event-v1",
          caseId: request.caseId,
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          eventType: "case_export_package_created",
          category: "export",
          summary: `${built.linkedCase.data.caseNumber} için delil paketi manifesti oluşturuldu.`,
          occurredAt: createdAt,
          actorUid: invocation.uid,
          appendOnly: true,
        });
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {
          contractVersion: "case-audit-event-v1",
          caseId: request.caseId,
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          action: "case_export.package_created",
          actorUid: invocation.uid,
          occurredAt: createdAt,
          packageId,
          manifestDigestSha256: built.manifestDigestSha256,
          appendOnly: true,
        });
        return packageSummary(packageData);
      });
    },
    async packageDetail(raw, invocation) {
      const request = detailRequest(raw);
      if (!invocation?.uid) throw new CaseExportError("unauthenticated", "authentication required");
      const context = {...await resolveContext({db, uid: invocation.uid, request: {}}), uid: invocation.uid};
      await ownerRequired({db, context});
      const snapshot = await db.collection("case_export_packages").doc(request.packageId).get();
      const data = snapshot.data() || {};
      if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) throw new CaseExportError("not-found", "export package not found");
      if (snapshot.id !== request.packageId || data.packageId !== snapshot.id) throw new CaseExportError("failed-precondition", "export package identity mismatch");
      if (typeof data.manifestJson !== "string" || data.manifestJson.length < 2 || Buffer.byteLength(data.manifestJson, "utf8") > MAX_MANIFEST_BYTES) throw new CaseExportError("failed-precondition", "export package manifest invalid");
      const manifestJson = data.manifestJson;
      const actualDigest = sha256(manifestJson);
      if (actualDigest !== data.manifestDigestSha256 || Buffer.byteLength(manifestJson, "utf8") !== data.manifestBytes) throw new CaseExportError("failed-precondition", "export package integrity mismatch");
      let manifest;
      try {
        manifest = JSON.parse(manifestJson);
      } catch (_) {
        throw new CaseExportError("failed-precondition", "export package manifest invalid");
      }
      if (canonicalJson(manifest) !== manifestJson) throw new CaseExportError("failed-precondition", "export package manifest is not canonical");
      if (manifest.contractVersion !== "case-export-manifest-v1" || manifest.schemaVersion !== "case-export-manifest-schema-v1" || manifest.packageFormat !== data.packageFormat || manifest.exportMode !== data.exportMode) throw new CaseExportError("failed-precondition", "export package manifest contract mismatch");
      if (manifest.tenantScope?.tenantId !== data.tenantId || manifest.tenantScope?.canonicalBrandId !== data.canonicalBrandId || manifest.caseIdentity?.caseId !== data.caseId || manifest.case?.recordId !== data.caseId) throw new CaseExportError("failed-precondition", "export package manifest scope mismatch");
      if (manifest.totalRecordCount !== data.totalRecordCount || canonicalJson(manifest.legalHold) !== canonicalJson(data.legalHoldSnapshot) || canonicalJson(manifest.retention) !== canonicalJson(data.retentionSnapshot)) throw new CaseExportError("failed-precondition", "export package manifest metadata mismatch");
      const manifestSectionCounts = Object.fromEntries((manifest.sections || []).map((section) => [section.collection, section.recordCount]));
      if (canonicalJson(manifestSectionCounts) !== canonicalJson(data.sectionCounts) || manifest.binaryEvidence?.included !== false || data.binaryEvidenceIncluded !== false) throw new CaseExportError("failed-precondition", "export package manifest section mismatch");
      return {
        contractVersion: "case-export-package-detail-v1",
        package: packageSummary(data),
        manifest,
        manifestJson,
        integrityStatus: "verified",
        readOnly: true,
        writesPerformed: 0,
      };
    },
  });
}

function invocationOf(request) {
  return {uid: request.auth?.uid || null, app: request.app || null};
}
function mapError(error) {
  if (error instanceof HttpsError) return error;
  const code = error?.code || "internal";
  const allowed = new Set(["invalid-argument", "unauthenticated", "permission-denied", "not-found", "already-exists", "failed-precondition", "resource-exhausted"]);
  return new HttpsError(allowed.has(code) ? code : "internal", error?.message || "case export failed");
}
function createHandler(method, {db, appCheck = true}) {
  const service = createCaseExportService({db});
  return async (request) => {
    try {
      const invocation = invocationOf(request);
      if (!invocation.uid) throw new CaseExportError("unauthenticated", "authentication required");
      if (appCheck && !invocation.app) throw new CaseExportError("failed-precondition", "App Check required");
      return await service[method](request.data, invocation);
    } catch (error) {
      throw mapError(error);
    }
  };
}
function buildGetCaseExportReadiness({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createHandler("readiness", {db, appCheck: false}));
}
function buildListCaseExportPackages({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createHandler("listPackages", {db, appCheck: false}));
}
function buildCreateCaseExportPackage({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: true, maxInstances: 1}, createHandler("createPackage", {db}));
}
function buildGetCaseExportPackageDetail({db}) {
  return onCall({region: "europe-west3", enforceAppCheck: false, maxInstances: 3}, createHandler("packageDetail", {db, appCheck: false}));
}

module.exports = {
  MAX_MANIFEST_BYTES,
  MAX_PACKAGES_PER_CASE,
  SECTION_LIMITS,
  CaseExportError,
  readinessRequest,
  listRequest,
  createRequest,
  detailRequest,
  canonicalJson,
  createCaseExportService,
  createHandler,
  buildGetCaseExportReadiness,
  buildListCaseExportPackages,
  buildCreateCaseExportPackage,
  buildGetCaseExportPackageDetail,
};
