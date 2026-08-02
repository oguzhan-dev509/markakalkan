/* eslint-disable max-len */
"use strict";

const SERVICE_REQUEST_STATUSES = Object.freeze([
  "draft",
  "requested",
  "scoping",
  "awaiting_client_authorization",
  "awaiting_budget_approval",
  "ready_for_assignment",
  "assigned",
  "in_progress",
  "waiting_external",
  "blocked",
  "delivered",
  "revision_requested",
  "accepted",
  "closed",
  "cancelled",
]);

const SERVICE_REQUEST_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["requested", "cancelled"]),
  requested: Object.freeze(["scoping", "cancelled"]),
  scoping: Object.freeze([
    "awaiting_client_authorization",
    "awaiting_budget_approval",
    "ready_for_assignment",
    "cancelled",
  ]),
  awaiting_client_authorization: Object.freeze([
    "awaiting_budget_approval",
    "ready_for_assignment",
    "cancelled",
  ]),
  awaiting_budget_approval: Object.freeze([
    "awaiting_client_authorization",
    "ready_for_assignment",
    "cancelled",
  ]),
  ready_for_assignment: Object.freeze(["assigned", "cancelled"]),
  assigned: Object.freeze(["in_progress", "cancelled"]),
  in_progress: Object.freeze([
    "waiting_external",
    "blocked",
    "delivered",
    "cancelled",
  ]),
  waiting_external: Object.freeze([
    "in_progress",
    "blocked",
    "delivered",
    "cancelled",
  ]),
  blocked: Object.freeze(["in_progress", "cancelled"]),
  delivered: Object.freeze([
    "revision_requested",
    "accepted",
    "cancelled",
  ]),
  revision_requested: Object.freeze(["in_progress", "cancelled"]),
  accepted: Object.freeze(["closed"]),
  closed: Object.freeze([]),
  cancelled: Object.freeze([]),
});

const AGENT_TASK_STATUSES = Object.freeze([
  "draft",
  "queued",
  "running",
  "waiting_human_review",
  "revision_requested",
  "approved",
  "rejected",
  "published",
  "failed",
  "cancelled",
]);

const AGENT_TASK_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["queued", "cancelled"]),
  queued: Object.freeze(["running", "failed", "cancelled"]),
  running: Object.freeze([
    "waiting_human_review",
    "failed",
    "cancelled",
  ]),
  waiting_human_review: Object.freeze([
    "revision_requested",
    "approved",
    "rejected",
  ]),
  revision_requested: Object.freeze([
    "queued",
    "running",
    "cancelled",
  ]),
  approved: Object.freeze(["published"]),
  rejected: Object.freeze([]),
  published: Object.freeze([]),
  failed: Object.freeze(["queued", "cancelled"]),
  cancelled: Object.freeze([]),
});

class ProfessionalServicesLifecycleError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ProfessionalServicesLifecycleError";
    this.code = code;
  }
}

function assertKnownStatus(status, transitions, field) {
  if (!Object.prototype.hasOwnProperty.call(transitions, status)) {
    throw new ProfessionalServicesLifecycleError(
        "invalid-argument",
        `${field} invalid`,
    );
  }
}

function allowedTransitions(status, transitions, field) {
  assertKnownStatus(status, transitions, field);
  return transitions[status];
}

function assertTransition(currentStatus, nextStatus, transitions, field) {
  assertKnownStatus(currentStatus, transitions, `${field}.currentStatus`);
  assertKnownStatus(nextStatus, transitions, `${field}.nextStatus`);
  if (!transitions[currentStatus].includes(nextStatus)) {
    throw new ProfessionalServicesLifecycleError(
        "failed-precondition",
        `${field} transition denied`,
    );
  }
  return true;
}

function allowedServiceRequestTransitions(status) {
  return allowedTransitions(status, SERVICE_REQUEST_TRANSITIONS,
      "serviceRequestStatus");
}

function assertServiceRequestTransition(currentStatus, nextStatus) {
  return assertTransition(currentStatus, nextStatus,
      SERVICE_REQUEST_TRANSITIONS, "serviceRequest");
}

function isServiceRequestTerminal(status) {
  assertKnownStatus(status, SERVICE_REQUEST_TRANSITIONS,
      "serviceRequestStatus");
  return ["closed", "cancelled"].includes(status);
}

function allowedAgentTaskTransitions(status) {
  return allowedTransitions(status, AGENT_TASK_TRANSITIONS,
      "agentTaskStatus");
}

function assertAgentTaskTransition(currentStatus, nextStatus) {
  return assertTransition(currentStatus, nextStatus,
      AGENT_TASK_TRANSITIONS, "agentTask");
}

function isAgentTaskTerminal(status) {
  assertKnownStatus(status, AGENT_TASK_TRANSITIONS,
      "agentTaskStatus");
  return ["rejected", "published", "cancelled"].includes(status);
}

module.exports = Object.freeze({
  AGENT_TASK_STATUSES,
  AGENT_TASK_TRANSITIONS,
  SERVICE_REQUEST_STATUSES,
  SERVICE_REQUEST_TRANSITIONS,
  ProfessionalServicesLifecycleError,
  allowedAgentTaskTransitions,
  allowedServiceRequestTransitions,
  assertAgentTaskTransition,
  assertServiceRequestTransition,
  isAgentTaskTerminal,
  isServiceRequestTerminal,
});
