/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");

const REGION = "europe-west3";
const SERVICE_ACCOUNT = "hms-case-evidence@markakalkan-app.iam.gserviceaccount.com";
const BUCKET = "markakalkan-app-hms-evidence-1038407696535";
const MAX_SIZE_BYTES = 25 * 1024 * 1024;
const SESSION_TTL_MS = 60 * 60 * 1000;
const SESSION_ISSUE_WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_SESSION_ISSUES_PER_WINDOW = 5;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HEX_64 = /^[0-9a-f]{64}$/;
const ORIGINS = new Set([
  "https://markakalkan-app.web.app",
  "https://markakalkan-app.firebaseapp.com",
  "https://markakalkan.com",
  "https://www.markakalkan.com",
]);
const MIME_EXTENSIONS = Object.freeze({
  "application/pdf": "pdf",
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "text/plain": "txt",
  "text/csv": "csv",
  "application/zip": "zip",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx",
  "application/vnd.oasis.opendocument.text": "odt",
  "application/vnd.oasis.opendocument.spreadsheet": "ods",
  "application/vnd.oasis.opendocument.presentation": "odp",
});
const MIME_FILE_EXTENSIONS = Object.freeze({
  ...Object.fromEntries(Object.entries(MIME_EXTENSIONS).map(([mime, extension]) => [mime, Object.freeze([extension])])),
  "image/jpeg": Object.freeze(["jpg", "jpeg"]),
});
const CLOSED_CASE_STATUSES = new Set(["closed", "archived", "cancelled"]);
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

class EvidenceObjectBindingError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "EvidenceObjectBindingError";
    this.code = code;
  }
}
const fail = (message, code = "invalid-argument") => {
  throw new EvidenceObjectBindingError(code, message);
};
function object(value, name = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail(`${name} invalid`);
  return value;
}
function text(value, name, min, max) {
  if (typeof value !== "string") fail(`${name} invalid`);
  const clean = value.trim();
  if (clean.length < min || clean.length > max || [...clean].some((character) => {
    const code = character.charCodeAt(0);
    return code === 127 || code < 32;
  })) fail(`${name} invalid`);
  return clean;
}
function strict(raw, contractVersion, fields) {
  object(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  if (raw.contractVersion !== contractVersion || Object.keys(raw).some((key) => !allowed.has(key))) fail("request contract invalid");
}
function requestId(value) {
  const clean = text(value, "requestId", 36, 36).toLowerCase();
  if (!UUID.test(clean)) fail("requestId invalid");
  return clean;
}
function documentId(value, name) {
  const clean = text(value, name, 1, 128);
  if (clean === "." || clean === ".." || clean.includes("/") || clean.includes("\\")) fail(`${name} invalid`);
  return clean;
}
function hexIdentifier(value, name) {
  const clean = text(value, name, 64, 64);
  if (!HEX_64.test(clean)) fail(`${name} invalid`);
  return clean;
}
function safeFileName(value, contentType) {
  const clean = text(value, "fileName", 1, 160);
  if (clean === "." || clean === ".." || clean.includes("/") || clean.includes("\\")) fail("fileName invalid");
  const separator = clean.lastIndexOf(".");
  if (separator <= 0 || separator === clean.length - 1) fail("fileName extension invalid");
  const extension = clean.slice(separator + 1).toLowerCase();
  if (!MIME_FILE_EXTENSIONS[contentType]?.includes(extension)) fail("fileName contentType mismatch");
  return clean;
}
function positiveInteger(value, name, maximum = Number.MAX_SAFE_INTEGER) {
  if (!Number.isSafeInteger(value) || value < 1 || value > maximum) fail(`${name} invalid`);
  return value;
}
function createRequest(raw) {
  strict(raw, "case-evidence-upload-session-create-request-v1", ["caseId", "evidenceRefId", "fileName", "contentType", "sizeBytes", "requestId"]);
  const contentType = text(raw.contentType, "contentType", 3, 160).toLowerCase();
  if (!MIME_EXTENSIONS[contentType]) fail("contentType invalid");
  return {
    caseId: documentId(raw.caseId, "caseId"),
    evidenceRefId: documentId(raw.evidenceRefId, "evidenceRefId"),
    fileName: safeFileName(raw.fileName, contentType),
    contentType,
    sizeBytes: positiveInteger(raw.sizeBytes, "sizeBytes", MAX_SIZE_BYTES),
    requestId: requestId(raw.requestId),
  };
}
function finalizeRequest(raw) {
  strict(raw, "case-evidence-upload-finalize-request-v1", ["uploadSessionId", "generation", "requestId"]);
  const generation = text(raw.generation, "generation", 1, 32);
  if (!/^[1-9][0-9]*$/.test(generation)) fail("generation invalid");
  return {
    uploadSessionId: hexIdentifier(raw.uploadSessionId, "uploadSessionId"),
    generation,
    requestId: requestId(raw.requestId),
  };
}
function detailRequest(raw) {
  strict(raw, "case-evidence-object-detail-request-v1", ["evidenceObjectId"]);
  return {evidenceObjectId: hexIdentifier(raw.evidenceObjectId, "evidenceObjectId")};
}
function originFromInvocation(invocation) {
  const value = invocation?.rawRequest?.headers?.origin;
  if (typeof value !== "string" || !ORIGINS.has(value)) fail("origin denied", "permission-denied");
  return value;
}
function assertInvocation(invocation, appCheck) {
  if (!invocation?.auth?.uid) fail("authentication required", "unauthenticated");
  if (appCheck && !invocation?.app?.appId) fail("app check required", "failed-precondition");
}
function assertScope(snapshot, context, caseId, code = "not-found") {
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId || (caseId && data.caseId !== caseId)) fail("record not found", code);
  return data;
}
function assertCaseOpen(caseData) {
  if (CLOSED_CASE_STATUSES.has(String(caseData.status || "").toLowerCase())) fail("case closed", "failed-precondition");
}
function pathKeys(context, caseId, evidenceRefId) {
  return {
    tenant: sha256(context.tenantId).slice(0, 24),
    caseKey: sha256(caseId).slice(0, 24),
    evidenceKey: sha256(evidenceRefId).slice(0, 24),
  };
}
function serverStagingObjectName(context, caseId, evidenceRefId, sessionId, contentType) {
  const {tenant, caseKey, evidenceKey} = pathKeys(context, caseId, evidenceRefId);
  return `case-evidence-staging/${tenant}/${caseKey}/${evidenceKey}/${sessionId}/upload.${MIME_EXTENSIONS[contentType]}`;
}
function serverEvidenceObjectName(context, caseId, evidenceRefId, sessionId, contentType) {
  const {tenant, caseKey, evidenceKey} = pathKeys(context, caseId, evidenceRefId);
  return `case-evidence/${tenant}/${caseKey}/${evidenceKey}/${sessionId}/evidence.${MIME_EXTENSIONS[contentType]}`;
}
const serverObjectName = serverStagingObjectName;
function metadataFor({context, request, sessionId, objectStage = "staging", digest = null, sourceGeneration = null}) {
  const metadata = {
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    caseId: request.caseId,
    evidenceRefId: request.evidenceRefId,
    uploadSessionId: sessionId,
    objectStage,
  };
  if (digest) metadata.sha256 = digest;
  if (sourceGeneration) metadata.sourceGeneration = String(sourceGeneration);
  return metadata;
}
function iso(value) {
  if (value == null) return null;
  try {
    const date = value instanceof Date ? value : value.toDate?.();
    if (date instanceof Date && !Number.isNaN(date.getTime())) return date.toISOString();
    if (typeof value === "string" && value.trim() && !Number.isNaN(Date.parse(value))) return new Date(value).toISOString();
  } catch (_) {
    return null;
  }
  return null;
}
function metadataMatches(actual, expected) {
  return Object.entries(expected).every(([key, value]) => actual?.[key] === value);
}
async function streamSha256(file, expectedSizeBytes = null) {
  const hash = createHash("sha256");
  let byteCount = 0;
  for await (const chunk of file.createReadStream({validation: false})) {
    const size = Buffer.isBuffer(chunk) ? chunk.length : Buffer.byteLength(chunk);
    byteCount += size;
    if (expectedSizeBytes != null && byteCount > expectedSizeBytes) fail("object size mismatch", "failed-precondition");
    hash.update(chunk);
  }
  if (expectedSizeBytes != null && byteCount !== expectedSizeBytes) fail("object size mismatch", "failed-precondition");
  return {digest: hash.digest("hex"), byteCount};
}
function createGoogleUploadInitiator({credential, fetchImpl = global.fetch}) {
  return async ({bucket, objectName, contentType, sizeBytes, metadata, origin}) => {
    if (!credential || typeof credential.getAccessToken !== "function" || typeof fetchImpl !== "function") throw new Error("storage upload authentication unavailable");
    const tokenResult = await credential.getAccessToken();
    const token = typeof tokenResult === "string" ? tokenResult : tokenResult?.access_token;
    if (!token) throw new Error("storage upload authentication unavailable");
    const url = new URL(`https://storage.googleapis.com/upload/storage/v1/b/${encodeURIComponent(bucket)}/o`);
    url.searchParams.set("uploadType", "resumable");
    url.searchParams.set("ifGenerationMatch", "0");
    url.searchParams.set("name", objectName);
    const response = await fetchImpl(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json; charset=utf-8",
        "Origin": origin,
        "X-Upload-Content-Length": String(sizeBytes),
        "X-Upload-Content-Type": contentType,
      },
      body: JSON.stringify({name: objectName, contentType, metadata}),
    });
    const uploadUri = response.headers.get("location");
    if (!response.ok || !uploadUri) throw new Error(`resumable upload initiation failed (${response.status})`);
    return uploadUri;
  };
}
function storageErrorCode(error) {
  return Number(error?.code || error?.statusCode || error?.response?.status || 0);
}
function createStorageObjectPromoter() {
  return async ({bucket, sourceFile, destinationObjectName, contentType, metadata}) => {
    const destination = bucket.file(destinationObjectName);
    let duplicate = false;
    let metadataResult;
    try {
      const [copiedFile] = await sourceFile.copy(destination, {
        preconditionOpts: {ifGenerationMatch: 0},
        cacheControl: "private, no-store, max-age=0",
        contentType,
        metadata,
      });
      const metadataFile = copiedFile && typeof copiedFile.getMetadata === "function" ? copiedFile : destination;
      [metadataResult] = await metadataFile.getMetadata();
    } catch (error) {
      if (![409, 412].includes(storageErrorCode(error))) throw error;
      duplicate = true;
      [metadataResult] = await destination.getMetadata();
    }
    const generation = String(metadataResult?.generation || "");
    if (!/^[1-9][0-9]*$/.test(generation)) throw new Error("promoted object generation unavailable");
    return {
      duplicate,
      file: bucket.file(destinationObjectName, {generation}),
      metadata: metadataResult,
    };
  };
}
function sessionContractMatches(existing, context, request, bucketName, objectName) {
  return existing.tenantId === context.tenantId &&
    existing.canonicalBrandId === context.brandId &&
    existing.caseId === request.caseId &&
    existing.evidenceRefId === request.evidenceRefId &&
    existing.requestId === request.requestId &&
    existing.bucket === bucketName &&
    existing.objectName === objectName &&
    existing.originalFileName === request.fileName &&
    existing.contentType === request.contentType &&
    Number(existing.sizeBytes) === request.sizeBytes;
}
function uploadWindow(summary, now) {
  const priorStart = iso(summary.uploadSessionWindowStartedAt);
  const priorCount = Number(summary.uploadSessionIssueCount || 0);
  const priorStartMs = priorStart ? Date.parse(priorStart) : Number.NaN;
  if (!Number.isFinite(priorStartMs) || priorStartMs + SESSION_ISSUE_WINDOW_MS <= now.getTime()) {
    return {startedAt: now, issueCount: 0};
  }
  return {startedAt: new Date(priorStartMs), issueCount: Number.isSafeInteger(priorCount) && priorCount >= 0 ? priorCount : 0};
}
function activeSessionAvailable(summary, now, sessionId) {
  const activeId = typeof summary.activeUploadSessionId === "string" ? summary.activeUploadSessionId : "";
  const activeStatus = typeof summary.activeUploadStatus === "string" ? summary.activeUploadStatus : "";
  const activeExpiresAt = iso(summary.activeUploadExpiresAt);
  if (!activeId || activeId === sessionId) return false;
  if (activeStatus === "promotion_pending") return true;
  return Boolean(activeExpiresAt && Date.parse(activeExpiresAt) > now.getTime());
}
function createEvidenceObjectBindingService({db, bucket, initiateUpload, promoteObject = createStorageObjectPromoter(), clock}) {
  const bucketName = typeof bucket === "string" ? bucket : bucket.name;
  const nowDate = () => {
    const value = clock.now();
    return value instanceof Date ? value : new Date(value);
  };
  const stamp = (date) => clock.timestamp ? clock.timestamp(date) : date.toISOString();
  async function contextFor(uid) {
    return resolveTenantContextV1({db, uid, request: {}});
  }
  return Object.freeze({
    async createUploadSession(raw, invocation) {
      const request = createRequest(raw);
      const origin = originFromInvocation(invocation);
      const context = await contextFor(invocation.auth.uid);
      const caseSnapshot = await db.collection("case_files").doc(request.caseId).get();
      const caseData = assertScope(caseSnapshot, context);
      assertCaseOpen(caseData);
      const evidenceSnapshot = await db.collection("case_evidence_refs").doc(request.evidenceRefId).get();
      const initialEvidenceData = assertScope(evidenceSnapshot, context, request.caseId);
      const sessionId = sha256([context.tenantId, request.caseId, request.evidenceRefId, request.requestId].join("|"));
      const sessionRef = db.collection("case_evidence_upload_sessions").doc(sessionId);
      const objectName = serverStagingObjectName(context, request.caseId, request.evidenceRefId, sessionId, request.contentType);
      const existingSnapshot = await sessionRef.get();
      const existing = existingSnapshot.data() || {};
      if (existingSnapshot.exists) {
        if (!sessionContractMatches(existing, context, request, bucketName, objectName)) fail("idempotency conflict", "already-exists");
        return {
          contractVersion: "case-evidence-upload-session-create-result-v1",
          ok: true,
          duplicate: true,
          uploadSessionId: sessionId,
          uploadUri: null,
          uploadUriAvailable: false,
          status: existing.status,
          expiresAt: iso(existing.expiresAt),
        };
      }
      const now = nowDate();
      const initialSummary = object(initialEvidenceData.objectBindingSummary || {}, "objectBindingSummary");
      if (activeSessionAvailable(initialSummary, now, sessionId)) fail("active upload session exists", "resource-exhausted");
      if (uploadWindow(initialSummary, now).issueCount >= MAX_SESSION_ISSUES_PER_WINDOW) fail("upload session quota exceeded", "resource-exhausted");
      const metadata = metadataFor({context, request, sessionId});
      const uploadUri = await initiateUpload({bucket: bucketName, objectName, contentType: request.contentType, sizeBytes: request.sizeBytes, metadata, origin});
      const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
      const transactionResult = await db.runTransaction(async (transaction) => {
        const currentCase = await transaction.get(db.collection("case_files").doc(request.caseId));
        const evidenceRef = db.collection("case_evidence_refs").doc(request.evidenceRefId);
        const currentEvidence = await transaction.get(evidenceRef);
        const duplicate = await transaction.get(sessionRef);
        const currentCaseData = assertScope(currentCase, context);
        assertCaseOpen(currentCaseData);
        const evidenceData = assertScope(currentEvidence, context, request.caseId);
        if (duplicate.exists) {
          const duplicateData = duplicate.data() || {};
          if (!sessionContractMatches(duplicateData, context, request, bucketName, objectName)) fail("idempotency conflict", "already-exists");
          return {created: false, data: duplicateData};
        }
        const previous = object(evidenceData.objectBindingSummary || {}, "objectBindingSummary");
        if (activeSessionAvailable(previous, now, sessionId)) fail("active upload session exists", "resource-exhausted");
        const window = uploadWindow(previous, now);
        if (window.issueCount >= MAX_SESSION_ISSUES_PER_WINDOW) fail("upload session quota exceeded", "resource-exhausted");
        transaction.create(sessionRef, {
          contractVersion: "case-evidence-upload-session-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: request.caseId,
          evidenceRefId: request.evidenceRefId,
          requestId: request.requestId,
          bucket: bucketName,
          objectName,
          objectStage: "staging",
          originalFileName: request.fileName,
          contentType: request.contentType,
          sizeBytes: request.sizeBytes,
          status: "upload_pending",
          createdByUid: invocation.auth.uid,
          createdAt: stamp(now),
          expiresAt: stamp(expiresAt),
        });
        transaction.update(evidenceRef, {
          objectBindingSummary: {
            ...previous,
            activeUploadSessionId: sessionId,
            activeUploadStatus: "upload_pending",
            activeUploadExpiresAt: stamp(expiresAt),
            uploadSessionIssueCount: window.issueCount + 1,
            uploadSessionWindowStartedAt: stamp(window.startedAt),
            lastUploadSessionIssuedAt: stamp(now),
          },
        });
        return {created: true};
      });
      if (!transactionResult.created) {
        const duplicate = transactionResult.data || {};
        return {
          contractVersion: "case-evidence-upload-session-create-result-v1",
          ok: true,
          duplicate: true,
          uploadSessionId: sessionId,
          uploadUri: null,
          uploadUriAvailable: false,
          status: duplicate.status,
          expiresAt: iso(duplicate.expiresAt),
        };
      }
      return {
        contractVersion: "case-evidence-upload-session-create-result-v1",
        ok: true,
        duplicate: false,
        uploadSessionId: sessionId,
        uploadUri,
        uploadUriAvailable: true,
        status: "upload_pending",
        expiresAt: expiresAt.toISOString(),
      };
    },
    async finalizeUpload(raw, invocation) {
      const request = finalizeRequest(raw);
      const context = await contextFor(invocation.auth.uid);
      const sessionRef = db.collection("case_evidence_upload_sessions").doc(request.uploadSessionId);
      const initialSessionSnapshot = await sessionRef.get();
      const initialSession = assertScope(initialSessionSnapshot, context);
      const finalizedAt = nowDate();
      if (initialSession.status === "finalized") {
        if (initialSession.stagingGeneration !== request.generation) fail("generation mismatch", "failed-precondition");
        return {contractVersion: "case-evidence-upload-finalize-result-v1", ok: true, duplicate: true, evidenceObjectId: initialSession.evidenceObjectId};
      }
      if (!["upload_pending", "promotion_pending"].includes(initialSession.status)) fail("session unavailable", "failed-precondition");
      if (initialSession.bucket !== bucketName || initialSession.objectStage !== "staging") fail("bucket mismatch", "failed-precondition");
      if (initialSession.status === "upload_pending") {
        const expiresAt = iso(initialSession.expiresAt);
        if (!expiresAt || Date.parse(expiresAt) <= finalizedAt.getTime()) fail("session expired", "failed-precondition");
      } else if (initialSession.stagingGeneration !== request.generation) {
        fail("generation mismatch", "failed-precondition");
      }
      const caseSnapshot = await db.collection("case_files").doc(initialSession.caseId).get();
      const caseData = assertScope(caseSnapshot, context);
      if (initialSession.status === "upload_pending") assertCaseOpen(caseData);
      const evidenceSnapshot = await db.collection("case_evidence_refs").doc(initialSession.evidenceRefId).get();
      assertScope(evidenceSnapshot, context, initialSession.caseId);
      const stagingFile = bucket.file(initialSession.objectName, {generation: request.generation});
      const [stagingMetadata] = await stagingFile.getMetadata();
      const actualGeneration = String(stagingMetadata.generation || "");
      if (stagingMetadata.bucket !== initialSession.bucket || stagingMetadata.name !== initialSession.objectName || actualGeneration !== request.generation) fail("object identity mismatch", "failed-precondition");
      if (Number(stagingMetadata.size) !== Number(initialSession.sizeBytes) || stagingMetadata.contentType !== initialSession.contentType) fail("object contract mismatch", "failed-precondition");
      const expectedStagingMetadata = {
        tenantId: context.tenantId,
        canonicalBrandId: context.brandId,
        caseId: initialSession.caseId,
        evidenceRefId: initialSession.evidenceRefId,
        uploadSessionId: request.uploadSessionId,
        objectStage: "staging",
      };
      if (!metadataMatches(stagingMetadata.metadata, expectedStagingMetadata)) fail("object metadata mismatch", "failed-precondition");
      const {digest} = await streamSha256(stagingFile, Number(initialSession.sizeBytes));
      const permanentObjectName = serverEvidenceObjectName(context, initialSession.caseId, initialSession.evidenceRefId, request.uploadSessionId, initialSession.contentType);
      const reservation = await db.runTransaction(async (transaction) => {
        const currentSessionSnapshot = await transaction.get(sessionRef);
        const currentSession = assertScope(currentSessionSnapshot, context);
        if (currentSession.status === "finalized") {
          if (currentSession.stagingGeneration !== request.generation) fail("generation mismatch", "failed-precondition");
          return {finalized: true, evidenceObjectId: currentSession.evidenceObjectId};
        }
        if (!["upload_pending", "promotion_pending"].includes(currentSession.status)) fail("session unavailable", "failed-precondition");
        if (currentSession.status === "upload_pending") {
          const currentExpiresAt = iso(currentSession.expiresAt);
          if (!currentExpiresAt || Date.parse(currentExpiresAt) <= finalizedAt.getTime()) fail("session expired", "failed-precondition");
          const currentCase = await transaction.get(db.collection("case_files").doc(currentSession.caseId));
          const currentCaseData = assertScope(currentCase, context);
          assertCaseOpen(currentCaseData);
          const evidenceRef = db.collection("case_evidence_refs").doc(currentSession.evidenceRefId);
          const currentEvidence = await transaction.get(evidenceRef);
          const evidenceData = assertScope(currentEvidence, context, currentSession.caseId);
          const previous = object(evidenceData.objectBindingSummary || {}, "objectBindingSummary");
          if (previous.activeUploadSessionId && previous.activeUploadSessionId !== request.uploadSessionId) fail("active upload session changed", "failed-precondition");
          transaction.update(sessionRef, {
            status: "promotion_pending",
            stagingGeneration: request.generation,
            permanentObjectName,
            sha256: digest,
            promotionStartedAt: stamp(finalizedAt),
            finalizeRequestId: request.requestId,
          });
          transaction.update(evidenceRef, {
            objectBindingSummary: {
              ...previous,
              activeUploadSessionId: request.uploadSessionId,
              activeUploadStatus: "promotion_pending",
            },
          });
          return {finalized: false};
        }
        if (currentSession.stagingGeneration !== request.generation || currentSession.permanentObjectName !== permanentObjectName || currentSession.sha256 !== digest) fail("promotion reservation mismatch", "failed-precondition");
        return {finalized: false};
      });
      if (reservation.finalized) return {contractVersion: "case-evidence-upload-finalize-result-v1", ok: true, duplicate: true, evidenceObjectId: reservation.evidenceObjectId};
      const permanentCustomMetadata = metadataFor({
        context,
        request: {caseId: initialSession.caseId, evidenceRefId: initialSession.evidenceRefId},
        sessionId: request.uploadSessionId,
        objectStage: "evidence",
        digest,
        sourceGeneration: request.generation,
      });
      const promotion = await promoteObject({
        bucket,
        sourceFile: stagingFile,
        destinationObjectName: permanentObjectName,
        contentType: initialSession.contentType,
        metadata: permanentCustomMetadata,
      });
      const permanentMetadata = promotion.metadata || {};
      const permanentGeneration = String(permanentMetadata.generation || "");
      if (permanentMetadata.bucket !== initialSession.bucket || permanentMetadata.name !== permanentObjectName || !/^[1-9][0-9]*$/.test(permanentGeneration)) fail("promoted object identity mismatch", "failed-precondition");
      if (Number(permanentMetadata.size) !== Number(initialSession.sizeBytes) || permanentMetadata.contentType !== initialSession.contentType) fail("promoted object contract mismatch", "failed-precondition");
      if (!metadataMatches(permanentMetadata.metadata, permanentCustomMetadata)) fail("promoted object metadata mismatch", "failed-precondition");
      const objectId = sha256([initialSession.bucket, permanentObjectName, permanentGeneration].join("|"));
      const eventId = sha256(`${objectId}|bound`);
      return db.runTransaction(async (transaction) => {
        const currentSessionSnapshot = await transaction.get(sessionRef);
        const currentSession = assertScope(currentSessionSnapshot, context);
        if (currentSession.status === "finalized") {
          if (currentSession.stagingGeneration !== request.generation) fail("generation mismatch", "failed-precondition");
          return {contractVersion: "case-evidence-upload-finalize-result-v1", ok: true, duplicate: true, evidenceObjectId: currentSession.evidenceObjectId};
        }
        if (currentSession.status !== "promotion_pending" || currentSession.stagingGeneration !== request.generation || currentSession.permanentObjectName !== permanentObjectName || currentSession.sha256 !== digest) fail("promotion reservation mismatch", "failed-precondition");
        const currentCase = await transaction.get(db.collection("case_files").doc(currentSession.caseId));
        assertScope(currentCase, context);
        const evidenceRef = db.collection("case_evidence_refs").doc(currentSession.evidenceRefId);
        const currentEvidence = await transaction.get(evidenceRef);
        const evidenceData = assertScope(currentEvidence, context, currentSession.caseId);
        const previous = object(evidenceData.objectBindingSummary || {}, "objectBindingSummary");
        if (previous.activeUploadSessionId && previous.activeUploadSessionId !== request.uploadSessionId) fail("active upload session changed", "failed-precondition");
        const objectRef = db.collection("case_evidence_objects").doc(objectId);
        const existingObject = await transaction.get(objectRef);
        if (existingObject.exists) fail("object identity already bound", "already-exists");
        const occurredAt = stamp(finalizedAt);
        transaction.create(objectRef, {
          contractVersion: "case-evidence-object-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: currentSession.caseId,
          evidenceRefId: currentSession.evidenceRefId,
          uploadSessionId: request.uploadSessionId,
          bucket: currentSession.bucket,
          objectName: permanentObjectName,
          generation: permanentGeneration,
          stagingObjectName: currentSession.objectName,
          stagingGeneration: request.generation,
          originalFileName: currentSession.originalFileName,
          contentType: currentSession.contentType,
          sizeBytes: currentSession.sizeBytes,
          sha256: digest,
          hashAlgorithm: "SHA-256",
          createdByUid: invocation.auth.uid,
          createdAt: occurredAt,
          immutable: true,
        });
        transaction.create(db.collection("case_evidence_object_events").doc(eventId), {
          contractVersion: "case-evidence-object-event-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: currentSession.caseId,
          evidenceRefId: currentSession.evidenceRefId,
          evidenceObjectId: objectId,
          eventType: "evidence_object_bound",
          actorUid: invocation.auth.uid,
          occurredAt,
          appendOnly: true,
        });
        transaction.create(db.collection("case_events").doc(sha256(`${eventId}|case`)), {
          contractVersion: "case-event-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: currentSession.caseId,
          eventType: "evidence_object_bound",
          summary: "Delil dosyası doğrulanarak vakaya bağlandı.",
          actorUid: invocation.auth.uid,
          occurredAt,
          appendOnly: true,
        });
        transaction.create(db.collection("case_audit_events").doc(sha256(`${eventId}|audit`)), {
          contractVersion: "case-audit-event-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          caseId: currentSession.caseId,
          action: "evidence_object.bound",
          actorUid: invocation.auth.uid,
          occurredAt,
          appendOnly: true,
        });
        transaction.update(evidenceRef, {
          objectBindingSummary: {
            ...previous,
            objectCount: Number(previous.objectCount || 0) + 1,
            lastEvidenceObjectId: objectId,
            lastBoundAt: occurredAt,
            lastContentType: currentSession.contentType,
            lastSizeBytes: currentSession.sizeBytes,
            activeUploadSessionId: null,
            activeUploadStatus: null,
            activeUploadExpiresAt: null,
          },
        });
        transaction.update(sessionRef, {
          status: "finalized",
          permanentGeneration,
          evidenceObjectId: objectId,
          finalizedAt: occurredAt,
        });
        return {contractVersion: "case-evidence-upload-finalize-result-v1", ok: true, duplicate: false, evidenceObjectId: objectId, sha256: digest};
      });
    },
    async objectDetail(raw, invocation) {
      const request = detailRequest(raw);
      const context = await contextFor(invocation.auth.uid);
      const snapshot = await db.collection("case_evidence_objects").doc(request.evidenceObjectId).get();
      const data = assertScope(snapshot, context);
      const caseSnapshot = await db.collection("case_files").doc(data.caseId).get();
      assertScope(caseSnapshot, context);
      const evidenceSnapshot = await db.collection("case_evidence_refs").doc(data.evidenceRefId).get();
      assertScope(evidenceSnapshot, context, data.caseId);
      const eventSnapshot = await db.collection("case_evidence_object_events").where("evidenceObjectId", "==", request.evidenceObjectId).limit(100).get();
      const events = eventSnapshot.docs.map((entry) => entry.data() || {}).filter((event) => event.tenantId === context.tenantId && event.canonicalBrandId === context.brandId).map((event) => ({
        eventType: event.eventType,
        occurredAt: iso(event.occurredAt),
      }));
      return {
        contractVersion: "case-evidence-object-detail-v1",
        evidenceObjectId: snapshot.id,
        caseId: data.caseId,
        evidenceRefId: data.evidenceRefId,
        originalFileName: data.originalFileName,
        contentType: data.contentType,
        sizeBytes: data.sizeBytes,
        sha256: data.sha256,
        hashAlgorithm: data.hashAlgorithm,
        createdAt: iso(data.createdAt),
        events,
        readOnly: true,
        writesPerformed: 0,
      };
    },
  });
}
function mapError(error) {
  const codes = new Set(["unauthenticated", "invalid-argument", "permission-denied", "failed-precondition", "not-found", "already-exists", "resource-exhausted"]);
  const code = codes.has(error.code) ? error.code : "internal";
  const messages = {
    "unauthenticated": "Oturum açmanız gerekir.",
    "invalid-argument": "Delil dosyası isteği geçersiz.",
    "permission-denied": "Bu işlem için yetkiniz bulunmuyor.",
    "failed-precondition": "Delil dosyası işlemi mevcut durumda gerçekleştirilemiyor.",
    "not-found": "Delil kaydı bulunamadı.",
    "already-exists": "Delil dosyası kimliği başka bir kayıtla çakışıyor.",
    "resource-exhausted": "Bu delil için yeni yükleme oturumu şu anda açılamıyor.",
    "internal": "Delil dosyası işlemi güvenli biçimde tamamlanamadı.",
  };
  return new HttpsError(code, messages[code]);
}
function handler(method, {service, appCheck, log = logger}) {
  return async (invocation) => {
    try {
      assertInvocation(invocation, appCheck);
      const result = await service[method](invocation.data || {}, invocation);
      log.info("Case evidence object callable completed", {
        event: `case_evidence_object_${method}_completed`,
        duplicate: result.duplicate === true,
        writeAttempted: ["createUploadSession", "finalizeUpload"].includes(method),
      });
      return result;
    } catch (error) {
      if (error instanceof EvidenceObjectBindingError) throw mapError(error);
      throw new HttpsError("internal", "Delil dosyası işlemi güvenli biçimde tamamlanamadı.");
    }
  };
}
function productionService({db, admin}) {
  const bucket = admin.storage().bucket(BUCKET);
  const credential = admin.app().options.credential;
  return createEvidenceObjectBindingService({
    db,
    bucket,
    initiateUpload: createGoogleUploadInitiator({credential}),
    promoteObject: createStorageObjectPromoter(),
    clock: {
      now: () => new Date(),
      timestamp: (date) => admin.firestore.Timestamp.fromDate(date),
    },
  });
}
const callableOptions = (enforceAppCheck, maxInstances) => ({
  region: REGION,
  enforceAppCheck,
  maxInstances,
  serviceAccount: SERVICE_ACCOUNT,
});
const buildCreateCaseEvidenceUploadSession = ({db, admin}) => onCall(callableOptions(true, 1), handler("createUploadSession", {service: productionService({db, admin}), appCheck: true}));
const buildFinalizeCaseEvidenceUpload = ({db, admin}) => onCall(callableOptions(true, 1), handler("finalizeUpload", {service: productionService({db, admin}), appCheck: true}));
const buildGetCaseEvidenceObjectDetail = ({db, admin}) => onCall(callableOptions(false, 3), handler("objectDetail", {service: productionService({db, admin}), appCheck: false}));

module.exports = {
  BUCKET,
  MAX_SIZE_BYTES,
  MAX_SESSION_ISSUES_PER_WINDOW,
  MIME_EXTENSIONS,
  ORIGINS,
  SERVICE_ACCOUNT,
  EvidenceObjectBindingError,
  buildCreateCaseEvidenceUploadSession,
  buildFinalizeCaseEvidenceUpload,
  buildGetCaseEvidenceObjectDetail,
  callableOptions,
  createEvidenceObjectBindingService,
  createGoogleUploadInitiator,
  createRequest,
  createStorageObjectPromoter,
  detailRequest,
  finalizeRequest,
  handler,
  serverEvidenceObjectName,
  serverObjectName,
  serverStagingObjectName,
  streamSha256,
};
