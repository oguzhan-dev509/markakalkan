/* eslint-disable max-len */
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {createAuthoritySubmissionService} = require("./service");

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
  if (["profile.not_found", "intervention.not_found", "submission.not_found", "package.not_found"].includes(error.code)) {
    return new HttpsError("not-found", "Resmî başvuru veya kaynak kaydı bulunamadı.");
  }
  if (error.code === "source.mismatch") {
    return new HttpsError("failed-precondition", "Koruma profili ile sınır müdahalesi bağlantısı uyumlu değil.");
  }
  if (error.code === "source.precondition_failed") {
    return new HttpsError("failed-precondition", "Resmî iletim kaynağı gerekli koşulları sağlamıyor.");
  }
  if (error.code === "idempotency.conflict") {
    return new HttpsError("already-exists", "Aynı istek kimliği farklı içerikle daha önce kullanılmış.");
  }
  if (["status.invalid_transition", "status.precondition_failed"].includes(error.code)) {
    return new HttpsError("failed-precondition", "İstenen durum geçişi veya güvenlik kapısı mevcut kayıt için uygun değil.");
  }
  if (error.code === "scope.too_large") {
    return new HttpsError("resource-exhausted", "Resmî iletim kapsamı güvenli sınırı aşıyor.");
  }
  if (error.code === "internal") {
    return new HttpsError("internal", "Resmî başvuru ve iletim işlemi tamamlanamadı.");
  }
  return new HttpsError("invalid-argument", "Geçersiz resmî başvuru veya iletim isteği.");
}

function createHandler(method, {
  db,
  clock,
  resolveContext,
  appCheck,
  log = logger,
}) {
  const service = createAuthoritySubmissionService({db, clock, resolveContext});
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
      log.info("customs authority submission callable completed", {
        method,
        duplicate: result.duplicate === true,
        transactionCommitted: result.transactionCommitted === true,
        readOnly: result.readOnly === true,
      });
      return result;
    } catch (error) {
      log.error("customs authority submission callable failed", {
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

function buildCreateCustomsAuthoritySubmission({db}) {
  return build("createSubmission", WRITE_OPTIONS, {db});
}
function buildUpdateCustomsAuthoritySubmission({db}) {
  return build("updateSubmission", WRITE_OPTIONS, {db});
}
function buildTransitionCustomsAuthoritySubmission({db}) {
  return build("transitionSubmission", WRITE_OPTIONS, {db});
}
function buildGenerateCustomsSubmissionPackage({db}) {
  return build("generatePackage", WRITE_OPTIONS, {db});
}
function buildRecordCustomsExternalSubmission({db}) {
  return build("recordExternalSubmission", WRITE_OPTIONS, {db});
}
function buildRecordCustomsSubmissionReceipt({db}) {
  return build("recordReceipt", WRITE_OPTIONS, {db});
}
function buildAppendCustomsAuthorityResponse({db}) {
  return build("appendResponse", WRITE_OPTIONS, {db});
}
function buildListCustomsAuthoritySubmissions({db}) {
  return build("listSubmissions", READ_OPTIONS, {db});
}
function buildGetCustomsAuthoritySubmissionDetail({db}) {
  return build("submissionDetail", READ_OPTIONS, {db});
}

module.exports = {
  READ_OPTIONS,
  WRITE_OPTIONS,
  buildAppendCustomsAuthorityResponse,
  buildCreateCustomsAuthoritySubmission,
  buildGenerateCustomsSubmissionPackage,
  buildGetCustomsAuthoritySubmissionDetail,
  buildListCustomsAuthoritySubmissions,
  buildRecordCustomsSubmissionReceipt,
  buildRecordCustomsExternalSubmission,
  buildTransitionCustomsAuthoritySubmission,
  buildUpdateCustomsAuthoritySubmission,
  createHandler,
  mapError,
};
