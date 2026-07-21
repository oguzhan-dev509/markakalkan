/* eslint-disable max-len */
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {RiskOperationsError} = require("./contracts");
const {createRiskOperationsReadServiceV1} = require("./service");
const CALLABLE_NAME = "listRiskOperationsReadModel";
const CALLABLE_OPTIONS = Object.freeze({region: "europe-west3", enforceAppCheck: true, maxInstances: 3});
function createRiskOperationsCallableHandlerV1({db, clock}) {
  const service = createRiskOperationsReadServiceV1({db, clock}); return async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir."); if (!request.app?.appId) throw new HttpsError("unauthenticated", "App Check doğrulaması gerekir."); try {
      return await service.list(request.data || {}, {uid: request.auth.uid});
    } catch (error) {
      if (error instanceof RiskOperationsError) throw new HttpsError(error.code, error.message); throw new HttpsError("internal", "Risk görünümü güvenli biçimde hazırlanamadı.");
    }
  };
}
function buildListRiskOperationsReadModel({db}) {
  return onCall(CALLABLE_OPTIONS, createRiskOperationsCallableHandlerV1({db, clock: {now: () => new Date().toISOString()}}));
}
module.exports = {CALLABLE_NAME, CALLABLE_OPTIONS, buildListRiskOperationsReadModel, createRiskOperationsCallableHandlerV1};
