"use strict";

const {validateAcquisitionResult} = require("./validate_acquisition_result");

function evaluateScannerInvocation({acquisitionResult, acquisitionValidation,
  evidenceBatchValidation, productionCallback = false} = {}) {
  const acquisition = acquisitionValidation || validateAcquisitionResult(
      acquisitionResult, Object.assign(Object.create(null), {
        taskId: acquisitionResult?.taskId,
        executionId: acquisitionResult?.executionId,
        productionCallback,
      }));
  if (!acquisition.valid) return {allowed: false,
    reason: acquisition.errors.some((e) =>
      e.code === "TEST_FIXTURE_PRODUCTION_CALLBACK") ?
      "TEST_FIXTURE_PRODUCTION_CALLBACK" : "ACQUISITION_INVALID"};
  if (acquisitionResult.status === "no_candidates") {
    return {allowed: false, reason: "NO_CANDIDATES"};
  }
  if (acquisitionResult.candidates.length === 0) {
    return {allowed: false, reason: "NO_CANDIDATES"};
  }
  if (!evidenceBatchValidation || evidenceBatchValidation.valid !== true) {
    return {allowed: false, reason: "EVIDENCE_BATCH_INVALID"};
  }
  if (!(evidenceBatchValidation.totalVisibleTextBytes > 0) ||
      !(evidenceBatchValidation.acceptedEvidenceCount > 0)) {
    return {allowed: false, reason: "NO_ACQUIRED_EVIDENCE"};
  }
  return {allowed: true, reason: "READY"};
}

module.exports = {evaluateScannerInvocation};
