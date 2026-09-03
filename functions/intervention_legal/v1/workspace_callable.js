"use strict";

const {
  HttpsError,
  onCall,
} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  getFirestore,
} = require("firebase-admin/firestore");

const {
  InterventionLegalContractError,
  exactKeys,
  objectRequired,
} = require("./contracts");
const {
  createInterventionLegalFirestoreAdapter,
} = require("./firestore_adapter");

const WORKSPACE_CONTRACT_VERSION = "intervention-legal-workspace-v1";
const WORKSPACE_CALLABLE_NAME = "getInterventionLegalWorkspace";
const READ_OPERATION_CODE = "read_legal_matter_workspace";
const LEGAL_ACTION_OPERATION_CODES = Object.freeze([
  "transition_legal_matter",
  "create_approval_request",
]);
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const MAX_MEMBERSHIPS = 50;
const RELATED_RECORD_LIMIT = 50;

const WORKSPACE_CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

const SUPPORTED_HTTPS_CODES = new Set([
  "invalid-argument",
  "failed-precondition",
  "not-found",
  "permission-denied",
  "already-exists",
  "aborted",
  "out-of-range",
  "resource-exhausted",
  "unavailable",
  "deadline-exceeded",
  "internal",
]);

const TERMINAL_MATTER_STATUSES = new Set([
  "resolved",
  "closed",
  "cancelled",
  "archived",
]);

function fail(code, message, details = undefined) {
  throw new InterventionLegalContractError(code, message, details);
}

function productionClock() {
  return new Date().toISOString();
}

function mapWorkspaceError(error) {
  if (error instanceof HttpsError) return error;

  if (
    error instanceof InterventionLegalContractError ||
    error?.name === "InterventionLegalContractError"
  ) {
    const code = SUPPORTED_HTTPS_CODES.has(error.code) ?
      error.code :
      "internal";
    const message = code === "internal" ?
      "Müdahale ve Hukuk çalışma alanı yüklenemedi." :
      error.message;
    const details = code === "internal" ? undefined : error.details;
    return new HttpsError(code, message, details);
  }

  return new HttpsError(
      "internal",
      "Müdahale ve Hukuk çalışma alanı yüklenemedi.",
  );
}

function assertWorkspaceCallableRequest(request) {
  if (!request?.auth?.uid) {
    throw new HttpsError(
        "unauthenticated",
        "Oturum açmanız gerekir.",
    );
  }
  if (!request?.app?.appId) {
    throw new HttpsError(
        "failed-precondition",
        "Uygulama doğrulaması gerekir.",
    );
  }
  return request.auth.uid;
}

function parseWorkspaceQuery(raw) {
  objectRequired(raw);
  exactKeys(raw, ["contractVersion", "limit"], ["contractVersion"]);

  if (raw.contractVersion !== WORKSPACE_CONTRACT_VERSION) {
    fail("invalid-argument", "workspace contractVersion is unsupported");
  }

  const limit = raw.limit === undefined || raw.limit === null ?
    DEFAULT_LIMIT :
    raw.limit;

  if (
    !Number.isSafeInteger(limit) ||
    limit < 1 ||
    limit > MAX_LIMIT
  ) {
    fail(
        "invalid-argument",
        `limit must be an integer between 1 and ${MAX_LIMIT}`,
    );
  }

  return Object.freeze({
    contractVersion: WORKSPACE_CONTRACT_VERSION,
    limit,
  });
}

function timestampToIso(value) {
  if (typeof value === "string" && !Number.isNaN(Date.parse(value))) {
    return new Date(value).toISOString();
  }
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    if (date instanceof Date && !Number.isNaN(date.getTime())) {
      return date.toISOString();
    }
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }
  return null;
}

function optionalString(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized === "" ? null : normalized;
}

function requiredProjectedString(value, field) {
  const normalized = optionalString(value);
  if (!normalized) {
    fail("internal", `workspace projection ${field} is invalid`);
  }
  return normalized;
}

function integerOr(value, fallback = 0) {
  return Number.isSafeInteger(value) ? value : fallback;
}

function projectMatter(documentId, data) {
  objectRequired(data, "matter");
  const legalMatterId = requiredProjectedString(
      data.legalMatterId || documentId,
      "legalMatterId",
  );

  return Object.freeze({
    legalMatterId,
    caseId: requiredProjectedString(data.caseId, "caseId"),
    tenantId: requiredProjectedString(data.tenantId, "tenantId"),
    canonicalBrandId: requiredProjectedString(
        data.canonicalBrandId,
        "canonicalBrandId",
    ),
    jurisdictionCode: requiredProjectedString(
        data.jurisdictionCode,
        "jurisdictionCode",
    ),
    countryCode: optionalString(data.countryCode),
    matterScopeCode: optionalString(data.matterScopeCode),
    priorityCode: optionalString(data.priorityCode),
    title: optionalString(data.title),
    status: requiredProjectedString(data.status, "status"),
    version: integerOr(data.version),
    sourceSystemCode: optionalString(data.sourceSystemCode),
    sourceRecordId: optionalString(data.sourceRecordId),
    createdAt: timestampToIso(data.createdAt),
    updatedAt: timestampToIso(data.updatedAt),
    createdByUid: optionalString(data.createdByUid),
    updatedByUid: optionalString(data.updatedByUid),
    statusChangedByUid: optionalString(data.statusChangedByUid),
  });
}

function projectApprovalRequest(documentId, data) {
  objectRequired(data, "approvalRequest");

  return Object.freeze({
    approvalRequestId: requiredProjectedString(
        data.approvalRequestId || documentId,
        "approvalRequestId",
    ),
    legalMatterId: requiredProjectedString(
        data.legalMatterId,
        "approvalRequest.legalMatterId",
    ),
    approvalType: requiredProjectedString(
        data.approvalType,
        "approvalType",
    ),
    status: requiredProjectedString(
        data.status,
        "approvalRequest.status",
    ),
    version: integerOr(data.version),
    requestSequence: integerOr(data.requestSequence),
    requestReasonCode: optionalString(data.requestReasonCode),
    requestNote: optionalString(data.requestNote),
    preparedByUid: optionalString(data.preparedByUid),
    decisionId: optionalString(data.decisionId),
    decidedByUid: optionalString(data.decidedByUid),
    createdAt: timestampToIso(data.createdAt),
    updatedAt: timestampToIso(data.updatedAt),
    decidedAt: timestampToIso(data.decidedAt),
  });
}

function projectApprovalDecision(documentId, data) {
  objectRequired(data, "approvalDecision");

  return Object.freeze({
    decisionId: requiredProjectedString(
        data.decisionId || documentId,
        "decisionId",
    ),
    approvalRequestId: requiredProjectedString(
        data.approvalRequestId,
        "decision.approvalRequestId",
    ),
    legalMatterId: requiredProjectedString(
        data.legalMatterId,
        "decision.legalMatterId",
    ),
    approvalType: requiredProjectedString(
        data.approvalType,
        "decision.approvalType",
    ),
    decision: requiredProjectedString(
        data.decision,
        "decision.decision",
    ),
    decisionReasonCode: optionalString(data.decisionReasonCode),
    decisionNote: optionalString(data.decisionNote),
    decidedByUid: optionalString(data.decidedByUid),
    decidedAt: timestampToIso(data.decidedAt),
    immutable: data.immutable === true,
  });
}

async function projectLegalActionCapabilityAccess({
  reader,
  uid,
  matter,
  serverMembershipRows,
}) {
  const entries = await Promise.all(
      LEGAL_ACTION_OPERATION_CODES.map(async (operationCode) => {
        const authority = await reader.resolveLegalMatterAuthority({
          uid,
          tenantId: matter.tenantId,
          canonicalBrandId: matter.canonicalBrandId,
          operationCode,
          serverMembershipRows,
        });
        const exactOperation =
          authority && authority.operationCode === operationCode;
        const granted = exactOperation && authority.authorized === true;
        const source = exactOperation ?
          optionalString(authority.authoritySource) :
          null;
        return [
          operationCode,
          Object.freeze({
            operationCode,
            canonicalBrandId: matter.canonicalBrandId,
            operationAuthorityGranted: granted,
            authoritySource: source || "none",
          }),
        ];
      }),
  );
  return Object.freeze({
    LEGAL_ACTION: Object.freeze(Object.fromEntries(entries)),
  });
}

function snapshotRows(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.docs)) return [];
  return snapshot.docs.map((doc) => Object.freeze({
    documentId: doc.id,
    data: doc.data() || {},
  }));
}

function createWorkspaceReader(dbInput) {
  if (
    !dbInput ||
    typeof dbInput.collection !== "function"
  ) {
    throw new TypeError("db must be a Firestore-compatible instance");
  }

  const authorityStore = createInterventionLegalFirestoreAdapter(dbInput);

  return Object.freeze({
    async listMembershipsByUid({uid}) {
      const snapshot = await dbInput
          .collection("tenant_memberships")
          .where("uid", "==", uid)
          .limit(MAX_MEMBERSHIPS)
          .get();
      return snapshotRows(snapshot);
    },

    async listMattersByTenant({tenantId, limit}) {
      const snapshot = await dbInput
          .collection("legal_matter_files")
          .where("tenantId", "==", tenantId)
          .limit(limit)
          .get();
      return snapshotRows(snapshot);
    },

    async listApprovalRequestsByMatter({legalMatterId}) {
      const snapshot = await dbInput
          .collection("legal_approval_requests")
          .where("legalMatterId", "==", legalMatterId)
          .limit(RELATED_RECORD_LIMIT)
          .get();
      return snapshotRows(snapshot);
    },

    async listApprovalDecisionsByMatter({legalMatterId}) {
      const snapshot = await dbInput
          .collection("legal_approval_decisions")
          .where("legalMatterId", "==", legalMatterId)
          .limit(RELATED_RECORD_LIMIT)
          .get();
      return snapshotRows(snapshot);
    },

    async resolveLegalMatterAuthority(input) {
      return authorityStore.resolveLegalMatterAuthority(input);
    },
  });
}

function resolveAuthorityScopes(rows) {
  const byTenant = new Map();

  for (const row of rows) {
    const data = row && row.data && typeof row.data === "object" ?
      row.data :
      {};

    if (data.status !== "active") continue;

    const tenantId = optionalString(data.tenantId);
    if (!tenantId) continue;

    const existing = byTenant.get(tenantId);
    if (data.role === "owner") {
      byTenant.set(tenantId, Object.freeze({
        tenantId,
        allBrands: true,
        allowedBrandIds: Object.freeze([]),
        authoritySource: "tenant_owner",
      }));
      continue;
    }

    if (existing && existing.allBrands === true) continue;

    const operations = Array.isArray(
        data.delegatedLegalMatterOperations,
    ) ? data.delegatedLegalMatterOperations : [];
    if (!operations.includes(READ_OPERATION_CODE)) continue;

    const brands = Array.isArray(
        data.delegatedCanonicalBrandIds,
    ) ? data.delegatedCanonicalBrandIds : [];
    const allowedBrandIds = brands
        .filter((value) => typeof value === "string" && value.trim() !== "")
        .map((value) => value.trim());

    if (allowedBrandIds.length === 0) continue;

    const merged = new Set([
      ...(existing ? existing.allowedBrandIds : []),
      ...allowedBrandIds,
    ]);
    byTenant.set(tenantId, Object.freeze({
      tenantId,
      allBrands: merged.has("*"),
      allowedBrandIds: Object.freeze([...merged]),
      authoritySource: "explicit_delegation",
    }));
  }

  return Object.freeze([...byTenant.values()]);
}

function scopeAllowsMatter(scope, matter) {
  if (matter.tenantId !== scope.tenantId) return false;
  if (scope.allBrands === true) return true;
  return scope.allowedBrandIds.includes(matter.canonicalBrandId);
}

function compareIsoDescending(left, right) {
  const leftValue = left.updatedAt || left.createdAt || "";
  const rightValue = right.updatedAt || right.createdAt || "";
  return rightValue.localeCompare(leftValue);
}

function compareRequestDescending(left, right) {
  const leftValue = left.updatedAt || left.createdAt || "";
  const rightValue = right.updatedAt || right.createdAt || "";
  return rightValue.localeCompare(leftValue);
}

function compareDecisionDescending(left, right) {
  return (right.decidedAt || "").localeCompare(left.decidedAt || "");
}

function buildInterventionLegalWorkspaceService({
  reader,
  clock = productionClock,
}) {
  if (
    !reader ||
    typeof reader.listMembershipsByUid !== "function" ||
    typeof reader.listMattersByTenant !== "function" ||
    typeof reader.listApprovalRequestsByMatter !== "function" ||
    typeof reader.listApprovalDecisionsByMatter !== "function" ||
    typeof reader.resolveLegalMatterAuthority !== "function"
  ) {
    throw new TypeError("workspace reader is incomplete");
  }
  if (typeof clock !== "function") {
    throw new TypeError("clock must be a function");
  }

  return async function getWorkspace({uid, raw}) {
    const query = parseWorkspaceQuery(raw);
    const membershipRows = await reader.listMembershipsByUid({uid});
    const scopes = resolveAuthorityScopes(membershipRows);

    if (scopes.length === 0) {
      fail(
          "permission-denied",
          "Müdahale ve Hukuk çalışma alanı için yetkiniz yok.",
      );
    }

    const matterById = new Map();

    for (const scope of scopes) {
      const rows = await reader.listMattersByTenant({
        tenantId: scope.tenantId,
        limit: query.limit,
      });

      for (const row of rows) {
        const matter = projectMatter(row.documentId, row.data);
        if (!scopeAllowsMatter(scope, matter)) continue;
        matterById.set(matter.legalMatterId, matter);
      }
    }

    const matters = [...matterById.values()]
        .sort(compareIsoDescending)
        .slice(0, query.limit);

    const enriched = await Promise.all(
        matters.map(async (matter) => {
          const [requestRows, decisionRows, capabilityAccess] =
            await Promise.all([
              reader.listApprovalRequestsByMatter({
                legalMatterId: matter.legalMatterId,
              }),
              reader.listApprovalDecisionsByMatter({
                legalMatterId: matter.legalMatterId,
              }),
              projectLegalActionCapabilityAccess({
                reader,
                uid,
                matter,
                serverMembershipRows: membershipRows,
              }),
            ]);

          const approvalRequests = requestRows
              .map((row) =>
                projectApprovalRequest(row.documentId, row.data))
              .sort(compareRequestDescending);
          const approvalDecisions = decisionRows
              .map((row) =>
                projectApprovalDecision(row.documentId, row.data))
              .sort(compareDecisionDescending);

          return Object.freeze({
            ...matter,
            capabilityAccess,
            approvalRequests: Object.freeze(approvalRequests),
            approvalDecisions: Object.freeze(approvalDecisions),
          });
        }),
    );

    const approvalRequests = enriched.flatMap(
        (matter) => matter.approvalRequests,
    );

    const counts = Object.freeze({
      legalMatterCount: enriched.length,
      activeLegalMatterCount: enriched.filter(
          (matter) => !TERMINAL_MATTER_STATUSES.has(matter.status),
      ).length,
      pendingApprovalCount: approvalRequests.filter(
          (request) => request.status === "pending",
      ).length,
      approvedApprovalCount: approvalRequests.filter(
          (request) => request.status === "approved",
      ).length,
      rejectedApprovalCount: approvalRequests.filter(
          (request) => request.status === "rejected",
      ).length,
    });

    return Object.freeze({
      contractVersion: WORKSPACE_CONTRACT_VERSION,
      generatedAt: clock(),
      limit: query.limit,
      authorityScopeCount: scopes.length,
      counts,
      matters: Object.freeze(enriched),
    });
  };
}

function buildGetInterventionLegalWorkspaceCallable(
    dependencies = {},
) {
  const onCallImpl = dependencies.onCallImpl || onCall;
  const log = dependencies.log || logger;

  let service = dependencies.service;
  if (!service) {
    const db = dependencies.db || getFirestore();
    const reader = dependencies.reader || createWorkspaceReader(db);
    service = buildInterventionLegalWorkspaceService({
      reader,
      clock: dependencies.clock || productionClock,
    });
  }

  const handler = async (request) => {
    try {
      const uid = assertWorkspaceCallableRequest(request);
      return await service({
        uid,
        raw: request.data,
      });
    } catch (error) {
      log.error("intervention legal workspace callable failed", {
        callableName: WORKSPACE_CALLABLE_NAME,
        code: error && error.code ? error.code : "unknown",
        message: error && error.message ? error.message : String(error),
      });
      throw mapWorkspaceError(error);
    }
  };

  return onCallImpl(WORKSPACE_CALLABLE_OPTIONS, handler);
}

module.exports = Object.freeze({
  WORKSPACE_CONTRACT_VERSION,
  WORKSPACE_CALLABLE_NAME,
  READ_OPERATION_CODE,
  LEGAL_ACTION_OPERATION_CODES,
  DEFAULT_LIMIT,
  MAX_LIMIT,
  MAX_MEMBERSHIPS,
  RELATED_RECORD_LIMIT,
  WORKSPACE_CALLABLE_OPTIONS,
  SUPPORTED_HTTPS_CODES,
  TERMINAL_MATTER_STATUSES,
  productionClock,
  mapWorkspaceError,
  assertWorkspaceCallableRequest,
  parseWorkspaceQuery,
  timestampToIso,
  projectMatter,
  projectLegalActionCapabilityAccess,
  projectApprovalRequest,
  projectApprovalDecision,
  createWorkspaceReader,
  resolveAuthorityScopes,
  scopeAllowsMatter,
  buildInterventionLegalWorkspaceService,
  buildGetInterventionLegalWorkspaceCallable,
});
