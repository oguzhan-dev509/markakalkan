const {COLLECTIONS} = require("./storage_contracts");

function createFirestorePersistenceStoreV1(db) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("Admin Firestore instance is required");
  }
  return Object.freeze({
    referencesFor({facts, creationAuditEventId}) {
      const collection = COLLECTIONS[
        facts.subjectType === "risk_signal" ? "riskSignal" :
        facts.subjectType === "risk_assessment" ? "riskAssessment" :
        "caseCandidate"
      ];
      return Object.freeze({
        subject: db.collection(collection).doc(facts.persistenceDocumentId),
        receipt: db.collection(COLLECTIONS.receipt).doc(facts.receiptId),
        audit: db.collection(COLLECTIONS.auditEvent).doc(creationAuditEventId),
      });
    },
    runTransaction(callback) {
      return db.runTransaction(callback);
    },
  });
}

module.exports = {createFirestorePersistenceStoreV1};
