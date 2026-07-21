const {immutableSnapshot} = require("./storage_contracts");

function subjectSnapshotV1(snapshot) {
  if (!snapshot.exists) return Object.freeze({status: "absent"});
  return immutableSnapshot({status: "present", ...snapshot.data()});
}

function creationAuditSnapshotV1(snapshot) {
  if (!snapshot.exists) return Object.freeze({status: "absent"});
  return immutableSnapshot({status: "present", ...snapshot.data()});
}

function receiptSnapshotV1(snapshot) {
  if (!snapshot.exists) return Object.freeze({status: "absent"});
  return immutableSnapshot(snapshot.data());
}

function validateStorageIntegrityV1({facts, receipt, subject, audit,
  creationAuditEventId}) {
  const conflicts = [];
  const mismatch = (code, actual, expected) => {
    if (actual !== expected) conflicts.push(code);
  };
  if (receipt.status === "absent") {
    if (subject.status === "present") {
      conflicts.push("integrity.orphan_subject");
    }
    if (audit.status === "present") conflicts.push("integrity.orphan_audit");
    return Object.freeze([...conflicts].sort());
  }
  if (receipt.status === "completed") {
    if (subject.status !== "present") {
      conflicts.push("integrity.subject_missing");
    }
    if (audit.status !== "present") conflicts.push("integrity.audit_missing");
    mismatch("integrity.receipt_schema", receipt.schemaVersion,
        "shared-risk-receipt-v1");
    mismatch("integrity.receipt_outcome", receipt.outcome, "created");
    mismatch("integrity.receipt_audit", receipt.creationAuditEventId,
        creationAuditEventId);
    mismatch("integrity.receipt_source_version", receipt.sourceRecordVersion,
        facts.sourceRecordVersion || null);
    mismatch("integrity.receipt_fingerprint_algorithm",
        receipt.fingerprintAlgorithm, facts.fingerprintAlgorithm);
    if (facts.provenance.contractVersion ===
        "shared-risk-promotion-command-v1") {
      mismatch("integrity.receipt_operation", receipt.operation,
          "human_approved_shared_risk_promotion");
      mismatch("integrity.receipt_signal", receipt.signalId,
          facts.persistenceDocumentId);
      mismatch("integrity.receipt_brand", receipt.canonicalBrandId,
          facts.resolvedIdentityScope.brandId);
      mismatch("integrity.receipt_source_system", receipt.sourceSystem,
          facts.sourceModule);
      mismatch("integrity.receipt_source_record", receipt.sourceRecordId,
          facts.canonicalSubjectPayload.sourceRecordId);
      mismatch("integrity.receipt_projection_fingerprint",
          receipt.projectionFingerprint,
          facts.provenance.projectionFingerprint);
      mismatch("integrity.receipt_signal_fingerprint",
          receipt.signalFingerprint, facts.subjectFingerprint);
      mismatch("integrity.receipt_audit_event", receipt.auditEventId,
          creationAuditEventId);
    }
  }
  if (subject.status === "present") {
    mismatch("integrity.subject_tenant", subject.tenantId,
        facts.resolvedIdentityScope.tenantId);
    mismatch("integrity.subject_target", subject.targetNamespace,
        facts.targetNamespace);
    mismatch("integrity.subject_type", subject.subjectType, facts.subjectType);
    mismatch("integrity.subject_id", subject.subjectId, facts.subjectId);
    mismatch("integrity.subject_command", subject.commandId, facts.commandId);
    mismatch("integrity.subject_key", subject.exactIdempotencyKey,
        facts.exactIdempotencyBinding.canonicalKey);
    mismatch("integrity.subject_fingerprint", subject.subjectFingerprint,
        facts.subjectFingerprint);
  }
  if (audit.status === "present") {
    mismatch("integrity.audit_schema", audit.schemaVersion,
        "shared-risk-audit-v1");
    mismatch("integrity.audit_id", audit.auditEventId, creationAuditEventId);
    mismatch("integrity.audit_tenant", audit.tenantId,
        facts.resolvedIdentityScope.tenantId);
    mismatch("integrity.audit_command", audit.commandId, facts.commandId);
    mismatch("integrity.audit_document", audit.persistenceDocumentId,
        facts.persistenceDocumentId);
    mismatch("integrity.audit_receipt", audit.receiptId, facts.receiptId);
    mismatch("integrity.audit_fingerprint", audit.subjectFingerprint,
        facts.subjectFingerprint);
    mismatch("integrity.audit_event_type", audit.eventType,
        "persistence_created");
    mismatch("integrity.audit_outcome", audit.outcome, "create");
    mismatch("integrity.audit_subject_type", audit.subjectType,
        facts.subjectType);
    mismatch("integrity.audit_subject_id", audit.subjectId, facts.subjectId);
    if (facts.provenance.contractVersion ===
        "shared-risk-promotion-command-v1") {
      mismatch("integrity.audit_source_ref", audit.sourceReference,
          facts.sourceRecordRef);
      mismatch("integrity.audit_brand", audit.canonicalBrandId,
          facts.resolvedIdentityScope.brandId);
      mismatch("integrity.audit_source_system", audit.sourceSystem,
          facts.sourceModule);
      mismatch("integrity.audit_source_version", audit.sourceRecordVersion,
          facts.sourceRecordVersion);
      mismatch("integrity.audit_producer", audit.producer,
          "shared_risk_promotion_v1");
    }
  }
  return Object.freeze([...new Set(conflicts)].sort());
}

module.exports = {
  creationAuditSnapshotV1,
  receiptSnapshotV1,
  subjectSnapshotV1,
  validateStorageIntegrityV1,
};
