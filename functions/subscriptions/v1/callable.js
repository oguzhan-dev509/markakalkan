/* eslint-disable max-len */
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
  SubscriptionRequestContractError,
} = require("./contracts");
const {
  createSubscriptionRequestFirestoreAdapter,
} = require("./firestore_adapter");
const {
  buildCreateSubscriptionRequestService,
} = require("./service");

const CREATE_SUBSCRIPTION_REQUEST_CALLABLE =
  "createSubscriptionServiceRequest";

const CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

const CLIENT_ACTOR_FIELDS = Object.freeze([
  "actorUid",
  "actorEmail",
  "requestedByUid",
  "requestedByEmail",
  "createdByUid",
  "updatedByUid",
]);

const SUPPORTED_CODES = new Set([
  "invalid-argument",
  "failed-precondition",
  "permission-denied",
  "already-exists",
  "aborted",
  "resource-exhausted",
  "unavailable",
  "deadline-exceeded",
  "internal",
]);

function productionClock() {
  return new Date().toISOString();
}

function assertCallableRequest(request) {
  if (!request?.auth?.uid) {
    throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  }
  if (!request?.app?.appId) {
    throw new HttpsError(
        "failed-precondition",
        "Uygulama doğrulaması gerekir.",
    );
  }
  return Object.freeze({
    uid: request.auth.uid,
    email:
      typeof request.auth.token?.email === "string" ?
        request.auth.token.email.trim() || null :
        null,
  });
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

function injectAuthenticatedActor(data, actor) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "İstek verisi geçersiz.");
  }

  const unsupported = collectClientActorFields(data);
  if (unsupported.length > 0) {
    throw new HttpsError(
        "invalid-argument",
        "Aktör kimliği istemci tarafından gönderilemez.",
        {unsupported: [...new Set(unsupported)].sort()},
    );
  }

  return Object.freeze({
    ...data,
    actorUid: actor.uid,
    actorEmail: actor.email,
  });
}

function mapSubscriptionRequestError(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  if (
    error instanceof SubscriptionRequestContractError ||
    error?.name === "SubscriptionRequestContractError"
  ) {
    const code = SUPPORTED_CODES.has(error.code) ?
      error.code :
      "internal";
    return new HttpsError(
        code,
        code === "internal" ?
          "Abonelik talebi oluşturulamadı." :
          error.message,
    );
  }
  return new HttpsError("internal", "Abonelik talebi oluşturulamadı.");
}

function createSubscriptionRequestServiceBundle({
  db = getFirestore(),
  clock = productionClock,
} = {}) {
  const store = createSubscriptionRequestFirestoreAdapter(db);
  return Object.freeze({
    createSubscriptionRequest:
      buildCreateSubscriptionRequestService({store, clock}),
  });
}

function createSubscriptionRequestHandler({
  service,
  log = logger,
}) {
  if (typeof service !== "function") {
    throw new TypeError("service must be a function");
  }

  return async (request) => {
    const actor = assertCallableRequest(request);
    try {
      const command = injectAuthenticatedActor(request.data, actor);
      const result = await service(command);
      log.info("subscription service request completed", {
        outcome: "completed",
        resultType: result?.resultType || null,
        idempotentReplay: result?.idempotentReplay === true,
      });
      return result;
    } catch (error) {
      const mapped = mapSubscriptionRequestError(error);
      log.error("subscription service request failed", {
        outcome: "failed",
        code: mapped.code,
      });
      throw mapped;
    }
  };
}

function buildCreateSubscriptionServiceRequestCallable(
    dependencies = {},
) {
  const services = dependencies.services ||
    createSubscriptionRequestServiceBundle({
      db: dependencies.db,
      clock: dependencies.clock || productionClock,
    });
  const handler = createSubscriptionRequestHandler({
    service: services.createSubscriptionRequest,
    log: dependencies.log || logger,
  });
  const onCallImpl = dependencies.onCallImpl || onCall;
  return onCallImpl(CALLABLE_OPTIONS, handler);
}

module.exports = Object.freeze({
  CALLABLE_OPTIONS,
  CLIENT_ACTOR_FIELDS,
  CREATE_SUBSCRIPTION_REQUEST_CALLABLE,
  assertCallableRequest,
  buildCreateSubscriptionServiceRequestCallable,
  collectClientActorFields,
  createSubscriptionRequestHandler,
  createSubscriptionRequestServiceBundle,
  injectAuthenticatedActor,
  mapSubscriptionRequestError,
  productionClock,
});
