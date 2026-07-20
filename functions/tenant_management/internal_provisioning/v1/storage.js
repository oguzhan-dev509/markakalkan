/* eslint-disable max-len */
const COLLECTIONS = Object.freeze({tenant: "tenants",
  brand: "canonical_brands", membership: "tenant_memberships",
  receipt: "tenant_brand_provisioning_receipts",
  audit: "tenant_brand_provisioning_audit_events"});

function refs(db, ids) {
  return Object.freeze({tenant: db.collection(COLLECTIONS.tenant).doc(ids.tenantId),
    brand: db.collection(COLLECTIONS.brand).doc(ids.brandId),
    membership: db.collection(COLLECTIONS.membership).doc(ids.membershipId),
    receipt: db.collection(COLLECTIONS.receipt).doc(ids.receiptId),
    audit: db.collection(COLLECTIONS.audit).doc(ids.auditId)});
}
module.exports = {COLLECTIONS, refs};
