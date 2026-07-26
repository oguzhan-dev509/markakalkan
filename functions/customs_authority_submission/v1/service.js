/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {resolveTenantContextV1} = require("../../risk_operations/v1/service");
const {
  INTERVENTION_COLLECTION,
  PROFILE_COLLECTION,
} = require("../../customs_security/v1/service");
const {
  AuthoritySubmissionError,
  SUBMISSION_STATUSES,
  createRequest,
  detailRequest,
  externalSubmissionRequest,
  fingerprint,
  listRequest,
  packageRequest,
  receiptRequest,
  responseRequest,
  transitionRequest,
  updateRequest,
} = require("./contracts");

const SUBMISSION_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["awaiting_human_review", "archived"]),
  awaiting_human_review: Object.freeze(["draft", "awaiting_rights_holder_approval", "rejected"]),
  awaiting_rights_holder_approval: Object.freeze(["awaiting_human_review", "approved_for_package", "rejected"]),
  approved_for_package: Object.freeze(["package_generated", "awaiting_human_review"]),
  package_generated: Object.freeze(["approved_for_package", "submitted_externally"]),
  submitted_externally: Object.freeze(["receipt_recorded", "authority_review", "withdrawn"]),
  receipt_recorded: Object.freeze(["authority_review", "additional_information_requested", "concluded"]),
  authority_review: Object.freeze(["additional_information_requested", "concluded"]),
  additional_information_requested: Object.freeze(["authority_review", "concluded"]),
  concluded: Object.freeze(["archived"]),
  withdrawn: Object.freeze(["archived"]),
  rejected: Object.freeze(["archived"]),
  archived: Object.freeze([]),
});

const SUBMISSION_COLLECTION = "customs_authority_submissions";
const PACKAGE_COLLECTION = "customs_submission_packages";
const RESPONSE_COLLECTION = "customs_submission_responses";
const EVENT_COLLECTION = "customs_submission_events";
const MAX_SCOPE = 200;
const MAX_SUBMITTED_AT_FUTURE_MS = 5 * 60 * 1000;
const MAX_SUBMITTED_AT_AGE_MS = 10 * 365 * 24 * 60 * 60 * 1000;

const sha256 = (value) => createHash("sha256").update(String(value), "utf8").digest("hex");

function nowIso(clock) {
  const value = clock.now();
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new AuthoritySubmissionError("internal", "clock invalid");
  }
  return date.toISOString();
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
    throw new AuthoritySubmissionError("authorization.denied", "owner required");
  }
}

function scoped(snapshot, context, code) {
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.tenantId !== context.tenantId || data.canonicalBrandId !== context.brandId) {
    throw new AuthoritySubmissionError(code, "record not found");
  }
  return data;
}

function assertFingerprint(existing, expected) {
  if ((existing.requestFingerprint || null) !== expected) {
    throw new AuthoritySubmissionError("idempotency.conflict", "request fingerprint mismatch");
  }
}

function normalizeBusinessValue(value) {
  return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function duplicateCheckKey(context, request) {
  return sha256([
    context.tenantId,
    context.brandId,
    request.submissionType,
    request.targetAuthority,
    request.protectionProfileId || "",
    request.interventionId || "",
    normalizeBusinessValue(request.incidentReference),
  ].join("|"));
}

function eventRef(db, context, submissionId, requestId) {
  const id = sha256(`${context.tenantId}|customs-submission-event|${submissionId}|${requestId}`);
  return {id, ref: db.collection(EVENT_COLLECTION).doc(id)};
}

function packageRef(db, context, submissionId, version) {
  const id = sha256(`${context.tenantId}|customs-submission-package|${submissionId}|${version}`);
  return {id, ref: db.collection(PACKAGE_COLLECTION).doc(id)};
}

function responseRef(db, context, submissionId, requestId) {
  const id = sha256(`${context.tenantId}|customs-submission-response|${submissionId}|${requestId}`);
  return {id, ref: db.collection(RESPONSE_COLLECTION).doc(id)};
}

function eventDocument({
  context,
  submissionId,
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
  return {
    contractVersion: "customs-submission-event-v1",
    schemaVersion: "customs-submission-event-schema-v1",
    tenantId: context.tenantId,
    canonicalBrandId: context.brandId,
    submissionId,
    sequence,
    eventType,
    previousStatus: previousStatus || null,
    nextStatus: nextStatus || null,
    summary,
    reason,
    actorUid,
    actorLabel: "Yetkili kullanıcı",
    recordedAt,
    previousEventId: previousEventId || null,
    requestId,
    requestFingerprint,
    appendOnly: true,
  };
}

function safeSubmission(id, data) {
  return {
    submissionId: id,
    submissionNumber: data.submissionNumber,
    submissionType: data.submissionType,
    targetAuthority: data.targetAuthority,
    targetUnit: data.targetUnit || null,
    channelType: data.channelType || null,
    protectionProfileId: data.protectionProfileId || null,
    interventionId: data.interventionId || null,
    caseId: data.caseId || null,
    legalMatterId: data.legalMatterId || null,
    incidentReference: data.incidentReference,
    title: data.title,
    authoritySummary: data.authoritySummary,
    status: data.status,
    humanReviewReference: data.humanReviewReference || null,
    rightsHolderApprovalReference: data.rightsHolderApprovalReference || null,
    dataMinimizationConfirmed: data.dataMinimizationConfirmed === true,
    nonAccusatoryLanguageConfirmed: data.nonAccusatoryLanguageConfirmed === true,
    duplicateCheckKey: data.duplicateCheckKey,
    currentPackageId: data.currentPackageId || null,
    currentPackageVersion: Number(data.currentPackageVersion || 0),
    currentPackageHash: data.currentPackageHash || null,
    preparedByUid: data.preparedByUid,
    reviewedByUid: data.reviewedByUid || null,
    approvedByUid: data.approvedByUid || null,
    submittedByUid: data.submittedByUid || null,
    submittedAt: data.submittedAt || null,
    externalSubmissionStatement: data.externalSubmissionStatement || null,
    officialReferenceNumber: data.officialReferenceNumber || null,
    receiptRecordedAt: data.receiptRecordedAt || null,
    packageCount: Number(data.packageCount || 0),
    responseCount: Number(data.responseCount || 0),
    eventCount: Number(data.eventCount || 0),
    lastEventType: data.lastEventType || null,
    lastEventAt: data.lastEventAt || null,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  };
}

function safePackage(id, data) {
  return {
    packageId: id,
    submissionId: data.submissionId,
    version: Number(data.version || 0),
    packageType: data.packageType,
    sourceSnapshot: data.sourceSnapshot,
    documentManifest: data.documentManifest || [],
    evidenceManifest: data.evidenceManifest || [],
    redactionManifest: data.redactionManifest || [],
    coverLetterText: data.coverLetterText,
    authoritySummary: data.authoritySummary,
    legalNeutralityStatement: data.legalNeutralityStatement,
    aggregateHashAlgorithm: data.aggregateHashAlgorithm,
    aggregateHash: data.aggregateHash,
    generatedAt: data.generatedAt,
    generatedByUid: data.generatedByUid,
    immutable: data.immutable === true,
  };
}

function safeResponse(id, data) {
  return {
    responseId: id,
    submissionId: data.submissionId,
    responseType: data.responseType,
    authorityReference: data.authorityReference || null,
    receivedAt: data.receivedAt,
    receivedByUid: data.receivedByUid,
    summary: data.summary,
    attachmentReferences: data.attachmentReferences || [],
    attachmentHashes: data.attachmentHashes || [],
    requestedDueAt: data.requestedDueAt || null,
    outcomeCode: data.outcomeCode || null,
    immutable: data.immutable === true,
  };
}

function safeEvent(data) {
  return {
    submissionId: data.submissionId,
    sequence: Number(data.sequence || 0),
    eventType: data.eventType,
    previousStatus: data.previousStatus || null,
    nextStatus: data.nextStatus || null,
    summary: data.summary,
    reason: data.reason,
    actorLabel: data.actorLabel,
    recordedAt: data.recordedAt,
  };
}

function profileSourceSnapshot(id, data) {
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
    authenticationInstructions: data.authenticationInstructions || null,
    serialVerificationMethods: data.serialVerificationMethods || [],
    securityFeatureSummaries: data.securityFeatureSummaries || [],
    counterfeitTwinRecordIds: data.counterfeitTwinRecordIds || [],
    productionAssetIds: data.productionAssetIds || [],
    riskCountryCodes: data.riskCountryCodes || [],
    riskRouteSummaries: data.riskRouteSummaries || [],
    emergencyContactIds: data.emergencyContactIds || [],
    validFrom: data.validFrom || null,
    validUntil: data.validUntil || null,
  };
}

function interventionSourceSnapshot(id, data) {
  return {
    interventionId: id,
    interventionNumber: data.interventionNumber,
    protectionProfileId: data.protectionProfileId,
    status: data.status,
    priority: data.priority,
    sourceType: data.sourceType,
    countryCode: data.countryCode,
    customsAuthorityName: data.customsAuthorityName || null,
    borderPointType: data.borderPointType,
    borderPointName: data.borderPointName,
    shipmentReference: data.shipmentReference || null,
    containerReference: data.containerReference || null,
    cargoReference: data.cargoReference || null,
    trackingReferences: data.trackingReferences || [],
    declaredProductDescription: data.declaredProductDescription,
    declaredHsCode: data.declaredHsCode || null,
    declaredQuantity: data.declaredQuantity ?? null,
    declaredUnit: data.declaredUnit || null,
    suspectedProductIds: data.suspectedProductIds || [],
    counterfeitTwinRecordIds: data.counterfeitTwinRecordIds || [],
    sourceRiskSignalIds: data.sourceRiskSignalIds || [],
    notificationReceivedAt: data.notificationReceivedAt || null,
    responseDeadlineAt: data.responseDeadlineAt || null,
    actionDeadlineAt: data.actionDeadlineAt || null,
    suspicionReasons: data.suspicionReasons || [],
    authenticationResult: data.authenticationResult,
    decisionSummary: data.decisionSummary || null,
    decisionReason: data.decisionReason || null,
    caseId: data.caseId || null,
    legalMatterId: data.legalMatterId || null,
    integrityStatus: data.integrityStatus,
  };
}

async function boundedQuery(query, message) {
  const snapshot = await query.get();
  const docs = snapshot.docs || [];
  if (docs.length > MAX_SCOPE) {
    throw new AuthoritySubmissionError("scope.too_large", message);
  }
  return docs.map((doc) => ({id: doc.id, data: doc.data() || {}}));
}

function paginate(records, request) {
  const sorted = [...records].sort((a, b) => {
    const time = String(b.updatedAt || "").localeCompare(String(a.updatedAt || ""));
    return time || String(a.id).localeCompare(String(b.id));
  });
  const start = request.pageToken ? sorted.findIndex((item) => item.id === request.pageToken) + 1 : 0;
  const safeStart = start < 0 ? 0 : start;
  const items = sorted.slice(safeStart, safeStart + request.pageSize);
  const nextPageToken = safeStart + request.pageSize < sorted.length ? items.at(-1)?.id || null : null;
  return {items, nextPageToken};
}

async function sourceSnapshots({db, context, request, transaction = null}) {
  const result = {};
  let profileData = null;
  let interventionData = null;
  if (request.protectionProfileId) {
    const ref = db.collection(PROFILE_COLLECTION).doc(request.protectionProfileId);
    const snapshot = transaction ? await transaction.get(ref) : await ref.get();
    profileData = scoped(snapshot, context, "profile.not_found");
    result.profile = profileSourceSnapshot(request.protectionProfileId, profileData);
  }
  if (request.interventionId) {
    const ref = db.collection(INTERVENTION_COLLECTION).doc(request.interventionId);
    const snapshot = transaction ? await transaction.get(ref) : await ref.get();
    interventionData = scoped(snapshot, context, "intervention.not_found");
    result.intervention = interventionSourceSnapshot(request.interventionId, interventionData);
    if (request.protectionProfileId && interventionData.protectionProfileId !== request.protectionProfileId) {
      throw new AuthoritySubmissionError("source.mismatch", "profile and intervention mismatch");
    }
  }
  if (request.submissionType === "fsmh_protection_application") {
    if (!profileData || profileData.status !== "active") {
      throw new AuthoritySubmissionError("source.precondition_failed", "active protection profile required");
    }
  }
  if (request.submissionType === "customs_smuggling_notification" && !interventionData) {
    throw new AuthoritySubmissionError("source.precondition_failed", "border intervention required");
  }
  return result;
}

function requireTransition(current, next, data, request) {
  if (!SUBMISSION_STATUSES.includes(current) || !SUBMISSION_STATUSES.includes(next) || !SUBMISSION_TRANSITIONS[current].includes(next)) {
    throw new AuthoritySubmissionError("status.invalid_transition", "submission transition invalid");
  }
  if (next === "package_generated") {
    throw new AuthoritySubmissionError("status.precondition_failed", "generate package operation required");
  }
  if (next === "receipt_recorded") {
    throw new AuthoritySubmissionError("status.precondition_failed", "record receipt operation required");
  }
  if (next === "awaiting_rights_holder_approval" && !data.humanReviewReference) {
    throw new AuthoritySubmissionError("status.precondition_failed", "human review required");
  }
  if (next === "approved_for_package") {
    if (!data.humanReviewReference || !data.rightsHolderApprovalReference) {
      throw new AuthoritySubmissionError("status.precondition_failed", "human and rights holder approval required");
    }
    if (!data.dataMinimizationConfirmed || !data.nonAccusatoryLanguageConfirmed) {
      throw new AuthoritySubmissionError("status.precondition_failed", "data minimization and legal neutrality required");
    }
  }
  if (next === "submitted_externally") {
    throw new AuthoritySubmissionError(
        "status.precondition_failed",
        "record external submission operation required",
    );
  }
  if (next === "concluded" && !data.officialReferenceNumber) {
    throw new AuthoritySubmissionError("status.precondition_failed", "official reference required");
  }
}

function createAuthoritySubmissionService({
  db,
  clock = {now: () => new Date().toISOString()},
  resolveContext = resolveTenantContextV1,
}) {
  async function contextFor(request, invocation, owner = false) {
    if (!invocation?.uid) {
      throw new AuthoritySubmissionError("unauthenticated", "authentication required");
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

  async function submissionSnapshot({submissionId, context, transaction = null}) {
    const ref = db.collection(SUBMISSION_COLLECTION).doc(submissionId);
    const snapshot = transaction ? await transaction.get(ref) : await ref.get();
    return {ref, data: scoped(snapshot, context, "submission.not_found")};
  }

  return Object.freeze({
    async createSubmission(raw, invocation) {
      const request = createRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const businessKey = duplicateCheckKey(context, request);
      const submissionId = sha256(`${context.tenantId}|${context.brandId}|customs-authority-submission|${businessKey}`);
      const submissionRef = db.collection(SUBMISSION_COLLECTION).doc(submissionId);
      const event = eventRef(db, context, submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const [existing, existingEvent] = await Promise.all([
          transaction.get(submissionRef),
          transaction.get(event.ref),
        ]);
        if (existing.exists) {
          const data = scoped(existing, context, "submission.not_found");
          assertFingerprint(data, requestFingerprint);
          if (existingEvent.exists) assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-authority-submission-create-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(submissionId, data),
            transactionCommitted: false,
          };
        }
        if (existingEvent.exists) {
          throw new AuthoritySubmissionError("internal", "orphan submission event");
        }
        await sourceSnapshots({db, context, request, transaction});
        const submissionNumber = `KRI-${recordedAt.slice(0, 4)}-${submissionId.slice(0, 8).toUpperCase()}`;
        const data = optional({
          contractVersion: "customs-authority-submission-v1",
          schemaVersion: "customs-authority-submission-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          submissionNumber,
          submissionType: request.submissionType,
          targetAuthority: request.targetAuthority,
          protectionProfileId: request.protectionProfileId || null,
          interventionId: request.interventionId || null,
          caseId: request.caseId || null,
          legalMatterId: request.legalMatterId || null,
          incidentReference: request.incidentReference,
          title: request.title,
          authoritySummary: request.authoritySummary,
          status: "draft",
          dataMinimizationConfirmed: request.dataMinimizationConfirmed,
          nonAccusatoryLanguageConfirmed: request.nonAccusatoryLanguageConfirmed,
          duplicateCheckKey: businessKey,
          duplicateCheckStatus: "unique",
          preparedByUid: invocation.uid,
          packageCount: 0,
          responseCount: 0,
          eventCount: 1,
          lastEventId: event.id,
          lastEventType: "authority_submission_created",
          lastEventAt: recordedAt,
          requestId: request.requestId,
          requestFingerprint,
          createdByUid: invocation.uid,
          createdAt: recordedAt,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
        }, {
          targetUnit: request.targetUnit,
          channelType: request.channelType,
          humanReviewReference: request.humanReviewReference,
          rightsHolderApprovalReference: request.rightsHolderApprovalReference,
        });
        transaction.create(submissionRef, data);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId,
          sequence: 1,
          eventType: "authority_submission_created",
          previousStatus: null,
          nextStatus: "draft",
          summary: `${submissionNumber} resmî iletim taslağı oluşturuldu.`,
          reason: "İlk taslak kaydı.",
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-authority-submission-create-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(submissionId, data),
          transactionCommitted: true,
        };
      });
    },

    async updateSubmission(raw, invocation) {
      const request = updateRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, request.submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({submissionId: request.submissionId, context, transaction});
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-authority-submission-update-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(request.submissionId, submission.data),
            transactionCommitted: false,
          };
        }
        if (!["draft", "awaiting_human_review", "awaiting_rights_holder_approval"].includes(submission.data.status)) {
          throw new AuthoritySubmissionError("status.precondition_failed", "submission no longer editable");
        }
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const updates = optional({
          title: request.title,
          authoritySummary: request.authoritySummary,
          dataMinimizationConfirmed: request.dataMinimizationConfirmed,
          nonAccusatoryLanguageConfirmed: request.nonAccusatoryLanguageConfirmed,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "authority_submission_updated",
          lastEventAt: recordedAt,
        }, {
          targetUnit: request.targetUnit,
          channelType: request.channelType,
          humanReviewReference: request.humanReviewReference,
          rightsHolderApprovalReference: request.rightsHolderApprovalReference,
        });
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType: "authority_submission_updated",
          previousStatus: submission.data.status,
          nextStatus: submission.data.status,
          summary: `${submission.data.submissionNumber} resmî iletim taslağı güncellendi.`,
          reason: "Yetkili kullanıcı güncellemesi.",
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-authority-submission-update-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(request.submissionId, {...submission.data, ...updates}),
          transactionCommitted: true,
        };
      });
    },

    async transitionSubmission(raw, invocation) {
      const request = transitionRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, request.submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({submissionId: request.submissionId, context, transaction});
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-authority-submission-transition-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(request.submissionId, submission.data),
            transactionCommitted: false,
          };
        }
        requireTransition(submission.data.status, request.nextStatus, submission.data, request);
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const updates = optional({
          status: request.nextStatus,
          statusReason: request.reason,
          statusChangedAt: recordedAt,
          statusChangedByUid: invocation.uid,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "authority_submission_status_transitioned",
          lastEventAt: recordedAt,
        }, {
          reviewedByUid: request.nextStatus === "awaiting_rights_holder_approval" ? invocation.uid : null,
          approvedByUid: request.nextStatus === "approved_for_package" ? invocation.uid : null,
          submittedByUid: request.nextStatus === "submitted_externally" ? invocation.uid : null,
          submittedAt: request.nextStatus === "submitted_externally" ? request.submittedAt : null,
          externalSubmissionStatement: request.nextStatus === "submitted_externally" ? request.externalSubmissionStatement : null,
          concludedAt: request.nextStatus === "concluded" ? recordedAt : null,
          withdrawnAt: request.nextStatus === "withdrawn" ? recordedAt : null,
          rejectedAt: request.nextStatus === "rejected" ? recordedAt : null,
          archivedAt: request.nextStatus === "archived" ? recordedAt : null,
        });
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType: "authority_submission_status_transitioned",
          previousStatus: submission.data.status,
          nextStatus: request.nextStatus,
          summary: `${submission.data.submissionNumber} iletim durumu ${request.nextStatus} olarak değiştirildi.`,
          reason: request.reason,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-authority-submission-transition-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(request.submissionId, {...submission.data, ...updates}),
          transactionCommitted: true,
        };
      });
    },

    async generatePackage(raw, invocation) {
      const request = packageRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, request.submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({submissionId: request.submissionId, context, transaction});
        const existingEvent = await transaction.get(event.ref);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          const current = await transaction.get(db.collection(PACKAGE_COLLECTION).doc(submission.data.currentPackageId));
          if (!current.exists) throw new AuthoritySubmissionError("internal", "package missing");
          return {
            contractVersion: "customs-submission-package-generate-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(request.submissionId, submission.data),
            package: safePackage(current.id, current.data() || {}),
            transactionCommitted: false,
          };
        }
        if (submission.data.status !== "approved_for_package") {
          throw new AuthoritySubmissionError("status.precondition_failed", "submission not approved for package");
        }
        if (!submission.data.humanReviewReference || !submission.data.rightsHolderApprovalReference || !submission.data.dataMinimizationConfirmed || !submission.data.nonAccusatoryLanguageConfirmed) {
          throw new AuthoritySubmissionError("status.precondition_failed", "package approval gates incomplete");
        }
        const sources = await sourceSnapshots({
          db,
          context,
          request: {
            submissionType: submission.data.submissionType,
            protectionProfileId: submission.data.protectionProfileId,
            interventionId: submission.data.interventionId,
          },
          transaction,
        });
        const version = Number(submission.data.currentPackageVersion || 0) + 1;
        const packageDocument = {
          contractVersion: "customs-submission-package-v1",
          schemaVersion: "customs-submission-package-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          submissionId: request.submissionId,
          version,
          packageType: request.packageType,
          sourceSnapshot: sources,
          documentManifest: request.documentManifest,
          evidenceManifest: request.evidenceManifest,
          redactionManifest: request.redactionManifest,
          coverLetterText: request.coverLetterText,
          authoritySummary: request.authoritySummary,
          legalNeutralityStatement: request.legalNeutralityStatement,
          aggregateHashAlgorithm: "SHA-256",
          generatedAt: recordedAt,
          generatedByUid: invocation.uid,
          immutable: true,
          requestId: request.requestId,
          requestFingerprint,
        };
        packageDocument.aggregateHash = fingerprint(packageDocument);
        const packageRecord = packageRef(db, context, request.submissionId, version);
        const existingPackage = await transaction.get(packageRecord.ref);
        if (existingPackage.exists) {
          throw new AuthoritySubmissionError("internal", "package version conflict");
        }
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const updates = {
          status: "package_generated",
          currentPackageId: packageRecord.id,
          currentPackageVersion: version,
          currentPackageHash: packageDocument.aggregateHash,
          packageCount: Number(submission.data.packageCount || 0) + 1,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "submission_package_generated",
          lastEventAt: recordedAt,
        };
        transaction.create(packageRecord.ref, packageDocument);
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType: "submission_package_generated",
          previousStatus: submission.data.status,
          nextStatus: "package_generated",
          summary: `${submission.data.submissionNumber} için ${version}. paket üretildi.`,
          reason: "İnsan onaylı resmî iletim paketi üretimi.",
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-submission-package-generate-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(request.submissionId, {...submission.data, ...updates}),
          package: safePackage(packageRecord.id, packageDocument),
          transactionCommitted: true,
        };
      });
    },

    async recordExternalSubmission(raw, invocation) {
      const request = externalSubmissionRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const recordedAtMs = new Date(recordedAt).getTime();
      const submittedAtMs = new Date(request.submittedAt).getTime();
      if (submittedAtMs > recordedAtMs + MAX_SUBMITTED_AT_FUTURE_MS ||
          submittedAtMs < recordedAtMs - MAX_SUBMITTED_AT_AGE_MS) {
        throw new AuthoritySubmissionError(
            "status.precondition_failed",
            "submittedAt outside accepted range",
        );
      }
      const requestFingerprint = fingerprint(request);
      const event = eventRef(
          db,
          context,
          request.submissionId,
          request.requestId,
      );
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({
          submissionId: request.submissionId,
          context,
          transaction,
        });
        const packageRecord = db.collection(PACKAGE_COLLECTION)
            .doc(request.packageId);
        const [existingEvent, packageSnapshot] = await Promise.all([
          transaction.get(event.ref),
          transaction.get(packageRecord),
        ]);
        if (existingEvent.exists) {
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          const duplicatePackageData = scoped(
              packageSnapshot,
              context,
              "package.not_found",
          );
          const existingSnapshot = submission.data.externalSubmission || {};
          if (submission.data.status !== "submitted_externally" ||
              existingSnapshot.requestId !== request.requestId ||
              existingSnapshot.submissionChannel !==
                request.submissionChannel ||
              existingSnapshot.submittedAt !== request.submittedAt ||
              existingSnapshot.externalSubmissionConfirmation !== true ||
              existingSnapshot.externalSubmissionConfirmationVersion !==
                request.externalSubmissionConfirmationVersion ||
              existingSnapshot.externalSubmissionStatement !==
                request.externalSubmissionStatement ||
              existingSnapshot.externalReferenceType !==
                request.externalReferenceType ||
              (existingSnapshot.externalReferenceValue || null) !==
                request.externalReferenceValue ||
              existingSnapshot.packageId !== request.packageId ||
              Number(existingSnapshot.packageVersion || 0) !==
                request.packageVersion ||
              existingSnapshot.packageHash !== request.packageHash ||
              submission.data.lastEventId !== event.id ||
              duplicatePackageData.immutable !== true ||
              duplicatePackageData.submissionId !== request.submissionId ||
              Number(duplicatePackageData.version || 0) !==
                request.packageVersion ||
              duplicatePackageData.aggregateHash !== request.packageHash) {
            throw new AuthoritySubmissionError(
                "internal",
                "inconsistent external submission duplicate",
            );
          }
          return {
            contractVersion:
              "customs-external-submission-record-result-v1",
            ok: true,
            duplicate: true,
            transactionApplied: false,
            submission: safeSubmission(request.submissionId, submission.data),
            event: safeEvent(existingEvent.data() || {}),
          };
        }
        if (submission.data.status !== "package_generated") {
          throw new AuthoritySubmissionError(
              "status.precondition_failed",
              "submission package is not ready",
          );
        }
        if (submission.data.currentPackageId !== request.packageId ||
            Number(submission.data.currentPackageVersion || 0) !==
              request.packageVersion ||
            submission.data.currentPackageHash !== request.packageHash) {
          throw new AuthoritySubmissionError(
              "status.precondition_failed",
              "active package mismatch",
          );
        }
        const packageData = scoped(
            packageSnapshot,
            context,
            "package.not_found",
        );
        if (packageData.immutable !== true ||
            packageData.submissionId !== request.submissionId ||
            Number(packageData.version || 0) !== request.packageVersion ||
            packageData.aggregateHash !== request.packageHash) {
          throw new AuthoritySubmissionError(
              "status.precondition_failed",
              "package integrity mismatch",
          );
        }
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const snapshot = {
          submissionChannel: request.submissionChannel,
          submittedAt: request.submittedAt,
          submittedByUid: invocation.uid,
          externalSubmissionConfirmation: true,
          externalSubmissionConfirmationVersion:
            request.externalSubmissionConfirmationVersion,
          externalSubmissionStatement: request.externalSubmissionStatement,
          externalReferenceType: request.externalReferenceType,
          externalReferenceValue: request.externalReferenceValue,
          packageId: request.packageId,
          packageVersion: request.packageVersion,
          packageHash: request.packageHash,
          recordedAt,
          requestId: request.requestId,
        };
        const updates = {
          status: "submitted_externally",
          channelType: request.submissionChannel,
          submittedAt: request.submittedAt,
          submittedByUid: invocation.uid,
          externalSubmissionStatement: request.externalSubmissionStatement,
          externalSubmission: snapshot,
          statusReason: "Dış kanalda tamamlanan resmî gönderim kaydedildi.",
          statusChangedAt: recordedAt,
          statusChangedByUid: invocation.uid,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType:
            "customs_submission_recorded_as_submitted_externally",
          lastEventAt: recordedAt,
        };
        const eventData = eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType:
            "customs_submission_recorded_as_submitted_externally",
          previousStatus: submission.data.status,
          nextStatus: "submitted_externally",
          summary: `${submission.data.submissionNumber} dış kanalda gönderilmiş olarak kaydedildi.`,
          reason: request.externalSubmissionStatement,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        });
        eventData.externalSubmission = snapshot;
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventData);
        return {
          contractVersion: "customs-external-submission-record-result-v1",
          ok: true,
          duplicate: false,
          transactionApplied: true,
          submission: safeSubmission(
              request.submissionId,
              {...submission.data, ...updates},
          ),
          event: safeEvent(eventData),
        };
      });
    },

    async recordReceipt(raw, invocation) {
      const request = receiptRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, request.submissionId, request.requestId);
      const response = responseRef(db, context, request.submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({submissionId: request.submissionId, context, transaction});
        const [existingEvent, existingResponse] = await Promise.all([
          transaction.get(event.ref),
          transaction.get(response.ref),
        ]);
        if (existingEvent.exists || existingResponse.exists) {
          if (!existingEvent.exists || !existingResponse.exists) {
            throw new AuthoritySubmissionError("internal", "partial receipt record");
          }
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          assertFingerprint(existingResponse.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-submission-receipt-record-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(request.submissionId, submission.data),
            response: safeResponse(response.id, existingResponse.data() || {}),
            transactionCommitted: false,
          };
        }
        if (!SUBMISSION_TRANSITIONS[submission.data.status]?.includes("receipt_recorded")) {
          throw new AuthoritySubmissionError("status.invalid_transition", "receipt cannot be recorded");
        }
        const responseDocument = optional({
          contractVersion: "customs-submission-response-v1",
          schemaVersion: "customs-submission-response-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          submissionId: request.submissionId,
          responseType: "receipt",
          authorityReference: request.officialReferenceNumber,
          receivedAt: request.receivedAt,
          receivedByUid: invocation.uid,
          summary: request.summary,
          attachmentReferences: request.receiptDocumentReference ? [request.receiptDocumentReference] : [],
          attachmentHashes: request.receiptDocumentHash ? [request.receiptDocumentHash] : [],
          immutable: true,
          requestId: request.requestId,
          requestFingerprint,
        }, {});
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const updates = {
          status: "receipt_recorded",
          officialReferenceNumber: request.officialReferenceNumber,
          receiptRecordedAt: request.receivedAt,
          channelType: request.channelType,
          responseCount: Number(submission.data.responseCount || 0) + 1,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "submission_receipt_recorded",
          lastEventAt: recordedAt,
        };
        transaction.create(response.ref, responseDocument);
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType: "submission_receipt_recorded",
          previousStatus: submission.data.status,
          nextStatus: "receipt_recorded",
          summary: `${submission.data.submissionNumber} teslim alındı kaydı işlendi.`,
          reason: request.summary,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-submission-receipt-record-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(request.submissionId, {...submission.data, ...updates}),
          response: safeResponse(response.id, responseDocument),
          transactionCommitted: true,
        };
      });
    },

    async appendResponse(raw, invocation) {
      const request = responseRequest(raw);
      const context = await contextFor(request, invocation, true);
      const recordedAt = nowIso(clock);
      const requestFingerprint = fingerprint(request);
      const event = eventRef(db, context, request.submissionId, request.requestId);
      const response = responseRef(db, context, request.submissionId, request.requestId);
      return db.runTransaction(async (transaction) => {
        const submission = await submissionSnapshot({submissionId: request.submissionId, context, transaction});
        const [existingEvent, existingResponse] = await Promise.all([
          transaction.get(event.ref),
          transaction.get(response.ref),
        ]);
        if (existingEvent.exists || existingResponse.exists) {
          if (!existingEvent.exists || !existingResponse.exists) {
            throw new AuthoritySubmissionError("internal", "partial authority response");
          }
          assertFingerprint(existingEvent.data() || {}, requestFingerprint);
          assertFingerprint(existingResponse.data() || {}, requestFingerprint);
          return {
            contractVersion: "customs-authority-response-append-result-v1",
            ok: true,
            duplicate: true,
            submission: safeSubmission(request.submissionId, submission.data),
            response: safeResponse(response.id, existingResponse.data() || {}),
            transactionCommitted: false,
          };
        }
        if (!["submitted_externally", "receipt_recorded", "authority_review", "additional_information_requested"].includes(submission.data.status)) {
          throw new AuthoritySubmissionError("status.precondition_failed", "authority response not allowed");
        }
        if (request.responseType === "receipt") {
          throw new AuthoritySubmissionError("invalid-argument", "use record receipt operation");
        }
        const responseDocument = optional({
          contractVersion: "customs-submission-response-v1",
          schemaVersion: "customs-submission-response-schema-v1",
          tenantId: context.tenantId,
          canonicalBrandId: context.brandId,
          submissionId: request.submissionId,
          responseType: request.responseType,
          receivedAt: request.receivedAt,
          receivedByUid: invocation.uid,
          summary: request.summary,
          attachmentReferences: request.attachmentReferences,
          attachmentHashes: request.attachmentHashes,
          immutable: true,
          requestId: request.requestId,
          requestFingerprint,
        }, {
          authorityReference: request.authorityReference,
          requestedDueAt: request.requestedDueAt,
          outcomeCode: request.outcomeCode,
        });
        const nextStatus = request.responseType === "information_request" ? "additional_information_requested" : submission.data.status;
        const sequence = Number(submission.data.eventCount || 0) + 1;
        const updates = {
          status: nextStatus,
          responseCount: Number(submission.data.responseCount || 0) + 1,
          updatedByUid: invocation.uid,
          updatedAt: recordedAt,
          eventCount: sequence,
          lastEventId: event.id,
          lastEventType: "authority_response_appended",
          lastEventAt: recordedAt,
        };
        transaction.create(response.ref, responseDocument);
        transaction.update(submission.ref, updates);
        transaction.create(event.ref, eventDocument({
          context,
          submissionId: request.submissionId,
          sequence,
          eventType: "authority_response_appended",
          previousStatus: submission.data.status,
          nextStatus,
          summary: `${submission.data.submissionNumber} için kurum cevabı kaydedildi.`,
          reason: request.summary,
          actorUid: invocation.uid,
          recordedAt,
          previousEventId: submission.data.lastEventId || null,
          requestId: request.requestId,
          requestFingerprint,
        }));
        return {
          contractVersion: "customs-authority-response-append-result-v1",
          ok: true,
          duplicate: false,
          submission: safeSubmission(request.submissionId, {...submission.data, ...updates}),
          response: safeResponse(response.id, responseDocument),
          transactionCommitted: true,
        };
      });
    },

    async listSubmissions(raw, invocation) {
      const request = listRequest(raw);
      const context = await contextFor(request, invocation, false);
      let query = db.collection(SUBMISSION_COLLECTION)
          .where("tenantId", "==", context.tenantId)
          .where("canonicalBrandId", "==", context.brandId);
      if (request.status) query = query.where("status", "==", request.status);
      if (request.targetAuthority) query = query.where("targetAuthority", "==", request.targetAuthority);
      const records = await boundedQuery(query, "authority submission list scope too large");
      const page = paginate(records.map((item) => ({
        id: item.id,
        updatedAt: item.data.updatedAt,
        value: safeSubmission(item.id, item.data),
      })), request);
      return {
        contractVersion: "customs-authority-submission-list-v1",
        items: page.items.map((item) => item.value),
        nextPageToken: page.nextPageToken,
        readOnly: true,
        writesPerformed: 0,
      };
    },

    async submissionDetail(raw, invocation) {
      const request = detailRequest(raw);
      const context = await contextFor(request, invocation, false);
      const submission = await submissionSnapshot({submissionId: request.submissionId, context});
      const [events, packages, responses] = await Promise.all([
        boundedQuery(db.collection(EVENT_COLLECTION).where("submissionId", "==", request.submissionId), "submission event scope too large"),
        boundedQuery(db.collection(PACKAGE_COLLECTION).where("submissionId", "==", request.submissionId), "submission package scope too large"),
        boundedQuery(db.collection(RESPONSE_COLLECTION).where("submissionId", "==", request.submissionId), "submission response scope too large"),
      ]);
      const safeEvents = events
          .filter((item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId)
          .map((item) => safeEvent(item.data))
          .sort((a, b) => a.sequence - b.sequence || String(a.recordedAt).localeCompare(String(b.recordedAt)));
      const safePackages = packages
          .filter((item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId)
          .map((item) => safePackage(item.id, item.data))
          .sort((a, b) => a.version - b.version);
      const safeResponses = responses
          .filter((item) => item.data.tenantId === context.tenantId && item.data.canonicalBrandId === context.brandId)
          .map((item) => safeResponse(item.id, item.data))
          .sort((a, b) => String(a.receivedAt).localeCompare(String(b.receivedAt)));
      const currentPackage = safePackages.find((item) => item.packageId === submission.data.currentPackageId) || null;
      const integrityStatus = safeEvents.length === Number(submission.data.eventCount || 0) &&
          safePackages.length === Number(submission.data.packageCount || 0) &&
          safeResponses.length === Number(submission.data.responseCount || 0) &&
          (!submission.data.currentPackageId || currentPackage?.aggregateHash === submission.data.currentPackageHash) ?
        "verified" : "record_count_or_hash_mismatch";
      return {
        contractVersion: "customs-authority-submission-detail-v1",
        submission: safeSubmission(request.submissionId, submission.data),
        packages: safePackages,
        responses: safeResponses,
        events: safeEvents,
        integrityStatus,
        readOnly: true,
        writesPerformed: 0,
      };
    },
  });
}

module.exports = {
  EVENT_COLLECTION,
  PACKAGE_COLLECTION,
  RESPONSE_COLLECTION,
  SUBMISSION_COLLECTION,
  SUBMISSION_TRANSITIONS,
  createAuthoritySubmissionService,
  duplicateCheckKey,
  paginate,
  requireTransition,
  safeEvent,
  safePackage,
  safeResponse,
  safeSubmission,
  MAX_SUBMITTED_AT_AGE_MS,
  MAX_SUBMITTED_AT_FUTURE_MS,
};
