/* eslint-disable */
"use strict";

const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

const REGION = "europe-west3";
const MAX_SCOPES = 50;

const COLLECTIONS = Object.freeze({
  laboratories: "odlaLaboratories",
  accreditations: "odlaLaboratoryAccreditations",
  scopes: "odlaLaboratoryTestScopes",
  audits: "odlaLaboratoryAuditEvents",
  idempotency: "odlaMutationIdempotency",
});

const LAB_STATUSES = new Set(["ACTIVE", "SUSPENDED", "RETIRED"]);
const ACCREDITATION_STATUSES = new Set([
  "PENDING_VERIFICATION",
  "ACTIVE",
  "SUSPENDED",
  "EXPIRED",
  "REVOKED",
  "SUPERSEDED",
]);
const VERIFICATION_STATUSES = new Set([
  "UNVERIFIED",
  "SOURCE_CHECKED",
  "VERIFIED",
  "DISPUTED",
]);

const LAB_TRANSITIONS = new Set([
  "ACTIVE->SUSPENDED",
  "SUSPENDED->ACTIVE",
  "ACTIVE->RETIRED",
  "SUSPENDED->RETIRED",
]);

const ACCREDITATION_TRANSITIONS = new Set([
  "PENDING_VERIFICATION->ACTIVE",
  "PENDING_VERIFICATION->REVOKED",
  "ACTIVE->SUSPENDED",
  "SUSPENDED->ACTIVE",
  "ACTIVE->EXPIRED",
  "SUSPENDED->EXPIRED",
  "ACTIVE->REVOKED",
  "SUSPENDED->REVOKED",
  "ACTIVE->SUPERSEDED",
  "SUSPENDED->SUPERSEDED",
]);

const REGISTRY_READ_ROLES = new Set([
  "platform_admin",
  "super_admin",
  "odla_registry_admin",
  "odla_accreditation_reviewer",
  "odla_reviewer",
]);

const REGISTRY_WRITE_ROLES = new Set([
  "platform_admin",
  "super_admin",
  "odla_registry_admin",
]);

const ACCREDITATION_REVIEW_ROLES = new Set([
  "platform_admin",
  "super_admin",
  "odla_accreditation_reviewer",
]);

function dbInstance() {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}

function normalizedTimestamp(value) {
  if (value == null) return null;
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string") {
    const d = new Date(value);
    if (!Number.isFinite(d.getTime())) throw new Error("INVALID_TIMESTAMP");
    return d.toISOString();
  }
  if (typeof value === "number") {
    const d = new Date(value);
    if (!Number.isFinite(d.getTime())) throw new Error("INVALID_TIMESTAMP");
    return d.toISOString();
  }
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  throw new Error("INVALID_TIMESTAMP");
}

function canonicalize(value) {
  if (value === undefined) return null;
  if (value === null) return null;
  if (value instanceof Timestamp || value instanceof Date) {
    return normalizedTimestamp(value);
  }
  if (Array.isArray(value)) return value.map(canonicalize);
  if (typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort()) {
      if (key === "recordSha256" || key === "scopeSha256" ||
          key === "lastAuditEventSha256") {
        continue;
      }
      out[key] = canonicalize(value[key]);
    }
    return out;
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256Hex(value) {
  const body = typeof value === "string" ? value : canonicalJson(value);
  return crypto.createHash("sha256").update(body, "utf8").digest("hex");
}

function stableRequestHash(callableName, data) {
  const copy = {...(data || {})};
  delete copy.idempotencyKey;
  return sha256Hex({callableName, data: copy});
}

function requiredString(data, key) {
  const value = data && data[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpsError("invalid-argument", `MISSING_OR_INVALID_${key}`);
  }
  return value.trim();
}

function optionalString(data, key) {
  const value = data && data[key];
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `INVALID_${key}`);
  }
  return value.trim();
}

function requiredCode(data, key) {
  const value = requiredString(data, key);
  if (!/^[A-Z0-9_.:-]+$/.test(value)) {
    throw new HttpsError("invalid-argument", `INVALID_CANONICAL_CODE_${key}`);
  }
  return value;
}

function toTimestamp(value, key) {
  if (value instanceof Timestamp) return value;
  const normalized = normalizedTimestamp(value);
  if (!normalized) {
    throw new HttpsError("invalid-argument", `INVALID_${key}`);
  }
  return Timestamp.fromDate(new Date(normalized));
}

function roleTokensFromValue(value, out) {
  if (value == null) return;
  if (Array.isArray(value)) {
    for (const item of value) roleTokensFromValue(item, out);
    return;
  }
  if (typeof value === "string") {
    for (const piece of value.split(/[,\s]+/)) {
      if (piece) out.add(piece.trim().toLowerCase());
    }
  }
}

function rolesFromToken(token) {
  const out = new Set();
  if (!token || typeof token !== "object") return out;
  roleTokensFromValue(token.role, out);
  roleTokensFromValue(token.roles, out);
  roleTokensFromValue(token.platformRole, out);
  roleTokensFromValue(token.platform_role, out);
  roleTokensFromValue(token.permissions, out);
  return out;
}

async function effectiveRoles(db, request) {
  const roles = rolesFromToken(request && request.auth && request.auth.token);
  const uid = request && request.auth && request.auth.uid;
  if (!uid) return roles;
  try {
    const snap = await db.collection("platform_admins").doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      roleTokensFromValue(data.role, roles);
      roleTokensFromValue(data.roles, roles);
      roleTokensFromValue(data.permission, roles);
      roleTokensFromValue(data.permissions, roles);
      if (data.super_admin === true || data.superAdmin === true) {
        roles.add("super_admin");
      }
      if (data.platform_admin === true || data.platformAdmin === true) {
        roles.add("platform_admin");
      }
    }
  } catch (_) {
    // Fail closed by keeping only already-authenticated token roles.
  }
  return roles;
}

function requireAuthAndAppCheck(request) {
  if (!request || !request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  }
  if (!request.app) {
    throw new HttpsError("failed-precondition", "APPCHECK_REQUIRED");
  }
}

function intersects(roles, allowed) {
  for (const role of roles) if (allowed.has(role)) return true;
  return false;
}

async function requireRole(db, request, allowed, code) {
  requireAuthAndAppCheck(request);
  const roles = await effectiveRoles(db, request);
  if (!intersects(roles, allowed)) {
    throw new HttpsError("permission-denied", code);
  }
  return roles;
}

function safeRoleCode(roles) {
  for (const role of [
    "super_admin",
    "platform_admin",
    "odla_registry_admin",
    "odla_accreditation_reviewer",
    "odla_reviewer",
  ]) {
    if (roles.has(role)) return role;
  }
  return "unknown";
}

function ensureStatusTransition(from, to, allowed, code) {
  if (!allowed.has(`${from}->${to}`)) {
    throw new HttpsError("failed-precondition", code);
  }
}

function evaluateCoverage(accreditation, scope, asOfInput) {
  if (!accreditation || !scope) {
    return {coverageStatus: "UNKNOWN", coverageReasonCode: "MISSING_DATA"};
  }
  const asOf = new Date(normalizedTimestamp(asOfInput || new Date()));
  const validFrom = accreditation.validFrom ?
    new Date(normalizedTimestamp(accreditation.validFrom)) : null;
  const validUntil = accreditation.validUntil ?
    new Date(normalizedTimestamp(accreditation.validUntil)) : null;
  if (accreditation.verificationStatus !== "VERIFIED") {
    return {
      coverageStatus: "UNVERIFIED",
      coverageReasonCode: "ACCREDITATION_NOT_VERIFIED",
    };
  }
  if (accreditation.status === "SUSPENDED") {
    return {
      coverageStatus: "SUSPENDED_AT_RESULT_TIME",
      coverageReasonCode: "ACCREDITATION_SUSPENDED",
    };
  }
  if (accreditation.status === "REVOKED") {
    return {
      coverageStatus: "NOT_COVERED",
      coverageReasonCode: "ACCREDITATION_REVOKED",
    };
  }
  if (accreditation.status === "EXPIRED" ||
      (validUntil && asOf.getTime() > validUntil.getTime())) {
    return {
      coverageStatus: "EXPIRED_AT_RESULT_TIME",
      coverageReasonCode: "ACCREDITATION_EXPIRED",
    };
  }
  if (validFrom && asOf.getTime() < validFrom.getTime()) {
    return {
      coverageStatus: "NOT_COVERED",
      coverageReasonCode: "ACCREDITATION_NOT_YET_VALID",
    };
  }
  if (accreditation.status !== "ACTIVE") {
    return {
      coverageStatus: "UNKNOWN",
      coverageReasonCode: "ACCREDITATION_NOT_ACTIVE",
    };
  }
  if (scope.scopeStatus !== "ACTIVE") {
    return {
      coverageStatus: "NOT_COVERED",
      coverageReasonCode: "SCOPE_NOT_ACTIVE",
    };
  }
  const scopeFrom = scope.validFrom ?
    new Date(normalizedTimestamp(scope.validFrom)) : null;
  const scopeUntil = scope.validUntil ?
    new Date(normalizedTimestamp(scope.validUntil)) : null;
  if ((scopeFrom && asOf.getTime() < scopeFrom.getTime()) ||
      (scopeUntil && asOf.getTime() > scopeUntil.getTime())) {
    return {
      coverageStatus: "NOT_COVERED",
      coverageReasonCode: "SCOPE_VALIDITY_WINDOW_MISMATCH",
    };
  }
  return {coverageStatus: "COVERED", coverageReasonCode: "COVERED"};
}

function validateScopeList(scopes) {
  if (!Array.isArray(scopes) || scopes.length === 0) {
    throw new HttpsError("invalid-argument", "EMPTY_SCOPE_SET");
  }
  if (scopes.length > MAX_SCOPES) {
    throw new HttpsError("invalid-argument", "SCOPE_LIMIT_EXCEEDED");
  }
  const seen = new Set();
  return scopes.map((scope, index) => {
    if (!scope || typeof scope !== "object") {
      throw new HttpsError("invalid-argument", `INVALID_SCOPE_${index}`);
    }
    const testTypeCode = requiredCode(scope, "testTypeCode");
    const methodCode = requiredCode(scope, "methodCode");
    const tuple = `${testTypeCode}::${methodCode}`;
    if (seen.has(tuple)) {
      throw new HttpsError("invalid-argument", "DUPLICATE_SCOPE_TUPLE");
    }
    seen.add(tuple);
    return {
      testTypeCode,
      methodCode,
      productCategoryCodes: Array.isArray(scope.productCategoryCodes) ?
        scope.productCategoryCodes.map(String) : [],
      materialMatrixCodes: Array.isArray(scope.materialMatrixCodes) ?
        scope.materialMatrixCodes.map(String) : [],
      analyteCodes: Array.isArray(scope.analyteCodes) ?
        scope.analyteCodes.map(String) : [],
      jurisdictionCodes: Array.isArray(scope.jurisdictionCodes) ?
        scope.jurisdictionCodes.map(String) : [],
      methodVersion: scope.methodVersion == null ? null : String(scope.methodVersion),
      limitOfDetection: scope.limitOfDetection == null ?
        null : String(scope.limitOfDetection),
      measurementUnitCode: scope.measurementUnitCode == null ?
        null : String(scope.measurementUnitCode),
    };
  });
}

function auditEventHash(event) {
  return sha256Hex(event);
}

async function replayIfIdempotent(tx, idemRef, requestSha256) {
  const snap = await tx.get(idemRef);
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (data.requestSha256 !== requestSha256) {
    throw new HttpsError(
        "failed-precondition",
        "IDEMPOTENCY_KEY_REUSE_MISMATCH",
    );
  }
  return data.result || null;
}

function idempotencyRef(db, callableName, uid, key) {
  const docId = sha256Hex(`${callableName}|${uid}|${key}`);
  return db.collection(COLLECTIONS.idempotency).doc(docId);
}

function mutationContext(request, callableName) {
  const data = request.data || {};
  const idempotencyKey = requiredString(data, "idempotencyKey");
  const reasonCode = requiredString(data, "reasonCode");
  return {
    data,
    idempotencyKey,
    reasonCode,
    requestSha256: stableRequestHash(callableName, data),
  };
}

function auditBase({
  auditEventId,
  entityType,
  entityId,
  entityVersion,
  eventType,
  uid,
  roleCode,
  idempotencyKey,
  reasonCode,
  occurredAt,
  beforeSha256,
  afterSha256,
  previousAuditEventSha256,
}) {
  return {
    schemaVersion: 1,
    auditEventId,
    entityType,
    entityId,
    entityVersion,
    eventType,
    actorUid: uid,
    actorRoleCode: roleCode,
    requestId: idempotencyKey,
    idempotencyKeyHash: sha256Hex(idempotencyKey),
    reasonCode,
    occurredAt,
    beforeSha256: beforeSha256 || null,
    afterSha256: afterSha256 || null,
    previousAuditEventSha256: previousAuditEventSha256 || "GENESIS",
  };
}

async function registryEntryHandler(request) {
  const db = dbInstance();
  await requireRole(
      db,
      request,
      REGISTRY_READ_ROLES,
      "ODLA_REGISTRY_READ_NOT_AUTHORIZED",
  );
  const data = request.data || {};
  const laboratoryId = requiredString(data, "laboratoryId");
  const labSnap = await db.collection(COLLECTIONS.laboratories).doc(laboratoryId).get();
  if (!labSnap.exists) {
    throw new HttpsError("not-found", "LABORATORY_NOT_FOUND");
  }
  const laboratory = {id: labSnap.id, ...labSnap.data()};
  let currentAccreditations = [];
  if (data.includeCurrentAccreditations !== false) {
    const accSnap = await db.collection(COLLECTIONS.accreditations)
        .where("laboratoryId", "==", laboratoryId)
        .limit(100)
        .get();
    currentAccreditations = accSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  }
  let scopes = [];
  if (data.includeScopes === true && currentAccreditations.length) {
    const ids = currentAccreditations.map((x) => x.accreditationId || x.id).slice(0, 30);
    if (ids.length) {
      const chunks = [];
      for (let i = 0; i < ids.length; i += 10) chunks.push(ids.slice(i, i + 10));
      for (const chunk of chunks) {
        const snap = await db.collection(COLLECTIONS.scopes)
            .where("accreditationId", "in", chunk)
            .limit(200)
            .get();
        scopes.push(...snap.docs.map((doc) => ({id: doc.id, ...doc.data()})));
      }
    }
  }
  return {
    laboratory,
    currentAccreditations,
    scopes,
    serverAuthorizationContext: {mode: "registry-role-read"},
  };
}

async function listAuthorizedWorkspaceHandler(request) {
  const db = dbInstance();
  await requireRole(
      db,
      request,
      REGISTRY_READ_ROLES,
      "ODLA_REGISTRY_READ_NOT_AUTHORIZED",
  );
  const data = request.data || {};
  const rawLimit = Number(data.limit || 25);
  const limit = Number.isInteger(rawLimit) ?
    Math.max(1, Math.min(rawLimit, 100)) : 25;
  let query = db.collection(COLLECTIONS.laboratories);
  if (data.status != null) {
    const status = String(data.status);
    if (!LAB_STATUSES.has(status)) {
      throw new HttpsError("invalid-argument", "INVALID_STATUS");
    }
    query = query.where("status", "==", status);
  }
  const snap = await query.limit(limit).get();
  return {
    laboratories: snap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    pagination: {limit, cursor: null},
    serverAuthorizationContext: {
      mode: "registry-role-read",
      brandWorkspaceEnumerationEnabled: false,
    },
  };
}

async function accreditationHistoryHandler(request) {
  const db = dbInstance();
  await requireRole(
      db,
      request,
      REGISTRY_READ_ROLES,
      "ODLA_REGISTRY_READ_NOT_AUTHORIZED",
  );
  const data = request.data || {};
  const laboratoryId = requiredString(data, "laboratoryId");
  const labSnap = await db.collection(COLLECTIONS.laboratories).doc(laboratoryId).get();
  if (!labSnap.exists) {
    throw new HttpsError("not-found", "LABORATORY_NOT_FOUND");
  }
  let query = db.collection(COLLECTIONS.accreditations)
      .where("laboratoryId", "==", laboratoryId);
  if (data.accreditationId != null) {
    query = query.where("accreditationId", "==", String(data.accreditationId));
  }
  const snap = await query.limit(100).get();
  const history = snap.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .sort((a, b) => Number(a.version || 0) - Number(b.version || 0));
  return {
    laboratorySummary: {id: labSnap.id, ...labSnap.data()},
    accreditationHistory: history,
    serverAuthorizationContext: {mode: "registry-role-read"},
  };
}

async function registerLaboratoryHandler(request) {
  const db = dbInstance();
  const roles = await requireRole(
      db,
      request,
      REGISTRY_WRITE_ROLES,
      "ODLA_REGISTRY_MUTATION_NOT_AUTHORIZED",
  );
  const ctx = mutationContext(request, "registerOdlaLaboratory");
  const data = ctx.data;
  const now = Timestamp.now();
  const uid = request.auth.uid;
  const labRef = db.collection(COLLECTIONS.laboratories).doc();
  const idemRef = idempotencyRef(
      db,
      "registerOdlaLaboratory",
      uid,
      ctx.idempotencyKey,
  );
  const result = await db.runTransaction(async (tx) => {
    const replay = await replayIfIdempotent(tx, idemRef, ctx.requestSha256);
    if (replay) return replay;
    const registrationAuthorityId = optionalString(
        data,
        "registrationAuthorityId",
    );
    const registrationNumber = optionalString(data, "registrationNumber");
    if (registrationAuthorityId && registrationNumber) {
      const collisionQuery = db.collection(COLLECTIONS.laboratories)
          .where("registrationAuthorityId", "==", registrationAuthorityId)
          .where("registrationNumber", "==", registrationNumber)
          .limit(1);
      const collision = await tx.get(collisionQuery);
      if (!collision.empty) {
        throw new HttpsError("already-exists", "LABORATORY_IDENTITY_COLLISION");
      }
    }
    const lab = {
      schemaVersion: 1,
      laboratoryId: labRef.id,
      legalName: requiredString(data, "legalName"),
      displayName: requiredString(data, "displayName"),
      countryCode: requiredCode(data, "countryCode"),
      registrationAuthorityTypeCode: optionalString(data, "registrationAuthorityTypeCode"),
      registrationAuthorityId,
      registrationNumber,
      websiteUri: optionalString(data, "websiteUri"),
      contactReference: data.contactReference || null,
      addressReference: data.addressReference || null,
      externalIdentifiers: data.externalIdentifiers || {},
      notes: optionalString(data, "notes"),
      status: "ACTIVE",
      version: 1,
      createdAt: now,
      createdBy: uid,
      updatedAt: now,
      updatedBy: uid,
    };
    lab.recordSha256 = sha256Hex(lab);
    const auditRef = db.collection(COLLECTIONS.audits).doc();
    const base = auditBase({
      auditEventId: auditRef.id,
      entityType: "laboratory",
      entityId: labRef.id,
      entityVersion: 1,
      eventType: "LABORATORY_REGISTERED",
      uid,
      roleCode: safeRoleCode(roles),
      idempotencyKey: ctx.idempotencyKey,
      reasonCode: ctx.reasonCode,
      occurredAt: now,
      beforeSha256: null,
      afterSha256: lab.recordSha256,
      previousAuditEventSha256: null,
    });
    const eventSha256 = auditEventHash(base);
    const audit = {...base, eventSha256};
    lab.lastAuditEventSha256 = eventSha256;
    const response = {laboratoryId: labRef.id, version: 1, recordSha256: lab.recordSha256};
    tx.create(labRef, lab);
    tx.create(auditRef, audit);
    tx.create(idemRef, {
      callableName: "registerOdlaLaboratory",
      actorUid: uid,
      requestSha256: ctx.requestSha256,
      createdAt: now,
      resultCode: "CREATED",
      resultEntityIds: [labRef.id],
      result: response,
    });
    return response;
  });
  return result;
}

async function submitAccreditationHandler(request) {
  const db = dbInstance();
  const roles = await requireRole(
      db,
      request,
      REGISTRY_WRITE_ROLES,
      "ODLA_REGISTRY_MUTATION_NOT_AUTHORIZED",
  );
  const ctx = mutationContext(request, "submitOdlaLaboratoryAccreditation");
  const data = ctx.data;
  const laboratoryId = requiredString(data, "laboratoryId");
  const scopes = validateScopeList(data.scopes);
  const validFrom = toTimestamp(data.validFrom, "validFrom");
  const validUntil = toTimestamp(data.validUntil, "validUntil");
  if (validFrom.toMillis() >= validUntil.toMillis()) {
    throw new HttpsError("invalid-argument", "INVALID_VALIDITY_WINDOW");
  }
  const standardCode = requiredCode(data, "standardCode");
  const certificateNumber = requiredString(data, "certificateNumber");
  const accreditationBodyTypeCode = requiredCode(
      data,
      "accreditationBodyTypeCode",
  );
  const accreditationBodyId = requiredString(data, "accreditationBodyId");
  const uid = request.auth.uid;
  const now = Timestamp.now();
  const labRef = db.collection(COLLECTIONS.laboratories).doc(laboratoryId);
  const accRef = db.collection(COLLECTIONS.accreditations).doc();
  const idemRef = idempotencyRef(
      db,
      "submitOdlaLaboratoryAccreditation",
      uid,
      ctx.idempotencyKey,
  );
  const result = await db.runTransaction(async (tx) => {
    const replay = await replayIfIdempotent(tx, idemRef, ctx.requestSha256);
    if (replay) return replay;
    const labSnap = await tx.get(labRef);
    if (!labSnap.exists) {
      throw new HttpsError("not-found", "LABORATORY_NOT_FOUND");
    }
    const lab = labSnap.data() || {};
    if (lab.status === "RETIRED") {
      throw new HttpsError("failed-precondition", "LABORATORY_RETIRED");
    }
    const collisionQuery = db.collection(COLLECTIONS.accreditations)
        .where("accreditationBodyId", "==", accreditationBodyId)
        .where("certificateNumber", "==", certificateNumber)
        .limit(1);
    const collision = await tx.get(collisionQuery);
    if (!collision.empty) {
      throw new HttpsError("already-exists", "CERTIFICATE_IDENTITY_COLLISION");
    }
    const accreditation = {
      schemaVersion: 1,
      accreditationId: accRef.id,
      laboratoryId,
      standardCode,
      certificateNumber,
      accreditationBodyTypeCode,
      accreditationBodyId,
      validFrom,
      validUntil,
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
      version: 1,
      createdAt: now,
      createdBy: uid,
      updatedAt: now,
      updatedBy: uid,
    };
    accreditation.recordSha256 = sha256Hex(accreditation);
    const auditRef = db.collection(COLLECTIONS.audits).doc();
    const base = auditBase({
      auditEventId: auditRef.id,
      entityType: "accreditation",
      entityId: accRef.id,
      entityVersion: 1,
      eventType: "ACCREDITATION_SUBMITTED",
      uid,
      roleCode: safeRoleCode(roles),
      idempotencyKey: ctx.idempotencyKey,
      reasonCode: ctx.reasonCode,
      occurredAt: now,
      beforeSha256: null,
      afterSha256: accreditation.recordSha256,
      previousAuditEventSha256: null,
    });
    const eventSha256 = auditEventHash(base);
    accreditation.lastAuditEventSha256 = eventSha256;
    tx.create(accRef, accreditation);

    const scopeIds = [];
    for (const inputScope of scopes) {
      const scopeRef = db.collection(COLLECTIONS.scopes).doc();
      const scope = {
        schemaVersion: 1,
        scopeId: scopeRef.id,
        laboratoryId,
        accreditationId: accRef.id,
        ...inputScope,
        scopeStatus: "ACTIVE",
        validFrom,
        validUntil,
        version: 1,
        createdAt: now,
        createdBy: uid,
      };
      scope.scopeSha256 = sha256Hex(scope);
      tx.create(scopeRef, scope);
      scopeIds.push(scopeRef.id);
    }
    tx.create(auditRef, {...base, eventSha256});
    const response = {
      laboratoryId,
      accreditationId: accRef.id,
      version: 1,
      recordSha256: accreditation.recordSha256,
      scopeIds,
    };
    tx.create(idemRef, {
      callableName: "submitOdlaLaboratoryAccreditation",
      actorUid: uid,
      requestSha256: ctx.requestSha256,
      createdAt: now,
      resultCode: "SUBMITTED",
      resultEntityIds: [accRef.id, ...scopeIds],
      result: response,
    });
    return response;
  });
  return result;
}

function reviewDecision(currentStatus, decisionCode) {
  if (decisionCode === "VERIFY_ACTIVE") {
    return {targetStatus: "ACTIVE", verificationStatus: "VERIFIED"};
  }
  if (decisionCode === "REJECT_REVOKED") {
    return {targetStatus: "REVOKED", verificationStatus: "UNVERIFIED"};
  }
  if (decisionCode === "SUSPEND") return {targetStatus: "SUSPENDED"};
  if (decisionCode === "REINSTATE") return {targetStatus: "ACTIVE"};
  if (decisionCode === "REVOKE") return {targetStatus: "REVOKED"};
  if (decisionCode === "SUPERSEDE") return {targetStatus: "SUPERSEDED"};
  if (decisionCode === "MARK_EXPIRED") return {targetStatus: "EXPIRED"};
  throw new HttpsError("invalid-argument", "INVALID_DECISION_CODE");
}

async function reviewAccreditationHandler(request) {
  const db = dbInstance();
  const roles = await requireRole(
      db,
      request,
      ACCREDITATION_REVIEW_ROLES,
      "ODLA_ACCREDITATION_REVIEW_NOT_AUTHORIZED",
  );
  const ctx = mutationContext(request, "reviewOdlaLaboratoryAccreditation");
  const data = ctx.data;
  const laboratoryId = requiredString(data, "laboratoryId");
  const accreditationId = requiredString(data, "accreditationId");
  const expectedVersion = Number(data.expectedVersion);
  if (!Number.isInteger(expectedVersion) || expectedVersion < 1) {
    throw new HttpsError("invalid-argument", "INVALID_EXPECTED_VERSION");
  }
  const decisionCode = requiredString(data, "decisionCode");
  const uid = request.auth.uid;
  const now = Timestamp.now();
  const accRef = db.collection(COLLECTIONS.accreditations).doc(accreditationId);
  const idemRef = idempotencyRef(
      db,
      "reviewOdlaLaboratoryAccreditation",
      uid,
      ctx.idempotencyKey,
  );
  return db.runTransaction(async (tx) => {
    const replay = await replayIfIdempotent(tx, idemRef, ctx.requestSha256);
    if (replay) return replay;
    const snap = await tx.get(accRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "ACCREDITATION_NOT_FOUND");
    }
    const before = snap.data() || {};
    if (before.laboratoryId !== laboratoryId) {
      throw new HttpsError("failed-precondition", "ACCREDITATION_LABORATORY_MISMATCH");
    }
    if (Number(before.version || 0) !== expectedVersion) {
      throw new HttpsError("aborted", "VERSION_PREIMAGE_MISMATCH");
    }
    const decision = reviewDecision(before.status, decisionCode);
    ensureStatusTransition(
        before.status,
        decision.targetStatus,
        ACCREDITATION_TRANSITIONS,
        "ILLEGAL_STATUS_TRANSITION",
    );
    const after = {
      ...before,
      status: decision.targetStatus,
      verificationStatus: decision.verificationStatus || before.verificationStatus,
      version: expectedVersion + 1,
      updatedAt: now,
      updatedBy: uid,
    };
    after.recordSha256 = sha256Hex(after);
    const auditRef = db.collection(COLLECTIONS.audits).doc();
    const base = auditBase({
      auditEventId: auditRef.id,
      entityType: "accreditation",
      entityId: accreditationId,
      entityVersion: after.version,
      eventType: `ACCREDITATION_${decisionCode}`,
      uid,
      roleCode: safeRoleCode(roles),
      idempotencyKey: ctx.idempotencyKey,
      reasonCode: ctx.reasonCode,
      occurredAt: now,
      beforeSha256: before.recordSha256 || sha256Hex(before),
      afterSha256: after.recordSha256,
      previousAuditEventSha256: before.lastAuditEventSha256 || null,
    });
    const eventSha256 = auditEventHash(base);
    after.lastAuditEventSha256 = eventSha256;
    const response = {
      laboratoryId,
      accreditationId,
      version: after.version,
      status: after.status,
      verificationStatus: after.verificationStatus,
      recordSha256: after.recordSha256,
    };
    tx.set(accRef, after, {merge: false});
    tx.create(auditRef, {...base, eventSha256});
    tx.create(idemRef, {
      callableName: "reviewOdlaLaboratoryAccreditation",
      actorUid: uid,
      requestSha256: ctx.requestSha256,
      createdAt: now,
      resultCode: "REVIEWED",
      resultEntityIds: [accreditationId],
      result: response,
    });
    return response;
  });
}

async function changeLaboratoryStatusHandler(request) {
  const db = dbInstance();
  const roles = await requireRole(
      db,
      request,
      REGISTRY_WRITE_ROLES,
      "ODLA_REGISTRY_MUTATION_NOT_AUTHORIZED",
  );
  const ctx = mutationContext(request, "changeOdlaLaboratoryStatus");
  const data = ctx.data;
  const laboratoryId = requiredString(data, "laboratoryId");
  const expectedVersion = Number(data.expectedVersion);
  if (!Number.isInteger(expectedVersion) || expectedVersion < 1) {
    throw new HttpsError("invalid-argument", "INVALID_EXPECTED_VERSION");
  }
  const targetStatus = requiredString(data, "targetStatus");
  if (!LAB_STATUSES.has(targetStatus)) {
    throw new HttpsError("invalid-argument", "INVALID_TARGET_STATUS");
  }
  const uid = request.auth.uid;
  const now = Timestamp.now();
  const labRef = db.collection(COLLECTIONS.laboratories).doc(laboratoryId);
  const idemRef = idempotencyRef(
      db,
      "changeOdlaLaboratoryStatus",
      uid,
      ctx.idempotencyKey,
  );
  return db.runTransaction(async (tx) => {
    const replay = await replayIfIdempotent(tx, idemRef, ctx.requestSha256);
    if (replay) return replay;
    const snap = await tx.get(labRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "LABORATORY_NOT_FOUND");
    }
    const before = snap.data() || {};
    if (Number(before.version || 0) !== expectedVersion) {
      throw new HttpsError("aborted", "VERSION_PREIMAGE_MISMATCH");
    }
    ensureStatusTransition(
        before.status,
        targetStatus,
        LAB_TRANSITIONS,
        "ILLEGAL_STATUS_TRANSITION",
    );
    const after = {
      ...before,
      status: targetStatus,
      version: expectedVersion + 1,
      updatedAt: now,
      updatedBy: uid,
    };
    after.recordSha256 = sha256Hex(after);
    const auditRef = db.collection(COLLECTIONS.audits).doc();
    const base = auditBase({
      auditEventId: auditRef.id,
      entityType: "laboratory",
      entityId: laboratoryId,
      entityVersion: after.version,
      eventType: `LABORATORY_STATUS_${targetStatus}`,
      uid,
      roleCode: safeRoleCode(roles),
      idempotencyKey: ctx.idempotencyKey,
      reasonCode: ctx.reasonCode,
      occurredAt: now,
      beforeSha256: before.recordSha256 || sha256Hex(before),
      afterSha256: after.recordSha256,
      previousAuditEventSha256: before.lastAuditEventSha256 || null,
    });
    const eventSha256 = auditEventHash(base);
    after.lastAuditEventSha256 = eventSha256;
    const response = {
      laboratoryId,
      version: after.version,
      status: after.status,
      recordSha256: after.recordSha256,
    };
    tx.set(labRef, after, {merge: false});
    tx.create(auditRef, {...base, eventSha256});
    tx.create(idemRef, {
      callableName: "changeOdlaLaboratoryStatus",
      actorUid: uid,
      requestSha256: ctx.requestSha256,
      createdAt: now,
      resultCode: "STATUS_CHANGED",
      resultEntityIds: [laboratoryId],
      result: response,
    });
    return response;
  });
}

const callableOptions = {region: REGION, enforceAppCheck: true};

const getOdlaLaboratoryRegistryEntry = onCall(
    callableOptions,
    registryEntryHandler,
);
const listOdlaLaboratoriesForAuthorizedWorkspace = onCall(
    callableOptions,
    listAuthorizedWorkspaceHandler,
);
const getOdlaLaboratoryAccreditationHistory = onCall(
    callableOptions,
    accreditationHistoryHandler,
);
const registerOdlaLaboratory = onCall(
    callableOptions,
    registerLaboratoryHandler,
);
const submitOdlaLaboratoryAccreditation = onCall(
    callableOptions,
    submitAccreditationHandler,
);
const reviewOdlaLaboratoryAccreditation = onCall(
    callableOptions,
    reviewAccreditationHandler,
);
const changeOdlaLaboratoryStatus = onCall(
    callableOptions,
    changeLaboratoryStatusHandler,
);

module.exports = {
  getOdlaLaboratoryRegistryEntry,
  listOdlaLaboratoriesForAuthorizedWorkspace,
  getOdlaLaboratoryAccreditationHistory,
  registerOdlaLaboratory,
  submitOdlaLaboratoryAccreditation,
  reviewOdlaLaboratoryAccreditation,
  changeOdlaLaboratoryStatus,
  _test: {
    MAX_SCOPES,
    canonicalize,
    canonicalJson,
    sha256Hex,
    stableRequestHash,
    validateScopeList,
    evaluateCoverage,
    ensureStatusTransition,
    reviewDecision,
    LAB_TRANSITIONS,
    ACCREDITATION_TRANSITIONS,
    ACCREDITATION_STATUSES,
    VERIFICATION_STATUSES,
  },
};
