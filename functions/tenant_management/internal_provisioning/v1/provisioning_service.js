/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {invocationContextV1, provisioningRequestV1} = require("./contracts");
const {buildIdsV1, fingerprint} = require("./document_ids");
const {evaluateProvisioningPolicyV1} = require("./policy");
const {refs} = require("./storage");

const TENANT_NAME = "MarkaKalkan Internal Pilot";
const BRAND_NAME = "MarkaKalkan Pilot";
const normalize = (value) => value.trim().toLocaleLowerCase("tr-TR");
const actorHash = (uid) => createHash("sha256").update(uid).digest("hex");
function immutableFingerprint(value) {
  const copy = {...value};
  delete copy.createdAt;
  delete copy.updatedAt;
  return fingerprint(copy);
}

function documents({ids, uid, pilotCode, at}) {
  const tenant = {contractVersion: "canonical-tenant-v1", tenantId: ids.tenantId,
    tenantType: "internal", displayName: TENANT_NAME,
    normalizedName: normalize(TENANT_NAME), status: "active",
    visibility: "private", createdByUid: uid, createdAt: at, updatedAt: at,
    source: "mk_rst_0k_internal_provisioning", pilotCode, lifecycleVersion: 1};
  const brand = {contractVersion: "canonical-brand-v1", brandId: ids.brandId,
    tenantId: ids.tenantId, brandType: "internal", displayName: BRAND_NAME,
    normalizedName: normalize(BRAND_NAME), status: "active",
    visibility: "private", verificationStatus: "unverified",
    createdByUid: uid, createdAt: at, updatedAt: at,
    source: "mk_rst_0k_internal_provisioning", pilotCode, lifecycleVersion: 1};
  const membership = {contractVersion: "tenant-membership-v1",
    membershipId: ids.membershipId, tenantId: ids.tenantId, uid, role: "owner",
    status: "active", permissions: ["internal_tenant_brand.provision"],
    createdByUid: uid, createdAt: at, updatedAt: at,
    source: "mk_rst_0k_internal_provisioning", lifecycleVersion: 1};
  const tenantFingerprint = immutableFingerprint(tenant);
  const brandFingerprint = immutableFingerprint(brand);
  const audit = {schemaVersion: "tenant-brand-provisioning-audit-v1",
    eventType: "internal_tenant_brand_created", commandId: ids.commandId,
    tenantId: ids.tenantId, brandId: ids.brandId,
    membershipId: ids.membershipId, actorHash: actorHash(uid), createdAt: at,
    source: "mk_rst_0k_internal_provisioning"};
  const receipt = {schemaVersion: "tenant-brand-provisioning-receipt-v1",
    status: "completed", operation: "internal_tenant_brand_provision",
    pilotCode, tenantId: ids.tenantId, brandId: ids.brandId,
    membershipId: ids.membershipId, commandId: ids.commandId,
    tenantFingerprint, brandFingerprint, createdAt: at, completedAt: at,
    auditEventId: ids.auditId};
  return Object.freeze({tenant, brand, membership, receipt, audit,
    tenantFingerprint, brandFingerprint});
}

function stateOutcome(snapshots, docs) {
  const present = Object.fromEntries(Object.entries(snapshots)
      .map(([key, value]) => [key, value.exists]));
  const count = Object.values(present).filter(Boolean).length;
  if (count === 0) return "empty";
  if (count !== 5) return "conflict";
  const receipt = snapshots.receipt.data();
  if (!receipt || receipt.status !== "completed" ||
      receipt.tenantFingerprint !== docs.tenantFingerprint ||
      receipt.brandFingerprint !== docs.brandFingerprint ||
      receipt.auditEventId !== snapshots.audit.id) return "conflict";
  if (immutableFingerprint(snapshots.tenant.data()) !==
      docs.tenantFingerprint ||
      immutableFingerprint(snapshots.brand.data()) !== docs.brandFingerprint ||
      immutableFingerprint(snapshots.membership.data()) !==
      immutableFingerprint(docs.membership) ||
      immutableFingerprint(snapshots.audit.data()) !==
      immutableFingerprint(docs.audit)) return "conflict";
  return "complete";
}

function createInternalTenantBrandProvisioningServiceV1({db, clock}) {
  return Object.freeze({async execute(rawRequest, rawInvocation) {
    const request = provisioningRequestV1(rawRequest);
    const invocation = invocationContextV1(rawInvocation);
    const adminSnap = await db.collection("platform_admins")
        .doc(invocation.authenticatedUid).get();
    const policy = evaluateProvisioningPolicyV1({request, invocation,
      admin: {exists: adminSnap.exists, data: adminSnap.data()}});
    if (!policy.allowed) return {outcome: "denied", blockerCodes: policy.blockers};
    const ids = buildIdsV1({pilotCode: request.pilotCode,
      projectId: invocation.projectId, uid: invocation.authenticatedUid});
    const at = clock.now();
    const docs = documents({ids, uid: invocation.authenticatedUid,
      pilotCode: request.pilotCode, at});
    const r = refs(db, ids);
    const read = async (reader) => {
      const values = await reader.getAll(
          r.tenant, r.brand, r.membership, r.receipt, r.audit);
      return Object.fromEntries(["tenant", "brand", "membership", "receipt", "audit"]
          .map((key, index) => [key, values[index]]));
    };
    if (request.dryRun) {
      const state = stateOutcome(await read(db), docs);
      return {outcome: state === "empty" ? "dry_run_ready" :
        state === "complete" ? "already_exists" : "conflict", dryRun: true,
      transactionCommitted: false, ...ids, writeCount: 0};
    }
    return db.runTransaction(async (tx) => {
      const state = stateOutcome(await read(tx), docs);
      if (state === "complete") {
        return {outcome: "idempotent_success",
          dryRun: false, transactionCommitted: false, ...ids, writeCount: 0};
      }
      if (state === "conflict") {
        return {outcome: "conflict", dryRun: false,
          transactionCommitted: false, ...ids, writeCount: 0};
      }
      tx.create(r.tenant, docs.tenant); tx.create(r.brand, docs.brand);
      tx.create(r.membership, docs.membership); tx.create(r.receipt, docs.receipt);
      tx.create(r.audit, docs.audit);
      return {outcome: "created", dryRun: false, transactionCommitted: true,
        ...ids, writeCount: 5};
    });
  }});
}

module.exports = {BRAND_NAME, TENANT_NAME, createInternalTenantBrandProvisioningServiceV1,
  documents, stateOutcome};
