/* eslint-disable max-len */
"use strict";

const {canonicalDigestSha256} = require("./canonical");

const PREFIX = /^[a-z][a-z0-9]{1,7}$/;
const VALUE = /^[A-Za-z0-9_.:@/-]{1,256}$/;

class ProfessionalServicesIdentifierError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ProfessionalServicesIdentifierError";
    this.code = code;
  }
}

function requiredValue(value, field) {
  if (typeof value !== "string") {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        `${field} invalid`,
    );
  }
  const clean = value.trim();
  if (!VALUE.test(clean)) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        `${field} invalid`,
    );
  }
  return clean;
}

function prefixedId(prefix, payload) {
  if (typeof prefix !== "string" || !PREFIX.test(prefix)) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        "prefix invalid",
    );
  }
  return `${prefix}_${canonicalDigestSha256(payload)}`;
}

function buildServiceRequestId({tenantId, requestId}) {
  return prefixedId("psr", {
    tenantId: requiredValue(tenantId, "tenantId"),
    requestId: requiredValue(requestId, "requestId").toLowerCase(),
  });
}

function buildServiceEngagementId({serviceRequestId}) {
  return prefixedId("pse", {
    serviceRequestId: requiredValue(serviceRequestId, "serviceRequestId"),
  });
}

function buildServiceAssignmentId({serviceRequestId, providerId,
  assignmentSequence}) {
  if (!Number.isSafeInteger(assignmentSequence) ||
      assignmentSequence < 1 || assignmentSequence > 1000000) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        "assignmentSequence invalid",
    );
  }
  return prefixedId("psa", {
    serviceRequestId: requiredValue(serviceRequestId, "serviceRequestId"),
    providerId: requiredValue(providerId, "providerId"),
    assignmentSequence,
  });
}

function buildAgentTaskId({serviceRequestId, agentCode, requestId}) {
  return prefixedId("pat", {
    serviceRequestId: requiredValue(serviceRequestId, "serviceRequestId"),
    agentCode: requiredValue(agentCode, "agentCode"),
    requestId: requiredValue(requestId, "requestId").toLowerCase(),
  });
}

function buildAgentRunId({agentTaskId, runSequence,
  inputManifestHashSha256}) {
  if (!Number.isSafeInteger(runSequence) ||
      runSequence < 1 || runSequence > 1000000) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        "runSequence invalid",
    );
  }
  const digest = requiredValue(inputManifestHashSha256,
      "inputManifestHashSha256").toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(digest)) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        "inputManifestHashSha256 invalid",
    );
  }
  return prefixedId("par", {
    agentTaskId: requiredValue(agentTaskId, "agentTaskId"),
    runSequence,
    inputManifestHashSha256: digest,
  });
}

function buildAgentOutputDraftId({agentRunId, outputHashSha256}) {
  const digest = requiredValue(outputHashSha256,
      "outputHashSha256").toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(digest)) {
    throw new ProfessionalServicesIdentifierError(
        "invalid-argument",
        "outputHashSha256 invalid",
    );
  }
  return prefixedId("pao", {
    agentRunId: requiredValue(agentRunId, "agentRunId"),
    outputHashSha256: digest,
  });
}

function buildAgentHumanReviewId({outputDraftId, reviewedByUid,
  decision}) {
  return prefixedId("phr", {
    outputDraftId: requiredValue(outputDraftId, "outputDraftId"),
    reviewedByUid: requiredValue(reviewedByUid, "reviewedByUid"),
    decision: requiredValue(decision, "decision"),
  });
}

function fingerprintCommand(command) {
  return canonicalDigestSha256(command);
}

module.exports = Object.freeze({
  ProfessionalServicesIdentifierError,
  buildAgentHumanReviewId,
  buildAgentOutputDraftId,
  buildAgentRunId,
  buildAgentTaskId,
  buildServiceAssignmentId,
  buildServiceEngagementId,
  buildServiceRequestId,
  fingerprintCommand,
  prefixedId,
});
