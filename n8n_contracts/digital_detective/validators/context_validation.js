"use strict";

const {isPlainRecord, issue} = require("./validator_result");

function nonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function candidateEntryValid(candidate) {
  return isPlainRecord(candidate) &&
    nonEmptyString(candidate.sourceId) &&
    nonEmptyString(candidate.taskId) &&
    nonEmptyString(candidate.executionId) &&
    nonEmptyString(candidate.acquisitionStatus) &&
    (nonEmptyString(candidate.canonicalUrl) || nonEmptyString(candidate.sourceUrl));
}

function evidenceEntryValid(evidence) {
  return isPlainRecord(evidence) &&
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
  invalidCandidateIssue, invalidEvidenceIssue};
