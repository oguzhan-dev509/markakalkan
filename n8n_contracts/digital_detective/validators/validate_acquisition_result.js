"use strict";
const {validateCandidateSource} = require("./validate_candidate_source");
const {issue, result} = require("./validator_result");
const {validateSchema} = require("./schema_engine");

function validateAcquisitionResultInternal(envelope,
  {productionCallback = false} = {}) {
  const schema = validateSchema("acquisition_result", envelope);
  if (!schema.valid) return schema;
  const errors = [], seenUrls = new Set(), seenIds = new Set();
  if (envelope.candidates.length > 3) errors.push(issue("CANDIDATE_LIMIT_EXCEEDED", "candidates", "Maximum three candidates."));
  for (let i = 0; i < envelope.candidates.length; i++) {
    const candidate = envelope.candidates[i];
    const child = validateCandidateSource(candidate, {
      taskId: envelope.taskId, executionId: envelope.executionId,
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
