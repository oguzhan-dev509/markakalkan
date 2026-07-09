const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

const ASSET_CLASSES = new Set(["physical", "digital", "hybrid"]);
const ASSET_TYPES = new Set([
  "injection_mold", "blow_mold", "casting_mold", "press_die",
  "cutting_die", "textile_pattern", "printing_plate",
  "printing_cylinder", "tablet_punch_die", "pcb_stencil", "fixture",
  "gauge", "assembly_tool", "cnc_program", "cad_file", "cam_file",
  "three_d_model", "packaging_artwork", "label_artwork", "other",
]);

function requiredText(value, fieldName, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }
  const cleaned = value.trim();
  if (!cleaned || cleaned.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} 1-${maxLength} karakter olmalidir.`,
    );
  }
  return cleaned;
}

function optionalText(value, fieldName, maxLength) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }
  const cleaned = value.trim();
  if (!cleaned) return null;
  if (cleaned.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} en fazla ${maxLength} karakter olabilir.`,
    );
  }
  return cleaned;
}

function requiredId(value, fieldName) {
  const cleaned = requiredText(value, fieldName, 240);
  if (cleaned.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} "/" karakteri iceremez.`,
    );
  }
  return cleaned;
}

function optionalId(value, fieldName) {
  if (value === null || value === undefined) return null;
  return requiredId(value, fieldName);
}

function requiredEnum(value, fieldName, allowedValues) {
  if (typeof value !== "string" || !allowedValues.has(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return value;
}

function stringList(value, fieldName) {
  if (!Array.isArray(value) || value.length > 200) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz liste.`);
  }
  const cleaned = value.map((item) => requiredId(item, fieldName));
  if (new Set(cleaned).size !== cleaned.length) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} tekrar eden deger iceremez.`,
    );
  }
  return cleaned;
}

function plainObject(value, fieldName) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} nesne olmalidir.`);
  }
  if (JSON.stringify(value).length > 20000) {
    throw new HttpsError("invalid-argument", `${fieldName} cok buyuk.`);
  }
  return value;
}

function deterministicAssetId(tenantId, normalizedCode) {
  const digest = crypto
      .createHash("sha256")
      .update(`${tenantId}\n${normalizedCode}`, "utf8")
      .digest("hex")
      .slice(0, 40);
  return `spa_${digest}`;
}

function operationalFields(data) {
  return {
    name: requiredText(data.name, "Varlik adi", 200),
    assetClass: requiredEnum(data.assetClass, "Varlik sinifi", ASSET_CLASSES),
    assetType: requiredEnum(data.assetType, "Varlik turu", ASSET_TYPES),
    partnerId: optionalId(data.partnerId, "Partner kimligi"),
    facilityId: optionalId(data.facilityId, "Tesis kimligi"),
    description: optionalText(data.description, "Aciklama", 5000),
    manufacturer: optionalText(data.manufacturer, "Uretici", 300),
    modelNumber: optionalText(data.modelNumber, "Model numarasi", 200),
    serialNumber: optionalText(data.serialNumber, "Seri numarasi", 200),
    internalReference: optionalText(data.internalReference, "Ic referans", 300),
    physicalLocation: optionalText(
        data.physicalLocation,
        "Fiziksel konum",
        500,
    ),
    digitalStorageReference: optionalText(
        data.digitalStorageReference,
        "Dijital saklama referansi",
        1000,
    ),
    version: optionalText(data.version, "Surum", 100),
    fileHash: optionalText(data.fileHash, "Dosya ozeti", 256),
    confidentialityLevel: optionalText(
        data.confidentialityLevel,
        "Gizlilik seviyesi",
        100,
    ),
    relatedProductIds: stringList(
        data.relatedProductIds ?? [],
        "Iliskili urun kimlikleri",
    ),
    relatedIpAssetIds: stringList(
        data.relatedIpAssetIds ?? [],
        "Iliskili fikri varlik kimlikleri",
    ),
    evidenceDocumentIds: stringList(
        data.evidenceDocumentIds ?? [],
        "Kanit belge kimlikleri",
    ),
    notes: optionalText(data.notes, "Notlar", 5000),
    metadata: plainObject(data.metadata ?? {}, "Metadata"),
  };
}

async function validateTargets(transaction, db, uid, partnerId, facilityId) {
  const reads = [];
  if (partnerId) {
    reads.push(transaction.get(
        db.collection("supply_security_partners").doc(partnerId),
    ));
  }
  if (facilityId) {
    reads.push(transaction.get(
        db.collection("supply_security_facilities").doc(facilityId),
    ));
  }

  const snapshots = await Promise.all(reads);
  let index = 0;
  if (partnerId) {
    const snapshot = snapshots[index++];
    const partner = snapshot.exists ? snapshot.data() : null;
    if (!partner) {
      throw new HttpsError("failed-precondition", "Partner bulunamadi.");
    }
    if (partner.tenantId !== uid || partner.brandId !== uid) {
      throw new HttpsError(
          "permission-denied",
          "Partner bu markaya ait degil.",
      );
    }
    if (partner.status === "archived") {
      throw new HttpsError(
          "failed-precondition",
          "Arsivlenmis partner varliga baglanamaz.",
      );
    }
  }

  if (facilityId) {
    const snapshot = snapshots[index];
    const facility = snapshot.exists ? snapshot.data() : null;
    if (!facility) {
      throw new HttpsError("failed-precondition", "Tesis bulunamadi.");
    }
    if (facility.tenantId !== uid || facility.brandId !== uid) {
      throw new HttpsError("permission-denied", "Tesis bu markaya ait degil.");
    }
    if (facility.status === "archived") {
      throw new HttpsError(
          "failed-precondition",
          "Arsivlenmis tesis varliga baglanamaz.",
      );
    }
    if (partnerId && facility.partnerId !== partnerId) {
      throw new HttpsError(
          "failed-precondition",
          "Secilen tesis belirtilen partnere bagli degil.",
      );
    }
  }
}

function buildCreateSupplyProductionAsset({db, admin}) {
  return onCall(
      {enforceAppCheck: false, maxInstances: 3},
      async (request) => {
        const uid = request.auth?.uid;
        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Uretim varligi olusturmak icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const assetCode = requiredText(data.assetCode, "Varlik kodu", 100);
        const assetCodeNormalized = assetCode.toUpperCase();
        const fields = operationalFields(data);
        const assetId = deterministicAssetId(uid, assetCodeNormalized);
        const assetRef = db
            .collection("supply_security_production_assets")
            .doc(assetId);

        try {
          await db.runTransaction(async (transaction) => {
            const existing = await transaction.get(assetRef);
            if (existing.exists) {
              throw new HttpsError(
                  "already-exists",
                  "Bu varlik kodu zaten kullaniliyor.",
              );
            }

            await validateTargets(
                transaction,
                db,
                uid,
                fields.partnerId,
                fields.facilityId,
            );

            const now = admin.firestore.Timestamp.now();
            transaction.create(assetRef, {
              tenantId: uid,
              brandId: uid,
              assetCode,
              assetCodeNormalized,
              ...fields,
              status: "draft",
              destroyedAt: null,
              destroyedBy: null,
              destructionReason: null,
              destructionEvidenceDocumentIds: [],
              archivedAt: null,
              archivedBy: null,
              archiveReason: null,
              createdAt: now,
              createdBy: uid,
              updatedAt: now,
              updatedBy: uid,
            });
          });

          logger.info("Supply production asset created", {
            assetId,
            tenantId: uid,
            assetCodeNormalized,
          });
          return {assetId};
        } catch (error) {
          logger.error("Supply production asset creation failed", {
            tenantId: uid,
            assetCodeNormalized,
            error,
          });
          if (error instanceof HttpsError) throw error;
          throw new HttpsError(
              "internal",
              "Uretim varligi olusturulurken sunucu hatasi olustu.",
          );
        }
      },
  );
}

function buildUpdateSupplyProductionAsset({db, admin}) {
  return onCall(
      {enforceAppCheck: false, maxInstances: 3},
      async (request) => {
        const uid = request.auth?.uid;
        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Uretim varligini guncellemek icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const assetId = requiredId(data.assetId, "Varlik kimligi");
        const fields = operationalFields(data);
        const assetRef = db
            .collection("supply_security_production_assets")
            .doc(assetId);

        try {
          await db.runTransaction(async (transaction) => {
            const snapshot = await transaction.get(assetRef);
            const current = snapshot.exists ? snapshot.data() : null;
            if (!current) {
              throw new HttpsError(
                  "not-found",
                  "Guncellenecek uretim varligi bulunamadi.",
              );
            }
            if (current.tenantId !== uid || current.brandId !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Uretim varligi bu marka hesabina ait degil.",
              );
            }
            if (current.status === "archived") {
              throw new HttpsError(
                  "failed-precondition",
                  "Arsivlenmis uretim varligi guncellenemez.",
              );
            }
            if (current.status === "destroyed") {
              throw new HttpsError(
                  "failed-precondition",
                  "Imha edilmis uretim varligi guncellenemez.",
              );
            }

            await validateTargets(
                transaction,
                db,
                uid,
                fields.partnerId,
                fields.facilityId,
            );

            transaction.update(assetRef, {
              ...fields,
              updatedAt: admin.firestore.Timestamp.now(),
              updatedBy: uid,
            });
          });

          logger.info("Supply production asset updated", {
            assetId,
            tenantId: uid,
          });
          return {assetId};
        } catch (error) {
          logger.error("Supply production asset update failed", {
            assetId,
            tenantId: uid,
            error,
          });
          if (error instanceof HttpsError) throw error;
          throw new HttpsError(
              "internal",
              "Uretim varligi guncellenirken sunucu hatasi olustu.",
          );
        }
      },
  );
}

module.exports = {
  buildCreateSupplyProductionAsset,
  buildUpdateSupplyProductionAsset,
};
