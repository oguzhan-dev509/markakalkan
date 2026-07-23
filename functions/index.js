const {setGlobalOptions} = require("firebase-functions");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const {
  buildAppendCaseReviewTaskEvent,
  buildCreateCaseReviewTask,
  buildGetCaseReviewTaskDetail,
  buildListCaseReviewTasks,
} = require("./case_evidence_center/v1/review_tasks");
const {
  buildAppendCaseGraphEvent,
  buildCreateCaseParty,
  buildCreateCaseRelationship,
  buildGetCasePartyDetail,
  buildGetCaseUnifiedTimeline,
  buildListCasePartyWorkspace,
  buildUpdateCasePartyProfile,
} = require("./case_evidence_center/v1/party_relationships");

const {
  buildCreateSupplyProtectionControl,
  buildUpdateSupplyProtectionControl,
} = require("./supply_security/protection_controls");

const {
  buildCreateSupplyProductionAsset,
  buildUpdateSupplyProductionAsset,
  buildListSupplyProductionAssets,
} = require("./supply_security/production_assets");

const {
  buildCreateCounterfeitTwinRecord,
  buildUpdateCounterfeitTwinRecord,
} = require("./counterfeit_twin/counterfeit_twin_records");

const {
  buildCreateIpCreationPriorityDraft,
  buildUpdateIpCreationPriorityDraft,
  buildSealIpCreationPriorityRecord,
  buildCreateIpCreationPriorityVersion,
} = require("./ip_creation_priority/ip_creation_priority_records");

const {
  buildEnsureIpCreationRegistryOwnerIdentity,
} = require(
    "./ip_creation_priority/ip_creation_registry_owner_identity",
);

const {
  buildListMyBrandApplications,
} = require("./brand_portfolio/brand_applications");

const {
  buildGetMyCorporateAccess,
} = require("./brand_portfolio/corporate_access");

const {
  buildVerifyAdminEntryGate,
  buildGetMyPlatformAdminAccess,
  buildListBrandApplicationsForAdmin,
  buildReviewBrandApplication,
} = require("./admin/brand_application_admin");

const {
  buildSubmitCounterfeitTwinReport,
  buildListCounterfeitTwinReportsForAdmin,
  buildReviewCounterfeitTwinReport,
  buildDeleteCounterfeitTwinReport,
  buildListPublicCounterfeitTwinComparisons,
  buildGetPublicCounterfeitTwinComparison,
} = require("./counterfeit_twin/counterfeit_twin_radar");

const {
  buildDispatchDigitalDetectiveTask,
} = require(
    "./digital_detective/digital_detective_dispatch",
);
const {
  buildAiFieldOperationBridge,
} = require(
    "./digital_detective/ai_field_operation_bridge",
);
const {
  buildReceiveDigitalDetectiveResult,
} = require(
    "./digital_detective/digital_detective_result",
);
const {
  buildPersistMonitoringRiskSignalPilot,
} = require(
    "./shared_risk/monitoring/v1/monitoring_callable",
);
const {
  buildProvisionInternalTenantBrandPilot,
} = require(
    "./tenant_management/internal_provisioning/v1/callable",
);
const {
  buildListRiskOperationsReadModel,
} = require("./risk_operations/v1");
const {
  buildPromoteRiskOperationToSharedRisk,
} = require("./shared_risk/promotion/v1");
const {
  buildCreateCaseFromRiskOperation,
  buildListCaseEvidenceCenter,
  buildGetCaseEvidenceDetail,
  buildListCaseEvidenceVault,
  buildGetCaseEvidenceItemDetail,
  buildAppendCaseEvidenceChainEvent,
} = require("./case_evidence_center/v1");

setGlobalOptions({
  region: "europe-west3",
  maxInstances: 3,
});

const {
  buildTraceabilityCallables,
} = require("./traceability/traceability");

const traceabilityCallables = buildTraceabilityCallables({
  db,
  admin,
  onCall,
  HttpsError,
  logger,
});

exports.verifyProductCode = traceabilityCallables.verifyProductCode;
exports.listSuspiciousVerificationScans =
  traceabilityCallables.listSuspiciousVerificationScans;
exports.reviewSuspiciousVerificationScan =
  traceabilityCallables.reviewSuspiciousVerificationScan;
exports.createTraceabilityCaseFromScan =
  traceabilityCallables.createTraceabilityCaseFromScan;
exports.listTraceabilityCases =
  traceabilityCallables.listTraceabilityCases;

exports.createSupplyProtectionControl =
    buildCreateSupplyProtectionControl({db, admin});

exports.updateSupplyProtectionControl =
    buildUpdateSupplyProtectionControl({db, admin});

exports.createSupplyProductionAsset =
    buildCreateSupplyProductionAsset({db, admin});

exports.updateSupplyProductionAsset =
    buildUpdateSupplyProductionAsset({db, admin});

exports.listSupplyProductionAssets =
    buildListSupplyProductionAssets({db});

exports.listMyBrandApplications =
    buildListMyBrandApplications({db});

exports.getMyCorporateAccess =
    buildGetMyCorporateAccess({db});

exports.verifyAdminEntryGate =
    buildVerifyAdminEntryGate({db, admin});

exports.getMyPlatformAdminAccess =
    buildGetMyPlatformAdminAccess({db});

exports.listBrandApplicationsForAdmin =
    buildListBrandApplicationsForAdmin({db});

exports.reviewBrandApplication =
    buildReviewBrandApplication({db, admin});

exports.submitCounterfeitTwinReport =
    buildSubmitCounterfeitTwinReport({db, admin});

exports.listCounterfeitTwinReportsForAdmin =
    buildListCounterfeitTwinReportsForAdmin({db});

exports.reviewCounterfeitTwinReport =
    buildReviewCounterfeitTwinReport({db, admin});

exports.deleteCounterfeitTwinReport =
    buildDeleteCounterfeitTwinReport({db, admin});

exports.listPublicCounterfeitTwinComparisons =
    buildListPublicCounterfeitTwinComparisons({db});

exports.getPublicCounterfeitTwinComparison =
    buildGetPublicCounterfeitTwinComparison({db});

exports.createCounterfeitTwinRecord =
    buildCreateCounterfeitTwinRecord({db, admin});

exports.updateCounterfeitTwinRecord =
    buildUpdateCounterfeitTwinRecord({db, admin});


exports.ensureIpCreationRegistryOwnerIdentity =
    buildEnsureIpCreationRegistryOwnerIdentity({db, admin});

exports.createIpCreationPriorityDraft =
    buildCreateIpCreationPriorityDraft({db, admin});

exports.updateIpCreationPriorityDraft =
    buildUpdateIpCreationPriorityDraft({db, admin});

exports.sealIpCreationPriorityRecord =
    buildSealIpCreationPriorityRecord({db, admin});

exports.createIpCreationPriorityVersion =
    buildCreateIpCreationPriorityVersion({db, admin});
exports.dispatchDigitalDetectiveTask =
    buildDispatchDigitalDetectiveTask({
      db,
      admin,
      onDocumentCreated,
      logger,
    });
exports.bridgeAiFieldOperation =
    buildAiFieldOperationBridge({
      db,
      admin,
      onDocumentCreated,
      logger,
    });
exports.receiveDigitalDetectiveResult =
    buildReceiveDigitalDetectiveResult({
      db,
      admin,
      onRequest,
      logger,
    });
exports.persistMonitoringRiskSignalPilot =
    buildPersistMonitoringRiskSignalPilot({db});
exports.provisionInternalTenantBrandPilot =
    buildProvisionInternalTenantBrandPilot({db});
exports.listRiskOperationsReadModel =
    buildListRiskOperationsReadModel({db});
exports.promoteRiskOperationToSharedRisk =
    buildPromoteRiskOperationToSharedRisk({db});
exports.listCaseEvidenceCenter =
    buildListCaseEvidenceCenter({db});
exports.getCaseEvidenceDetail =
    buildGetCaseEvidenceDetail({db});
exports.listCaseEvidenceVault = buildListCaseEvidenceVault({db});
exports.getCaseEvidenceItemDetail = buildGetCaseEvidenceItemDetail({db});
exports.appendCaseEvidenceChainEvent = buildAppendCaseEvidenceChainEvent({db});
exports.listCaseReviewTasks = buildListCaseReviewTasks({db, admin});
exports.getCaseReviewTaskDetail = buildGetCaseReviewTaskDetail({db, admin});
exports.createCaseReviewTask = buildCreateCaseReviewTask({db, admin});
exports.appendCaseReviewTaskEvent =
    buildAppendCaseReviewTaskEvent({db, admin});
exports.listCasePartyWorkspace = buildListCasePartyWorkspace({db, admin});
exports.getCasePartyDetail = buildGetCasePartyDetail({db, admin});
exports.getCaseUnifiedTimeline = buildGetCaseUnifiedTimeline({db, admin});
exports.createCaseParty = buildCreateCaseParty({db, admin});
exports.createCaseRelationship = buildCreateCaseRelationship({db, admin});
exports.appendCaseGraphEvent = buildAppendCaseGraphEvent({db, admin});
exports.updateCasePartyProfile = buildUpdateCasePartyProfile({db, admin});
exports.createCaseFromRiskOperation =
    buildCreateCaseFromRiskOperation({db});
