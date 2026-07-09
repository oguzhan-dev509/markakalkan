const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
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

setGlobalOptions({
  region: "europe-west3",
  maxInstances: 3,
});

function normalizeCode(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().toUpperCase();
}

function normalizePlatform(value) {
  const allowedPlatforms = [
    "web",
    "android",
    "ios",
    "windows",
    "macos",
    "linux",
    "other",
  ];

  if (typeof value !== "string") {
    return "other";
  }

  const normalized = value.trim().toLowerCase();

  return allowedPlatforms.includes(normalized) ? normalized : "other";
}

function normalizeSource(value) {
  return value === "qr" ? "qr" : "manual";
}

exports.verifyProductCode = onCall(
    {
      // App Check kurulmadan true yapılmamalıdır.
      enforceAppCheck: false,
      maxInstances: 3,
    },
    async (request) => {
      const publicCode = normalizeCode(request.data?.publicCode);
      const platform = normalizePlatform(request.data?.platform);
      const source = normalizeSource(request.data?.source);

      if (
        publicCode.length < 10 ||
        publicCode.length > 80 ||
        !/^MK-[A-Z0-9-]+$/.test(publicCode)
      ) {
        throw new HttpsError(
            "invalid-argument",
            "Geçerli bir MarkaKalkan ürün kodu girilmelidir.",
        );
      }

      const publicCodeRef = db
          .collection("publicProductCodes")
          .doc(publicCode);

      const privateCodeRef = db
          .collection("productCodes")
          .doc(publicCode);

      const scanRef = db.collection("verificationScans").doc();

      try {
        const result = await db.runTransaction(async (transaction) => {
          const publicSnapshot = await transaction.get(publicCodeRef);
          const privateSnapshot = await transaction.get(privateCodeRef);

          const verifiedAt = admin.firestore.Timestamp.now();

          if (!publicSnapshot.exists || !privateSnapshot.exists) {
            transaction.set(scanRef, {
              publicCode,
              found: false,
              result: "not_found",
              platform,
              source,
              repeatScan: false,
              suspicious: false,
              createdAt: verifiedAt,
            });

            return {
              found: false,
              publicCode,
              result: "not_found",
            };
          }

          const publicData = publicSnapshot.data();
          const privateData = privateSnapshot.data();

          const previousScanCount =
            Number.isInteger(privateData.scanCount) ?
              privateData.scanCount :
              0;

          const nextScanCount = previousScanCount + 1;
          const repeatScan = nextScanCount > 1;

          transaction.update(privateCodeRef, {
            scanCount: nextScanCount,
            firstVerifiedAt:
              privateData.firstVerifiedAt ?? verifiedAt,
            lastVerifiedAt: verifiedAt,
            updatedAt: verifiedAt,
          });

          transaction.set(scanRef, {
            publicCode,
            ownerUid: privateData.ownerUid,
            productId: privateData.productId,
            batchId: privateData.batchId,
            brandName: publicData.brandName,
            productName: publicData.productName,
            batchNumber: publicData.batchNumber,
            status: privateData.status,
            found: true,
            result: privateData.status,
            platform,
            source,
            scanNumber: nextScanCount,
            repeatScan,
            suspicious: false,
            createdAt: verifiedAt,
          });

          return {
            found: true,
            publicCode,
            brandName: publicData.brandName,
            productName: publicData.productName,
            batchNumber: publicData.batchNumber,
            status: privateData.status,
            scanCount: nextScanCount,
            repeatScan,
          };
        });

        logger.info("Product code verified", {
          publicCode,
          found: result.found,
          result: result.result ?? result.status,
          platform,
          source,
        });

        return result;
      } catch (error) {
        logger.error("Product verification failed", {
          publicCode,
          error,
        });

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            "Ürün kodu doğrulanırken sunucu hatası oluştu.",
        );
      }
    },
);

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
