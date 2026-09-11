"use strict";

function fail(code, message) {
  const error = new Error(message || code);
  error.code = code;
  throw error;
}

function requireString(value, name) {
  if (typeof value !== "string" || !value) {
    fail("invalid-argument", `${name} required`);
  }
  return value;
}

function createOdlaFirestoreAdapter({db, FieldValue}) {
  if (
    !db ||
    typeof db.doc !== "function" ||
    typeof db.runTransaction !== "function" ||
    typeof db.collection !== "function"
  ) {
    fail("failed-precondition", "Injected Firestore db required");
  }
  if (!FieldValue || typeof FieldValue.serverTimestamp !== "function") {
    fail("failed-precondition", "Injected FieldValue required");
  }

  const casePath = (caseId) =>
    `odlaVerificationCases/${requireString(caseId, "caseId")}`;
  const childPath = (caseId, kind, id) =>
    `${casePath(caseId)}/${kind}/${requireString(id, "documentId")}`;

  function normalizeAuditContext(
      caseId,
      operationId,
      actorUid,
      action,
      auditContext,
  ) {
    if (!auditContext || typeof auditContext !== "object") {
      fail("failed-precondition", "Trusted audit context required");
    }
    if (
      auditContext.caseId !== caseId ||
      auditContext.operationId !== operationId ||
      auditContext.actorUid !== actorUid ||
      auditContext.action !== action
    ) {
      fail("failed-precondition", "Trusted audit context mismatch");
    }
    return Object.freeze({
      auditEventId: requireString(
          auditContext.auditEventId,
          "auditEventId",
      ),
      caseId,
      operationId: requireString(operationId, "operationId"),
      actorUid: requireString(actorUid, "actorUid"),
      action: requireString(action, "action"),
      tenantId: requireString(auditContext.tenantId, "tenantId"),
      brandUid: requireString(auditContext.brandUid, "brandUid"),
      source: "odla_server_trusted_context",
      appendOnly: true,
      recordedAt: FieldValue.serverTimestamp(),
    });
  }

  async function createIdempotentWithAudit({
    ref,
    caseId,
    payload,
    operationId,
    actorUid,
    action,
    auditContext,
  }) {
    requireString(operationId, "operationId");
    const audit = normalizeAuditContext(
        caseId,
        operationId,
        actorUid,
        action,
        auditContext,
    );
    const auditRef = db.doc(
        childPath(caseId, "auditEvents", audit.auditEventId),
    );
    return db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      const auditSnap = await tx.get(auditRef);
      if (existing.exists) {
        const current = existing.data();
        if (current.operationId !== operationId) {
          fail(
              "already-exists",
              "Conflicting operation for immutable ODLA record",
          );
        }
        if (
          !auditSnap.exists ||
          auditSnap.data().operationId !== operationId ||
          auditSnap.data().action !== action
        ) {
          fail(
              "failed-precondition",
              "Idempotent domain record missing matching audit",
          );
        }
        return {created: false, idempotent: true, data: current};
      }
      if (auditSnap.exists) {
        fail("already-exists", "Audit event identity conflict");
      }
      const data = Object.freeze({
        ...payload,
        operationId,
        actorUid: requireString(actorUid, "actorUid"),
        recordedAt: FieldValue.serverTimestamp(),
      });
      tx.create(ref, data);
      tx.create(auditRef, audit);
      return {created: true, idempotent: false, data};
    });
  }

  async function appendAuditEvent(caseId, event) {
    const eventId = requireString(event.auditEventId, "auditEventId");
    const ref = db.doc(childPath(caseId, "auditEvents", eventId));
    const data = Object.freeze({
      ...event,
      appendOnly: true,
      recordedAt: FieldValue.serverTimestamp(),
    });
    await ref.create(data);
    return data;
  }

  async function createCase({
    caseRecord,
    operationId,
    actorUid,
    auditContext,
  }) {
    const ref = db.doc(casePath(caseRecord.caseId));
    return createIdempotentWithAudit({
      ref,
      caseId: caseRecord.caseId,
      payload: {
        ...caseRecord,
        creationOperationId: operationId,
        immutableCreationMetadata: true,
      },
      operationId,
      actorUid,
      action: "create_case",
      auditContext,
    });
  }

  async function getWorkspace(caseId) {
    const ref = db.doc(casePath(caseId));
    const snap = await ref.get();
    if (!snap.exists) fail("not-found", "ODLA verification case not found");
    return Object.freeze({case: Object.freeze({...snap.data()})});
  }

  async function getVerificationProfile(profileId) {
    const ref = db.doc(
        `odlaVerificationProfiles/${requireString(profileId, "profileId")}`,
    );
    const snap = await ref.get();
    if (!snap.exists) {
      fail("not-found", "ODLA verification profile not found");
    }
    return Object.freeze({...snap.data(), profileId});
  }

  async function getLatestCustodyEvent(caseId) {
    const root = await db.doc(casePath(caseId)).get();
    if (!root.exists) fail("not-found", "ODLA verification case not found");
    const data = root.data();
    if (!data.latestCustodyEventId) return null;
    const eventSnap = await db
        .doc(childPath(caseId, "custodyEvents", data.latestCustodyEventId))
        .get();
    return eventSnap.exists ? Object.freeze({...eventSnap.data()}) : null;
  }

  async function appendCustodyEvent({
    event,
    operationId,
    actorUid,
    auditContext,
  }) {
    const rootRef = db.doc(casePath(event.caseId));
    const eventRef = db.doc(
        childPath(event.caseId, "custodyEvents", event.eventId),
    );
    const audit = normalizeAuditContext(
        event.caseId,
        operationId,
        actorUid,
        "append_custody",
        auditContext,
    );
    const auditRef = db.doc(
        childPath(event.caseId, "auditEvents", audit.auditEventId),
    );
    return db.runTransaction(async (tx) => {
      const root = await tx.get(rootRef);
      if (!root.exists) {
        fail("not-found", "ODLA verification case not found");
      }
      const existing = await tx.get(eventRef);
      const auditSnap = await tx.get(auditRef);
      if (existing.exists) {
        const current = existing.data();
        if (current.operationId !== operationId) {
          fail("already-exists", "Custody event identity conflict");
        }
        if (
          !auditSnap.exists ||
          auditSnap.data().operationId !== operationId
        ) {
          fail(
              "failed-precondition",
              "Idempotent custody event missing matching audit",
          );
        }
        return {created: false, idempotent: true, data: current};
      }
      if (auditSnap.exists) {
        fail("already-exists", "Audit event identity conflict");
      }
      const rootData = root.data();
      const expectedSequence = Number.isInteger(
          rootData.latestCustodySequence,
      ) ?
        rootData.latestCustodySequence + 1 :
        1;
      if (event.eventSequence !== expectedSequence) {
        fail("failed-precondition", "Custody sequence precondition failed");
      }
      const data = {
        ...event,
        operationId: requireString(operationId, "operationId"),
        actorUid: requireString(actorUid, "actorUid"),
        recordedAtServer: FieldValue.serverTimestamp(),
      };
      tx.create(eventRef, data);
      tx.create(auditRef, audit);
      tx.set(
          rootRef,
          {
            latestCustodySequence: event.eventSequence,
            latestCustodyEventId: event.eventId,
            latestCustodyEventPayloadSha256: event.eventPayloadSha256,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return {created: true, idempotent: false, data};
    });
  }

  async function createTestRequest({
    caseId,
    requestRecord,
    operationId,
    actorUid,
    auditContext,
    linkAppealId = null,
  }) {
    const ref = db.doc(
        childPath(caseId, "testRequests", requestRecord.testRequestId),
    );
    const audit = normalizeAuditContext(
        caseId,
        operationId,
        actorUid,
        "create_test_request",
        auditContext,
    );
    const auditRef = db.doc(
        childPath(caseId, "auditEvents", audit.auditEventId),
    );
    const appealRef = linkAppealId ?
      db.doc(childPath(caseId, "appeals", linkAppealId)) :
      null;
    return db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      const auditSnap = await tx.get(auditRef);
      const appealSnap = appealRef ? await tx.get(appealRef) : null;
      if (appealRef && !appealSnap.exists) {
        fail("not-found", "Appeal not found");
      }
      if (existing.exists) {
        const current = existing.data();
        if (current.operationId !== operationId) {
          fail(
              "already-exists",
              "Conflicting operation for immutable ODLA record",
          );
        }
        if (
          !auditSnap.exists ||
          auditSnap.data().operationId !== operationId
        ) {
          fail(
              "failed-precondition",
              "Idempotent test request missing matching audit",
          );
        }
        return {created: false, idempotent: true, data: current};
      }
      if (auditSnap.exists) {
        fail("already-exists", "Audit event identity conflict");
      }
      const data = Object.freeze({
        ...requestRecord,
        operationId,
        actorUid: requireString(actorUid, "actorUid"),
        recordedAt: FieldValue.serverTimestamp(),
      });
      tx.create(ref, data);
      tx.create(auditRef, audit);
      if (appealRef) {
        tx.set(
            appealRef,
            {
              appealTestRequestId: requestRecord.testRequestId,
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
      }
      return {created: true, idempotent: false, data};
    });
  }

  async function getTestRequest(caseId, testRequestId) {
    const snap = await db
        .doc(childPath(caseId, "testRequests", testRequestId))
        .get();
    if (!snap.exists) fail("not-found", "ODLA test request not found");
    return Object.freeze({...snap.data()});
  }

  async function createTestResult({
    caseId,
    resultRecord,
    operationId,
    actorUid,
    auditContext,
  }) {
    return createIdempotentWithAudit({
      ref: db.doc(
          childPath(caseId, "testResults", resultRecord.testResultId),
      ),
      caseId,
      payload: {...resultRecord, appendOnly: true},
      operationId,
      actorUid,
      action: "record_test_result",
      auditContext,
    });
  }

  async function writeFinding({
    caseId,
    findingRecord,
    operationId,
    actorUid,
    auditContext,
  }) {
    return createIdempotentWithAudit({
      ref: db.doc(childPath(caseId, "findings", findingRecord.findingId)),
      caseId,
      payload: findingRecord,
      operationId,
      actorUid,
      action: "adjudicate_finding",
      auditContext,
    });
  }

  async function getFinding(caseId, findingId) {
    const snap = await db
        .doc(childPath(caseId, "findings", findingId))
        .get();
    if (!snap.exists) fail("not-found", "ODLA finding not found");
    return Object.freeze({...snap.data()});
  }

  async function createAppeal({
    caseId,
    appealRecord,
    operationId,
    actorUid,
    auditContext,
  }) {
    return createIdempotentWithAudit({
      ref: db.doc(childPath(caseId, "appeals", appealRecord.appealId)),
      caseId,
      payload: appealRecord,
      operationId,
      actorUid,
      action: "open_appeal",
      auditContext,
    });
  }

  async function getAppeal(caseId, appealId) {
    const snap = await db.doc(childPath(caseId, "appeals", appealId)).get();
    if (!snap.exists) fail("not-found", "Appeal not found");
    return Object.freeze({...snap.data()});
  }

  async function resolveAppeal({
    caseId,
    appealId,
    resolution,
    operationId,
    actorUid,
    auditContext,
  }) {
    requireString(operationId, "operationId");
    const ref = db.doc(childPath(caseId, "appeals", appealId));
    const audit = normalizeAuditContext(
        caseId,
        operationId,
        actorUid,
        "resolve_appeal",
        auditContext,
    );
    const auditRef = db.doc(
        childPath(caseId, "auditEvents", audit.auditEventId),
    );
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) fail("not-found", "Appeal not found");
      const auditSnap = await tx.get(auditRef);
      const current = snap.data();
      if (current.resolutionOperationId) {
        if (current.resolutionOperationId !== operationId) {
          fail(
              "already-exists",
              "Appeal already resolved by another operation",
          );
        }
        if (
          !auditSnap.exists ||
          auditSnap.data().operationId !== operationId
        ) {
          fail(
              "failed-precondition",
              "Idempotent appeal resolution missing matching audit",
          );
        }
        return {updated: false, idempotent: true, data: current};
      }
      if (auditSnap.exists) {
        fail("already-exists", "Audit event identity conflict");
      }
      const data = {
        ...resolution,
        resolutionOperationId: operationId,
        resolvedBy: requireString(actorUid, "actorUid"),
        resolvedAt: FieldValue.serverTimestamp(),
      };
      tx.set(ref, data, {merge: true});
      tx.create(auditRef, audit);
      return {
        updated: true,
        idempotent: false,
        data: {...current, ...data},
      };
    });
  }

  async function getLaboratory(laboratoryId) {
    const snap = await db
        .doc(
            `odlaLaboratories/${requireString(laboratoryId, "laboratoryId")}`,
        )
        .get();
    if (!snap.exists) fail("not-found", "Laboratory not found");
    return Object.freeze({...snap.data(), laboratoryId});
  }

  async function getAdjudicationContext(caseId, excludeAppealId = null) {
    const caseSnap = await db.doc(casePath(caseId)).get();
    if (!caseSnap.exists) {
      fail("not-found", "ODLA verification case not found");
    }
    const appealQuery = await db
        .collection(`${casePath(caseId)}/appeals`)
        .get();
    const appeals = Array.isArray(appealQuery.docs) ?
      appealQuery.docs.map((d) => d.data()) :
      [];
    const openMaterialAppeal = appeals.some(
        (a) =>
          a &&
        a.appealId !== excludeAppealId &&
        a.material === true &&
        !["resolved", "closed", "dismissed"].includes(a.state),
    );
    const root = caseSnap.data();
    const summary =
      root &&
      root.trustedEvidenceSummary &&
      root.trustedEvidenceSummary.serverOwned === true ?
        root.trustedEvidenceSummary :
        null;
    const missingRequiredEvidence =
      !summary ||
      summary.complete !== true ||
      summary.missingRequiredEvidence === true;
    return Object.freeze({
      openMaterialAppeal,
      unresolvedIntegrityConflict: summary ?
        summary.unresolvedIntegrityConflict === true :
        false,
      missingRequiredEvidence,
      singleReporterOnly: summary ?
        summary.singleReporterOnly === true :
        false,
      sellerSuppliedSampleSole: summary ?
        summary.sellerSuppliedSampleSole === true :
        false,
      source: "server_persisted_odla_state",
    });
  }

  return Object.freeze({
    createCase,
    getWorkspace,
    getVerificationProfile,
    getLatestCustodyEvent,
    appendCustodyEvent,
    createTestRequest,
    getTestRequest,
    createTestResult,
    writeFinding,
    getFinding,
    createAppeal,
    getAppeal,
    resolveAppeal,
    getLaboratory,
    getAdjudicationContext,
    appendAuditEvent,
  });
}

module.exports = {createOdlaFirestoreAdapter};
