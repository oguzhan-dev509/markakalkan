"use strict";
const {canonicalizeUrl} = require("./canonicalize_url");
const {buildFindingKey} = require("./deterministic_ids");
const {isPlainRecord, issue, result} = require("./validator_result");
const {validateSchema} = require("./schema_engine");
const {invalidCandidateIssue, invalidEvidenceIssue} =
  require("./context_validation");

const CONCLUSIVE = /(?:kesin|doğrulanmış)\s+(?:sahte|taklit)|confirmed[_ -]?counterfeit/i;
const META = /\b(?:örnek|varsayımsal|demo|template|şablon|metodoloji)\b/i;

function validateScannerResultInternal(scanner, context) {
  const schema = validateSchema("digital_field_scanner_result", scanner);
  if (!schema.valid) return result({errors: schema.errors,
    acceptedFindingCount: 0, rejectedFindingCount: 0});
  if (!isPlainRecord(context) || typeof context.taskId !== "string" || !context.taskId ||
      typeof context.executionId !== "string" || !context.executionId ||
      !Array.isArray(context.candidates) || !Array.isArray(context.evidences)) {
    return result({errors: [issue("CONTEXT_REQUIRED", "$",
      "Task, execution, candidates ve evidences context zorunludur.")],
    acceptedFindingCount: 0, rejectedFindingCount: 0});
  }
  const {candidates, evidences: evidence, productionCallback = false} = context;
  const invalidCandidate = invalidCandidateIssue(candidates);
  if (invalidCandidate) return result({errors: [invalidCandidate],
    acceptedFindingCount: 0, rejectedFindingCount: 0});
  const invalidEvidence = invalidEvidenceIssue(evidence);
  if (invalidEvidence) return result({errors: [invalidEvidence],
    acceptedFindingCount: 0, rejectedFindingCount: 0});
  const errors = [], warnings = [], seen = new Set(), rejected = new Set();
  if (scanner.taskId !== context.taskId || scanner.executionId !== context.executionId) {
    errors.push(issue("SCANNER_SCOPE_MISMATCH", "executionId", "Scanner scope mismatch."));
  }
  const acquired = candidates.filter((c) => c.acquisitionStatus === "acquired");
  for (const id of scanner.analyzedSourceIds) if (!acquired.some((c) => c.sourceId === id)) errors.push(issue("ANALYZED_SOURCE_NOT_ACQUIRED", "analyzedSourceIds", "Analyzed source is not acquired."));
  scanner.findings.forEach((finding, i) => {
    const path = `findings[${i}]`, candidate = acquired.find((c) => c.sourceId === finding.candidateId);
    const reject = (entry) => { errors.push(entry); rejected.add(i); };
    if (!candidate) reject(issue("FINDING_CANDIDATE_NOT_FOUND", `${path}.candidateId`, "Acquired candidate not found."));
    const canonical = canonicalizeUrl(finding.sourceUrl);
    if (candidate && (!canonical.valid || canonical.canonicalUrl !== candidate.canonicalUrl)) reject(issue("FINDING_URL_MISMATCH", `${path}.sourceUrl`, "Finding URL mismatch."));
    const refs = finding.evidenceReferences.map((id) => evidence.find((e) => e.snapshotId === id));
    if (refs.some((e) => !e)) reject(issue("EVIDENCE_REFERENCE_NOT_FOUND", `${path}.evidenceReferences`, "Evidence reference not found."));
    if (candidate && refs.some((e) => e && (e.taskId !== scanner.taskId || e.executionId !== scanner.executionId || e.sourceId !== candidate.sourceId))) reject(issue("FINDING_EVIDENCE_SCOPE_MISMATCH", `${path}.evidenceReferences`, "Evidence scope mismatch."));
    const expected = buildFindingKey(scanner.taskId, scanner.executionId, finding.candidateId, finding.signalType, finding.evidenceReferences);
    if (finding.findingKey !== expected) reject(issue("FINDING_KEY_MISMATCH", `${path}.findingKey`, "Finding key mismatch."));
    if (seen.has(finding.findingKey)) reject(issue("DUPLICATE_FINDING_KEY", `${path}.findingKey`, "Duplicate finding key."));
    seen.add(finding.findingKey);
    if (finding.severity === "critical" && finding.evidenceReferences.length === 0) reject(issue("CRITICAL_EVIDENCE_REQUIRED", `${path}.evidenceReferences`, "Critical finding requires evidence."));
    if (finding.severity === "critical" && finding.confidence < 0.8) reject(issue("CRITICAL_CONFIDENCE_LOW", `${path}.confidence`, "Critical confidence must be >= 0.80."));
    if (CONCLUSIVE.test(finding.description)) reject(issue("CONCLUSIVE_COUNTERFEIT_LANGUAGE", `${path}.description`, "Conclusive counterfeit language forbidden."));
    if (!candidate && finding.evidenceReferences.length === 0 && META.test(finding.description)) reject(issue("METHODOLOGY_AS_FINDING", `${path}.description`, "Methodology/example cannot become a finding."));
  });
  const fixture = scanner.fixtureMetadata || candidates.some((c) => c.fixtureMetadata);
  if (fixture && productionCallback) errors.push(issue("TEST_FIXTURE_PRODUCTION_CALLBACK", "fixtureMetadata", "Test fixture cannot use production callback."));
  return result({errors, warnings,
    acceptedFindingCount: scanner.findings.length - rejected.size,
    rejectedFindingCount: rejected.size});
}

function validateScannerResult(scanner, context) {
  try {
    return validateScannerResultInternal(scanner, context);
  } catch (_) {
    return result({errors: [issue("SCANNER_VALIDATION_EXCEPTION", "$",
      "Doğrulama güvenli biçimde tamamlanamadı.")],
    acceptedFindingCount: 0, rejectedFindingCount: 0});
  }
}
module.exports = {validateScannerResult};
