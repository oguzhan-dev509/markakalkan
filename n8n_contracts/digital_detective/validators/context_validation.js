"use strict";

const {issue} = require("./validator_result");

function isValidationContext(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === null || Object.getPrototypeOf(prototype) === null;
}

function readValidationContext(value, {candidates = false,
  evidences = false} = {}) {
  if (!isValidationContext(value)) return null;
  const owns = (key) => Object.prototype.hasOwnProperty.call(value, key);
  const taskId = value.taskId;
  const executionId = value.executionId;
  const candidateEntries = candidates ? value.candidates : undefined;
  const evidenceEntries = evidences ? value.evidences : undefined;
  const callback = value.productionCallback;
  if (!owns("taskId") || typeof taskId !== "string" || !taskId ||
      !owns("executionId") || typeof executionId !== "string" ||
      !executionId ||
      (candidates && (!owns("candidates") ||
       !Array.isArray(candidateEntries))) ||
      (evidences && (!owns("evidences") || !Array.isArray(evidenceEntries)))) {
    return null;
  }
  return Object.assign(Object.create(null), {
    taskId,
    executionId,
    candidates: candidateEntries,
    evidences: evidenceEntries,
    productionCallback: owns("productionCallback") &&
      callback === true,
  });
}

function nonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function candidateEntryValid(candidate) {
  return isValidationContext(candidate) &&
    nonEmptyString(candidate.sourceId) &&
    nonEmptyString(candidate.taskId) &&
    nonEmptyString(candidate.executionId) &&
    nonEmptyString(candidate.acquisitionStatus) &&
    (nonEmptyString(candidate.canonicalUrl) || nonEmptyString(candidate.sourceUrl));
}

function evidenceEntryValid(evidence) {
  return isValidationContext(evidence) &&
    nonEmptyString(evidence.sourceId) &&
    nonEmptyString(evidence.taskId) &&
    nonEmptyString(evidence.executionId) &&
    nonEmptyString(evidence.acquisitionStatus) &&
    (typeof evidence.snapshotId === "string" || evidence.snapshotId === null) &&
    nonEmptyString(evidence.sourceUrl);
}

function invalidCandidateIssue(candidates) {
  const index = candidates.findIndex((entry) => !candidateEntryValid(entry));
  return index === -1 ? null : issue("CONTEXT_CANDIDATE_INVALID",
      `candidates[${index}]`, "Candidate context öğesi geçersiz.");
}

function invalidEvidenceIssue(evidences) {
  const index = evidences.findIndex((entry) => !evidenceEntryValid(entry));
  return index === -1 ? null : issue("CONTEXT_EVIDENCE_INVALID",
      `evidences[${index}]`, "Evidence context öğesi geçersiz.");
}

module.exports = {candidateEntryValid, evidenceEntryValid,
  invalidCandidateIssue, invalidEvidenceIssue, isValidationContext,
  readValidationContext};
