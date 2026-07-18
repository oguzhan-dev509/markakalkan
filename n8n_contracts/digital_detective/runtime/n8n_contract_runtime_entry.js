"use strict";

const {validateAcquisitionResult} = require("../validators/validate_acquisition_result");
const {validateCandidateSource} = require("../validators/validate_candidate_source");
const {validateEvidenceBatch} = require("../validators/validate_evidence_batch");
const {validateScannerResult} = require("../validators/validate_scanner_result");
const {evaluateScannerInvocation} = require("../validators/pipeline_guard");
const fixtureCatalog = require("ddt-fixture-catalog");

const RUNTIME_VERSION = "ddt-n8n-runtime-v1";

function safeFailure(errorCode) {
  return {
    contractRuntimeVersion: RUNTIME_VERSION,
    valid: false,
    errorCode,
    acquisitionValidation: null,
    candidateValidations: [],
    evidenceBatchValidation: null,
    scannerValidation: null,
    scannerInvocation: {allowed: false, reason: errorCode},
    findingCount: 0,
  };
}

function runContractPipeline(input) {
  try {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
      return safeFailure("PIPELINE_INPUT_INVALID");
    }
    const {acquisitionResult, candidates, evidences, scannerResult} = input;
    const productionCallback = input.productionCallback === true;
    const context = acquisitionResult && typeof acquisitionResult === "object" ? {
      taskId: acquisitionResult.taskId,
      executionId: acquisitionResult.executionId,
      candidates,
    } : {};
    const acquisitionValidation = validateAcquisitionResult(acquisitionResult,
        {productionCallback});
    const candidateValidations = Array.isArray(candidates) ? candidates.map((candidate) =>
      validateCandidateSource(candidate, context)) : [];
    const evidenceBatchValidation = validateEvidenceBatch(evidences, context);
    const scannerValidation = validateScannerResult(scannerResult, {
      ...context, evidences, productionCallback,
    });
    const scannerInvocation = evaluateScannerInvocation({
      acquisitionResult, evidenceBatchValidation, productionCallback,
    });
    const candidatesValid = Array.isArray(candidates) &&
      candidateValidations.every((validation) => validation.valid === true);
    const valid = acquisitionValidation.valid === true && candidatesValid &&
      evidenceBatchValidation.valid === true && scannerValidation.valid === true;
    const findingCount = valid && scannerInvocation.allowed === true ?
      scannerValidation.acceptedFindingCount : 0;
    return {contractRuntimeVersion:RUNTIME_VERSION, valid,
      acquisitionValidation, candidateValidations, evidenceBatchValidation,
      scannerValidation, scannerInvocation, findingCount};
  } catch (_) {
    return safeFailure("CONTRACT_PIPELINE_EXCEPTION");
  }
}

function runFixtureScenario(scenarioName) {
  try {
    if (!Object.prototype.hasOwnProperty.call(fixtureCatalog, scenarioName)) {
      return {valid:false, errorCode:"FIXTURE_SCENARIO_UNSUPPORTED"};
    }
    return runContractPipeline(fixtureCatalog[scenarioName]);
  } catch (_) {
    return {valid:false, errorCode:"FIXTURE_SCENARIO_EXCEPTION"};
  }
}

module.exports = {runContractPipeline, runFixtureScenario};
