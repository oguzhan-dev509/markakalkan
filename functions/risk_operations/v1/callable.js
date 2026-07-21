/* eslint-disable max-len */
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {createHash} = require("node:crypto");
const {RiskOperationsError, riskOperationsDiagnosticsV1} = require("./contracts");
const {createRiskOperationsReadServiceV1} = require("./service");
const CALLABLE_NAME = "listRiskOperationsReadModel";
const CALLABLE_OPTIONS = Object.freeze({region: "europe-west3", enforceAppCheck: true, maxInstances: 3});
const ADAPTER_VERSION = "risk-operations-read-adapter-v1";
const hashDiagnosticId = (value) => createHash("sha256").update(value, "utf8").digest("hex");
function diagnosticLogFields(diagnostics, revision = process.env.K_REVISION || "unknown") {
  return Object.freeze({hashedBrowserTabSessionId: hashDiagnosticId(diagnostics.browserTabSessionId), hashedAppBootId: hashDiagnosticId(diagnostics.appBootId), authEpoch: diagnostics.authEpoch, hashedNavigationRequestId: hashDiagnosticId(diagnostics.navigationRequestId), hashedRouteEntryId: hashDiagnosticId(diagnostics.routeEntryId), hashedPageInstanceId: hashDiagnosticId(diagnostics.pageInstanceId), hashedLoadAttemptId: hashDiagnosticId(diagnostics.loadAttemptId), navigationType: diagnostics.navigationType, routeEntryCause: diagnostics.routeEntryCause, pageshowPersisted: diagnostics.pageshowPersisted, initialVisibilityState: diagnostics.initialVisibilityState, documentReferrerPresent: diagnostics.documentReferrerPresent, serviceWorkerControlled: diagnostics.serviceWorkerControlled, lifecycleQuality: diagnostics.lifecycleQuality, trigger: diagnostics.trigger, attemptSequence: diagnostics.attemptSequence, revision, adapterVersion: ADAPTER_VERSION});
}
function createRiskOperationsCallableHandlerV1({db, clock, logInfo = (event) => logger.info(event.eventName, event)}) {
  const service = createRiskOperationsReadServiceV1({db, clock}); return async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekir."); if (!request.app?.appId) throw new HttpsError("unauthenticated", "App Check doğrulaması gerekir."); try {
      const diagnostics = riskOperationsDiagnosticsV1(request.data || {}); const correlation = diagnosticLogFields(diagnostics);
      logInfo({eventName: "risk_operations_read_started", ...correlation, authPresent: true, appCheckPresent: true, appCheckValidated: true});
      const result = await service.list(request.data || {}, {uid: request.auth.uid});
      logInfo({eventName: "risk_operations_read_completed", ...correlation, outcome: "read_completed", itemCount: result.items.length, partialSources: result.sourceAvailability.filter((item) => item.status !== "available").map((item) => item.sourceSystem), transactionCommitted: false, writeAttempted: false});
      return result;
    } catch (error) {
      if (error instanceof RiskOperationsError) throw new HttpsError(error.code, error.message); throw new HttpsError("internal", "Risk görünümü güvenli biçimde hazırlanamadı.");
    }
  };
}
function buildListRiskOperationsReadModel({db}) {
  return onCall(CALLABLE_OPTIONS, createRiskOperationsCallableHandlerV1({db, clock: {now: () => new Date().toISOString()}}));
}
module.exports = {ADAPTER_VERSION, CALLABLE_NAME, CALLABLE_OPTIONS, buildListRiskOperationsReadModel, createRiskOperationsCallableHandlerV1, diagnosticLogFields, hashDiagnosticId};
