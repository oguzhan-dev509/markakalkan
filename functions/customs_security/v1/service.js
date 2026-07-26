/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");
const {
  CustomsSecurityError,
  INTERVENTION_STATUSES,
  PROFILE_STATUSES,
  fingerprint,
  interventionCreateRequest,
  interventionDetailRequest,
  interventionListRequest,
  interventionTransitionRequest,
  interventionUpdateRequest,
  profileCreateRequest,
  profileCreateAndActivateRequest,
  profileDetailRequest,
  profileListRequest,
  profileTransitionRequest,
  profileUpdateRequest,
} = require("./contracts");

const PROFILE_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["under_review", "archived"]),
  under_review: Object.freeze(["draft", "active", "archived"]),
  active: Object.freeze(["suspended", "expired", "archived"]),
  suspended: Object.freeze(["active", "expired", "archived"]),
  expired: Object.freeze(["archived"]),
  archived: Object.freeze([]),
});

const INTERVENTION_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["risk_review", "under_preliminary_review", "closed", "archived"]),
  risk_review: Object.freeze(["under_preliminary_review", "temporarily_detained", "closed"]),
  under_preliminary_review: Object.freeze(["temporarily_detained", "awaiting_right_holder", "authentication_in_progress", "infringement_not_confirmed", "infringement_suspected", "closed"]),
  temporarily_detained: Object.freeze(["awaiting_right_holder", "authentication_in_progress", "released", "referred_to_authority"]),
  awaiting_right_holder: Object.freeze(["authentication_in_progress", "infringement_not_confirmed", "infringement_suspected", "released", "legal_action_required"]),
  authentication_in_progress: Object.freeze(["infringement_not_confirmed", "infringement_suspected", "infringement_confirmed"]),
  infringement_not_confirmed: Object.freeze(["released", "closed"]),
  infringement_suspected: Object.freeze(["temporarily_detained", "awaiting_right_holder", "authentication_in_progress", "legal_action_required", "released"]),
  infringement_confirmed: Object.freeze(["importer_objection", "legal_action_required", "destruction_pending", "referred_to_authority"]),
  importer_objection: Object.freeze(["authentication_in_progress", "legal_action_required", "destruction_pending", "released", "referred_to_authority"]),
  legal_action_required: Object.freeze(["destruction_pending", "released", "referred_to_authority", "closed"]),
  destruction_pending: Object.freeze(["destroyed", "legal_action_required"]),
  destroyed: Object.freeze(["closed"]),
  released: Object.freeze(["closed"]),
  referred_to_authority: Object.freeze(["legal_action_required", "closed"]),
  closed: Object.freeze(["archived"]),
  archived: Object.freeze([]),
});

const PROFILE_COLLECTION = "customs_protection_profiles";
const INTERVENTION_COLLECTION = "customs_border_interventions";
const EVENT_COLLECTION = "customs_intervention_events";
const MAX_SCOPE = 200;

const sha256 = (value) => createHash("sha256").update(String(value), "utf8").digest("hex");

function nowIso(clock) {
  const value = clock.now();
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new CustomsSecurityError("internal", "clock invalid");
  }
  return date.toISOString();
}

function dataOf(snapshot) {
  return {id: snapshot.id, data: snapshot.data() || {}};
}

function optional(target, values) {
  for (const [key, value] of Object.entries(values)) {
    if (value != null) target[key] = value;
  }
  return target;
}

async function ownerRequired({db, context}) {
  const snapshot = await db.collection("tenant_memberships").doc(context.membershipId).get();
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.status !== "active" || data.role !== "owner") {
    throw new CustomsSecurityError("authorization.denied", "owner required");
  }
}

function scoped(snapshot, context, code) {
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) {
    throw new CustomsSecurityError(code, "record not found");
  }
  return data;
}

function eventRef(db, context, entityType, entityId, requestId) {
  const id = sha256(`${context.tenantId}|customs-security-event|${entityType}|${entityId}|${requestId}`);
  return {id, ref: db.collection(EVENT_COLLECTION).doc(id)};
}

function assertFingerprint(existing, expected) {
  if ((existing.requestFingerprint || null) !== expected) {
    throw new CustomsSecurityError("idempotency.conflict", "request fingerprint mismatch");
  }
}

function eventDocument({
  context,
  entityType,
  entityId,
  profileId,
  interventionId,
  sequence,
  eventType,
  previousStatus,
  nextStatus,
  summary,
  reason,
  actorUid,
  recordedAt,
  previousEventId,
  requestId,
  requestFingerprint,
}) {
  return optional({
    contractVersion: "customs-security-event-v1",
    schemaVersion: "customs-security-event-schema-v1",
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    entityType,
    entityId,
    sequence,
    eventType,
    summary,
    reason,
    actorUid,
    actorRole: "owner",
    actorLabel: "Yetkili kullanıcı",
    recordedAt,
    requestId,
    requestFingerprint,
    appendOnly: true,
  }, {
    protectionProfileId: profileId,
    interventionId,
    previousStatus,
    nextStatus,
    previousEventId,
  });
}

function profileData(request) {
  const result = {...request};
  delete result.contractVersion;
  delete result.tenantId;
  delete result.canonicalBrandId;
  delete result.profileId;
  delete result.requestId;
  delete result.activationConfirmation;
  delete result.activationConfirmationVersion;
  delete result.activationReason;
  return result;
}

function interventionData(request) {
  const result = {...request};
  delete result.contractVersion;
  delete result.tenantId;
  delete result.canonicalBrandId;
  delete result.interventionId;
  delete result.requestId;
  return result;
}

function hasIntegritySignal(data) {
  return [
    "unusualReleaseFlag",
    "decisionEvidenceMismatchFlag",
    "missingRecordOrSampleFlag",
    "postRecordModificationFlag",
    "unexplainedAccelerationFlag",
    "quantityOrDestructionMismatchFlag",
    "independentReviewRequired",
  ].some((field) => data[field] === true);
}

function safeProfile(id, data) {
  return {
    profileId: id,
    profileNumber: data.profileNumber,
    profileName: data.profileName,
    status: data.status,
    rightHolderName: data.rightHolderName,
    rightHolderReferenceIds: data.rightHolderReferenceIds || [],
    authorizedRepresentativeIds: data.authorizedRepresentativeIds || [],
    authorizedManufacturerIds: data.authorizedManufacturerIds || [],
    authorizedImporterIds: data.authorizedImporterIds || [],
    protectedProductIds: data.protectedProductIds || [],
    hsCodes: data.hsCodes || [],
    productCategories: data.productCategories || [],
    originCountries: data.originCountries || [],
    authorizedImportCountries: data.authorizedImportCountries || [],
    authenticationInstructions: data.authenticationInstructions,
    serialVerificationMethods: data.serialVerificationMethods || [],
    securityFeatureSummaries: data.securityFeatureSummaries || [],
    counterfeitTwinRecordIds: data.counterfeitTwinRecordIds || [],
    productionAssetIds: data.productionAssetIds || [],
    riskCountryCodes: data.riskCountryCodes || [],
    riskRouteSummaries: data.riskRouteSummaries || [],
    emergencyContactIds: data.emergencyContactIds || [],
    validFrom: data.validFrom || null,
    validUntil: data.validUntil || null,
    reviewDueAt: data.reviewDueAt || null,
    eventCount: Number(data.eventCount || 0),
    lastEventType: data.lastEventType || null,
    lastEventAt: data.lastEventAt || null,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  };
}

function safeIntervention(id, data) {
  return {
    interventionId: id,
    interventionNumber: data.interventionNumber,
    protectionProfileId: data.protectionProfileId,
    status: data.status,
    integrityStatus: data.integrityStatus,
    priority: data.priority,
    sourceType: data.sourceType,
    countryCode: data.countryCode,
    customsAuthorityName: data.customsAuthorityName,
    borderPointType: data.borderPointType,
    borderPointName: data.borderPointName,
    shipmentReference: data.shipmentReference || null,
    containerReference: data.containerReference || null,
    cargoReference: data.cargoReference || null,
    trackingReferences: data.trackingReferences || [],
    senderParty: data.senderParty || null,
    recipientParty: data.recipientParty || null,
    importerParty: data.importerParty || null,
    carrierParty: data.carrierParty || null,
    customsBrokerParty: data.customsBrokerParty || null,
    declaredProductDescription: data.declaredProductDescription,
    declaredHsCode: data.declaredHsCode || null,
    declaredQuantity: data.declaredQuantity ?? null,
    declaredUnit: data.declaredUnit || null,
    declaredValue: data.declaredValue ?? null,
    declaredCurrency: data.declaredCurrency || null,
    suspectedProductIds: data.suspectedProductIds || [],
    counterfeitTwinRecordIds: data.counterfeitTwinRecordIds || [],
    supplyPartnerIds: data.supplyPartnerIds || [],
    supplyFacilityIds: data.supplyFacilityIds || [],
    productionAssetIds: data.productionAssetIds || [],
    sourceRiskSignalIds: data.sourceRiskSignalIds || [],
    detainedAt: data.detainedAt || null,
    notificationReceivedAt: data.notificationReceivedAt || null,
    responseDeadlineAt: data.responseDeadlineAt || null,
    actionDeadlineAt: data.actionDeadlineAt || null,
    suspicionReasons: data.suspicionReasons || [],
    authenticationResult: data.authenticationResult,
    decisionSummary: data.decisionSummary || null,
    decisionReason: data.decisionReason || null,
    caseId: data.caseId || null,
    legalMatterId: data.legalMatterId || null,
    assignedUserUid: data.assignedUserUid || null,
    reviewerUserUid: data.reviewerUserUid || null,
    approvedByUid: data.approvedByUid || null,
    unusualReleaseFlag: data.unusualReleaseFlag === true,
    decisionEvidenceMismatchFlag: data.decisionEvidenceMismatchFlag === true,
    missingRecordOrSampleFlag: data.missingRecordOrSampleFlag === true,
    postRecordModificationFlag: data.postRecordModificationFlag === true,
    unexplainedAccelerationFlag: data.unexplainedAccelerationFlag === true,
    quantityOrDestructionMismatchFlag: data.quantityOrDestructionMismatchFlag === true,
    independentReviewRequired: data.independentReviewRequired === true,
    eventCount: Number(data.eventCount || 0),
    lastEventType: data.lastEventType || null,
    lastEventAt: data.lastEventAt || null,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  };
}

function safeEvent(data) {
  return {
    entityType: data.entityType,
    entityId: data.entityId,
    protectionProfileId: data.protectionProfileId || null,
    interventionId: data.interventionId || null,
    sequence: Number(data.sequence || 0),
    eventType: data.eventType,
    previousStatus: data.previousStatus || null,
    nextStatus: data.nextStatus || null,
    summary: data.summary,
    reason: data.reason,
    actorLabel: data.actorLabel || "Yetkili kullanıcı",
    recordedAt: data.recordedAt,
  };
}

function decodeCursor(token) {
  if (!token) return null;
  try {
    const parsed = JSON.parse(Buffer.from(token, "base64url").toString("utf8"));
    if (!parsed || typeof parsed.updatedAt !== "string" || typeof parsed.id !== "string") {
      throw new Error("invalid cursor");
    }
    return parsed;
  } catch (_) {
    throw new CustomsSecurityError("invalid-argument", "pageToken invalid");
  }
}

function paginate(items, request) {
  const sorted = [...items].sort((a, b) =>
    String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")) ||
    a.id.localeCompare(b.id),
  );
  const cursor = decodeCursor(request.pageToken);
  const after = cursor ? sorted.filter((item) =>
    String(item.updatedAt || "") < cursor.updatedAt ||
    (String(item.updatedAt || "") === cursor.updatedAt && item.id > cursor.id),
  ) : sorted;
  const page = after.slice(0, request.pageSize);
  const last = page.at(-1);
  const nextPageToken = after.length > page.length && last ?
    Buffer.from(JSON.stringify({updatedAt: last.updatedAt || "", id: last.id}), "utf8").toString("base64url") :
    null;
  return {items: page, nextPageToken};
}

async function boundedQuery(query, code) {
  const snapshot = await query.limit(MAX_SCOPE + 1).get();
  if (snapshot.docs.length > MAX_SCOPE) {
    throw new CustomsSecurityError("scope.too_large", code);
  }
  return snapshot.docs.map(dataOf);
}

async function profileSnapshot({db, profileId, context, transaction = null}) {
  const ref = db.collection(PROFILE_COLLECTION).doc(profileId);
  const snapshot = transaction ? await transaction.get(ref) : await ref.get();
  return {ref, data: scoped(snapshot, context, "profile.not_found")};
}

async function interventionSnapshot({db, interventionId, context, transaction = null}) {
  const ref = db.collection(INTERVENTION_COLLECTION).doc(interventionId);
  const snapshot = transaction ? await transaction.get(ref) : await ref.get();
  return {ref, data: scoped(snapshot, context, "intervention.not_found")};
}

function requireProfileTransition(current, next, data, now) {
  if (!PROFILE_STATUSES.includes(current) || !PROFILE_STATUSES.includes(next) || !PROFILE_TRANSITIONS[current].includes(next)) {
    throw new CustomsSecurityError("status.invalid_transition", "profile transition invalid");
  }
  if (next === "active") {
    if (!(data.rightHolderReferenceIds || []).length || !(data.protectedProductIds || []).length) {
      throw new CustomsSecurityError("status.precondition_failed", "active profile requires rights and products");
    }
    if (data.validUntil && data.validUntil <= now) {
      throw new CustomsSecurityError("status.precondition_failed", "active profile validity expired");
    }
  }
}

function requireInterventionTransition(current, next, data, request) {
  if (!INTERVENTION_STATUSES.includes(current) || !INTERVENTION_STATUSES.includes(next) || !INTERVENTION_TRANSITIONS[current].includes(next)) {
    throw new CustomsSecurityError("status.invalid_transition", "intervention transition invalid");
  }
  if (next === "infringement_confirmed") {
    if (!request.humanAssessmentReference || !["likely_counterfeit", "confirmed_counterfeit"].includes(data.authenticationResult)) {
      throw new CustomsSecurityError("status.precondition_failed", "confirmed infringement requires human assessment and authentication basis");
    }
  }
  if (["destroyed", "released"].includes(next) && !request.decisionReference) {
    throw new CustomsSecurityError("status.precondition_failed", `${next} requires decision reference`);
  }
  if (next === "referred_to_authority" && !request.authorityReference) {
    throw new CustomsSecurityError("status.precondition_failed", "authority reference required");
  }
}

function createCustomsSecurityService({
  db,
  clock = {now: () => new Date().toISOString()},
  resolveContext = resolveTenantContextV1,
}) {
  async function contextFor(request, invocation, owner = false) {
    if (!invocation?.uid) {
      throw new CustomsSecurityError("unauthenticated", "authentication required");
    }
    const context = await resolveContext({
      db,
      uid: invocation.uid,
      request: {
        tenantId: request.tenantId || null,
        canonicalBrandId: request.canonicalBrandId || null,
      },
    });
    if (owner) await ownerRequired({db, context});
    return context;
  }

  return Object.freeze({
    async createAndActivateProfile(raw, invocation) {
      const request = profileCreateAndActivateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const profileId = sha256(`${context.tenantId}|${context.brandId}|customs-profile|${request.requestId}`);
      const profileRef = db.collection(PROFILE_COLLECTION).doc(profileId);
      const events = [1, 2, 3].map((sequence) =>
        eventRef(db, context, "protection_profile", profileId, `${request.requestId}|${sequence}`),
      );
      return db.runTransaction(async (transaction) => {
        const [existing, ...existingEvents] = await Promise.all([
          transaction.get(profileRef),
          ...events.map((event) => transaction.get(event.ref)),
        ]);
        if (existing.exists) {
          const data = scoped(existing, context, "profile.not_found");
          assertFingerprint(data, requestFingerprint);
          if (data.status !== "active" || existingEvents.some((snapshot) => !snapshot.exists)) {
            throw new CustomsSecurityError("internal", "incomplete create-and-activate state");
          }
          for (const snapshot of existingEvents) {
            assertFingerprint(snapshot.data() || {}, requestFingerprint);
          }
          return {
            contractVersion: "customs-protection-profile-create-and-activate-result-v1",
            ok: true,
            duplicate: true,
            transactionApplied: false,
            profile: safeProfile(profileId, data),
          };
        }
        if (existingEvents.some((snapshot) => snapshot.exists)) {
          throw new CustomsSecurityError("internal", "orphan customs event");
        }

        const base = profileData(request);
        requireProfileTransition("draft", "under_review", base, recordedAt);
        requireProfileTransition("under_review", "active", base, recordedAt);
        const profileNumber = `GKP-${recordedAt.slice(0, 4)}-${profileId.slice(0, 8).toUpperCase()}`;
        const data = {
          contractVersion: "customs-protection-profile-v1",
          schemaVersion: "customs-protection-profile-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          profileNumber,
          status: "active",
          ...base,
          requestId: request.requestId,
          requestFingerprint,
          createdByUid: invocation.uid,
          createdAt: recordedAt,
          statusReason: request.activationReason,
          statusChangedAt: recordedAt,
          statusChangedByUid: invocation.uid,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: 3,
          lastEventId: events[2].id,
          lastEventType: "protection_profile_status_transitioned",
          lastEventAt: recordedAt,
        };
        const eventInputs = [
          {
            sequence: 1,
            previousStatus: null,
            nextStatus: "draft",
            eventType: "protection_profile_created",
            summary: `${profileNumber} gümrük koruma profili oluşturuldu.`,
            reason: "Gümrük koruma profili ilk taslak kaydı.",
            previousEventId: null,
          },
          {
            sequence: 2,
            previousStatus: "draft",
            nextStatus: "under_review",
            eventType: "protection_profile_status_transitioned",
            summary: `${profileNumber} profil durumu under_review olarak değiştirildi.`,
            reason: "owner_confirmed_create_and_activate (customs-profile-activation-confirmation-v1): Hak sahibi/yetkili kullanıcı beyanıyla inceleme adımı kaydedildi.",
            previousEventId: events[0].id,
          },
          {
            sequence: 3,
            previousStatus: "under_review",
            nextStatus: "active",
            eventType: "protection_profile_status_transitioned",
            summary: `${profileNumber} profil durumu active olarak değiştirildi.`,
            reason: request.activationReason,
            previousEventId: events[1].id,
          },
        ];
        transaction.create(profileRef, data);
        for (let index = 0; index < events.length; index += 1) {
          transaction.create(events[index].ref, eventDocument({
            context,
            entityType: "protection_profile",
            entityId: profileId,
            profileId,
            ...eventInputs[index],
            actorUid: invocation.uid,
            recordedAt,
            requestId: request.requestId,
            requestFingerprint,
          }));
        }
        return {
          contractVersion: "customs-protection-profile-create-and-activate-result-v1",
          ok: true,
          duplicate: false,
          transactionApplied: true,
          profile: safeProfile(profileId, data),
        };
      });
    },

    async createProfile(raw, invocation) {
      const request = profileCreateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const profileId = sha256(`${context.tenantId}|${context.brandId}|customs-profile|${request.requestId}`);
      const profileRef = db.collection(PROFILE_COLLECTION).doc(profileId);
      const event = eventRef(db, context, "protection_profile", profileId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const [existing, existingEvent] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(event.ref),
        ]);
        if (existing.exists) {
          const data = scoped(existing, context, "profile.not_found");
          assertFingerprint(data, requestFingerprint);
          if (existingEvent.exists) assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-protection-profile-create-result-v1",
            ok: true,
            duplicate: true,
            profile: safeProfile(profileId, data),
            transactionCommitted: false,
          };
        }
        if (existingEvent.exists) {
          throw new CustomsSecurityError("internal", "orphan customs event");
        }
        const profileNumber = `GKP-${recordedAt.slice(0, 4)}-${profileId.slice(0, 8).toUpperCase()}`;
        const data = {
          contractVersion: "customs-protection-profile-v1",
          schemaVersion: "customs-protection-profile-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          profileNumber,
          status: "draft",
          ...profileData(request),
          requestId: request.requestId,
          requestFingerprint,
          createdByUid: invocation.uid,
          createdAt: recordedAt,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: 1,
          lastEventId: event.id,
          lastEventType: "protection_profile_created",
          lastEventAt: recordedAt,
        };
        transaction.create(profileRef, data);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "protection_profile",
          entityId: profileId,
          profileId,
          sequence: 1,
          eventType: "protection_profile_created",
          previousStatus: null,
          nextStatus: "draft",
          summary: `${profileNumber} gümrük koruma profili oluşturuldu.`,
          reason: "Gümrük koruma profili ilk taslak kaydı.",
          actorUid: invocation.uid,
          recordedAt,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-protection-profile-create-result-v1",
          ok: true,
          duplicate: false,
          profile: safeProfile(profileId, data),
          transactionCommitted: true,
        };
      });
    },

    async updateProfile(raw, invocation) {
      const request = profileUpdateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, "protection_profile", request.profileId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const profile = await profileSnapshot({db, profileId: request.profileId, context, transaction});
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-protection-profile-update-result-v1",
            ok: true,
            duplicate: true,
            profile: safeProfile(request.profileId, profile.data),
            transactionCommitted: false,
          };
        }
        if (profile.data.status === "archived") {
          throw new CustomsSecurityError("status.precondition_failed", "archived profile immutable");
        }
        const sequence = Number(profile.data.eventCount || 0) + 1;
        const updates = {
          ...profileData(request),
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "protection_profile_updated",
          lastEventAt: recordedAt,
        };
        transaction.update(profile.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "protection_profile",
          entityId: request.profileId,
          profileId: request.profileId,
          sequence,
          eventType: "protection_profile_updated",
          previousStatus: profile.data.status,
          nextStatus: profile.data.status,
          summary: `${profile.data.profileNumber} gümrük koruma profili güncellendi.`,
          reason: "Yetkili kullanıcı profil bilgilerini güncelledi.",
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: profile.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        const merged = {...profile.data, ...updates};
        return {
          contractVersion: "customs-protection-profile-update-result-v1",
          ok: true,
          duplicate: false,
          profile: safeProfile(request.profileId, merged),
          transactionCommitted: true,
        };
      });
    },

    async transitionProfile(raw, invocation) {
      const request = profileTransitionRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, "protection_profile", request.profileId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const profile = await profileSnapshot({db, profileId: request.profileId, context, transaction});
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-protection-profile-transition-result-v1",
            ok: true,
            duplicate: true,
            profile: safeProfile(request.profileId, profile.data),
            transactionCommitted: false,
          };
        }
        requireProfileTransition(profile.data.status, request.nextStatus, profile.data, recordedAt);
        const sequence = Number(profile.data.eventCount || 0) + 1;
        const updates = {
          status: request.nextStatus,
          statusReason: request.reason,
          statusChangedAt: recordedAt,
          statusChangedByUid: invocation.uid,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "protection_profile_status_transitioned",
          lastEventAt: recordedAt,
        };
        transaction.update(profile.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "protection_profile",
          entityId: request.profileId,
          profileId: request.profileId,
          sequence,
          eventType: "protection_profile_status_transitioned",
          previousStatus: profile.data.status,
          nextStatus: request.nextStatus,
          summary: `${profile.data.profileNumber} profil durumu ${request.nextStatus} olarak değiştirildi.`,
          reason: request.reason,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: profile.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-protection-profile-transition-result-v1",
          ok: true,
          duplicate: false,
          profile: safeProfile(request.profileId, {...profile.data, ...updates}),
          transactionCommitted: true,
        };
      });
    },

    async listProfiles(raw, invocation) {
      const request = profileListRequest(raw);
      const context = await contextFor(request, invocation, false);
      let query = db.collection(PROFILE_COLLECTION)
          .where("tenantId", "==", context.tenantId)
          .where("canonicalBrandId", "==", context.brandId);
      if (request.status) query = query.where("status", "==", request.status);
      const records = await boundedQuery(query, "profile list scope too large");
      const page = paginate(records.map((item) => ({
        id: item.id,
        updatedAt: item.data.updatedAt,
        value: safeProfile(item.id, item.data),
      })), request);
      return {
        contractVersion: "customs-protection-profile-list-v1",
        items: page.items.map((item) => item.value),
        nextPageToken: page.nextPageToken,
        readOnly: true,
        writesPerformed: 0,
      };
    },

    async profileDetail(raw, invocation) {
      const request = profileDetailRequest(raw);
      const context = await contextFor(request, invocation, false);
      const profile = await profileSnapshot({db, profileId: request.profileId, context});
      return {
        contractVersion: "customs-protection-profile-detail-v1",
        profile: safeProfile(request.profileId, profile.data),
        readOnly: true,
        writesPerformed: 0,
      };
    },

    async createIntervention(raw, invocation) {
      const request = interventionCreateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const interventionId = sha256(`${context.tenantId}|${context.brandId}|customs-intervention|${request.requestId}`);
      const interventionRef = db.collection(INTERVENTION_COLLECTION).doc(interventionId);
      const event = eventRef(db, context, "border_intervention", interventionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const [existing, existingEvent] = await Promise.all([
          transaction.get(interventionRef),
          transaction.get(event.ref),
        ]);
        if (existing.exists) {
          const data = scoped(existing, context, "intervention.not_found");
          assertFingerprint(data, requestFingerprint);
          if (existingEvent.exists) assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-border-intervention-create-result-v1",
            ok: true,
            duplicate: true,
            intervention: safeIntervention(interventionId, data),
            transactionCommitted: false,
          };
        }
        if (existingEvent.exists) {
          throw new CustomsSecurityError("internal", "orphan customs event");
        }
        const profile = await profileSnapshot({
          db,
          profileId: request.protectionProfileId,
          context,
          transaction,
        });
        if (profile.data.status !== "active") {
          throw new CustomsSecurityError("profile.not_active", "active protection profile required");
        }
        const interventionNumber = `SGM-${recordedAt.slice(0, 4)}-${interventionId.slice(0, 8).toUpperCase()}`;
        const base = interventionData(request);
        const data = {
          contractVersion: "customs-border-intervention-v1",
          schemaVersion: "customs-border-intervention-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          interventionNumber,
          status: "draft",
          integrityStatus: hasIntegritySignal(base) ? "integrity_signal_detected" : "no_integrity_signal",
          ...base,
          legalMatterId: null,
          approvedByUid: null,
          requestId: request.requestId,
          requestFingerprint,
          createdByUid: invocation.uid,
          createdAt: recordedAt,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: 1,
          lastEventId: event.id,
          lastEventType: "border_intervention_created",
          lastEventAt: recordedAt,
        };
        transaction.create(interventionRef, data);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "border_intervention",
          entityId: interventionId,
          profileId: request.protectionProfileId,
          interventionId,
          sequence: 1,
          eventType: "border_intervention_created",
          previousStatus: null,
          nextStatus: "draft",
          summary: `${interventionNumber} sınır müdahale dosyası oluşturuldu.`,
          reason: "Sınır müdahale dosyası ilk taslak kaydı.",
          actorUid: invocation.uid,
          recordedAt,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-border-intervention-create-result-v1",
          ok: true,
          duplicate: false,
          intervention: safeIntervention(interventionId, data),
          transactionCommitted: true,
        };
      });
    },

    async updateIntervention(raw, invocation) {
      const request = interventionUpdateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, "border_intervention", request.interventionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const intervention = await interventionSnapshot({
          db,
          interventionId: request.interventionId,
          context,
          transaction,
        });
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-border-intervention-update-result-v1",
            ok: true,
            duplicate: true,
            intervention: safeIntervention(request.interventionId, intervention.data),
            transactionCommitted: false,
          };
        }
        if (intervention.data.status === "archived") {
          throw new CustomsSecurityError("status.precondition_failed", "archived intervention immutable");
        }
        if (intervention.data.protectionProfileId !== request.protectionProfileId) {
          throw new CustomsSecurityError("invalid-argument", "protectionProfileId immutable");
        }
        if (intervention.data.caseId && intervention.data.caseId !== request.caseId) {
          throw new CustomsSecurityError("invalid-argument", "caseId immutable once linked");
        }
        const sequence = Number(intervention.data.eventCount || 0) + 1;
        const base = interventionData(request);
        const updates = {
          ...base,
          integrityStatus: hasIntegritySignal(base) && intervention.data.integrityStatus === "no_integrity_signal" ?
            "integrity_signal_detected" :
            intervention.data.integrityStatus,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "border_intervention_updated",
          lastEventAt: recordedAt,
        };
        transaction.update(intervention.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "border_intervention",
          entityId: request.interventionId,
          profileId: intervention.data.protectionProfileId,
          interventionId: request.interventionId,
          sequence,
          eventType: "border_intervention_updated",
          previousStatus: intervention.data.status,
          nextStatus: intervention.data.status,
          summary: `${intervention.data.interventionNumber} sınır müdahale dosyası güncellendi.`,
          reason: "Yetkili kullanıcı operasyon kayıtlarını güncelledi.",
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: intervention.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-border-intervention-update-result-v1",
          ok: true,
          duplicate: false,
          intervention: safeIntervention(request.interventionId, {...intervention.data, ...updates}),
          transactionCommitted: true,
        };
      });
    },

    async transitionIntervention(raw, invocation) {
      const request = interventionTransitionRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, "border_intervention", request.interventionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const intervention = await interventionSnapshot({
          db,
          interventionId: request.interventionId,
          context,
          transaction,
        });
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-border-intervention-transition-result-v1",
            ok: true,
            duplicate: true,
            intervention: safeIntervention(request.interventionId, intervention.data),
            transactionCommitted: false,
          };
        }
        requireInterventionTransition(intervention.data.status, request.nextStatus, intervention.data, request);
        const sequence = Number(intervention.data.eventCount || 0) + 1;
        const updates = optional({
          status: request.nextStatus,
          statusReason: request.reason,
          statusChangedAt: recordedAt,
          statusChangedByUid: invocation.uid,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "border_intervention_status_transitioned",
          lastEventAt: recordedAt,
        }, {
          decisionReference: request.decisionReference,
          humanAssessmentReference: request.humanAssessmentReference,
          authorityReference: request.authorityReference,
          approvedByUid: ["infringement_confirmed", "destroyed", "released", "referred_to_authority"].includes(request.nextStatus) ? invocation.uid : null,
          detainedAt: request.nextStatus === "temporarily_detained" && !intervention.data.detainedAt ? recordedAt : null,
          destroyedAt: request.nextStatus === "destroyed" ? recordedAt : null,
          releasedAt: request.nextStatus === "released" ? recordedAt : null,
          referredToAuthorityAt: request.nextStatus === "referred_to_authority" ? recordedAt : null,
          closedAt: request.nextStatus === "closed" ? recordedAt : null,
          archivedAt: request.nextStatus === "archived" ? recordedAt : null,
        });
        transaction.update(intervention.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          entityType: "border_intervention",
          entityId: request.interventionId,
          profileId: intervention.data.protectionProfileId,
          interventionId: request.interventionId,
          sequence,
          eventType: "border_intervention_status_transitioned",
          previousStatus: intervention.data.status,
          nextStatus: request.nextStatus,
          summary: `${intervention.data.interventionNumber} dosya durumu ${request.nextStatus} olarak değiştirildi.`,
          reason: request.reason,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: intervention.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-border-intervention-transition-result-v1",
          ok: true,
          duplicate: false,
          intervention: safeIntervention(request.interventionId, {...intervention.data, ...updates}),
          transactionCommitted: true,
        };
      });
    },

    async listInterventions(raw, invocation) {
      const request = interventionListRequest(raw);
      const context = await contextFor(request, invocation, false);
      let query = db.collection(INTERVENTION_COLLECTION)
          .where("tenantId", "==", context.tenantId)
          .where("canonicalBrandId", "==", context.brandId);
      if (request.status) query = query.where("status", "==", request.status);
      if (request.protectionProfileId) {
        query = query.where("protectionProfileId", "==", request.protectionProfileId);
      }
      const records = await boundedQuery(query, "intervention list scope too large");
      const page = paginate(records.map((item) => ({
        id: item.id,
        updatedAt: item.data.updatedAt,
        value: safeIntervention(item.id, item.data),
      })), request);
      return {
        contractVersion: "customs-border-intervention-list-v1",
        items: page.items.map((item) => item.value),
        nextPageToken: page.nextPageToken,
        readOnly: true,
        writesPerformed: 0,
      };
    },

    async interventionDetail(raw, invocation) {
      const request = interventionDetailRequest(raw);
      const context = await contextFor(request, invocation, false);
      const intervention = await interventionSnapshot({
        db,
        interventionId: request.interventionId,
        context,
      });
      const events = await boundedQuery(
          db.collection(EVENT_COLLECTION).where("interventionId", "==", request.interventionId),
          "intervention event scope too large",
      );
      const safeEvents = events
          .filter((item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId)
          .map((item) => safeEvent(item.data))
          .sort((a, b) => a.sequence - b.sequence || String(a.recordedAt).localeCompare(String(b.recordedAt)));
      return {
        contractVersion: "customs-border-intervention-detail-v1",
        intervention: safeIntervention(request.interventionId, intervention.data),
        events: safeEvents,
        integrityStatus: safeEvents.length === Number(intervention.data.eventCount || 0) ? "verified" : "event_count_mismatch",
        readOnly: true,
        writesPerformed: 0,
      };
    },
  });
}

module.exports = {
  EVENT_COLLECTION,
  INTERVENTION_COLLECTION,
  INTERVENTION_TRANSITIONS,
  PROFILE_COLLECTION,
  PROFILE_TRANSITIONS,
  createCustomsSecurityService,
  paginate,
  requireInterventionTransition,
  requireProfileTransition,
  safeEvent,
  safeIntervention,
  safeProfile,
};
