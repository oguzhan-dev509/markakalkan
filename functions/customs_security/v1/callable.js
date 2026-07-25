/* eslint-disable max-len */
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {createCustomsSecurityService} = require("./service");

const READ_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: false,
  maxInstances: 3,
});
const WRITE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

function mapError(error) {
  if (error instanceof HttpsError) return error;
  if (error.code === "unauthenticated") {
    return new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  }
  if (error.code === "authorization.denied") {
    return new HttpsError("permission-denied", "Bu işlem için marka sahibi yetkisi gerekir.");
  }
  if (["profile.not_found", "intervention.not_found"].includes(error.code)) {
    return new HttpsError("not-found", "Gümrük güvenliği kaydı bulunamadı.");
  }
  if (error.code === "profile.not_active") {
    return new HttpsError("failed-precondition", "Aktif bir Gümrük Koruma Profili gerekir.");
  }
  if (error.code === "idempotency.conflict") {
    return new HttpsError("already-exists", "Aynı istek kimliği farklı içerikle daha önce kullanılmış.");
  }
  if (["status.invalid_transition", "status.precondition_failed"].includes(error.code)) {
    return new HttpsError("failed-precondition", "İstenen durum geçişi mevcut kayıt için uygun değil.");
  }
  if (error.code === "scope.too_large") {
    return new HttpsError("resource-exhausted", "Gümrük güvenliği kapsamı güvenli sınırı aşıyor.");
  }
  if (error.code === "internal") {
    return new HttpsError("internal", "Gümrük güvenliği işlemi tamamlanamadı.");
  }
  return new HttpsError("invalid-argument", "Geçersiz gümrük güvenliği isteği.");
}

function createHandler(method, {
  db,
  clock,
  resolveContext,
  appCheck,
  log = logger,
}) {
  const service = createCustomsSecurityService({db, clock, resolveContext});
  return async (invocation) => {
    if (!invocation.auth?.uid) {
      throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    }
    if (appCheck && !invocation.app) {
      throw new HttpsError("failed-precondition", "Uygulama doğrulaması gerekir.");
    }
    try {
      const result = await service[method](invocation.data || {}, {
        uid: invocation.auth.uid,
      });
      log.info("customs security callable completed", {
        method,
        duplicate: result.duplicate === true,
        transactionCommitted: result.transactionCommitted === true,
        readOnly: result.readOnly === true,
      });
      return result;
    } catch (error) {
      log.error("customs security callable failed", {
        method,
        code: error.code || "unknown",
        message: error.message,
      });
      throw mapError(error);
    }
  };
}

function build(method, options, dependencies) {
  return onCall(options, createHandler(method, {
    ...dependencies,
    appCheck: options.enforceAppCheck === true,
  }));
}

function buildCreateCustomsProtectionProfile({db}) {
  return build("createProfile", WRITE_OPTIONS, {db});
}
function buildUpdateCustomsProtectionProfile({db}) {
  return build("updateProfile", WRITE_OPTIONS, {db});
}
function buildTransitionCustomsProtectionProfile({db}) {
  return build("transitionProfile", WRITE_OPTIONS, {db});
}
function buildListCustomsProtectionProfiles({db}) {
  return build("listProfiles", READ_OPTIONS, {db});
}
function buildGetCustomsProtectionProfileDetail({db}) {
  return build("profileDetail", READ_OPTIONS, {db});
}
function buildCreateCustomsBorderIntervention({db}) {
  return build("createIntervention", WRITE_OPTIONS, {db});
}
function buildUpdateCustomsBorderIntervention({db}) {
  return build("updateIntervention", WRITE_OPTIONS, {db});
}
function buildTransitionCustomsBorderIntervention({db}) {
  return build("transitionIntervention", WRITE_OPTIONS, {db});
}
function buildListCustomsBorderInterventions({db}) {
  return build("listInterventions", READ_OPTIONS, {db});
}
function buildGetCustomsBorderInterventionDetail({db}) {
  return build("interventionDetail", READ_OPTIONS, {db});
}

module.exports = {
  READ_OPTIONS,
  WRITE_OPTIONS,
  buildCreateCustomsBorderIntervention,
  buildCreateCustomsProtectionProfile,
  buildGetCustomsBorderInterventionDetail,
  buildGetCustomsProtectionProfileDetail,
  buildListCustomsBorderInterventions,
  buildListCustomsProtectionProfiles,
  buildTransitionCustomsBorderIntervention,
  buildTransitionCustomsProtectionProfile,
  buildUpdateCustomsBorderIntervention,
  buildUpdateCustomsProtectionProfile,
  createHandler,
  mapError,
};
