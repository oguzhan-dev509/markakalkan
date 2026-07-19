"use strict";
const {buildContentHash, buildSnapshotId} = require("./deterministic_ids");
const {issue, result} = require("./validator_result");
const {validateSchema} = require("./schema_engine");
const {invalidCandidateIssue, readValidationContext} =
  require("./context_validation");
const {utf8ByteLength} = require("../runtime/portable_primitives");

function validateStructuredEvidenceInternal(evidence, context) {
  const schema = validateSchema("structured_evidence", evidence);
  if (!schema.valid) return schema;
  const errors = [], warnings = [];
  const validationContext = readValidationContext(context, {candidates: true});
  if (!validationContext) {
    return result({errors: [issue("CONTEXT_REQUIRED", "$",
      "Task, execution ve candidates context zorunludur.")]});
  }
  const {candidates} = validationContext;
  const invalidCandidate = invalidCandidateIssue(candidates);
  if (invalidCandidate) return result({errors: [invalidCandidate]});
  const candidate = candidates.find((c) => c.sourceId === evidence.sourceId);
  if (!candidate) errors.push(issue("EVIDENCE_CANDIDATE_NOT_FOUND", "sourceId", "Candidate not found."));
  if (evidence.taskId !== validationContext.taskId ||
      evidence.executionId !== validationContext.executionId ||
      (candidate && (candidate.taskId !== evidence.taskId ||
       candidate.executionId !== evidence.executionId))) {
    errors.push(issue("EVIDENCE_SCOPE_MISMATCH", "executionId", "Evidence scope mismatch."));
  }
  if (candidate && candidate.canonicalUrl !== evidence.sourceUrl) errors.push(issue("EVIDENCE_URL_MISMATCH", "sourceUrl", "Evidence URL mismatch."));
  const bytes = utf8ByteLength(evidence.visibleText || "");
  if ((evidence.visibleText || "").length > 50000) errors.push(issue("VISIBLE_TEXT_CHAR_LIMIT", "visibleText", "Visible text exceeds character limit."));
  if (bytes > 131072) errors.push(issue("VISIBLE_TEXT_BYTE_LIMIT", "visibleText", "Visible text exceeds byte limit."));
  if (evidence.acquisitionStatus === "acquired") {
    const contentHash = evidence.visibleText ? buildContentHash(evidence.visibleText) : null;
    if (!evidence.visibleText) errors.push(issue("ACQUIRED_TEXT_EMPTY", "visibleText", "Acquired evidence must have text."));
    if (evidence.contentHash !== contentHash) errors.push(issue("CONTENT_HASH_MISMATCH", "contentHash", "Content hash mismatch."));
    if (contentHash && evidence.snapshotId !== buildSnapshotId(evidence.taskId, evidence.executionId, evidence.sourceId, contentHash)) errors.push(issue("SNAPSHOT_ID_MISMATCH", "snapshotId", "Snapshot ID mismatch."));
  } else if (evidence.visibleText || evidence.contentHash || evidence.snapshotId) {
    errors.push(issue("INACTIVE_EVIDENCE_HAS_CONTENT", "visibleText", "Failed or blocked evidence cannot carry content."));
  }
  if (/<script\b|<style\b/i.test(evidence.visibleText || "")) errors.push(issue("ACTIVE_CONTENT_IN_VISIBLE_TEXT", "visibleText", "Script/style content forbidden."));
  else if (/<[a-z][\s\S]*>/i.test(evidence.visibleText || "")) warnings.push(issue("HTML_IN_VISIBLE_TEXT", "visibleText", "HTML-like text detected."));
  if (/data:[^;]+;base64,|[A-Za-z0-9+/]{500,}={0,2}/.test(evidence.visibleText || "")) errors.push(issue("BINARY_CONTENT_SIGNAL", "visibleText", "Base64/binary signal forbidden."));
  return result({errors, warnings});
}

function validateStructuredEvidence(evidence, context) {
  try {
    return validateStructuredEvidenceInternal(evidence, context);
  } catch (_) {
    return result({errors: [issue("EVIDENCE_VALIDATION_EXCEPTION", "$",
      "Doğrulama güvenli biçimde tamamlanamadı.")]});
  }
}
module.exports = {validateStructuredEvidence};
