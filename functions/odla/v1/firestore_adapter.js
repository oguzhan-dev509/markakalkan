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

  async function listCaseChildren(caseId, kind, sequenceKey, idKey) {
    const allowedKinds = new Set([
      "custodyEvents",
      "testRequests",
      "testResults",
      "findings",
      "appeals",
    ]);
    if (!allowedKinds.has(kind)) {
      fail("failed-precondition", "Unsupported ODLA workspace child kind");
    }

    const collectionRef = db.collection(`${casePath(caseId)}/${kind}`);
    const query =
      collectionRef && typeof collectionRef.limit === "function" ?
        collectionRef.limit(200) :
        collectionRef;
    const snapshot = await query.get();
    const docs = Array.isArray(snapshot.docs) ? snapshot.docs : [];

    const rows = docs.map((doc) => {
      const raw =
        doc && typeof doc.data === "function" ?
          (doc.data() || {}) :
          {};
      return {
        ...raw,
        [idKey]: raw[idKey] || doc.id,
      };
    });

    rows.sort((left, right) => {
      const leftSequence =
        sequenceKey && Number.isInteger(left[sequenceKey]) ?
          left[sequenceKey] :
          null;
      const rightSequence =
        sequenceKey && Number.isInteger(right[sequenceKey]) ?
          right[sequenceKey] :
          null;

      if (leftSequence !== null && rightSequence !== null &&
          leftSequence !== rightSequence) {
        return leftSequence - rightSequence;
      }
      if (leftSequence !== null && rightSequence === null) return -1;
      if (leftSequence === null && rightSequence !== null) return 1;

      return String(left[idKey] || "").localeCompare(
          String(right[idKey] || ""),
      );
    });

    return Object.freeze(
        rows.map((row) => Object.freeze({...row})),
    );
  }

  async function listCustodyEvents(caseId) {
    return listCaseChildren(
        caseId,
        "custodyEvents",
        "eventSequence",
        "eventId",
    );
  }

  async function listTestRequests(caseId) {
    return listCaseChildren(
        caseId,
        "testRequests",
        "requestSequence",
        "testRequestId",
    );
  }

  async function listTestResults(caseId) {
    return listCaseChildren(
        caseId,
        "testResults",
        null,
        "testResultId",
    );
  }

  async function listFindings(caseId) {
    return listCaseChildren(
        caseId,
        "findings",
        "findingVersion",
        "findingId",
    );
  }

  async function listAppeals(caseId) {
    return listCaseChildren(
        caseId,
        "appeals",
        "appealSequence",
        "appealId",
    );
  }

  async function getOperationalWorkspaceDetails(caseId) {
    const [
      custodyEvents,
      testRequests,
      testResults,
      findings,
      appeals,
    ] = await Promise.all([
      listCustodyEvents(caseId),
      listTestRequests(caseId),
      listTestResults(caseId),
      listFindings(caseId),
      listAppeals(caseId),
    ]);

    return Object.freeze({
      custodyEvents,
      testRequests,
      testResults,
      findings,
      appeals,
    });
  }

  async function getWorkspaceLaboratoryRegistryContext(input) {
    const rawLaboratoryIds =
      input && Array.isArray(input.laboratoryIds) ?
        input.laboratoryIds :
        [];
    const laboratoryIds = [...new Set(
        rawLaboratoryIds
            .filter((value) => typeof value === "string" && value.trim())
            .map((value) => value.trim()),
    )].slice(0, 20);
    const references =
      input && Array.isArray(input.references) ?
        input.references
            .filter((value) => value && typeof value === "object")
            .filter((value) => laboratoryIds.includes(value.laboratoryId))
            .slice(0, 200) :
        [];

    if (laboratoryIds.length === 0) {
      return Object.freeze({
        contractVersion:
          "odla-workspace-laboratory-registry-context-v1",
        laboratories: Object.freeze([]),
        referencedLaboratoryCount:
          Number(input && input.totalReferencedLaboratoryCount) || 0,
        resolvedLaboratoryCount: 0,
        legacyUnknownCount: 0,
        truncated: Boolean(input && input.truncated),
      });
    }

    const laboratorySnapshots = await Promise.all(
        laboratoryIds.map((laboratoryId) =>
          db.doc(`odlaLaboratories/${laboratoryId}`).get(),
        ),
    );

    const accreditations = [];
    for (let offset = 0; offset < laboratoryIds.length; offset += 10) {
      const chunk = laboratoryIds.slice(offset, offset + 10);
      const snap = await db
          .collection("odlaLaboratoryAccreditations")
          .where("laboratoryId", "in", chunk)
          .limit(100)
          .get();
      const docs = Array.isArray(snap.docs) ? snap.docs : [];
      for (const doc of docs) {
        const data =
          doc && typeof doc.data === "function" ?
            (doc.data() || {}) :
            {};
        accreditations.push({
          ...data,
          accreditationId: data.accreditationId || doc.id,
        });
        if (accreditations.length >= 100) break;
      }
      if (accreditations.length >= 100) break;
    }

    const accreditationIds = [...new Set(
        accreditations
            .map((value) => value.accreditationId)
            .filter((value) => typeof value === "string" && value.trim()),
    )].slice(0, 30);

    const scopes = [];
    for (let offset = 0; offset < accreditationIds.length; offset += 10) {
      const chunk = accreditationIds.slice(offset, offset + 10);
      const snap = await db
          .collection("odlaLaboratoryTestScopes")
          .where("accreditationId", "in", chunk)
          .limit(200)
          .get();
      const docs = Array.isArray(snap.docs) ? snap.docs : [];
      for (const doc of docs) {
        const data =
          doc && typeof doc.data === "function" ?
            (doc.data() || {}) :
            {};
        scopes.push({
          ...data,
          scopeId: data.scopeId || doc.id,
        });
        if (scopes.length >= 200) break;
      }
      if (scopes.length >= 200) break;
    }

    const contexts = laboratoryIds.map((laboratoryId, index) => {
      const labSnap = laboratorySnapshots[index];
      const laboratory =
        labSnap && labSnap.exists ?
          Object.freeze({
            ...(labSnap.data() || {}),
            laboratoryId,
          }) :
          null;
      const laboratoryAccreditations = accreditations
          .filter((value) => value.laboratoryId === laboratoryId)
          .slice(0, 50);
      const laboratoryAccreditationIds = new Set(
          laboratoryAccreditations.map((value) => value.accreditationId),
      );
      const laboratoryScopes = scopes
          .filter((value) =>
            laboratoryAccreditationIds.has(value.accreditationId),
          )
          .slice(0, 100);
      const laboratoryReferences = references
          .filter((value) => value.laboratoryId === laboratoryId);

      const coverageContexts = laboratoryReferences.map((reference) => {
        const accreditationId =
          typeof reference.accreditationId === "string" ?
            reference.accreditationId :
            null;
        const scopeId =
          typeof reference.scopeId === "string" ?
            reference.scopeId :
            null;
        const accreditation = accreditationId ?
          laboratoryAccreditations.find(
              (value) => value.accreditationId === accreditationId,
          ) :
          null;
        const scope = scopeId ?
          laboratoryScopes.find((value) => value.scopeId === scopeId) :
          null;
        const partialReference =
          (accreditationId && !accreditation) ||
          (scopeId && !scope);
        return Object.freeze({
          referenceType: reference.referenceType || "UNKNOWN",
          referenceId: reference.referenceId || null,
          accreditationId,
          scopeId,
          persistedCoverageStatus:
            reference.accreditationCoverageStatus || "UNKNOWN",
          persistedCoverageReasonCode:
            reference.accreditationCoverageReasonCode || "UNKNOWN",
          verificationStatus:
            accreditation && accreditation.verificationStatus ?
              accreditation.verificationStatus :
              "UNVERIFIED",
          registryMatchStatus:
            !laboratory ?
              "UNKNOWN" :
              (partialReference ? "PARTIAL" : "RESOLVED"),
        });
      });

      return Object.freeze({
        laboratoryId,
        laboratory,
        registryStatus:
          laboratory && laboratory.status ?
            laboratory.status :
            "UNKNOWN",
        verificationStatus:
          laboratoryAccreditations.some(
              (value) => value.verificationStatus === "VERIFIED",
          ) ?
            "VERIFIED" :
            "UNVERIFIED",
        accreditations: Object.freeze(
            laboratoryAccreditations.map(
                (value) => Object.freeze({...value}),
            ),
        ),
        scopes: Object.freeze(
            laboratoryScopes.map((value) => Object.freeze({...value})),
        ),
        coverageContexts: Object.freeze(coverageContexts),
        registryResolutionStatus:
          laboratory ? "RESOLVED" : "UNKNOWN",
      });
    });

    return Object.freeze({
      contractVersion:
        "odla-workspace-laboratory-registry-context-v1",
      laboratories: Object.freeze(contexts),
      referencedLaboratoryCount:
        Number(input && input.totalReferencedLaboratoryCount) ||
        laboratoryIds.length,
      resolvedLaboratoryCount:
        contexts.filter((value) => value.laboratory !== null).length,
      legacyUnknownCount:
        contexts.filter((value) => value.laboratory === null).length,
      truncated: Boolean(input && input.truncated),
    });
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

  function custodySampleStatePath(caseId, sampleId) {
    const normalized = requireString(sampleId, "sampleId");
    const encoded = Buffer.from(normalized, "utf8").toString("base64url");
    return childPath(caseId, "samples", `s_${encoded}`);
  }

  async function getLatestCustodyEvent(caseId, sampleId = null) {
    const root = await db.doc(casePath(caseId)).get();
    if (!root.exists) fail("not-found", "ODLA verification case not found");
    const rootData = root.data();

    if (typeof sampleId !== "string" || !sampleId.trim()) {
      if (!rootData.latestCustodyEventId) return null;
      const legacySnap = await db
          .doc(
              childPath(
                  caseId,
                  "custodyEvents",
                  rootData.latestCustodyEventId,
              ),
          )
          .get();
      return legacySnap.exists ?
        Object.freeze({...legacySnap.data()}) :
        null;
    }

    const normalizedSampleId = sampleId.trim();
    const sampleSnap = await db
        .doc(custodySampleStatePath(caseId, normalizedSampleId))
        .get();
    if (sampleSnap.exists) {
      const state = sampleSnap.data();
      if (!state.latestCustodyEventId) {
        fail("failed-precondition", "Custody sample head is incomplete");
      }
      const eventSnap = await db
          .doc(
              childPath(
                  caseId,
                  "custodyEvents",
                  state.latestCustodyEventId,
              ),
          )
          .get();
      if (!eventSnap.exists) {
        fail("failed-precondition", "Custody sample head event missing");
      }
      const event = eventSnap.data();
      if (
        event.sampleId !== normalizedSampleId ||
        event.eventPayloadSha256 !==
          state.latestCustodyEventPayloadSha256 ||
        event.eventSequence !== state.latestCustodySequence
      ) {
        fail("failed-precondition", "Custody sample head mismatch");
      }
      return Object.freeze({...event});
    }

    if (rootData.latestCustodyEventId) {
      const legacySnap = await db
          .doc(
              childPath(
                  caseId,
                  "custodyEvents",
                  rootData.latestCustodyEventId,
              ),
          )
          .get();
      if (legacySnap.exists) {
        const legacy = legacySnap.data();
        if (legacy.sampleId === normalizedSampleId) {
          return Object.freeze({...legacy});
        }
      }
    }

    const legacyEvents = await listCustodyEvents(caseId);
    const matching = legacyEvents.filter(
        (event) => event.sampleId === normalizedSampleId,
    );
    return matching.length ?
      Object.freeze({...matching[matching.length - 1]}) :
      null;
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
    const sampleRef = db.doc(
        custodySampleStatePath(event.caseId, event.sampleId),
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
      const sampleSnap = await tx.get(sampleRef);

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

      let predecessor = null;
      if (event.eventSequence === 1) {
        if (
          event.previousEventId !== null ||
          event.previousEventPayloadSha256 !== null
        ) {
          fail(
              "failed-precondition",
              "Custody genesis predecessor mismatch",
          );
        }
      } else {
        if (
          typeof event.previousEventId !== "string" ||
          !event.previousEventId ||
          typeof event.previousEventPayloadSha256 !== "string" ||
          !event.previousEventPayloadSha256
        ) {
          fail("failed-precondition", "Custody predecessor required");
        }
        const predecessorSnap = await tx.get(
            db.doc(
                childPath(
                    event.caseId,
                    "custodyEvents",
                    event.previousEventId,
                ),
            ),
        );
        if (!predecessorSnap.exists) {
          fail("failed-precondition", "Custody predecessor event missing");
        }
        predecessor = predecessorSnap.data();
        if (
          predecessor.sampleId !== event.sampleId ||
          predecessor.eventId !== event.previousEventId ||
          predecessor.eventPayloadSha256 !==
            event.previousEventPayloadSha256 ||
          predecessor.eventSequence !== event.eventSequence - 1
        ) {
          fail("failed-precondition", "Custody predecessor mismatch");
        }
      }

      if (sampleSnap.exists) {
        const state = sampleSnap.data();
        const expectedSequence = Number.isInteger(
            state.latestCustodySequence,
        ) ?
          state.latestCustodySequence + 1 :
          1;
        if (event.eventSequence !== expectedSequence) {
          fail(
              "failed-precondition",
              "Custody sample sequence precondition failed",
          );
        }
        if (
          event.eventSequence > 1 &&
          (
            event.previousEventId !== state.latestCustodyEventId ||
            event.previousEventPayloadSha256 !==
              state.latestCustodyEventPayloadSha256
          )
        ) {
          fail(
              "failed-precondition",
              "Custody sample predecessor precondition failed",
          );
        }
      } else if (event.eventSequence > 1 && predecessor === null) {
        fail(
            "failed-precondition",
            "Legacy custody predecessor validation failed",
        );
      }

      const data = {
        ...event,
        operationId: requireString(operationId, "operationId"),
        actorUid: requireString(actorUid, "actorUid"),
        recordedAtServer: FieldValue.serverTimestamp(),
      };
      const now = FieldValue.serverTimestamp();
      tx.create(eventRef, data);
      tx.create(auditRef, audit);
      tx.set(
          sampleRef,
          {
            schemaVersion: 1,
            sampleId: event.sampleId,
            latestCustodySequence: event.eventSequence,
            latestCustodyEventId: event.eventId,
            latestCustodyEventPayloadSha256: event.eventPayloadSha256,
            currentSealId: event.sealId ?? null,
            updatedAt: now,
          },
          {merge: true},
      );

      const rootData = root.data();
      if (
        !rootData.latestCustodyEventId ||
        event.previousEventId === rootData.latestCustodyEventId
      ) {
        tx.set(
            rootRef,
            {
              latestCustodySequence: event.eventSequence,
              latestCustodyEventId: event.eventId,
              latestCustodyEventPayloadSha256:
                event.eventPayloadSha256,
              updatedAt: now,
            },
            {merge: true},
        );
      } else {
        tx.set(rootRef, {updatedAt: now}, {merge: true});
      }
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


  async function listCasesForAuthority({tenantId, brandUids, limit = 100}) {
    if (typeof tenantId !== "string" || !tenantId.trim()) {
      throw new Error("ODLA tenant scope required");
    }
    if (!Array.isArray(brandUids) || brandUids.length === 0) {
      throw new Error("ODLA brand scope required");
    }
    const boundedLimit = Number.isInteger(limit) ?
      Math.min(Math.max(limit, 1), 100) :
      100;
    const allowedBrands = new Set(brandUids);
    const snapshot = await db.collection("odlaVerificationCases")
        .where("tenantId", "==", tenantId)
        .get();
    return snapshot.docs
        .map((doc) => ({id: doc.id, data: doc.data() || {}}))
        .filter((item) => allowedBrands.has(item.data.brandUid))
        .slice(0, boundedLimit)
        .map((item) => Object.freeze({
          caseId: item.data.caseId || item.id,
          tenantId: item.data.tenantId,
          brandUid: item.data.brandUid,
          state: item.data.state || null,
          profileId: item.data.profileId || null,
          profileCode: item.data.profileCode || null,
          profileVersion: item.data.profileVersion || null,
          productClassCode: item.data.productClassCode || null,
          countryCode: item.data.countryCode || null,
        }));
  }

  return Object.freeze({
    listCasesForAuthority,
    createCase,
    getWorkspace,
    getOperationalWorkspaceDetails,
    getWorkspaceLaboratoryRegistryContext,
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
