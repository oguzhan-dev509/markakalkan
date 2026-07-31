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
} = require("./contracts");
const {
  buildCreateLegalMatterService,
  buildRecordApprovalDecisionService,
  buildTransitionLegalMatterService,
} = require("./service");
const {
  createInterventionLegalFirestoreAdapter,
} = require("./firestore_adapter");

const CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

const CALLABLE_NAMES = Object.freeze({
  CREATE_LEGAL_MATTER: "createInterventionLegalMatter",
  TRANSITION_LEGAL_MATTER: "transitionInterventionLegalMatter",
  RECORD_APPROVAL_DECISION: "recordInterventionLegalApprovalDecision",
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

function productionClock() {
  return new Date().toISOString();
}

function mapInterventionLegalError(error) {
  if (error instanceof HttpsError) return error;

  if (
    error instanceof InterventionLegalContractError ||
    error?.name === "InterventionLegalContractError"
  ) {
    const code = SUPPORTED_HTTPS_CODES.has(error.code) ?
      error.code :
      "internal";
    const message = code === "internal" ?
      "Müdahale ve Hukuk işlemi tamamlanamadı." :
      error.message;
    const details = code === "internal" ? undefined : error.details;
    return new HttpsError(code, message, details);
  }

  return new HttpsError(
    "internal",
    "Müdahale ve Hukuk işlemi tamamlanamadı.",
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

function injectAuthenticatedActor(data, actorField, uid) {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    return data;
  }

  const clientActorFields = [
    "actorUid",
    "decidedByUid",
  ].filter((field) =>
    Object.prototype.hasOwnProperty.call(data, field));

  if (clientActorFields.length > 0) {
    throw new HttpsError(
      "invalid-argument",
      "Aktör kimliği istemci tarafından gönderilemez.",
      {unsupported: clientActorFields},
    );
  }

  return Object.freeze({
    ...data,
    [actorField]: uid,
  });
}

function createInterventionLegalServiceBundle({
  db = getFirestore(),
  clock = productionClock,
} = {}) {
  const store = createInterventionLegalFirestoreAdapter(db);
  return Object.freeze({
    createLegalMatter: buildCreateLegalMatterService({
      store,
      clock,
    }),
    transitionLegalMatter: buildTransitionLegalMatterService({
      store,
      clock,
    }),
    recordApprovalDecision: buildRecordApprovalDecisionService({
      store,
      clock,
    }),
  });
}

function createInterventionLegalCallableHandlers({
  services,
  log = logger,
}) {
  if (!services || typeof services !== "object") {
    throw new TypeError("services must be an object");
  }

  const definitions = Object.freeze({
    createLegalMatter: Object.freeze({
      service: services.createLegalMatter,
      actorField: "actorUid",
    }),
    transitionLegalMatter: Object.freeze({
      service: services.transitionLegalMatter,
      actorField: "actorUid",
    }),
    recordApprovalDecision: Object.freeze({
      service: services.recordApprovalDecision,
      actorField: "decidedByUid",
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
          definition.actorField,
          uid,
        );
        const result = await definition.service(command);
        log.info("intervention legal callable completed", {
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
        const mapped = mapInterventionLegalError(error);
        log.error("intervention legal callable failed", {
          method,
          outcome: "failed",
          code: mapped.code,
        });
        throw mapped;
      }
    };
  };

  return Object.freeze({
    createLegalMatter: buildHandler("createLegalMatter"),
    transitionLegalMatter: buildHandler("transitionLegalMatter"),
    recordApprovalDecision:
      buildHandler("recordApprovalDecision"),
  });
}

function resolveBuildDependencies(dependencies = {}) {
  const services = dependencies.services ||
    createInterventionLegalServiceBundle({
      db: dependencies.db,
      clock: dependencies.clock || productionClock,
    });
  const handlers = createInterventionLegalCallableHandlers({
    services,
    log: dependencies.log || logger,
  });
  return Object.freeze({
    handlers,
    onCallImpl: dependencies.onCallImpl || onCall,
  });
}

function buildCreateInterventionLegalMatterCallable(
    dependencies = {},
) {
  const resolved = resolveBuildDependencies(dependencies);
  return resolved.onCallImpl(
    CALLABLE_OPTIONS,
    resolved.handlers.createLegalMatter,
  );
}

function buildTransitionInterventionLegalMatterCallable(
    dependencies = {},
) {
  const resolved = resolveBuildDependencies(dependencies);
  return resolved.onCallImpl(
    CALLABLE_OPTIONS,
    resolved.handlers.transitionLegalMatter,
  );
}

function buildRecordInterventionLegalApprovalDecisionCallable(
    dependencies = {},
) {
  const resolved = resolveBuildDependencies(dependencies);
  return resolved.onCallImpl(
    CALLABLE_OPTIONS,
    resolved.handlers.recordApprovalDecision,
  );
}

module.exports = Object.freeze({
  CALLABLE_NAMES,
  CALLABLE_OPTIONS,
  SUPPORTED_HTTPS_CODES,
  productionClock,
  mapInterventionLegalError,
  assertCallableRequest,
  injectAuthenticatedActor,
  createInterventionLegalServiceBundle,
  createInterventionLegalCallableHandlers,
  buildCreateInterventionLegalMatterCallable,
  buildTransitionInterventionLegalMatterCallable,
  buildRecordInterventionLegalApprovalDecisionCallable,
});
