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
  ProfessionalServicesCanonicalError,
} = require("./canonical");
const {
  ProfessionalServicesContractError,
} = require("./contracts");
const {
  ProfessionalServicesIdentifierError,
} = require("./identifiers");
const {
  ProfessionalServicesLifecycleError,
} = require("./lifecycle");
const {
  buildCreateServiceAssignmentService,
  buildCreateServiceEngagementService,
  buildCreateServiceRequestService,
  buildPublishAgentOutputService,
  buildRecordAgentOutputService,
  buildRecordAgentReviewService,
  buildStartAgentRunService,
  buildTransitionServiceRequestService,
} = require("./service");
const {
  createProfessionalServicesFirestoreAdapter,
} = require("./firestore_adapter");

const CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

const CALLABLE_NAMES = Object.freeze({
  CREATE_SERVICE_REQUEST: "createProfessionalServiceRequest",
  TRANSITION_SERVICE_REQUEST: "transitionProfessionalServiceRequest",
  CREATE_SERVICE_ENGAGEMENT: "createProfessionalServiceEngagement",
  CREATE_SERVICE_ASSIGNMENT: "createProfessionalServiceAssignment",
  START_AGENT_RUN: "startProfessionalAgentRun",
  RECORD_AGENT_OUTPUT: "recordProfessionalAgentOutput",
  RECORD_AGENT_REVIEW: "recordProfessionalAgentReview",
  PUBLISH_AGENT_OUTPUT: "publishProfessionalAgentOutput",
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

const PROFESSIONAL_ERROR_NAMES = new Set([
  "ProfessionalServicesCanonicalError",
  "ProfessionalServicesContractError",
  "ProfessionalServicesIdentifierError",
  "ProfessionalServicesLifecycleError",
]);

const CLIENT_ACTOR_FIELDS = Object.freeze([
  "actorUid",
  "requestedByUid",
  "createdByUid",
  "updatedByUid",
  "statusChangedByUid",
  "assignedByUid",
  "initiatedByUid",
  "reviewedByUid",
  "publishedByUid",
  "authorizedByUid",
  "preparedByUid",
  "decidedByUid",
]);

function productionClock() {
  return new Date().toISOString();
}

function isProfessionalServicesError(error) {
  return error instanceof ProfessionalServicesCanonicalError ||
    error instanceof ProfessionalServicesContractError ||
    error instanceof ProfessionalServicesIdentifierError ||
    error instanceof ProfessionalServicesLifecycleError ||
    PROFESSIONAL_ERROR_NAMES.has(error?.name);
}

function mapProfessionalServicesError(error) {
  if (error instanceof HttpsError) return error;

  if (isProfessionalServicesError(error)) {
    const sourceCode = error.code === "canonical.invalid" ?
      "invalid-argument" :
      error.code;
    const code = SUPPORTED_HTTPS_CODES.has(sourceCode) ?
      sourceCode :
      "internal";
    const message = code === "internal" ?
      "Profesyonel Hizmetler işlemi tamamlanamadı." :
      error.message;
    const details = code === "internal" ? undefined : error.details;
    return new HttpsError(code, message, details);
  }

  return new HttpsError(
      "internal",
      "Profesyonel Hizmetler işlemi tamamlanamadı.",
  );
}

function assertCallableRequest(request) {
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

function collectClientActorFields(
    value,
    path = "$",
    found = [],
    seen = new WeakSet(),
) {
  if (!value || typeof value !== "object") {
    return found;
  }
  if (seen.has(value)) {
    return found;
  }
  seen.add(value);

  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      collectClientActorFields(item, `${path}[${index}]`, found, seen);
    });
    return found;
  }

  for (const [field, item] of Object.entries(value)) {
    const itemPath = `${path}.${field}`;
    if (CLIENT_ACTOR_FIELDS.includes(field)) {
      found.push(itemPath);
    }
    collectClientActorFields(item, itemPath, found, seen);
  }
  return found;
}

function injectAuthenticatedActor(data, nestedActorPath, uid) {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    return data;
  }

  const unsupported = collectClientActorFields(data);
  if (unsupported.length > 0) {
    throw new HttpsError(
        "invalid-argument",
        "Aktör kimliği istemci tarafından gönderilemez.",
        {unsupported: [...new Set(unsupported)].sort()},
    );
  }

  let command = {
    ...data,
    actorUid: uid,
  };

  if (Array.isArray(nestedActorPath) && nestedActorPath.length === 2) {
    const [containerField, actorField] = nestedActorPath;
    const container = command[containerField];
    if (
      container !== null &&
      typeof container === "object" &&
      !Array.isArray(container)
    ) {
      command = {
        ...command,
        [containerField]: Object.freeze({
          ...container,
          [actorField]: uid,
        }),
      };
    }
  }

  return Object.freeze(command);
}

function createProfessionalServicesServiceBundle({
  db = getFirestore(),
  clock = productionClock,
} = {}) {
  const store = createProfessionalServicesFirestoreAdapter(db);
  return Object.freeze({
    createServiceRequest: buildCreateServiceRequestService({store, clock}),
    transitionServiceRequest:
      buildTransitionServiceRequestService({store, clock}),
    createServiceEngagement:
      buildCreateServiceEngagementService({store, clock}),
    createServiceAssignment:
      buildCreateServiceAssignmentService({store, clock}),
    startAgentRun: buildStartAgentRunService({store, clock}),
    recordAgentOutput: buildRecordAgentOutputService({store, clock}),
    recordAgentReview: buildRecordAgentReviewService({store, clock}),
    publishAgentOutput: buildPublishAgentOutputService({store, clock}),
  });
}

function createProfessionalServicesCallableHandlers({
  services,
  log = logger,
}) {
  if (!services || typeof services !== "object") {
    throw new TypeError("services must be an object");
  }

  const definitions = Object.freeze({
    createServiceRequest: Object.freeze({
      service: services.createServiceRequest,
      nestedActorPath: Object.freeze([
        "serviceRequest",
        "requestedByUid",
      ]),
    }),
    transitionServiceRequest: Object.freeze({
      service: services.transitionServiceRequest,
      nestedActorPath: null,
    }),
    createServiceEngagement: Object.freeze({
      service: services.createServiceEngagement,
      nestedActorPath: Object.freeze([
        "serviceEngagement",
        "createdByUid",
      ]),
    }),
    createServiceAssignment: Object.freeze({
      service: services.createServiceAssignment,
      nestedActorPath: Object.freeze([
        "serviceAssignment",
        "assignedByUid",
      ]),
    }),
    startAgentRun: Object.freeze({
      service: services.startAgentRun,
      nestedActorPath: Object.freeze([
        "agentRunRequest",
        "initiatedByUid",
      ]),
    }),
    recordAgentOutput: Object.freeze({
      service: services.recordAgentOutput,
      nestedActorPath: null,
    }),
    recordAgentReview: Object.freeze({
      service: services.recordAgentReview,
      nestedActorPath: Object.freeze([
        "agentHumanReview",
        "reviewedByUid",
      ]),
    }),
    publishAgentOutput: Object.freeze({
      service: services.publishAgentOutput,
      nestedActorPath: null,
    }),
  });

  for (const [method, definition] of Object.entries(definitions)) {
    if (typeof definition.service !== "function") {
      throw new TypeError(`${method} service must be a function`);
    }
  }

  const buildHandler = (method) => {
    const definition = definitions[method];
    return async (request) => {
      const uid = assertCallableRequest(request);
      try {
        const command = injectAuthenticatedActor(
            request.data,
            definition.nestedActorPath,
            uid,
        );
        const result = await definition.service(command);
        log.info("professional services callable completed", {
          method,
          outcome: "completed",
          resultType: result?.resultType || null,
          idempotentReplay:
            Boolean(result?.idempotentReplay === true),
          transactionCommitted:
            result?.idempotentReplay === true ? false : true,
        });
        return result;
      } catch (error) {
        const mapped = mapProfessionalServicesError(error);
        log.error("professional services callable failed", {
          method,
          outcome: "failed",
          code: mapped.code,
        });
        throw mapped;
      }
    };
  };

  return Object.freeze({
    createServiceRequest: buildHandler("createServiceRequest"),
    transitionServiceRequest: buildHandler("transitionServiceRequest"),
    createServiceEngagement: buildHandler("createServiceEngagement"),
    createServiceAssignment: buildHandler("createServiceAssignment"),
    startAgentRun: buildHandler("startAgentRun"),
    recordAgentOutput: buildHandler("recordAgentOutput"),
    recordAgentReview: buildHandler("recordAgentReview"),
    publishAgentOutput: buildHandler("publishAgentOutput"),
  });
}

function resolveBuildDependencies(dependencies = {}) {
  const services = dependencies.services ||
    createProfessionalServicesServiceBundle({
      db: dependencies.db,
      clock: dependencies.clock || productionClock,
    });
  const handlers = createProfessionalServicesCallableHandlers({
    services,
    log: dependencies.log || logger,
  });
  return Object.freeze({
    handlers,
    onCallImpl: dependencies.onCallImpl || onCall,
  });
}

function buildCallable(method, dependencies = {}) {
  const resolved = resolveBuildDependencies(dependencies);
  return resolved.onCallImpl(
      CALLABLE_OPTIONS,
      resolved.handlers[method],
  );
}

function buildCreateProfessionalServiceRequestCallable(
    dependencies = {},
) {
  return buildCallable("createServiceRequest", dependencies);
}

function buildTransitionProfessionalServiceRequestCallable(
    dependencies = {},
) {
  return buildCallable("transitionServiceRequest", dependencies);
}

function buildCreateProfessionalServiceEngagementCallable(
    dependencies = {},
) {
  return buildCallable("createServiceEngagement", dependencies);
}

function buildCreateProfessionalServiceAssignmentCallable(
    dependencies = {},
) {
  return buildCallable("createServiceAssignment", dependencies);
}

function buildStartProfessionalAgentRunCallable(dependencies = {}) {
  return buildCallable("startAgentRun", dependencies);
}

function buildRecordProfessionalAgentOutputCallable(dependencies = {}) {
  return buildCallable("recordAgentOutput", dependencies);
}

function buildRecordProfessionalAgentReviewCallable(dependencies = {}) {
  return buildCallable("recordAgentReview", dependencies);
}

function buildPublishProfessionalAgentOutputCallable(dependencies = {}) {
  return buildCallable("publishAgentOutput", dependencies);
}

module.exports = Object.freeze({
  CALLABLE_NAMES,
  CALLABLE_OPTIONS,
  CLIENT_ACTOR_FIELDS,
  SUPPORTED_HTTPS_CODES,
  assertCallableRequest,
  buildCreateProfessionalServiceAssignmentCallable,
  buildCreateProfessionalServiceEngagementCallable,
  buildCreateProfessionalServiceRequestCallable,
  buildPublishProfessionalAgentOutputCallable,
  buildRecordProfessionalAgentOutputCallable,
  buildRecordProfessionalAgentReviewCallable,
  buildStartProfessionalAgentRunCallable,
  buildTransitionProfessionalServiceRequestCallable,
  collectClientActorFields,
  createProfessionalServicesCallableHandlers,
  createProfessionalServicesServiceBundle,
  injectAuthenticatedActor,
  mapProfessionalServicesError,
  productionClock,
});
