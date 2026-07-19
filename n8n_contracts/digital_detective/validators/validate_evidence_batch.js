"use strict";

const {issue} = require("./validator_result");
const {validateStructuredEvidence} = require("./validate_structured_evidence");
const {invalidCandidateIssue, readValidationContext} =
  require("./context_validation");
const {validateSchema} = require("./schema_engine");
const {utf8ByteLength} = require("../runtime/portable_primitives");

const MAX_TOTAL_VISIBLE_TEXT_BYTES = 393216;

function batchResult(errors, warnings, rejected, total, length) {
  return {
    valid: errors.length === 0,
    errors,
    warnings,
    acceptedEvidenceCount: Math.max(0, length - rejected.size),
    rejectedEvidenceCount: rejected.size,
    totalVisibleTextBytes: total,
  };
}

function validateEvidenceBatchInternal(evidences, context) {
  const errors = [], warnings = [], rejected = new Set();
  if (!Array.isArray(evidences)) {
    errors.push(issue("EVIDENCE_BATCH_ARRAY_REQUIRED", "$",
      "Evidence batch dizi olmalıdır."));
    return batchResult(errors, warnings, rejected, 0, 0);
  }
  const validationContext = readValidationContext(context, {candidates: true});
  if (!validationContext) {
    errors.push(issue("CONTEXT_REQUIRED", "$",
      "Task, execution ve candidates context zorunludur."));
    return batchResult(errors, warnings, rejected, 0, 0);
  }
  const invalidCandidate = invalidCandidateIssue(validationContext.candidates);
  if (invalidCandidate) {
    errors.push(invalidCandidate);
    return batchResult(errors, warnings, rejected, 0, 0);
  }

  const sourceIds = new Set();
  const snapshots = new Map();
  let totalVisibleTextBytes = 0;
  if (validationContext.candidates.length > 3) {
    errors.push(issue("EVIDENCE_CANDIDATE_LIMIT_EXCEEDED", "candidates",
      "En fazla üç candidate kullanılabilir."));
  }
  evidences.forEach((evidence, index) => {
    const schema = validateSchema("structured_evidence", evidence);
    let validation;
    try {
      validation = validateStructuredEvidence(evidence, validationContext);
    } catch (_) {
      validation = {valid: false, warnings: [], errors: [issue(
        "EVIDENCE_VALIDATION_EXCEPTION", "$",
        "Doğrulama güvenli biçimde tamamlanamadı.")]};
    }
    if (!validation.valid) rejected.add(index);
    errors.push(...validation.errors.map((entry) => ({...entry,
      path: `evidences[${index}].${entry.path}`})));
    warnings.push(...validation.warnings.map((entry) => ({...entry,
      path: `evidences[${index}].${entry.path}`})));
    if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) return;
    if (typeof evidence.sourceId === "string") sourceIds.add(evidence.sourceId);
    if (schema.valid && evidence.acquisitionStatus === "acquired" &&
        typeof evidence.visibleText === "string") {
      totalVisibleTextBytes += utf8ByteLength(evidence.visibleText);
    }
    if (typeof evidence.snapshotId === "string") {
      if (snapshots.has(evidence.snapshotId)) {
        rejected.add(index);
        errors.push(issue("DUPLICATE_SNAPSHOT_ID",
            `evidences[${index}].snapshotId`, "Snapshot ID yinelenemez."));
      } else snapshots.set(evidence.snapshotId, index);
    }
  });

  if (sourceIds.size > 3) {
    errors.push(issue("EVIDENCE_SOURCE_LIMIT_EXCEEDED", "evidences",
      "En fazla üç source kullanılabilir."));
  }
  if (totalVisibleTextBytes > MAX_TOTAL_VISIBLE_TEXT_BYTES) {
    errors.push(issue("TOTAL_VISIBLE_TEXT_BYTES_EXCEEDED", "evidences",
      "Toplam görünür metin byte bütçesini aşıyor."));
  }
  return batchResult(errors, warnings, rejected, totalVisibleTextBytes,
      evidences.length);
}

function validateEvidenceBatch(evidences, context) {
  try {
    return validateEvidenceBatchInternal(evidences, context);
  } catch (_) {
    return batchResult([issue("EVIDENCE_BATCH_VALIDATION_EXCEPTION", "$",
      "Doğrulama güvenli biçimde tamamlanamadı.")], [], new Set(), 0, 0);
  }
}

module.exports = {MAX_TOTAL_VISIBLE_TEXT_BYTES, validateEvidenceBatch};
