"use strict";

const {
  InterventionLegalContractError,
  objectRequired,
  requiredString,
} = require("./contracts");
const {
  prefixedId,
} = require("./identifiers");

const FIRESTORE_COLLECTIONS = Object.freeze({
  CASE_FILES: "case_files",
  TENANT_MEMBERSHIPS: "tenant_memberships",
  LEGAL_TEAM_PROFILES: "legal_team_profiles",
  LEGAL_MATTER_FILES: "legal_matter_files",
  LEGAL_APPROVAL_REQUESTS: "legal_approval_requests",
  LEGAL_APPROVAL_DECISIONS: "legal_approval_decisions",
  LEGAL_MATTER_EVENTS: "legal_matter_events",
});

const DOMAIN_EVENT_RECORD_TYPE = "domain_event";
const COMMAND_RECEIPT_RECORD_TYPE = "command_receipt";

function fail(code, message, details = undefined) {
  throw new InterventionLegalContractError(code, message, details);
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
  return prefixedId("lmr", {
    scopeType: requiredString(scopeType, "scopeType", 96),
    scopeId: requiredString(scopeId, "scopeId", 128),
    idempotencyKey: requiredString(
      idempotencyKey,
      "idempotencyKey",
      256,
    ),
  });
}

function buildMatterIdFromKey(legalMatterKey) {
  return prefixedId("lm", {
    legalMatterKey: requiredString(
      legalMatterKey,
      "legalMatterKey",
      64,
    ),
  });
}

function legalMatterRef(db, legalMatterId) {
  return db
    .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES)
    .doc(requiredString(legalMatterId, "legalMatterId", 128));
}

function legalMatterEventRef(db, eventId) {
  return db
    .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS)
    .doc(requiredString(eventId, "eventId", 128));
}

function commandReceiptRef(db, input) {
  return db
    .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS)
    .doc(buildCommandReceiptId(input));
}

function approvalRequestRef(db, approvalRequestId) {
  return db
    .collection(FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS)
    .doc(requiredString(
      approvalRequestId,
      "approvalRequestId",
      128,
    ));
}

function approvalDecisionRef(db, decisionId) {
  return db
    .collection(FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS)
    .doc(requiredString(decisionId, "decisionId", 128));
}

function commandReceiptDocument({
  scopeType,
  scopeId,
  receipt,
  tenantId = null,
  canonicalBrandId = null,
  caseId = null,
  legalMatterId = null,
}) {
  objectRequired(receipt, "receipt");
  return Object.freeze({
    recordType: COMMAND_RECEIPT_RECORD_TYPE,
    projectionEligible: false,
    contractVersion: receipt.contractVersion,
    scopeType,
    scopeId,
    tenantId,
    canonicalBrandId,
    caseId,
    legalMatterId,
    requestId: receipt.requestId,
    idempotencyKey: receipt.idempotencyKey,
    payloadFingerprint: receipt.payloadFingerprint,
    resultType: receipt.resultType,
    resultId: receipt.resultId,
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
    caseId: scope.caseId,
    immutable: true,
  });
}

function assertReceiptReplay(existing, incoming) {
  if (
    existing.recordType !== COMMAND_RECEIPT_RECORD_TYPE ||
    existing.idempotencyKey !== incoming.idempotencyKey ||
    existing.payloadFingerprint !== incoming.payloadFingerprint
  ) {
    fail(
      "already-exists",
      "command receipt conflicts with the incoming payload",
    );
  }
  return true;
}

function assertMatterScope(matter, expected) {
  if (
    matter.tenantId !== expected.tenantId ||
    matter.canonicalBrandId !== expected.canonicalBrandId ||
    matter.caseId !== expected.caseId
  ) {
    fail("failed-precondition", "legal matter scope mismatch");
  }
  return true;
}

function assertApprovalRequestMatches(existing, expected) {
  if (
    existing.legalMatterId !== expected.legalMatterId ||
    existing.approvalType !== expected.approvalType
  ) {
    fail("failed-precondition", "approval request scope mismatch");
  }
  return true;
}

function createInterventionLegalFirestoreAdapter(dbInput) {
  const db = assertDb(dbInput);

  return Object.freeze({
    async getCommandReceipt({scopeType, scopeId, idempotencyKey}) {
      const ref = commandReceiptRef(db, {
        scopeType,
        scopeId,
        idempotencyKey,
      });
      const data = snapshotData(await ref.get());
      if (!data) return null;
      if (
        data.recordType !== COMMAND_RECEIPT_RECORD_TYPE ||
        data.scopeType !== scopeType ||
        data.scopeId !== scopeId ||
        data.idempotencyKey !== idempotencyKey
      ) {
        fail("internal", "command receipt scope is invalid");
      }
      return data;
    },

    async resolveCaseScope({caseId}) {
      const normalizedCaseId = requiredString(caseId, "caseId", 128);
      const snapshot = await db
        .collection(FIRESTORE_COLLECTIONS.CASE_FILES)
        .doc(normalizedCaseId)
        .get();
      const data = snapshotData(snapshot);
      if (!data) return null;
      return Object.freeze({
        caseId: normalizedCaseId,
        tenantId: data.tenantId || null,
        canonicalBrandId: data.canonicalBrandId || null,
        status: data.status || null,
        archived:
          data.archived === true ||
          data.status === "archived" ||
          data.dispositionStatus === "archived",
      });
    },

    async findLegalMatterByKey({tenantId, legalMatterKey}) {
      const normalizedTenantId = requiredString(
        tenantId,
        "tenantId",
        128,
      );
      const normalizedKey = requiredString(
        legalMatterKey,
        "legalMatterKey",
        64,
      );
      const ref = legalMatterRef(
        db,
        buildMatterIdFromKey(normalizedKey),
      );
      const data = snapshotData(await ref.get());
      if (!data) return null;
      if (
        data.tenantId !== normalizedTenantId ||
        data.legalMatterKey !== normalizedKey
      ) {
        fail("internal", "deterministic legal matter key mismatch");
      }
      return data;
    },

    async getLegalMatterById({legalMatterId}) {
      return snapshotData(
        await legalMatterRef(db, legalMatterId).get(),
      );
    },

    async createLegalMatterAtomic({matter, event, receipt}) {
      objectRequired(matter, "matter");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");

      const matterRef = legalMatterRef(db, matter.legalMatterId);
      const eventRef = legalMatterEventRef(db, event.eventId);
      const receiptRef = commandReceiptRef(db, {
        scopeType: "create_legal_matter",
        scopeId: matter.tenantId,
        idempotencyKey: receipt.idempotencyKey,
      });

      return db.runTransaction(async (transaction) => {
        const matterSnapshot = await transaction.get(matterRef);
        const eventSnapshot = await transaction.get(eventRef);
        const receiptSnapshot = await transaction.get(receiptRef);
        const existingMatter = snapshotData(matterSnapshot);
        const existingEvent = snapshotData(eventSnapshot);
        const existingReceipt = snapshotData(receiptSnapshot);

        if (existingReceipt) {
          assertReceiptReplay(existingReceipt, receipt);
          if (!existingMatter) {
            fail("internal", "receipt exists without legal matter");
          }
          return {matter: existingMatter, idempotentReplay: true};
        }

        if (existingMatter || existingEvent) {
          fail(
            "already-exists",
            "partial or duplicate legal matter bundle exists",
          );
        }

        const scope = {
          tenantId: matter.tenantId,
          canonicalBrandId: matter.canonicalBrandId,
          caseId: matter.caseId,
        };
        transaction.create(matterRef, matter);
        transaction.create(
          eventRef,
          domainEventDocument(event, scope),
        );
        transaction.create(
          receiptRef,
          commandReceiptDocument({
            scopeType: "create_legal_matter",
            scopeId: matter.tenantId,
            receipt,
            ...scope,
            legalMatterId: matter.legalMatterId,
          }),
        );
        return {matter, idempotentReplay: false};
      });
    },

    async transitionLegalMatterAtomic({
      currentMatter,
      nextMatter,
      event,
      receipt,
    }) {
      objectRequired(currentMatter, "currentMatter");
      objectRequired(nextMatter, "nextMatter");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");

      const matterRef = legalMatterRef(
        db,
        currentMatter.legalMatterId,
      );
      const eventRef = legalMatterEventRef(db, event.eventId);
      const receiptRef = commandReceiptRef(db, {
        scopeType: "legal_matter",
        scopeId: currentMatter.legalMatterId,
        idempotencyKey: receipt.idempotencyKey,
      });

      return db.runTransaction(async (transaction) => {
        const matterSnapshot = await transaction.get(matterRef);
        const eventSnapshot = await transaction.get(eventRef);
        const receiptSnapshot = await transaction.get(receiptRef);
        const persisted = snapshotData(matterSnapshot);
        const existingEvent = snapshotData(eventSnapshot);
        const existingReceipt = snapshotData(receiptSnapshot);

        if (existingReceipt) {
          assertReceiptReplay(existingReceipt, receipt);
          if (!persisted) {
            fail("internal", "receipt exists without legal matter");
          }
          return {matter: persisted, idempotentReplay: true};
        }
        if (!persisted) {
          fail("not-found", "legal matter was not found");
        }
        assertMatterScope(persisted, currentMatter);
        if (persisted.version !== currentMatter.version) {
          fail("aborted", "legal matter version conflict", {
            expectedVersion: currentMatter.version,
            actualVersion: persisted.version,
          });
        }
        if (existingEvent) {
          fail("already-exists", "legal matter event already exists");
        }

        const scope = {
          tenantId: persisted.tenantId,
          canonicalBrandId: persisted.canonicalBrandId,
          caseId: persisted.caseId,
        };
        transaction.update(matterRef, nextMatter);
        transaction.create(
          eventRef,
          domainEventDocument(event, scope),
        );
        transaction.create(
          receiptRef,
          commandReceiptDocument({
            scopeType: "legal_matter",
            scopeId: currentMatter.legalMatterId,
            receipt,
            ...scope,
            legalMatterId: currentMatter.legalMatterId,
          }),
        );
        return {matter: nextMatter, idempotentReplay: false};
      });
    },

    async getApprovalRequestById({approvalRequestId}) {
      return snapshotData(
        await approvalRequestRef(db, approvalRequestId).get(),
      );
    },

    async getLegalTeamProfileByUid({uid}) {
      const normalizedUid = requiredString(uid, "uid", 128);
      return snapshotData(
        await db
          .collection(FIRESTORE_COLLECTIONS.LEGAL_TEAM_PROFILES)
          .doc(normalizedUid)
          .get(),
      );
    },

    async resolveClientAuthority({
      uid,
      tenantId,
      canonicalBrandId,
      approvalType,
    }) {
      const normalizedUid = requiredString(uid, "uid", 128);
      const normalizedTenantId = requiredString(
        tenantId,
        "tenantId",
        128,
      );
      const normalizedBrandId = requiredString(
        canonicalBrandId,
        "canonicalBrandId",
        128,
      );
      const normalizedApprovalType = requiredString(
        approvalType,
        "approvalType",
        96,
      );

      const snapshot = await db
        .collection(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS)
        .where("tenantId", "==", normalizedTenantId)
        .where("uid", "==", normalizedUid)
        .limit(10)
        .get();

      const active = snapshot.docs
        .map((doc) => ({membershipId: doc.id, ...doc.data()}))
        .filter((item) => item.status === "active");

      const owner = active.find((item) => item.role === "owner");
      if (owner) {
        return Object.freeze({
          authorized: true,
          authoritySource: "tenant_owner",
          membershipId: owner.membershipId,
        });
      }

      const delegated = active.find((item) => {
        const allowedTypes = Array.isArray(
          item.delegatedLegalApprovalTypes,
        ) ? item.delegatedLegalApprovalTypes : [];
        const allowedBrands = Array.isArray(
          item.delegatedCanonicalBrandIds,
        ) ? item.delegatedCanonicalBrandIds : [];
        return (
          allowedTypes.includes(normalizedApprovalType) &&
          (
            allowedBrands.includes("*") ||
            allowedBrands.includes(normalizedBrandId)
          )
        );
      });

      return delegated ?
        Object.freeze({
          authorized: true,
          authoritySource: "explicit_delegation",
          membershipId: delegated.membershipId,
        }) :
        Object.freeze({
          authorized: false,
          authoritySource: "none",
          membershipId: null,
        });
    },

    async recordApprovalDecisionAtomic({
      approvalRequest,
      expectedApprovalRequestVersion,
      decision,
      event,
      receipt,
    }) {
      objectRequired(approvalRequest, "approvalRequest");
      if (
        !Number.isSafeInteger(expectedApprovalRequestVersion) ||
        expectedApprovalRequestVersion < 0
      ) {
        fail(
          "internal",
          "expected approval request version is invalid",
        );
      }
      objectRequired(decision, "decision");
      objectRequired(event, "event");
      objectRequired(receipt, "receipt");

      const requestRef = approvalRequestRef(
        db,
        approvalRequest.approvalRequestId,
      );
      const matterRef = legalMatterRef(
        db,
        approvalRequest.legalMatterId,
      );
      const decisionRef = approvalDecisionRef(
        db,
        decision.decisionId,
      );
      const eventRef = legalMatterEventRef(db, event.eventId);
      const receiptRef = commandReceiptRef(db, {
        scopeType: "legal_approval_decision",
        scopeId: approvalRequest.approvalRequestId,
        idempotencyKey: receipt.idempotencyKey,
      });

      return db.runTransaction(async (transaction) => {
        const requestSnapshot = await transaction.get(requestRef);
        const matterSnapshot = await transaction.get(matterRef);
        const decisionSnapshot = await transaction.get(decisionRef);
        const eventSnapshot = await transaction.get(eventRef);
        const receiptSnapshot = await transaction.get(receiptRef);

        const persistedRequest = snapshotData(requestSnapshot);
        const matter = snapshotData(matterSnapshot);
        const existingDecision = snapshotData(decisionSnapshot);
        const existingEvent = snapshotData(eventSnapshot);
        const existingReceipt = snapshotData(receiptSnapshot);

        if (existingReceipt) {
          assertReceiptReplay(existingReceipt, receipt);
          if (!existingDecision) {
            fail("internal", "receipt exists without approval decision");
          }
          return {
            decision: existingDecision,
            idempotentReplay: true,
          };
        }
        if (!persistedRequest) {
          fail("not-found", "approval request was not found");
        }
        if (!matter) {
          fail("not-found", "legal matter was not found");
        }
        assertApprovalRequestMatches(
          persistedRequest,
          approvalRequest,
        );
        if (
          persistedRequest.version !== expectedApprovalRequestVersion
        ) {
          fail("aborted", "approval request version conflict", {
            expectedApprovalRequestVersion,
            actualApprovalRequestVersion: persistedRequest.version,
          });
        }
        if (persistedRequest.status !== "pending") {
          fail(
            "failed-precondition",
            "approval request is not pending",
          );
        }
        if (existingDecision || existingEvent) {
          fail(
            "already-exists",
            "partial or duplicate approval decision bundle exists",
          );
        }

        const nextRequest = {
          ...persistedRequest,
          status: decision.decision,
          decisionId: decision.decisionId,
          decidedAt: decision.decidedAt,
          decidedByUid: decision.decidedByUid,
          updatedAt: decision.decidedAt,
          version: expectedApprovalRequestVersion + 1,
        };
        const scope = {
          tenantId: matter.tenantId,
          canonicalBrandId: matter.canonicalBrandId,
          caseId: matter.caseId,
        };

        transaction.update(requestRef, nextRequest);
        transaction.create(decisionRef, decision);
        transaction.create(
          eventRef,
          domainEventDocument(event, scope),
        );
        transaction.create(
          receiptRef,
          commandReceiptDocument({
            scopeType: "legal_approval_decision",
            scopeId: approvalRequest.approvalRequestId,
            receipt,
            ...scope,
            legalMatterId: matter.legalMatterId,
          }),
        );

        return {decision, idempotentReplay: false};
      });
    },
  });
}

module.exports = Object.freeze({
  FIRESTORE_COLLECTIONS,
  DOMAIN_EVENT_RECORD_TYPE,
  COMMAND_RECEIPT_RECORD_TYPE,
  assertDb,
  buildCommandReceiptId,
  buildMatterIdFromKey,
  createInterventionLegalFirestoreAdapter,
});
