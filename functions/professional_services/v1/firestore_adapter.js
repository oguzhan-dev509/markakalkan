/* eslint-disable max-len */
"use strict";

const {
  ProfessionalServicesContractError,
  SOURCE_REFERENCE_FIELDS,
  requiredCode,
  requiredString,
} = require("./contracts");
const {
  prefixedId,
} = require("./identifiers");
const {
  PROFESSIONAL_SERVICE_OPERATION_CODES,
} = require("./service");

const FIRESTORE_COLLECTIONS = Object.freeze({
  TENANT_MEMBERSHIPS: "tenant_memberships",
  PROFESSIONAL_SERVICE_AUTHORITIES: "professional_service_authorities",
  PROFESSIONAL_SERVICE_REQUESTS: "professional_service_requests",
  PROFESSIONAL_CLIENT_AUTHORIZATIONS: "professional_client_authorizations",
  PROFESSIONAL_SERVICE_ENGAGEMENTS: "professional_service_engagements",
  PROFESSIONAL_SERVICE_PROVIDERS: "professional_service_providers",
  PROFESSIONAL_CONFLICT_CHECKS: "professional_conflict_checks",
  PROFESSIONAL_SERVICE_ASSIGNMENTS: "professional_service_assignments",
  PROFESSIONAL_AGENT_TASKS: "professional_agent_tasks",
  PROFESSIONAL_AGENT_RUNS: "professional_agent_runs",
  PROFESSIONAL_AGENT_OUTPUT_DRAFTS: "professional_agent_output_drafts",
  PROFESSIONAL_AGENT_HUMAN_REVIEWS: "professional_agent_human_reviews",
  PROFESSIONAL_AGENT_OUTPUT_PUBLICATIONS:
    "professional_agent_output_publications",
  PROFESSIONAL_SERVICE_EVENTS: "professional_service_events",
});

const SOURCE_REFERENCE_COLLECTIONS = Object.freeze({
  riskSignalId: "shared_risk_signals",
  riskOperationId: "risk_scan_runs",
  caseId: "case_files",
  evidenceRefId: "case_evidence_records",
  evidenceObjectId: "case_evidence_objects",
  legalMatterId: "legal_matter_files",
  authorityActionId: "legal_authority_actions",
  customsSubmissionId: "customs_security_submissions",
  customsInterventionId: "customs_security_interventions",
  counterfeitTwinId: "counterfeit_twin_records",
});

const DOMAIN_EVENT_RECORD_TYPE = "domain_event";
const COMMAND_RECEIPT_RECORD_TYPE = "command_receipt";

function fail(code, message) {
  throw new ProfessionalServicesContractError(code, message);
}

function objectRequired(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail("failed-precondition", `${field} invalid`);
  }
  return value;
}

function assertDb(db) {
  if (
    !db ||
    typeof db.collection !== "function" ||
    typeof db.runTransaction !== "function"
  ) {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function snapshotData(snapshot) {
  if (!snapshot || snapshot.exists !== true) return null;
  const data = snapshot.data();
  return data && typeof data === "object" ? data : null;
}

function buildCommandReceiptId({scopeType, scopeId, idempotencyKey}) {
  return prefixedId("psrc", {
    scopeType: requiredString(scopeType, "scopeType", 1, 96),
    scopeId: requiredString(scopeId, "scopeId", 1, 128),
    idempotencyKey: requiredString(
        idempotencyKey,
        "idempotencyKey",
        1,
        256,
    ),
  });
}

function buildConflictCheckId({serviceRequestId, providerId}) {
  return prefixedId("pcc", {
    serviceRequestId: requiredString(
        serviceRequestId,
        "serviceRequestId",
        1,
        128,
    ),
    providerId: requiredString(providerId, "providerId", 1, 128),
  });
}

function documentRef(db, collectionName, id, field) {
  return db
      .collection(collectionName)
      .doc(requiredString(id, field, 1, 128));
}

function serviceRequestRef(db, serviceRequestId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
      serviceRequestId,
      "serviceRequestId",
  );
}

function clientAuthorizationRef(db, authorizationId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_CLIENT_AUTHORIZATIONS,
      authorizationId,
      "authorizationId",
  );
}

function serviceEngagementRef(db, serviceEngagementId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_ENGAGEMENTS,
      serviceEngagementId,
      "serviceEngagementId",
  );
}

function serviceProviderRef(db, providerId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_PROVIDERS,
      providerId,
      "providerId",
  );
}

function conflictCheckRef(db, input) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_CONFLICT_CHECKS,
      buildConflictCheckId(input),
      "conflictCheckId",
  );
}

function serviceAssignmentRef(db, serviceAssignmentId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_ASSIGNMENTS,
      serviceAssignmentId,
      "serviceAssignmentId",
  );
}

function agentTaskRef(db, agentTaskId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_TASKS,
      agentTaskId,
      "agentTaskId",
  );
}

function agentRunRef(db, agentRunId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_RUNS,
      agentRunId,
      "agentRunId",
  );
}

function agentOutputDraftRef(db, outputDraftId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_DRAFTS,
      outputDraftId,
      "outputDraftId",
  );
}

function agentHumanReviewRef(db, humanReviewId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_HUMAN_REVIEWS,
      humanReviewId,
      "humanReviewId",
  );
}

function agentOutputPublicationRef(db, publicationId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_PUBLICATIONS,
      publicationId,
      "publicationId",
  );
}

function serviceEventRef(db, eventId) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS,
      eventId,
      "eventId",
  );
}

function commandReceiptRef(db, input) {
  return documentRef(
      db,
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS,
      buildCommandReceiptId(input),
      "commandReceiptId",
  );
}

function normalizeSourceReferenceCollections(raw) {
  if (raw == null) return SOURCE_REFERENCE_COLLECTIONS;
  objectRequired(raw, "sourceReferenceCollections");
  const extras = Object.keys(raw)
      .filter((field) => !SOURCE_REFERENCE_FIELDS.includes(field));
  if (extras.length > 0) {
    fail("invalid-argument", "sourceReferenceCollections invalid");
  }
  const result = {...SOURCE_REFERENCE_COLLECTIONS};
  for (const field of SOURCE_REFERENCE_FIELDS) {
    if (raw[field] != null) {
      result[field] = requiredString(
          raw[field],
          `sourceReferenceCollections.${field}`,
          1,
          128,
      );
    }
  }
  return Object.freeze(result);
}

function sourceDocumentScope(data, field, referenceId) {
  objectRequired(data, `sourceReferences.${field}`);
  const tenantId = data.tenantId;
  const canonicalBrandId = data.canonicalBrandId || data.brandId;
  if (
    typeof tenantId !== "string" ||
    tenantId.trim() === "" ||
    typeof canonicalBrandId !== "string" ||
    canonicalBrandId.trim() === ""
  ) {
    fail(
        "internal",
        `canonical source scope is incomplete: ${field}:${referenceId}`,
    );
  }
  return Object.freeze({
    tenantId: tenantId.trim(),
    canonicalBrandId: canonicalBrandId.trim(),
    archived:
      data.archived === true ||
      data.status === "archived" ||
      data.lifecycleStatus === "archived" ||
      data.dispositionStatus === "archived",
  });
}

function assertMatchingScope(current, candidate) {
  if (
    current.tenantId !== candidate.tenantId ||
    current.canonicalBrandId !== candidate.canonicalBrandId
  ) {
    fail("failed-precondition", "canonical source scope mismatch");
  }
  return true;
}

function commandReceiptDocument({
  scopeType,
  scopeId,
  receipt,
  scope,
  aggregateType,
  aggregateId,
}) {
  objectRequired(receipt, "receipt");
  objectRequired(scope, "scope");
  return Object.freeze({
    recordType: COMMAND_RECEIPT_RECORD_TYPE,
    projectionEligible: false,
    contractVersion: receipt.contractVersion,
    scopeType,
    scopeId,
    tenantId: scope.tenantId,
    canonicalBrandId: scope.canonicalBrandId,
    aggregateType,
    aggregateId,
    requestId: receipt.requestId,
    idempotencyKey: receipt.idempotencyKey,
    payloadFingerprint: receipt.payloadFingerprint,
    resultType: receipt.resultType,
    resultId: receipt.resultId,
    actorUid: receipt.actorUid,
    recordedAt: receipt.recordedAt,
    immutable: true,
  });
}

function domainEventDocument(event, scope) {
  objectRequired(event, "event");
  objectRequired(scope, "scope");
  return Object.freeze({
    ...event,
    recordType: DOMAIN_EVENT_RECORD_TYPE,
    projectionEligible: true,
    tenantId: scope.tenantId,
    canonicalBrandId: scope.canonicalBrandId,
    immutable: true,
  });
}

function assertReceiptReplay(existing, incoming, scopeType, scopeId) {
  if (
    existing.recordType !== COMMAND_RECEIPT_RECORD_TYPE ||
    existing.scopeType !== scopeType ||
    existing.scopeId !== scopeId ||
    existing.idempotencyKey !== incoming.idempotencyKey ||
    existing.payloadFingerprint !== incoming.payloadFingerprint ||
    existing.resultType !== incoming.resultType ||
    existing.resultId !== incoming.resultId
  ) {
    fail(
        "already-exists",
        "command receipt conflicts with the incoming payload",
    );
  }
  return true;
}

function assertServiceRequestScope(persisted, expected) {
  if (
    persisted.serviceRequestId !== expected.serviceRequestId ||
    persisted.tenantId !== expected.tenantId ||
    persisted.canonicalBrandId !== expected.canonicalBrandId
  ) {
    fail("failed-precondition", "service request scope mismatch");
  }
  return true;
}

function assertAgentTaskScope(persisted, expected) {
  if (
    persisted.agentTaskId !== expected.agentTaskId ||
    persisted.serviceRequestId !== expected.serviceRequestId ||
    persisted.tenantId !== expected.tenantId ||
    persisted.canonicalBrandId !== expected.canonicalBrandId
  ) {
    fail("failed-precondition", "agent task scope mismatch");
  }
  return true;
}

function assertVersion(persisted, expected, field) {
  if (
    !Number.isSafeInteger(persisted.version) ||
    persisted.version !== expected.version
  ) {
    fail("aborted", `${field} version conflict`);
  }
  return true;
}

function recordScope(record) {
  objectRequired(record, "record");
  return Object.freeze({
    tenantId: requiredString(record.tenantId, "tenantId", 1, 128),
    canonicalBrandId: requiredString(
        record.canonicalBrandId,
        "canonicalBrandId",
        1,
        128,
    ),
  });
}

function activeAuthorityResult(item, source, operationCode) {
  return Object.freeze({
    authorized: true,
    authoritySource: source,
    authorityId: item.authorityId || null,
    membershipId: item.membershipId || null,
    operationCode,
    professionalClass: item.professionalClass || "authorized_human",
    canPublish: item.canPublishProfessionalServiceOutputs === true,
  });
}

function authorityAllows(item, {
  canonicalBrandId,
  serviceFamily,
  operationCode,
}) {
  const operations = Array.isArray(
      item.delegatedProfessionalServiceOperations,
  ) ? item.delegatedProfessionalServiceOperations : [];
  const brands = Array.isArray(
      item.delegatedCanonicalBrandIds,
  ) ? item.delegatedCanonicalBrandIds : [];
  const families = Array.isArray(
      item.delegatedProfessionalServiceFamilies,
  ) ? item.delegatedProfessionalServiceFamilies : [];
  return (
    (operations.includes("*") || operations.includes(operationCode)) &&
    (brands.includes("*") || brands.includes(canonicalBrandId)) &&
    (families.includes("*") || families.includes(serviceFamily))
  );
}

async function readSnapshots(transaction, refs) {
  return Promise.all(refs.map((ref) => transaction.get(ref)));
}

function createProfessionalServicesFirestoreAdapter(
    dbInput,
    options = {},
) {
  const db = assertDb(dbInput);
  const sourceCollections = normalizeSourceReferenceCollections(
      options.sourceReferenceCollections,
  );

  return Object.freeze({
    async getCommandReceipt({scopeType, scopeId, idempotencyKey}) {
      const normalizedScopeType = requiredString(
          scopeType,
          "scopeType",
          1,
          96,
      );
      const normalizedScopeId = requiredString(
          scopeId,
          "scopeId",
          1,
          128,
      );
      const normalizedIdempotencyKey = requiredString(
          idempotencyKey,
          "idempotencyKey",
          1,
          256,
      );
      const data = snapshotData(await commandReceiptRef(db, {
        scopeType: normalizedScopeType,
        scopeId: normalizedScopeId,
        idempotencyKey: normalizedIdempotencyKey,
      }).get());
      if (!data) return null;
      if (
        data.recordType !== COMMAND_RECEIPT_RECORD_TYPE ||
        data.scopeType !== normalizedScopeType ||
        data.scopeId !== normalizedScopeId ||
        data.idempotencyKey !== normalizedIdempotencyKey
      ) {
        fail("internal", "command receipt scope is invalid");
      }
      return data;
    },

    async resolveSourceScope({sourceReferences}) {
      objectRequired(sourceReferences, "sourceReferences");
      const extras = Object.keys(sourceReferences)
          .filter((field) => !SOURCE_REFERENCE_FIELDS.includes(field));
      if (extras.length > 0) {
        fail("invalid-argument", "sourceReferences invalid");
      }
      const resolved = [];
      const unresolvedReferences = [];
      for (const field of SOURCE_REFERENCE_FIELDS) {
        if (sourceReferences[field] == null) continue;
        const referenceId = requiredString(
            sourceReferences[field],
            `sourceReferences.${field}`,
            1,
            128,
        );
        const data = snapshotData(
            await documentRef(
                db,
                sourceCollections[field],
                referenceId,
                `sourceReferences.${field}`,
            ).get(),
        );
        if (!data) {
          unresolvedReferences.push(`${field}:${referenceId}`);
          continue;
        }
        resolved.push(sourceDocumentScope(data, field, referenceId));
      }
      if (resolved.length === 0) {
        return Object.freeze({
          tenantId: null,
          canonicalBrandId: null,
          archived: false,
          unresolvedReferences: Object.freeze(unresolvedReferences),
        });
      }
      const scope = resolved[0];
      for (const candidate of resolved.slice(1)) {
        assertMatchingScope(scope, candidate);
      }
      return Object.freeze({
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        archived: resolved.some((item) => item.archived === true),
        unresolvedReferences: Object.freeze(unresolvedReferences),
      });
    },

    async resolveProfessionalServiceAuthority({
      uid,
      tenantId,
      canonicalBrandId,
      serviceFamily,
      operationCode,
    }) {
      const normalizedUid = requiredString(uid, "uid", 1, 128);
      const normalizedTenantId = requiredString(
          tenantId,
          "tenantId",
          1,
          128,
      );
      const normalizedBrandId = requiredString(
          canonicalBrandId,
          "canonicalBrandId",
          1,
          128,
      );
      const normalizedFamily = requiredCode(serviceFamily, "serviceFamily");
      if (!PROFESSIONAL_SERVICE_OPERATION_CODES.includes(operationCode)) {
        fail("invalid-argument", "operationCode unsupported");
      }

      const membershipSnapshot = await db
          .collection(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS)
          .where("tenantId", "==", normalizedTenantId)
          .where("uid", "==", normalizedUid)
          .limit(20)
          .get();
      const memberships = membershipSnapshot.docs
          .map((doc) => ({membershipId: doc.id, ...doc.data()}))
          .filter((item) => item.status === "active");
      const owner = memberships.find((item) => item.role === "owner");
      if (owner) {
        return activeAuthorityResult(
            {
              ...owner,
              professionalClass:
                owner.professionalClass || "tenant_owner",
            },
            "tenant_owner",
            operationCode,
        );
      }
      const delegatedMembership = memberships.find((item) =>
        authorityAllows(item, {
          canonicalBrandId: normalizedBrandId,
          serviceFamily: normalizedFamily,
          operationCode,
        }));
      if (delegatedMembership) {
        return activeAuthorityResult(
            delegatedMembership,
            "tenant_membership_delegation",
            operationCode,
        );
      }

      const authoritySnapshot = await db
          .collection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_AUTHORITIES,
          )
          .where("tenantId", "==", normalizedTenantId)
          .where("uid", "==", normalizedUid)
          .limit(20)
          .get();
      const delegatedAuthority = authoritySnapshot.docs
          .map((doc) => ({authorityId: doc.id, ...doc.data()}))
          .filter((item) => item.status === "active")
          .find((item) => authorityAllows(item, {
            canonicalBrandId: normalizedBrandId,
            serviceFamily: normalizedFamily,
            operationCode,
          }));
      if (delegatedAuthority) {
        return activeAuthorityResult(
            delegatedAuthority,
            "professional_service_authority",
            operationCode,
        );
      }

      return Object.freeze({
        authorized: false,
        authoritySource: "none",
        authorityId: null,
        membershipId: null,
        operationCode,
        professionalClass: null,
        canPublish: false,
      });
    },

    async getServiceRequestById({serviceRequestId}) {
      return snapshotData(
          await serviceRequestRef(db, serviceRequestId).get(),
      );
    },

    async createServiceRequestAtomic({serviceRequest, event, receipt}) {
      objectRequired(serviceRequest, "serviceRequest");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const requestRef = serviceRequestRef(
          db,
          serviceRequest.serviceRequestId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "create_service_request";
      const scopeId = serviceRequest.tenantId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const [requestSnapshot, eventSnapshot, receiptSnapshot] =
          await readSnapshots(
              transaction,
              [requestRef, eventRef, receiptRef],
          );
        const persisted = snapshotData(requestSnapshot);
        const existingEvent = snapshotData(eventSnapshot);
        const existingReceipt = snapshotData(receiptSnapshot);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persisted) {
            fail("internal", "receipt exists without service request");
          }
          return {serviceRequest: persisted, idempotentReplay: true};
        }
        if (persisted || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate service request bundle exists",
          );
        }
        const scope = recordScope(serviceRequest);
        transaction.create(requestRef, serviceRequest);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "service_request",
              aggregateId: serviceRequest.serviceRequestId,
            }),
        );
        return {serviceRequest, idempotentReplay: false};
      });
    },

    async transitionServiceRequestAtomic({
      currentServiceRequest,
      nextServiceRequest,
      event,
      receipt,
    }) {
      objectRequired(currentServiceRequest, "currentServiceRequest");
      objectRequired(nextServiceRequest, "nextServiceRequest");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const requestRef = serviceRequestRef(
          db,
          currentServiceRequest.serviceRequestId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "service_request";
      const scopeId = currentServiceRequest.serviceRequestId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const [requestSnapshot, eventSnapshot, receiptSnapshot] =
          await readSnapshots(
              transaction,
              [requestRef, eventRef, receiptRef],
          );
        const persisted = snapshotData(requestSnapshot);
        const existingEvent = snapshotData(eventSnapshot);
        const existingReceipt = snapshotData(receiptSnapshot);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persisted) {
            fail("internal", "receipt exists without service request");
          }
          return {serviceRequest: persisted, idempotentReplay: true};
        }
        if (!persisted) {
          fail("not-found", "service request was not found");
        }
        assertServiceRequestScope(persisted, currentServiceRequest);
        assertVersion(persisted, currentServiceRequest, "service request");
        if (existingEvent) {
          fail("already-exists", "service request event already exists");
        }
        const scope = recordScope(persisted);
        transaction.update(requestRef, nextServiceRequest);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "service_request",
              aggregateId: scopeId,
            }),
        );
        return {
          serviceRequest: nextServiceRequest,
          idempotentReplay: false,
        };
      });
    },

    async getClientAuthorizationById({authorizationId}) {
      return snapshotData(
          await clientAuthorizationRef(db, authorizationId).get(),
      );
    },

    async getServiceEngagementById({serviceEngagementId}) {
      return snapshotData(
          await serviceEngagementRef(db, serviceEngagementId).get(),
      );
    },

    async createServiceEngagementAtomic({
      currentServiceRequest,
      nextServiceRequest,
      serviceEngagement,
      event,
      receipt,
    }) {
      objectRequired(currentServiceRequest, "currentServiceRequest");
      objectRequired(nextServiceRequest, "nextServiceRequest");
      objectRequired(serviceEngagement, "serviceEngagement");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const requestRef = serviceRequestRef(
          db,
          currentServiceRequest.serviceRequestId,
      );
      const engagementRef = serviceEngagementRef(
          db,
          serviceEngagement.serviceEngagementId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "service_engagement";
      const scopeId = currentServiceRequest.serviceRequestId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          requestRef,
          engagementRef,
          eventRef,
          receiptRef,
        ]);
        const persistedRequest = snapshotData(snapshots[0]);
        const existingEngagement = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedRequest || !existingEngagement) {
            fail("internal", "receipt exists without engagement bundle");
          }
          return {
            serviceRequest: persistedRequest,
            serviceEngagement: existingEngagement,
            idempotentReplay: true,
          };
        }
        if (!persistedRequest) {
          fail("not-found", "service request was not found");
        }
        assertServiceRequestScope(
            persistedRequest,
            currentServiceRequest,
        );
        assertVersion(
            persistedRequest,
            currentServiceRequest,
            "service request",
        );
        if (existingEngagement || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate engagement bundle exists",
          );
        }
        const scope = recordScope(persistedRequest);
        transaction.update(requestRef, nextServiceRequest);
        transaction.create(engagementRef, serviceEngagement);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "service_request",
              aggregateId: scopeId,
            }),
        );
        return {
          serviceRequest: nextServiceRequest,
          serviceEngagement,
          idempotentReplay: false,
        };
      });
    },

    async getServiceProviderById({providerId}) {
      return snapshotData(
          await serviceProviderRef(db, providerId).get(),
      );
    },

    async resolveConflictCheck({serviceRequestId, providerId}) {
      const data = snapshotData(
          await conflictCheckRef(db, {
            serviceRequestId,
            providerId,
          }).get(),
      );
      if (!data) return null;
      if (
        data.serviceRequestId !== serviceRequestId ||
        data.providerId !== providerId
      ) {
        fail("internal", "conflict check scope is invalid");
      }
      return data;
    },

    async getServiceAssignmentById({serviceAssignmentId}) {
      return snapshotData(
          await serviceAssignmentRef(db, serviceAssignmentId).get(),
      );
    },

    async createServiceAssignmentAtomic({
      currentServiceRequest,
      nextServiceRequest,
      serviceAssignment,
      event,
      receipt,
    }) {
      objectRequired(currentServiceRequest, "currentServiceRequest");
      objectRequired(nextServiceRequest, "nextServiceRequest");
      objectRequired(serviceAssignment, "serviceAssignment");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const requestRef = serviceRequestRef(
          db,
          currentServiceRequest.serviceRequestId,
      );
      const assignmentRef = serviceAssignmentRef(
          db,
          serviceAssignment.serviceAssignmentId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "service_assignment";
      const scopeId = currentServiceRequest.serviceRequestId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          requestRef,
          assignmentRef,
          eventRef,
          receiptRef,
        ]);
        const persistedRequest = snapshotData(snapshots[0]);
        const existingAssignment = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedRequest || !existingAssignment) {
            fail("internal", "receipt exists without assignment bundle");
          }
          return {
            serviceRequest: persistedRequest,
            serviceAssignment: existingAssignment,
            idempotentReplay: true,
          };
        }
        if (!persistedRequest) {
          fail("not-found", "service request was not found");
        }
        assertServiceRequestScope(
            persistedRequest,
            currentServiceRequest,
        );
        assertVersion(
            persistedRequest,
            currentServiceRequest,
            "service request",
        );
        if (existingAssignment || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate assignment bundle exists",
          );
        }
        const scope = recordScope(persistedRequest);
        transaction.update(requestRef, nextServiceRequest);
        transaction.create(assignmentRef, serviceAssignment);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "service_request",
              aggregateId: scopeId,
            }),
        );
        return {
          serviceRequest: nextServiceRequest,
          serviceAssignment,
          idempotentReplay: false,
        };
      });
    },

    async getAgentTaskById({agentTaskId}) {
      return snapshotData(await agentTaskRef(db, agentTaskId).get());
    },

    async getAgentRunById({agentRunId}) {
      return snapshotData(await agentRunRef(db, agentRunId).get());
    },

    async createAgentRunAtomic({
      currentAgentTask,
      nextAgentTask,
      agentRun,
      event,
      receipt,
    }) {
      if (currentAgentTask != null) {
        objectRequired(currentAgentTask, "currentAgentTask");
      }
      objectRequired(nextAgentTask, "nextAgentTask");
      objectRequired(agentRun, "agentRun");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const taskRef = agentTaskRef(db, nextAgentTask.agentTaskId);
      const runRef = agentRunRef(db, agentRun.agentRunId);
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "agent_run";
      const scopeId = agentRun.serviceRequestId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          taskRef,
          runRef,
          eventRef,
          receiptRef,
        ]);
        const persistedTask = snapshotData(snapshots[0]);
        const existingRun = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedTask || !existingRun) {
            fail("internal", "receipt exists without agent run bundle");
          }
          return {
            agentTask: persistedTask,
            agentRun: existingRun,
            idempotentReplay: true,
          };
        }
        if (currentAgentTask == null) {
          if (persistedTask) {
            fail("already-exists", "agent task already exists");
          }
        } else {
          if (!persistedTask) {
            fail("not-found", "agent task was not found");
          }
          assertAgentTaskScope(persistedTask, currentAgentTask);
          assertVersion(persistedTask, currentAgentTask, "agent task");
        }
        if (existingRun || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate agent run bundle exists",
          );
        }
        const scope = recordScope(nextAgentTask);
        if (currentAgentTask == null) {
          transaction.create(taskRef, nextAgentTask);
        } else {
          transaction.update(taskRef, nextAgentTask);
        }
        transaction.create(runRef, agentRun);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "agent_task",
              aggregateId: nextAgentTask.agentTaskId,
            }),
        );
        return {
          agentTask: nextAgentTask,
          agentRun,
          idempotentReplay: false,
        };
      });
    },

    async getAgentOutputDraftById({outputDraftId}) {
      return snapshotData(
          await agentOutputDraftRef(db, outputDraftId).get(),
      );
    },

    async createAgentOutputDraftAtomic({
      currentAgentTask,
      nextAgentTask,
      agentOutputDraft,
      event,
      receipt,
    }) {
      objectRequired(currentAgentTask, "currentAgentTask");
      objectRequired(nextAgentTask, "nextAgentTask");
      objectRequired(agentOutputDraft, "agentOutputDraft");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const taskRef = agentTaskRef(
          db,
          currentAgentTask.agentTaskId,
      );
      const outputRef = agentOutputDraftRef(
          db,
          agentOutputDraft.outputDraftId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "agent_output_draft";
      const scopeId = agentOutputDraft.agentRunId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          taskRef,
          outputRef,
          eventRef,
          receiptRef,
        ]);
        const persistedTask = snapshotData(snapshots[0]);
        const existingOutput = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedTask || !existingOutput) {
            fail("internal", "receipt exists without output bundle");
          }
          return {
            agentTask: persistedTask,
            agentOutputDraft: existingOutput,
            idempotentReplay: true,
          };
        }
        if (!persistedTask) {
          fail("not-found", "agent task was not found");
        }
        assertAgentTaskScope(persistedTask, currentAgentTask);
        assertVersion(persistedTask, currentAgentTask, "agent task");
        if (existingOutput || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate agent output bundle exists",
          );
        }
        const scope = recordScope(persistedTask);
        transaction.update(taskRef, nextAgentTask);
        transaction.create(outputRef, agentOutputDraft);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "agent_task",
              aggregateId: currentAgentTask.agentTaskId,
            }),
        );
        return {
          agentTask: nextAgentTask,
          agentOutputDraft,
          idempotentReplay: false,
        };
      });
    },

    async getAgentHumanReviewById({humanReviewId}) {
      return snapshotData(
          await agentHumanReviewRef(db, humanReviewId).get(),
      );
    },

    async recordAgentHumanReviewAtomic({
      currentAgentTask,
      nextAgentTask,
      agentHumanReview,
      event,
      receipt,
    }) {
      objectRequired(currentAgentTask, "currentAgentTask");
      objectRequired(nextAgentTask, "nextAgentTask");
      objectRequired(agentHumanReview, "agentHumanReview");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const taskRef = agentTaskRef(
          db,
          currentAgentTask.agentTaskId,
      );
      const reviewRef = agentHumanReviewRef(
          db,
          agentHumanReview.humanReviewId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "agent_human_review";
      const scopeId = agentHumanReview.outputDraftId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          taskRef,
          reviewRef,
          eventRef,
          receiptRef,
        ]);
        const persistedTask = snapshotData(snapshots[0]);
        const existingReview = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedTask || !existingReview) {
            fail("internal", "receipt exists without review bundle");
          }
          return {
            agentTask: persistedTask,
            agentHumanReview: existingReview,
            idempotentReplay: true,
          };
        }
        if (!persistedTask) {
          fail("not-found", "agent task was not found");
        }
        assertAgentTaskScope(persistedTask, currentAgentTask);
        assertVersion(persistedTask, currentAgentTask, "agent task");
        if (existingReview || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate human review bundle exists",
          );
        }
        const scope = recordScope(persistedTask);
        transaction.update(taskRef, nextAgentTask);
        transaction.create(reviewRef, agentHumanReview);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "agent_task",
              aggregateId: currentAgentTask.agentTaskId,
            }),
        );
        return {
          agentTask: nextAgentTask,
          agentHumanReview,
          idempotentReplay: false,
        };
      });
    },

    async publishAgentOutputAtomic({
      currentAgentTask,
      nextAgentTask,
      publication,
      event,
      receipt,
    }) {
      objectRequired(currentAgentTask, "currentAgentTask");
      objectRequired(nextAgentTask, "nextAgentTask");
      objectRequired(publication, "publication");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");
      const taskRef = agentTaskRef(
          db,
          currentAgentTask.agentTaskId,
      );
      const publicationRef = agentOutputPublicationRef(
          db,
          publication.publicationId,
      );
      const eventRef = serviceEventRef(db, event.eventId);
      const scopeType = "agent_output_publication";
      const scopeId = publication.outputDraftId;
      const receiptRef = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey: receipt.idempotencyKey,
      });
      return db.runTransaction(async (transaction) => {
        const snapshots = await readSnapshots(transaction, [
          taskRef,
          publicationRef,
          eventRef,
          receiptRef,
        ]);
        const persistedTask = snapshotData(snapshots[0]);
        const existingPublication = snapshotData(snapshots[1]);
        const existingEvent = snapshotData(snapshots[2]);
        const existingReceipt = snapshotData(snapshots[3]);
        if (existingReceipt) {
          assertReceiptReplay(
              existingReceipt,
              receipt,
              scopeType,
              scopeId,
          );
          if (!persistedTask || !existingPublication) {
            fail("internal", "receipt exists without publication bundle");
          }
          return {
            agentTask: persistedTask,
            publication: existingPublication,
            idempotentReplay: true,
          };
        }
        if (!persistedTask) {
          fail("not-found", "agent task was not found");
        }
        assertAgentTaskScope(persistedTask, currentAgentTask);
        assertVersion(persistedTask, currentAgentTask, "agent task");
        if (existingPublication || existingEvent) {
          fail(
              "already-exists",
              "partial or duplicate publication bundle exists",
          );
        }
        const scope = recordScope(persistedTask);
        transaction.update(taskRef, nextAgentTask);
        transaction.create(publicationRef, publication);
        transaction.create(
            eventRef,
            domainEventDocument(event, scope),
        );
        transaction.create(
            receiptRef,
            commandReceiptDocument({
              scopeType,
              scopeId,
              receipt,
              scope,
              aggregateType: "agent_task",
              aggregateId: currentAgentTask.agentTaskId,
            }),
        );
        return {
          agentTask: nextAgentTask,
          publication,
          idempotentReplay: false,
        };
      });
    },
  });
}

module.exports = Object.freeze({
  COMMAND_RECEIPT_RECORD_TYPE,
  DOMAIN_EVENT_RECORD_TYPE,
  FIRESTORE_COLLECTIONS,
  SOURCE_REFERENCE_COLLECTIONS,
  assertDb,
  buildCommandReceiptId,
  buildConflictCheckId,
  createProfessionalServicesFirestoreAdapter,
});
