"use strict";

const {issue} = require("./validator_result");

function isValidationContext(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function readOwnDataProperty(value, key) {
  try {
    if (!Object.prototype.hasOwnProperty.call(value, key)) {
      return {kind: "absent"};
    }
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor,
        "value")) {
      return {kind: "invalid"};
    }
    return {kind: "data", value: descriptor.value};
  } catch (_) {
    return {kind: "invalid"};
  }
}

function readValidationContext(value, {candidates = false,
  evidences = false} = {}) {
  if (!isValidationContext(value)) return null;
  const taskId = readOwnDataProperty(value, "taskId");
  const executionId = readOwnDataProperty(value, "executionId");
  const candidateEntries = candidates ?
    readOwnDataProperty(value, "candidates") : {kind: "absent"};
  const evidenceEntries = evidences ?
    readOwnDataProperty(value, "evidences") : {kind: "absent"};
  const callback = readOwnDataProperty(value, "productionCallback");
  if (taskId.kind !== "data" || typeof taskId.value !== "string" ||
      !taskId.value || executionId.kind !== "data" ||
      typeof executionId.value !== "string" || !executionId.value ||
      (candidates && (candidateEntries.kind !== "data" ||
       !Array.isArray(candidateEntries.value))) ||
      (evidences && (evidenceEntries.kind !== "data" ||
       !Array.isArray(evidenceEntries.value))) || callback.kind === "invalid") {
    return null;
  }
  return Object.assign(Object.create(null), {
    taskId: taskId.value,
    executionId: executionId.value,
    candidates: candidateEntries.value,
    evidences: evidenceEntries.value,
    productionCallback: callback.kind === "data" && callback.value === true,
  });
}

function nonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function candidateEntryValid(candidate) {
  if (!isValidationContext(candidate)) return false;
  const sourceId = readOwnDataProperty(candidate, "sourceId");
  const taskId = readOwnDataProperty(candidate, "taskId");
  const executionId = readOwnDataProperty(candidate, "executionId");
  const acquisitionStatus = readOwnDataProperty(candidate, "acquisitionStatus");
  const canonicalUrl = readOwnDataProperty(candidate, "canonicalUrl");
  const sourceUrl = readOwnDataProperty(candidate, "sourceUrl");
  return sourceId.kind === "data" && nonEmptyString(sourceId.value) &&
    taskId.kind === "data" && nonEmptyString(taskId.value) &&
    executionId.kind === "data" && nonEmptyString(executionId.value) &&
    acquisitionStatus.kind === "data" &&
    nonEmptyString(acquisitionStatus.value) &&
    canonicalUrl.kind !== "invalid" && sourceUrl.kind !== "invalid" &&
    ((canonicalUrl.kind === "data" && nonEmptyString(canonicalUrl.value)) ||
     (sourceUrl.kind === "data" && nonEmptyString(sourceUrl.value)));
}

function evidenceEntryValid(evidence) {
  if (!isValidationContext(evidence)) return false;
  const sourceId = readOwnDataProperty(evidence, "sourceId");
  const taskId = readOwnDataProperty(evidence, "taskId");
  const executionId = readOwnDataProperty(evidence, "executionId");
  const acquisitionStatus = readOwnDataProperty(evidence, "acquisitionStatus");
  const snapshotId = readOwnDataProperty(evidence, "snapshotId");
  const sourceUrl = readOwnDataProperty(evidence, "sourceUrl");
  return sourceId.kind === "data" && nonEmptyString(sourceId.value) &&
    taskId.kind === "data" && nonEmptyString(taskId.value) &&
    executionId.kind === "data" && nonEmptyString(executionId.value) &&
    acquisitionStatus.kind === "data" &&
    nonEmptyString(acquisitionStatus.value) && snapshotId.kind === "data" &&
    (typeof snapshotId.value === "string" || snapshotId.value === null) &&
    sourceUrl.kind === "data" && nonEmptyString(sourceUrl.value);
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
  readOwnDataProperty, readValidationContext};
