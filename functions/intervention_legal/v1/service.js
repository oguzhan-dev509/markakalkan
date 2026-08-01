"use strict";

const {
  APPROVAL_TYPES,
  LEGAL_MATTER_OPERATION_CODES,
  InterventionLegalContractError,
  assertLegalProfessionalCanApprove,
  requiredString,
  assertSegregationOfDuties,
  parseApprovalDecisionCommand,
  parseCreateApprovalRequestCommand,
  parseCreateLegalMatterCommand,
  parseTransitionLegalMatterCommand,
} = require("./contracts");
const {
  canonicalPayloadFingerprint,
  canonicalizeLegalMatterIdentity,
} = require("./canonical");
const {
  buildApprovalDecisionId,
  buildApprovalRequestId,
  buildLegalMatterId,
  buildLegalMatterKey,
  buildMatterEventId,
} = require("./identifiers");
const {
  assertTransition,
} = require("./lifecycle");
const {
  assertClock,
  assertReceiptShape,
  assertStoragePort,
} = require("./storage_contracts");

const CLIENT_APPROVAL_TYPES = Object.freeze([
  "client_action_authorization",
  "client_budget_authorization",
  "client_litigation_authorization",
  "client_settlement_authorization",
]);

const LAWYER_APPROVAL_TYPES = Object.freeze([
  "lawyer_legal_approval",
  "senior_legal_review",
]);

const APPROVAL_REQUEST_MATTER_STATUSES = Object.freeze({
  client_action_authorization: Object.freeze([
    "legal_review",
    "awaiting_authorization",
  ]),
  client_budget_authorization: Object.freeze([
    "legal_review",
    "awaiting_authorization",
  ]),
  client_litigation_authorization: Object.freeze([
    "legal_review",
    "awaiting_authorization",
  ]),
  client_settlement_authorization: Object.freeze([
    "legal_review",
    "awaiting_authorization",
  ]),
  lawyer_legal_approval: Object.freeze(["legal_review"]),
  senior_legal_review: Object.freeze(["legal_review"]),
});

function commandActorUid(command) {
  return requiredString(
      command.actorUid || command.preparedByUid || command.decidedByUid,
      "actorUid",
      128,
  );
}

function createServiceDependencies({store, clock}) {
  return Object.freeze({
    store: assertStoragePort(store),
    clock: assertClock(clock),
  });
}

async function assertLegalMatterCommandAuthority({
  store,
  command,
  tenantId,
  canonicalBrandId,
  operationCode,
}) {
  if (!LEGAL_MATTER_OPERATION_CODES.includes(operationCode)) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "legal matter operation code is unsupported",
    );
  }
  const authority = await store.resolveLegalMatterAuthority({
    uid: commandActorUid(command),
    tenantId,
    canonicalBrandId,
    operationCode,
  });
  if (!authority || authority.authorized !== true) {
    throw new InterventionLegalContractError(
        "permission-denied",
        "legal matter command authority is not sufficient",
    );
  }
  return authority;
}

function assertApprovalRequestMatterStatus({approvalType, matterStatus}) {
  const allowed = APPROVAL_REQUEST_MATTER_STATUSES[approvalType];
  if (!allowed || !allowed.includes(matterStatus)) {
    throw new InterventionLegalContractError(
        "failed-precondition",
        "legal matter status does not allow this approval request",
        {approvalType, matterStatus, allowedStatuses: allowed || []},
    );
  }
  return true;
}

function assertScopeMatches(command, caseScope) {
  if (!caseScope || typeof caseScope !== "object") {
    throw new InterventionLegalContractError(
        "not-found",
        "canonical case was not found",
    );
  }
  if (caseScope.tenantId !== command.tenantId) {
    throw new InterventionLegalContractError(
        "permission-denied",
        "case tenant scope mismatch",
    );
  }
  if (caseScope.canonicalBrandId !== command.canonicalBrandId) {
    throw new InterventionLegalContractError(
        "failed-precondition",
        "case brand scope mismatch",
    );
  }
  if (caseScope.archived === true || caseScope.status === "archived") {
    throw new InterventionLegalContractError(
        "failed-precondition",
        "archived case cannot open a legal matter",
    );
  }
  return true;
}

function resolveIdempotentReceipt(receipt, payloadFingerprint) {
  const checked = assertReceiptShape(receipt);
  if (!checked) return null;
  if (checked.payloadFingerprint !== payloadFingerprint) {
    throw new InterventionLegalContractError(
        "already-exists",
        "idempotency key is already used with a different payload",
        {
          resultType: checked.resultType,
          resultId: checked.resultId,
        },
    );
  }
  return Object.freeze({
    idempotentReplay: true,
    resultType: checked.resultType,
    resultId: checked.resultId,
  });
}

function createReceipt({
  command,
  payloadFingerprint,
  resultType,
  resultId,
  recordedAt,
}) {
  return Object.freeze({
    contractVersion: command.contractVersion,
    requestId: command.requestId,
    idempotencyKey: command.idempotencyKey,
    payloadFingerprint,
    resultType,
    resultId,
    actorUid: commandActorUid(command),
    recordedAt,
  });
}

function buildEvent({
  legalMatterId,
  command,
  eventType,
  eventData,
  recordedAt,
}) {
  return Object.freeze({
    eventId: buildMatterEventId({
      legalMatterId,
      requestId: command.requestId,
      eventType,
    }),
    contractVersion: command.contractVersion,
    legalMatterId,
    eventType,
    requestId: command.requestId,
    idempotencyKey: command.idempotencyKey,
    actorUid: commandActorUid(command),
    eventData: Object.freeze({...eventData}),
    recordedAt,
  });
}

function buildCreateLegalMatterService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);

  return async function createLegalMatter(raw) {
    const command = parseCreateLegalMatterCommand(raw);
    const identity = canonicalizeLegalMatterIdentity(command);
    const legalMatterKey = buildLegalMatterKey(identity);
    const legalMatterId = buildLegalMatterId(identity);
    const payloadFingerprint = canonicalPayloadFingerprint(command);

    const receipt = await store.getCommandReceipt({
      scopeType: "create_legal_matter",
      scopeId: command.tenantId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) return replay;

    const caseScope = await store.resolveCaseScope({
      caseId: command.caseId,
    });
    assertScopeMatches(command, caseScope);
    await assertLegalMatterCommandAuthority({
      store,
      command,
      tenantId: command.tenantId,
      canonicalBrandId: command.canonicalBrandId,
      operationCode: "create_legal_matter",
    });

    const existing = await store.findLegalMatterByKey({
      tenantId: command.tenantId,
      legalMatterKey,
    });
    if (existing) {
      if (
        existing.caseId === command.caseId &&
        existing.jurisdictionCode === identity.jurisdictionCode &&
        existing.matterScopeCode === identity.matterScopeCode
      ) {
        return Object.freeze({
          idempotentReplay: true,
          resultType: "legal_matter",
          resultId: existing.legalMatterId,
        });
      }
      throw new InterventionLegalContractError(
          "already-exists",
          "an active legal matter already uses the canonical key",
      );
    }

    const now = clock();
    const matter = Object.freeze({
      contractVersion: command.contractVersion,
      legalMatterId,
      legalMatterKey,
      tenantId: identity.tenantId,
      canonicalBrandId: identity.canonicalBrandId,
      caseId: identity.caseId,
      jurisdictionCode: identity.jurisdictionCode,
      matterScopeCode: identity.matterScopeCode,
      countryCode: identity.countryCode,
      priorityCode: command.priorityCode,
      title: command.title,
      sourceSystemCode: command.sourceSystemCode,
      sourceRecordId: command.sourceRecordId,
      status: "intake_pending",
      version: 1,
      createdAt: now,
      createdByRequestId: command.requestId,
      createdByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
    });

    const event = buildEvent({
      legalMatterId,
      command,
      eventType: "legal_matter_created",
      eventData: {
        status: matter.status,
        caseId: matter.caseId,
        jurisdictionCode: matter.jurisdictionCode,
        matterScopeCode: matter.matterScopeCode,
      },
      recordedAt: now,
    });

    const result = await store.createLegalMatterAtomic({
      matter,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "legal_matter",
        resultId: legalMatterId,
        recordedAt: now,
      }),
    });

    return Object.freeze({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "legal_matter",
      resultId: legalMatterId,
      matter: result && result.matter ? result.matter : matter,
    });
  };
}

function buildTransitionLegalMatterService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);

  return async function transitionLegalMatter(raw) {
    const command = parseTransitionLegalMatterCommand(raw);
    const payloadFingerprint = canonicalPayloadFingerprint(command);

    const receipt = await store.getCommandReceipt({
      scopeType: "legal_matter",
      scopeId: command.legalMatterId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) return replay;

    const current = await store.getLegalMatterById({
      legalMatterId: command.legalMatterId,
    });
    if (!current) {
      throw new InterventionLegalContractError(
          "not-found",
          "legal matter was not found",
      );
    }
    await assertLegalMatterCommandAuthority({
      store,
      command,
      tenantId: current.tenantId,
      canonicalBrandId: current.canonicalBrandId,
      operationCode: "transition_legal_matter",
    });
    if (current.version !== command.expectedVersion) {
      throw new InterventionLegalContractError(
          "aborted",
          "legal matter version conflict",
          {
            expectedVersion: command.expectedVersion,
            actualVersion: current.version,
          },
      );
    }

    assertTransition("legalMatter", current.status, command.nextStatus);

    const now = clock();
    const nextMatter = Object.freeze({
      ...current,
      status: command.nextStatus,
      version: current.version + 1,
      statusReasonCode: command.reasonCode,
      statusNote: command.note,
      statusChangedAt: now,
      statusChangedByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
    });

    const event = buildEvent({
      legalMatterId: current.legalMatterId,
      command,
      eventType: "legal_matter_status_changed",
      eventData: {
        previousStatus: current.status,
        nextStatus: command.nextStatus,
        reasonCode: command.reasonCode,
      },
      recordedAt: now,
    });

    const result = await store.transitionLegalMatterAtomic({
      currentMatter: current,
      nextMatter,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "legal_matter",
        resultId: current.legalMatterId,
        recordedAt: now,
      }),
    });

    return Object.freeze({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "legal_matter",
      resultId: current.legalMatterId,
      matter: result && result.matter ? result.matter : nextMatter,
    });
  };
}

function buildCreateApprovalRequestService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);

  return async function createApprovalRequest(raw) {
    const command = parseCreateApprovalRequestCommand(raw);
    const payloadFingerprint = canonicalPayloadFingerprint(command);

    const receipt = await store.getCommandReceipt({
      scopeType: "legal_approval_request",
      scopeId: command.legalMatterId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) return replay;

    const matter = await store.getLegalMatterById({
      legalMatterId: command.legalMatterId,
    });
    if (!matter) {
      throw new InterventionLegalContractError(
          "not-found",
          "legal matter was not found",
      );
    }
    if (!Number.isSafeInteger(matter.version) || matter.version < 1) {
      throw new InterventionLegalContractError(
          "internal",
          "legal matter version is invalid",
      );
    }
    if (matter.version !== command.expectedLegalMatterVersion) {
      throw new InterventionLegalContractError(
          "aborted",
          "legal matter version conflict",
          {
            expectedLegalMatterVersion: command.expectedLegalMatterVersion,
            actualLegalMatterVersion: matter.version,
          },
      );
    }

    assertApprovalRequestMatterStatus({
      approvalType: command.approvalType,
      matterStatus: matter.status,
    });
    await assertLegalMatterCommandAuthority({
      store,
      command,
      tenantId: matter.tenantId,
      canonicalBrandId: matter.canonicalBrandId,
      operationCode: "create_approval_request",
    });

    const requestSequence = command.expectedLegalMatterVersion;
    const approvalRequestId = buildApprovalRequestId({
      legalMatterId: matter.legalMatterId,
      approvalType: command.approvalType,
      requestSequence,
    });
    const now = clock();
    const approvalRequest = Object.freeze({
      contractVersion: command.contractVersion,
      approvalRequestId,
      requestSequence,
      legalMatterId: matter.legalMatterId,
      legalMatterVersionAtRequest: matter.version,
      tenantId: matter.tenantId,
      canonicalBrandId: matter.canonicalBrandId,
      caseId: matter.caseId,
      jurisdictionCode: matter.jurisdictionCode,
      approvalType: command.approvalType,
      requestReasonCode: command.requestReasonCode,
      requestNote: command.requestNote,
      preparedByUid: command.preparedByUid,
      status: "pending",
      version: 1,
      createdAt: now,
      createdByRequestId: command.requestId,
      createdByUid: command.preparedByUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.preparedByUid,
    });

    const event = buildEvent({
      legalMatterId: matter.legalMatterId,
      command,
      eventType: "legal_approval_requested",
      eventData: {
        approvalRequestId,
        approvalType: command.approvalType,
        requestReasonCode: command.requestReasonCode,
        legalMatterVersionAtRequest: matter.version,
        status: "pending",
      },
      recordedAt: now,
    });

    const result = await store.createApprovalRequestAtomic({
      matter,
      approvalRequest,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "legal_approval_request",
        resultId: approvalRequestId,
        recordedAt: now,
      }),
    });

    return Object.freeze({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "legal_approval_request",
      resultId: approvalRequestId,
      approvalRequest: result && result.approvalRequest ?
        result.approvalRequest :
        approvalRequest,
    });
  };
}

function buildRecordApprovalDecisionService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);

  return async function recordApprovalDecision(raw) {
    const command = parseApprovalDecisionCommand(raw);
    const payloadFingerprint = canonicalPayloadFingerprint(command);

    const receipt = await store.getCommandReceipt({
      scopeType: "legal_approval_decision",
      scopeId: command.approvalRequestId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) return replay;

    const approvalRequest = await store.getApprovalRequestById({
      approvalRequestId: command.approvalRequestId,
    });
    if (!approvalRequest) {
      throw new InterventionLegalContractError(
          "not-found",
          "approval request was not found",
      );
    }
    if (!Number.isSafeInteger(approvalRequest.version)) {
      throw new InterventionLegalContractError(
          "internal",
          "approval request version is invalid",
      );
    }
    if (
      approvalRequest.version !== command.expectedApprovalRequestVersion
    ) {
      throw new InterventionLegalContractError(
          "aborted",
          "approval request version conflict",
          {
            expectedApprovalRequestVersion:
            command.expectedApprovalRequestVersion,
            actualApprovalRequestVersion: approvalRequest.version,
          },
      );
    }
    if (approvalRequest.legalMatterId !== command.legalMatterId) {
      throw new InterventionLegalContractError(
          "failed-precondition",
          "approval request does not belong to the legal matter",
      );
    }
    if (approvalRequest.approvalType !== command.approvalType) {
      throw new InterventionLegalContractError(
          "failed-precondition",
          "approval type mismatch",
      );
    }
    if (approvalRequest.status !== "pending") {
      throw new InterventionLegalContractError(
          "failed-precondition",
          "approval request is not pending",
      );
    }

    const matter = await store.getLegalMatterById({
      legalMatterId: command.legalMatterId,
    });
    if (!matter) {
      throw new InterventionLegalContractError(
          "not-found",
          "legal matter was not found",
      );
    }

    if (LAWYER_APPROVAL_TYPES.includes(command.approvalType)) {
      const profile = await store.getLegalTeamProfileByUid({
        uid: command.decidedByUid,
      });
      assertLegalProfessionalCanApprove(profile, matter.jurisdictionCode);
      if (approvalRequest.preparedByUid) {
        assertSegregationOfDuties({
          preparedByUid: approvalRequest.preparedByUid,
          approvedByUid: command.decidedByUid,
        });
      }
    } else if (CLIENT_APPROVAL_TYPES.includes(command.approvalType)) {
      const authority = await store.resolveClientAuthority({
        uid: command.decidedByUid,
        tenantId: matter.tenantId,
        canonicalBrandId: matter.canonicalBrandId,
        approvalType: command.approvalType,
      });
      if (!authority || authority.authorized !== true) {
        throw new InterventionLegalContractError(
            "permission-denied",
            "client authority is not sufficient",
        );
      }
    } else if (!APPROVAL_TYPES.includes(command.approvalType)) {
      throw new InterventionLegalContractError(
          "invalid-argument",
          "approval type is unsupported",
      );
    }

    const decisionId = buildApprovalDecisionId({
      approvalRequestId: command.approvalRequestId,
      decidedByUid: command.decidedByUid,
      decision: command.decision,
    });
    const now = clock();
    const decision = Object.freeze({
      contractVersion: command.contractVersion,
      decisionId,
      approvalRequestId: command.approvalRequestId,
      legalMatterId: command.legalMatterId,
      approvalType: command.approvalType,
      decision: command.decision,
      decisionReasonCode: command.decisionReasonCode,
      decisionNote: command.decisionNote,
      decidedByUid: command.decidedByUid,
      decidedAt: now,
      immutable: true,
    });

    const event = buildEvent({
      legalMatterId: command.legalMatterId,
      command,
      eventType: "legal_approval_decided",
      eventData: {
        approvalRequestId: command.approvalRequestId,
        approvalType: command.approvalType,
        decision: command.decision,
      },
      recordedAt: now,
    });

    const result = await store.recordApprovalDecisionAtomic({
      approvalRequest,
      expectedApprovalRequestVersion:
        command.expectedApprovalRequestVersion,
      decision,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "legal_approval_decision",
        resultId: decisionId,
        recordedAt: now,
      }),
    });

    return Object.freeze({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "legal_approval_decision",
      resultId: decisionId,
      decision: result && result.decision ? result.decision : decision,
    });
  };
}

module.exports = Object.freeze({
  CLIENT_APPROVAL_TYPES,
  LAWYER_APPROVAL_TYPES,
  APPROVAL_REQUEST_MATTER_STATUSES,
  commandActorUid,
  createServiceDependencies,
  assertLegalMatterCommandAuthority,
  assertApprovalRequestMatterStatus,
  assertScopeMatches,
  resolveIdempotentReceipt,
  buildCreateLegalMatterService,
  buildTransitionLegalMatterService,
  buildCreateApprovalRequestService,
  buildRecordApprovalDecisionService,
});
