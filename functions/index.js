const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

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
