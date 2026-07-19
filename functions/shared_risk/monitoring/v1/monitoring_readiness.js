function evaluateMonitoringReadinessV1({subject, exactKey, evaluatedAt}) {
  const blockers = [];
  const warnings = [];
  const block = (code) => blockers.push(code);
  if (subject.contractVersion !== "risk-signal-v1") {
    block("contract.unsupported");
  }
  if (!subject.identityScope.tenantId) block("identity.tenant_missing");
  if (!subject.signalId) block("signal.id_missing");
  if (!exactKey || exactKey.purpose !== "exact_source_occurrence") {
    block("idempotency.exact_key_required");
  }
  if (subject.signalSource.module !== "digital_market_monitoring" ||
      subject.provenance.producerModule !== "digital_market_monitoring") {
    block("consistency.source_module_mismatch");
  }
  if (!subject.signalType.namespace || !subject.signalType.value) {
    block("signal.type_invalid");
  }
  if (!subject.summary || !subject.detectedAt || !subject.createdAt) {
    block("signal.required_field_missing");
  }
  if (!subject.provenance.sourceRecordId) {
    block("provenance.source_missing");
  }
  if (!subject.canonicalAssetRef) warnings.push("signal.asset_missing");
  if (subject.evidenceRefs.length === 0) warnings.push("signal.evidence_empty");
  if (subject.relatedEntityRefs.length === 0) {
    warnings.push("signal.refs_empty");
  }
  warnings.push("signal.confidence_missing");
  return Object.freeze({allowed: blockers.length === 0,
    blockers: Object.freeze(blockers.sort()),
    warnings: Object.freeze(warnings.sort()),
    policyVersion: "mk-risk-persistence-readiness-v1", evaluatedAt,
    identityResolutionStatus: "resolved",
    evaluatedIdempotencyKey: exactKey.canonicalKey});
}

module.exports = {evaluateMonitoringReadinessV1};
