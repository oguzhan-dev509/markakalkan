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
  }
  return Object.freeze([...new Set(conflicts)].sort());
}

module.exports = {
  creationAuditSnapshotV1,
  receiptSnapshotV1,
  subjectSnapshotV1,
  validateStorageIntegrityV1,
};
