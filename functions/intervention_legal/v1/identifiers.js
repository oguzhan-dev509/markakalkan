"use strict";

const {
  canonicalizeLegalMatterIdentity,
  canonicalizeReference,
  sha256Hex,
  stableStringify,
} = require("./canonical");
const {
  InterventionLegalContractError,
  requiredString,
} = require("./contracts");

function prefixedId(prefix, payload, hashLength = 24) {
  const normalizedPrefix = requiredString(prefix, "prefix", 20).toLowerCase();
  if (!/^[a-z][a-z0-9_]*$/.test(normalizedPrefix)) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "prefix is invalid",
    );
  }
  if (!Number.isSafeInteger(hashLength) || hashLength < 16 || hashLength > 64) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "hashLength must be between 16 and 64",
    );
  }
  // eslint-disable-next-line max-len
  return `${normalizedPrefix}_${sha256Hex(stableStringify(payload)).slice(0, hashLength)}`;
}

function buildLegalMatterKey(input) {
  const identity = canonicalizeLegalMatterIdentity(input);
  return sha256Hex([
    identity.tenantId,
    identity.caseId,
    identity.jurisdictionCode,
    identity.matterScopeCode,
  ].join("|"));
}

function buildLegalMatterId(input) {
  return prefixedId("lm", {legalMatterKey: buildLegalMatterKey(input)}, 24);
}

function buildAssignmentId({legalMatterId, assigneeUid, roleCode}) {
  return prefixedId("lma", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    assigneeUid: requiredString(assigneeUid, "assigneeUid", 128),
    roleCode: requiredString(roleCode, "roleCode", 96),
  });
}

function buildAssessmentId({legalMatterId, version}) {
  if (!Number.isSafeInteger(version) || version < 1) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "assessment version must be a positive integer",
    );
  }
  return prefixedId("las", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    version,
  });
}

function buildPlanId({legalMatterId, planSequence}) {
  if (!Number.isSafeInteger(planSequence) || planSequence < 1) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "planSequence must be a positive integer",
    );
  }
  return prefixedId("lip", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    planSequence,
  });
}

function buildActionId({legalMatterId, planId, actionSequence}) {
  if (!Number.isSafeInteger(actionSequence) || actionSequence < 1) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "actionSequence must be a positive integer",
    );
  }
  return prefixedId("lia", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    planId: requiredString(planId, "planId", 128),
    actionSequence,
  });
}

function buildLinkId({legalMatterId, referenceType, referenceId}) {
  const reference = canonicalizeReference({referenceType, referenceId});
  return prefixedId("lml", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    ...reference,
  });
}

function buildApprovalRequestId({
  legalMatterId,
  approvalType,
  requestSequence,
}) {
  if (!Number.isSafeInteger(requestSequence) || requestSequence < 1) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "requestSequence must be a positive integer",
    );
  }
  return prefixedId("lar", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    approvalType: requiredString(approvalType, "approvalType", 96),
    requestSequence,
  });
}

function buildApprovalDecisionId({
  approvalRequestId,
  decidedByUid,
  decision,
}) {
  return prefixedId("lad", {
    approvalRequestId: requiredString(
        approvalRequestId,
        "approvalRequestId",
        128,
    ),
    decidedByUid: requiredString(decidedByUid, "decidedByUid", 128),
    decision: requiredString(decision, "decision", 32),
  });
}

function buildMatterEventId({legalMatterId, requestId, eventType}) {
  return prefixedId("lme", {
    legalMatterId: requiredString(legalMatterId, "legalMatterId", 128),
    requestId: requiredString(requestId, "requestId", 128),
    eventType: requiredString(eventType, "eventType", 96),
  });
}

module.exports = Object.freeze({
  prefixedId,
  buildLegalMatterKey,
  buildLegalMatterId,
  buildAssignmentId,
  buildAssessmentId,
  buildPlanId,
  buildActionId,
  buildLinkId,
  buildApprovalRequestId,
  buildApprovalDecisionId,
  buildMatterEventId,
});
