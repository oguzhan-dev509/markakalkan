"use strict";

const contracts = require("../contracts");
const profiles = require("../verification_profiles");
const custody = require("../chain_of_custody");
const adjudication = require("../adjudication");
const {
  assertTenantMatch,
  assertActionAuthorized,
  assertAssignedLaboratory,
} = require("./authorization");

function fail(code, message) {
  const error = new Error(message || code);
  error.code = code;
  throw error;
}

function requireOperationId(data) {
  if (!data || typeof data.operationId !== "string" || !data.operationId) {
    fail("invalid-argument", "operationId required");
  }
  return data.operationId;
}

function requireString(value, name) {
  if (typeof value !== "string" || !value) {
    fail("invalid-argument", `${name} required`);
  }
  return value;
}

function auditEventId(operationId, suffix) {
  return contracts.deriveDeterministicId("odla-audit-event-v1", [
    operationId,
    suffix,
  ]);
}

function trustedAuditContext(authority, data, operationId, action) {
  return Object.freeze({
    auditEventId: auditEventId(operationId, action),
    caseId: requireString(data.caseId, "caseId"),
    operationId,
    actorUid: authority.uid,
    tenantId: requireString(data.tenantId, "tenantId"),
    brandUid: requireString(data.brandUid, "brandUid"),
    action,
    source: "odla_server_trusted_context",
  });
}

function custodyEventHashPayload(event) {
  return {
    contractVersion: event.contractVersion,
    tenantId: event.tenantId,
    brandUid: event.brandUid,
    caseId: event.caseId,
    sampleId: event.sampleId,
    eventSequence: event.eventSequence,
    eventType: event.eventType,
    occurredAt: event.occurredAt,
    recordedAt: event.recordedAt,
    actorType: event.actorType,
    actorId: event.actorId,
    locationCode: event.locationCode,
    sealId: event.sealId ?? null,
    previousEventId: event.previousEventId ?? null,
    previousEventPayloadSha256: event.previousEventPayloadSha256 ?? null,
    evidenceRefs: Array.isArray(event.evidenceRefs) ?
      [...event.evidenceRefs] :
      [],
    appendOnly: event.appendOnly,
    eventId: event.eventId,
  };
}

function assertStoredCustodyEventSelfHash(event) {
  const expected = contracts.sha256Hex(
      contracts.canonicalJson(custodyEventHashPayload(event)),
  );
  if (expected !== event.eventPayloadSha256) {
    fail("failed-precondition", "CUSTODY_PREDECESSOR_SELF_HASH_MISMATCH");
  }
  return true;
}

function assertTrustedProfileDocument(profile) {
  if (!profile || profile.status !== "active") {
    fail("failed-precondition", "VERIFICATION_PROFILE_NOT_ACTIVE");
  }
  for (const field of ["profileId", "profileCode", "productClassCode"]) {
    requireString(profile[field], field);
  }
  if (
    !Number.isInteger(profile.profileVersion) ||
    profile.profileVersion < 1
  ) {
    fail("failed-precondition", "VERIFICATION_PROFILE_VERSION_INVALID");
  }
  if (
    !profile.jurisdictionOverrides ||
    typeof profile.jurisdictionOverrides !== "object" ||
    Array.isArray(profile.jurisdictionOverrides)
  ) {
    fail(
        "failed-precondition",
        "VERIFICATION_PROFILE_JURISDICTIONS_MISSING",
    );
  }
  return profile;
}

async function resolveTrustedPolicy(adapter, profileId, countryCode) {
  requireString(profileId, "profileId");
  requireString(countryCode, "countryCode");
  const profile = assertTrustedProfileDocument(
      await adapter.getVerificationProfile(profileId),
  );
  const jurisdictionOverride = profile.jurisdictionOverrides[countryCode];
  const resolution = profiles.resolveVerificationPolicy({
    productClassCode: profile.productClassCode,
    countryCode,
    jurisdictionOverride,
  });
  if (!resolution.ok) fail("failed-precondition", resolution.code);
  if (
    profile.profileCode !== resolution.profile.profileCode ||
    profile.profileVersion !== resolution.profile.profileVersion
  ) {
    fail("failed-precondition", "TRUSTED_PROFILE_CORE_BINDING_MISMATCH");
  }
  return Object.freeze({profile, resolution});
}

function assertCaseScope(authority, workspace, data) {
  if (!workspace || !workspace.case) {
    fail("not-found", "ODLA verification case not found");
  }
  assertTenantMatch(authority, workspace.case);
  if (data.tenantId && workspace.case.tenantId !== data.tenantId) {
    fail("permission-denied", "Cross-tenant ODLA case mismatch");
  }
  if (data.brandUid && workspace.case.brandUid !== data.brandUid) {
    fail("permission-denied", "Cross-brand ODLA case mismatch");
  }
  return workspace.case;
}

function createOdlaWorkspaceService({adapter}) {
  if (!adapter || typeof adapter !== "object") {
    fail("failed-precondition", "ODLA persistence adapter required");
  }

  async function createOdlaVerificationCase({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "create_case");
    const operationId = requireOperationId(data);
    const trusted = await resolveTrustedPolicy(
        adapter,
        data.profileId,
        data.countryCode,
    );
    const caseRecord = contracts.validateVerificationCase({
      caseId: data.caseId,
      tenantId: data.tenantId,
      brandUid: data.brandUid,
      profileId: trusted.profile.profileId,
      profileCode: trusted.resolution.profile.profileCode,
      profileVersion: trusted.resolution.profile.profileVersion,
      productClassCode: trusted.resolution.profile.productClassCode,
      countryCode: data.countryCode,
      policyFingerprint: trusted.resolution.policyFingerprint,
      state: "opened",
    });
    const result = await adapter.createCase({
      caseRecord,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          data,
          operationId,
          "create_case",
      ),
    });
    return Object.freeze({
      case: result.data,
      idempotent: result.idempotent,
    });
  }

  async function getOdlaVerificationWorkspace({authority, data}) {
    assertActionAuthorized(authority, "read_workspace");
    const caseId = typeof data.caseId === "string" ? data.caseId.trim() : "";
    if (!caseId) {
      const cases = await adapter.listCasesForAuthority({
        tenantId: authority.tenantId,
        brandUids: authority.brandUids,
        limit: 100,
      });
      return Object.freeze({
        contractVersion: "odla-workspace-discovery-v1",
        mode: "discovery",
        tenantId: authority.tenantId,
        brandUids: Object.freeze([...(authority.brandUids || [])]),
        roles: Object.freeze([...(authority.roles || [])]),
        count: cases.length,
        cases: Object.freeze(cases),
      });
    }
    assertTenantMatch(authority, data);
    const workspace = await adapter.getWorkspace(caseId);
    assertCaseScope(authority, workspace, data);
    const operational =
      await adapter.getOperationalWorkspaceDetails(caseId);
    return Object.freeze({
      contractVersion: "odla-workspace-detail-v1",
      mode: "detail",
      case: workspace.case,
      custodyEvents: operational.custodyEvents,
      testRequests: operational.testRequests,
      testResults: operational.testResults,
      findings: operational.findings,
      appeals: operational.appeals,
    });
  }

  async function appendOdlaChainOfCustodyEvent({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "append_custody");
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    assertCaseScope(authority, workspace, data);
    const previous = await adapter.getLatestCustodyEvent(data.caseId);
    if (previous) assertStoredCustodyEventSelfHash(previous);
    const event = custody.buildCustodyEvent({
      tenantId: workspace.case.tenantId,
      brandUid: workspace.case.brandUid,
      caseId: data.caseId,
      sampleId: data.sampleId,
      eventSequence: data.eventSequence,
      eventType: data.eventType,
      occurredAt: data.occurredAt,
      recordedAt: data.recordedAt,
      actorType: data.actorType,
      actorId: authority.uid,
      locationCode: data.locationCode,
      sealId: data.sealId ?? null,
      previousEventId: previous ? previous.eventId : null,
      previousEventPayloadSha256: previous ?
        previous.eventPayloadSha256 :
        null,
      evidenceRefs: data.evidenceRefs,
    });
    const check = previous ?
      custody.validateCustodyAppend(previous, event, {
        transportEvidenceRequired:
            data.transportEvidenceRequired === true,
      }) :
      custody.validateCustodyGenesis(event);
    if (!check.ok) fail("failed-precondition", check.code);
    return adapter.appendCustodyEvent({
      event,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: workspace.case.tenantId,
            brandUid: workspace.case.brandUid,
          },
          operationId,
          "append_custody",
      ),
    });
  }

  async function createOdlaTestRequest({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "create_test_request");
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    const caseRecord = assertCaseScope(authority, workspace, data);
    const trusted = await resolveTrustedPolicy(
        adapter,
        caseRecord.profileId,
        caseRecord.countryCode,
    );
    if (
      caseRecord.profileCode !== trusted.resolution.profile.profileCode ||
      caseRecord.profileVersion !==
        trusted.resolution.profile.profileVersion ||
      caseRecord.productClassCode !==
        trusted.resolution.profile.productClassCode
    ) {
      fail("failed-precondition", "CASE_TRUSTED_PROFILE_BINDING_MISMATCH");
    }
    const question = profiles.resolveTestQuestion(
        trusted.resolution,
        data.testQuestionCode,
    );
    if (!question.ok) fail("failed-precondition", question.code);
    const laboratory = await adapter.getLaboratory(data.laboratoryId);
    let appealPrimaryLaboratoryId = null;
    let linkAppealId = null;
    if (data.appealId) {
      const appeal = await adapter.getAppeal(data.caseId, data.appealId);
      if (appeal.state !== "opened" || appeal.material !== true) {
        fail("failed-precondition", "APPEAL_NOT_OPEN_MATERIAL");
      }
      appealPrimaryLaboratoryId = appeal.originalPrimaryLaboratoryId;
      if (!appealPrimaryLaboratoryId) {
        fail("failed-precondition", "APPEAL_PRIMARY_LAB_UNRESOLVED");
      }
      linkAppealId = appeal.appealId;
    }
    const eligibility = profiles.evaluateLaboratoryEligibility({
      laboratory,
      policyResolution: trusted.resolution,
      questionResolution: question,
      methodCode: data.methodCode,
      requireChainOfCustody: data.requireChainOfCustody === true,
      appealPrimaryLaboratoryId,
    });
    if (!eligibility.eligible) {
      fail("failed-precondition", eligibility.code);
    }
    const requestRecord = contracts.validateTestRequest({
      testRequestId: data.testRequestId,
      sampleId: data.sampleId,
      laboratoryId: laboratory.laboratoryId,
      testQuestionCode: data.testQuestionCode,
      methodCode: data.methodCode,
      appealId: linkAppealId,
      laboratoryEvidenceClass:
        laboratory.ownerType === "RIGHTSHOLDER" ?
          "BRAND_OWNED" :
          "INDEPENDENT_OR_OTHER",
      profileId: trusted.profile.profileId,
      profileCode: trusted.resolution.profile.profileCode,
      profileVersion: trusted.resolution.profile.profileVersion,
      appendOnly: true,
    });
    return adapter.createTestRequest({
      caseId: data.caseId,
      requestRecord,
      operationId,
      actorUid: authority.uid,
      linkAppealId,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: caseRecord.tenantId,
            brandUid: caseRecord.brandUid,
          },
          operationId,
          "create_test_request",
      ),
    });
  }

  async function recordOdlaTestResult({authority, data}) {
    assertTenantMatch(authority, data);
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    const caseRecord = assertCaseScope(authority, workspace, data);
    const request = await adapter.getTestRequest(
        data.caseId,
        data.testRequestId,
    );
    if (data.sampleId && data.sampleId !== request.sampleId) {
      fail("failed-precondition", "TEST_RESULT_SAMPLE_BINDING_MISMATCH");
    }
    if (data.laboratoryId && data.laboratoryId !== request.laboratoryId) {
      fail("failed-precondition", "TEST_RESULT_LAB_BINDING_MISMATCH");
    }
    assertAssignedLaboratory(authority, request.laboratoryId);
    const resultRecord = contracts.validateTestResult({
      testResultId: data.testResultId,
      testRequestId: request.testRequestId,
      sampleId: request.sampleId,
      laboratoryId: request.laboratoryId,
      laboratoryReportId: data.laboratoryReportId,
      reportSha256: data.reportSha256,
      appendOnly: true,
      resultCode: data.resultCode,
    });
    return adapter.createTestResult({
      caseId: data.caseId,
      resultRecord,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: caseRecord.tenantId,
            brandUid: caseRecord.brandUid,
          },
          operationId,
          "record_test_result",
      ),
    });
  }

  async function adjudicateOdlaFinding({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "adjudicate_finding");
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    const caseRecord = assertCaseScope(authority, workspace, data);
    const context = await adapter.getAdjudicationContext(data.caseId);
    const derived = adjudication.deriveFinding(data.findingInputs || {});
    const finality = adjudication.evaluateFinality({
      findingCode: derived.findingCode,
      openMaterialAppeal: context.openMaterialAppeal === true,
      unresolvedIntegrityConflict:
        context.unresolvedIntegrityConflict === true,
      missingRequiredEvidence: context.missingRequiredEvidence === true,
    });
    if (finality.allowed && context.singleReporterOnly === true) {
      fail(
          "failed-precondition",
          "SINGLE_REPORTER_CANNOT_CREATE_FINAL_FINDING",
      );
    }
    if (finality.allowed && context.sellerSuppliedSampleSole === true) {
      fail(
          "failed-precondition",
          "SELLER_SUPPLIED_SAMPLE_CANNOT_BE_SOLE_FINAL_EVIDENCE",
      );
    }
    let primaryLaboratoryId = null;
    if (data.primaryTestRequestId) {
      const primaryRequest = await adapter.getTestRequest(
          data.caseId,
          data.primaryTestRequestId,
      );
      primaryLaboratoryId = primaryRequest.laboratoryId;
    }
    const findingRecord = contracts.validateFinding({
      findingId: data.findingId,
      findingVersion: data.findingVersion,
      findingCode: derived.findingCode,
      supersedesFindingId: data.supersedesFindingId,
      appendOnly: true,
      primaryLaboratoryId,
      permanentFinalityAllowed: finality.allowed,
      finalityCode: finality.code,
    });
    return adapter.writeFinding({
      caseId: data.caseId,
      findingRecord,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: caseRecord.tenantId,
            brandUid: caseRecord.brandUid,
          },
          operationId,
          "adjudicate_finding",
      ),
    });
  }

  async function openOdlaAppeal({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "open_appeal");
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    const caseRecord = assertCaseScope(authority, workspace, data);
    const challengedFinding = await adapter.getFinding(
        data.caseId,
        data.challengedFindingId,
    );
    const eligibility = adjudication.evaluateAppealEligibility({
      groundCode: data.groundCode,
    });
    if (!eligibility.eligible) {
      fail("failed-precondition", eligibility.code);
    }
    const appealRecord = contracts.validateAppeal({
      appealId: data.appealId,
      challengedFindingId: challengedFinding.findingId,
      originalPrimaryLaboratoryId:
        challengedFinding.primaryLaboratoryId || null,
      groundCode: data.groundCode,
      state: "opened",
      material: true,
      appendOnly: true,
    });
    return adapter.createAppeal({
      caseId: data.caseId,
      appealRecord,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: caseRecord.tenantId,
            brandUid: caseRecord.brandUid,
          },
          operationId,
          "open_appeal",
      ),
    });
  }

  async function resolveOdlaAppeal({authority, data}) {
    assertTenantMatch(authority, data);
    assertActionAuthorized(authority, "resolve_appeal");
    const operationId = requireOperationId(data);
    const workspace = await adapter.getWorkspace(data.caseId);
    const caseRecord = assertCaseScope(authority, workspace, data);
    const appeal = await adapter.getAppeal(data.caseId, data.appealId);
    if (!appeal.originalPrimaryLaboratoryId) {
      fail("failed-precondition", "APPEAL_PRIMARY_LAB_UNRESOLVED");
    }
    if (!appeal.appealTestRequestId) {
      fail("failed-precondition", "APPEAL_TEST_REQUEST_MISSING");
    }
    const appealRequest = await adapter.getTestRequest(
        data.caseId,
        appeal.appealTestRequestId,
    );
    if (appealRequest.appealId !== appeal.appealId) {
      fail("failed-precondition", "APPEAL_TEST_REQUEST_BINDING_MISMATCH");
    }
    const independence = adjudication.evaluateSecondLabIndependence(
        appeal.originalPrimaryLaboratoryId,
        appealRequest.laboratoryId,
    );
    if (!independence.allowed) {
      fail("failed-precondition", independence.code);
    }
    if (data.conflictingLaboratoryResults === true) {
      return adapter.resolveAppeal({
        caseId: data.caseId,
        appealId: data.appealId,
        operationId,
        actorUid: authority.uid,
        auditContext: trustedAuditContext(
            authority,
            {
              ...data,
              tenantId: caseRecord.tenantId,
              brandUid: caseRecord.brandUid,
            },
            operationId,
            "resolve_appeal",
        ),
        resolution: {
          state: "conflict_review",
          permanentAdverseFinalityAllowed: false,
          resolutionCode: "CONFLICT_REVIEW_REQUIRED",
          originalPrimaryLaboratoryId: appeal.originalPrimaryLaboratoryId,
          appealLaboratoryId: appealRequest.laboratoryId,
        },
      });
    }
    const context = await adapter.getAdjudicationContext(
        data.caseId,
        data.appealId,
    );
    const derived = adjudication.deriveFinding(data.findingInputs || {});
    const finality = adjudication.evaluateFinality({
      findingCode: derived.findingCode,
      openMaterialAppeal: context.openMaterialAppeal === true,
      unresolvedIntegrityConflict:
        context.unresolvedIntegrityConflict === true,
      missingRequiredEvidence: context.missingRequiredEvidence === true,
    });
    if (finality.allowed && context.singleReporterOnly === true) {
      fail(
          "failed-precondition",
          "SINGLE_REPORTER_CANNOT_CREATE_FINAL_FINDING",
      );
    }
    if (finality.allowed && context.sellerSuppliedSampleSole === true) {
      fail(
          "failed-precondition",
          "SELLER_SUPPLIED_SAMPLE_CANNOT_BE_SOLE_FINAL_EVIDENCE",
      );
    }
    return adapter.resolveAppeal({
      caseId: data.caseId,
      appealId: data.appealId,
      operationId,
      actorUid: authority.uid,
      auditContext: trustedAuditContext(
          authority,
          {
            ...data,
            tenantId: caseRecord.tenantId,
            brandUid: caseRecord.brandUid,
          },
          operationId,
          "resolve_appeal",
      ),
      resolution: {
        state: "resolved",
        findingCode: derived.findingCode,
        permanentAdverseFinalityAllowed: finality.allowed,
        resolutionCode: finality.code,
        originalPrimaryLaboratoryId: appeal.originalPrimaryLaboratoryId,
        appealLaboratoryId: appealRequest.laboratoryId,
      },
    });
  }

  return Object.freeze({
    createOdlaVerificationCase,
    getOdlaVerificationWorkspace,
    appendOdlaChainOfCustodyEvent,
    createOdlaTestRequest,
    recordOdlaTestResult,
    adjudicateOdlaFinding,
    openOdlaAppeal,
    resolveOdlaAppeal,
  });
}

module.exports = {createOdlaWorkspaceService};
