"use strict";
const {validateCandidateSource} = require("./validate_candidate_source");
const {issue, result} = require("./validator_result");
const {validateSchema} = require("./schema_engine");

function validateAcquisitionResultInternal(envelope,
  context = {}) {
  const schema = validateSchema("acquisition_result", envelope);
  if (!schema.valid) return schema;
  const taskId = context.taskId ?? envelope.taskId;
  const executionId = context.executionId ?? envelope.executionId;
  const productionCallback = context.productionCallback === true;
  const errors = [], seenUrls = new Set(), seenIds = new Set();
  if (typeof taskId !== "string" || !taskId ||
      typeof executionId !== "string" || !executionId) {
    return result({errors: [issue("CONTEXT_REQUIRED", "$",
      "Task ve execution context zorunludur.")]});
  }
  if (envelope.taskId !== taskId) {
    errors.push(issue("TASK_ID_MISMATCH", "taskId", "Task ID mismatch."));
  }
  if (envelope.executionId !== executionId) {
    errors.push(issue("EXECUTION_ID_MISMATCH", "executionId",
        "Execution ID mismatch."));
  }
  if (envelope.candidates.length > 3) errors.push(issue("CANDIDATE_LIMIT_EXCEEDED", "candidates", "Maximum three candidates."));
  for (let i = 0; i < envelope.candidates.length; i++) {
    const candidate = envelope.candidates[i];
    const child = validateCandidateSource(candidate, {
      taskId, executionId, productionCallback,
    });
    errors.push(...child.errors.map((e) => ({...e, path: `candidates[${i}].${e.path}`})));
    if (seenUrls.has(candidate.canonicalUrl)) errors.push(issue("DUPLICATE_CANONICAL_URL", `candidates[${i}].canonicalUrl`, "Duplicate canonical URL."));
    if (seenIds.has(candidate.sourceId)) errors.push(issue("DUPLICATE_SOURCE_ID", `candidates[${i}].sourceId`, "Duplicate source ID."));
    seenUrls.add(candidate.canonicalUrl); seenIds.add(candidate.sourceId);
  }
  const fixture = envelope.fixtureMetadata || envelope.candidates.some((c) => c.fixtureMetadata);
  if (fixture && productionCallback) errors.push(issue("TEST_FIXTURE_PRODUCTION_CALLBACK", "fixtureMetadata", "Test fixture cannot use production callback."));
  return result({errors});
}

function validateAcquisitionResult(envelope, options) {
  try {
    return validateAcquisitionResultInternal(envelope, options);
  } catch (_) {
    return result({errors: [issue("ACQUISITION_VALIDATION_EXCEPTION", "$",
      "Doğrulama güvenli biçimde tamamlanamadı.")]});
  }
}
module.exports = {validateAcquisitionResult};
