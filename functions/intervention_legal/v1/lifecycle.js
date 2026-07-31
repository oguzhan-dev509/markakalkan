"use strict";

const {
  LEGAL_MATTER_STATUSES,
  ASSESSMENT_STATUSES,
  PLAN_STATUSES,
  ACTION_STATUSES,
  APPROVAL_REQUEST_STATUSES,
  PROFESSIONAL_STATUSES,
  InterventionLegalContractError,
} = require("./contracts");

function freezeTransitionMap(map) {
  const output = {};
  for (const [source, targets] of Object.entries(map)) {
    output[source] = Object.freeze([...targets]);
  }
  return Object.freeze(output);
}

const LEGAL_MATTER_TRANSITIONS = freezeTransitionMap({
  intake_pending: ["legal_review", "cancelled"],
  legal_review: ["evidence_required", "strategy_preparation", "cancelled"],
  evidence_required: ["legal_review", "cancelled"],
  strategy_preparation: [
    "awaiting_authorization",
    "legal_review",
    "cancelled",
  ],
  awaiting_authorization: ["approved", "strategy_preparation", "cancelled"],
  approved: ["in_preparation", "cancelled"],
  in_preparation: [
    "submitted",
    "in_progress",
    "awaiting_authorization",
    "cancelled",
  ],
  submitted: ["in_progress", "awaiting_response", "escalated", "resolved"],
  in_progress: ["awaiting_response", "escalated", "resolved"],
  awaiting_response: ["in_progress", "escalated", "resolved"],
  escalated: ["in_progress", "awaiting_response", "resolved"],
  resolved: ["closed", "in_progress"],
  closed: ["in_progress", "archived"],
  cancelled: ["archived"],
  archived: [],
});

const ASSESSMENT_TRANSITIONS = freezeTransitionMap({
  draft: ["evidence_required", "awaiting_lawyer_review", "withdrawn"],
  evidence_required: ["draft", "awaiting_lawyer_review", "withdrawn"],
  awaiting_lawyer_review: ["approved", "evidence_required", "withdrawn"],
  approved: ["superseded"],
  superseded: [],
  withdrawn: [],
});

const PLAN_TRANSITIONS = freezeTransitionMap({
  draft: ["awaiting_lawyer_review", "cancelled"],
  awaiting_lawyer_review: [
    "awaiting_client_authorization",
    "approved",
    "rejected",
    "draft",
  ],
  awaiting_client_authorization: ["approved", "rejected", "cancelled"],
  approved: ["active", "cancelled", "superseded"],
  active: ["completed", "cancelled", "superseded"],
  completed: ["superseded"],
  rejected: ["superseded"],
  cancelled: [],
  superseded: [],
});

const ACTION_TRANSITIONS = freezeTransitionMap({
  draft: ["awaiting_human_review", "cancelled"],
  awaiting_human_review: [
    "awaiting_client_authorization",
    "approved",
    "rejected",
    "draft",
  ],
  awaiting_client_authorization: ["approved", "rejected", "cancelled"],
  approved: ["in_preparation", "cancelled"],
  in_preparation: ["ready_for_execution", "cancelled"],
  ready_for_execution: ["executed", "cancelled"],
  executed: ["awaiting_response", "in_progress", "resolved"],
  awaiting_response: [
    "in_progress",
    "additional_information_required",
    "resolved",
    "rejected",
  ],
  in_progress: [
    "awaiting_response",
    "additional_information_required",
    "resolved",
    "rejected",
  ],
  additional_information_required: [
    "in_preparation",
    "in_progress",
    "cancelled",
  ],
  resolved: ["archived"],
  rejected: ["archived"],
  withdrawn: ["archived"],
  cancelled: ["archived"],
  archived: [],
});

const APPROVAL_REQUEST_TRANSITIONS = freezeTransitionMap({
  pending: ["approved", "rejected", "expired", "withdrawn"],
  approved: [],
  rejected: [],
  expired: [],
  withdrawn: [],
});

const PROFESSIONAL_TRANSITIONS = freezeTransitionMap({
  pending: ["active", "inactive", "archived"],
  active: ["suspended", "inactive", "archived"],
  suspended: ["active", "inactive", "archived"],
  inactive: ["active", "archived"],
  archived: [],
});

const LIFECYCLES = Object.freeze({
  legalMatter: Object.freeze({
    statuses: LEGAL_MATTER_STATUSES,
    transitions: LEGAL_MATTER_TRANSITIONS,
  }),
  assessment: Object.freeze({
    statuses: ASSESSMENT_STATUSES,
    transitions: ASSESSMENT_TRANSITIONS,
  }),
  plan: Object.freeze({
    statuses: PLAN_STATUSES,
    transitions: PLAN_TRANSITIONS,
  }),
  action: Object.freeze({
    statuses: ACTION_STATUSES,
    transitions: ACTION_TRANSITIONS,
  }),
  approvalRequest: Object.freeze({
    statuses: APPROVAL_REQUEST_STATUSES,
    transitions: APPROVAL_REQUEST_TRANSITIONS,
  }),
  professional: Object.freeze({
    statuses: PROFESSIONAL_STATUSES,
    transitions: PROFESSIONAL_TRANSITIONS,
  }),
});

function lifecycleRequired(name) {
  const lifecycle = LIFECYCLES[name];
  if (!lifecycle) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "unknown lifecycle",
        {name},
    );
  }
  return lifecycle;
}

function assertKnownStatus(lifecycleName, status) {
  const lifecycle = lifecycleRequired(lifecycleName);
  if (!lifecycle.statuses.includes(status)) {
    throw new InterventionLegalContractError(
        "invalid-argument",
        "unknown lifecycle status",
        {lifecycleName, status},
    );
  }
  return status;
}

function allowedTransitions(lifecycleName, status) {
  assertKnownStatus(lifecycleName, status);
  return lifecycleRequired(lifecycleName).transitions[status];
}

function canTransition(lifecycleName, currentStatus, nextStatus) {
  assertKnownStatus(lifecycleName, currentStatus);
  assertKnownStatus(lifecycleName, nextStatus);
  return allowedTransitions(lifecycleName, currentStatus).includes(nextStatus);
}

function assertTransition(lifecycleName, currentStatus, nextStatus) {
  if (!canTransition(lifecycleName, currentStatus, nextStatus)) {
    throw new InterventionLegalContractError(
        "failed-precondition",
        "lifecycle transition denied",
        {lifecycleName, currentStatus, nextStatus},
    );
  }
  return true;
}

function isTerminal(lifecycleName, status) {
  return allowedTransitions(lifecycleName, status).length === 0;
}

module.exports = Object.freeze({
  LEGAL_MATTER_TRANSITIONS,
  ASSESSMENT_TRANSITIONS,
  PLAN_TRANSITIONS,
  ACTION_TRANSITIONS,
  APPROVAL_REQUEST_TRANSITIONS,
  PROFESSIONAL_TRANSITIONS,
  LIFECYCLES,
  assertKnownStatus,
  allowedTransitions,
  canTransition,
  assertTransition,
  isTerminal,
});
