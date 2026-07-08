const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const COLLECTION = "counterfeit_twin_records";

const STATUSES = new Set([
  "draft", "suspected", "under_review", "probable",
  "confirmed", "dismissed", "contained", "archived",
]);

const CONFIDENCE_LEVELS = new Set([
  "low", "medium", "high", "very_high", "verified",
]);

const RISK_LEVELS = new Set(["low", "medium", "high", "critical"]);

const REVIEW_STATUSES = new Set([
  "not_started", "in_progress", "awaiting_evidence",
  "awaiting_expert_review", "completed",
]);

const CLONE_METHODS = new Set([
  "exact_replica",
  "packaging_imitation",
  "logo_imitation",
  "brand_name_variation",
  "product_name_imitation",
  "trade_dress_imitation",
  "color_scheme_imitation",
  "product_image_theft",
  "description_copying",
  "fake_authorized_seller",
  "domain_impersonation",
  "social_store_impersonation",
  "repackaging",
  "content_or_formula_imitation",
  "label_or_certificate_forgery",
  "mixed",
  "unknown",
]);

function requiredText(value, fieldName, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }
  const cleaned = value.trim();
  if (cleaned.length === 0 || cleaned.length > maxLength) {
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
  if (cleaned.length === 0) return null;
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
  const cleaned = optionalText(value, fieldName, 240);
  if (cleaned && cleaned.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} "/" karakteri iceremez.`,
    );
  }
  return cleaned;
}

function requiredEnum(value, fieldName, allowedValues) {
  if (typeof value !== "string" || !allowedValues.has(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return value;
}

function score(value, fieldName) {
  if (!Number.isInteger(value) || value < 0 || value > 100) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} 0-100 arasinda tam sayi olmalidir.`,
    );
  }
  return value;
}

function nonNegativeInt(value, fieldName) {
  if (!Number.isInteger(value) || value < 0) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} negatif olmayan tam sayi olmalidir.`,
    );
  }
  return value;
}

function stringList(value, fieldName, maxItems = 500) {
  if (!Array.isArray(value) || value.length > maxItems) {
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

function cloneMethodList(value) {
  if (!Array.isArray(value) || value.length > CLONE_METHODS.size) {
    throw new HttpsError("invalid-argument", "cloneMethods gecersiz liste.");
  }
  const cleaned = value.map((item) =>
    requiredEnum(item, "cloneMethods", CLONE_METHODS),
  );
  if (new Set(cleaned).size !== cleaned.length) {
    throw new HttpsError(
        "invalid-argument",
        "cloneMethods tekrar eden deger iceremez.",
    );
  }
  return cleaned;
}

function optionalDate(value, fieldName, admin) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return admin.firestore.Timestamp.fromDate(parsed);
}

function plainObject(value, fieldName) {
  if (value === null || value === undefined) return {};
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} nesne olmalidir.`);
  }
  return value;
}

function cleanPayload(data, admin) {
  const status = requiredEnum(data.status, "status", STATUSES);
  const dismissReason = optionalText(data.dismissReason, "dismissReason", 5000);
  const archiveReason = optionalText(data.archiveReason, "archiveReason", 5000);

  if (status === "dismissed" && !dismissReason) {
    throw new HttpsError(
        "invalid-argument",
        "Curutulen kayit icin dismissReason zorunludur.",
    );
  }
  if (status === "archived" && !archiveReason) {
    throw new HttpsError(
        "invalid-argument",
        "Arsivlenen kayit icin archiveReason zorunludur.",
    );
  }

  return {
    title: requiredText(data.title, "title", 240),
    status,
    confidenceLevel: requiredEnum(
        data.confidenceLevel,
        "confidenceLevel",
        CONFIDENCE_LEVELS,
    ),
    riskLevel: requiredEnum(data.riskLevel, "riskLevel", RISK_LEVELS),
    reviewStatus: requiredEnum(
        data.reviewStatus,
        "reviewStatus",
        REVIEW_STATUSES,
    ),
    primaryCloneMethod: requiredEnum(
        data.primaryCloneMethod,
        "primaryCloneMethod",
        CLONE_METHODS,
    ),
    originalProductId: optionalId(data.originalProductId, "originalProductId"),
    originalIpAssetId: optionalId(data.originalIpAssetId, "originalIpAssetId"),
    originalBrandName: optionalText(
        data.originalBrandName,
        "originalBrandName",
        240,
    ),
    originalProductName: optionalText(
        data.originalProductName,
        "originalProductName",
        500,
    ),
    originalVariantName: optionalText(
        data.originalVariantName,
        "originalVariantName",
        500,
    ),
    suspectedBrandName: optionalText(
        data.suspectedBrandName,
        "suspectedBrandName",
        240,
    ),
    suspectedProductName: optionalText(
        data.suspectedProductName,
        "suspectedProductName",
        500,
    ),
    suspectedVariantName: optionalText(
        data.suspectedVariantName,
        "suspectedVariantName",
        500,
    ),
    claimedManufacturer: optionalText(
        data.claimedManufacturer,
        "claimedManufacturer",
        500,
    ),
    countryCode: optionalText(
        data.countryCode,
        "countryCode",
        16,
    )?.toUpperCase() || null,
    region: optionalText(data.region, "region", 240),
    cloneMethods: cloneMethodList(data.cloneMethods),
    visualSimilarityScore: score(
        data.visualSimilarityScore,
        "visualSimilarityScore",
    ),
    packagingSimilarityScore: score(
        data.packagingSimilarityScore,
        "packagingSimilarityScore",
    ),
    logoSimilarityScore: score(data.logoSimilarityScore, "logoSimilarityScore"),
    nameSimilarityScore: score(data.nameSimilarityScore, "nameSimilarityScore"),
    textSimilarityScore: score(data.textSimilarityScore, "textSimilarityScore"),
    priceAnomalyScore: score(data.priceAnomalyScore, "priceAnomalyScore"),
    overallSimilarityScore: score(
        data.overallSimilarityScore,
        "overallSimilarityScore",
    ),
    sourceIds: stringList(data.sourceIds, "sourceIds"),
    listingIds: stringList(data.listingIds, "listingIds"),
    sellerIds: stringList(data.sellerIds, "sellerIds"),
    storeIds: stringList(data.storeIds, "storeIds"),
    monitoredPageIds: stringList(data.monitoredPageIds, "monitoredPageIds"),
    mediaAssetIds: stringList(data.mediaAssetIds, "mediaAssetIds"),
    evidencePackageIds: stringList(
        data.evidencePackageIds,
        "evidencePackageIds",
    ),
    monitoringEventIds: stringList(
        data.monitoringEventIds,
        "monitoringEventIds",
    ),
    monitoringSignalIds: stringList(
        data.monitoringSignalIds,
        "monitoringSignalIds",
    ),
    cloneFamilyId: optionalId(data.cloneFamilyId, "cloneFamilyId"),
    waveId: optionalId(data.waveId, "waveId"),
    relatedTwinRecordIds: stringList(
        data.relatedTwinRecordIds,
        "relatedTwinRecordIds",
    ),
    recurrenceCount: nonNegativeInt(data.recurrenceCount, "recurrenceCount"),
    firstSeenAt: optionalDate(data.firstSeenAt, "firstSeenAt", admin),
    lastSeenAt: optionalDate(data.lastSeenAt, "lastSeenAt", admin),
    dismissReason,
    archiveReason,
    notes: optionalText(data.notes, "notes", 10000),
    metadata: plainObject(data.metadata, "metadata"),
  };
}

function lifecycleFields(payload, existing, admin) {
  const now = admin.firestore.Timestamp.now();
  return {
    confirmedAt: payload.status === "confirmed" ?
      (existing?.confirmedAt || now) :
      null,
    dismissedAt: payload.status === "dismissed" ?
      (existing?.dismissedAt || now) :
      null,
    archivedAt: payload.status === "archived" ?
      (existing?.archivedAt || now) :
      null,
  };
}

function buildCreateCounterfeitTwinRecord({db, admin}) {
  return onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Oturum acmaniz gerekir.");
    }

    try {
      const data = request.data || {};
      const recordCode = requiredText(data.recordCode, "recordCode", 100);
      const recordCodeNormalized = recordCode.toUpperCase();
      const payload = cleanPayload(data, admin);
      const lifecycle = lifecycleFields(payload, null, admin);
      const recordRef = db.collection(COLLECTION).doc();
      const duplicateQuery = db
          .collection(COLLECTION)
          .where("tenantId", "==", uid)
          .where("brandId", "==", uid)
          .where("recordCodeNormalized", "==", recordCodeNormalized)
          .limit(1);

      await db.runTransaction(async (transaction) => {
        const duplicate = await transaction.get(duplicateQuery);
        if (!duplicate.empty) {
          throw new HttpsError(
              "already-exists",
              "Bu sahte ikiz kayit kodu zaten kullaniliyor.",
          );
        }

        const now = admin.firestore.Timestamp.now();
        transaction.create(recordRef, {
          tenantId: uid,
          brandId: uid,
          recordCode,
          recordCodeNormalized,
          ...payload,
          ...lifecycle,
          createdAt: now,
          createdBy: uid,
          updatedAt: now,
          updatedBy: null,
        });
      });

      logger.info("Counterfeit twin record created", {
        recordId: recordRef.id,
        tenantId: uid,
        status: payload.status,
      });

      return {recordId: recordRef.id};
    } catch (error) {
      logger.error("Counterfeit twin record create failed", {
        tenantId: uid,
        error,
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
          "internal",
          "Sahte ikiz kaydi olusturulurken sunucu hatasi olustu.",
      );
    }
  });
}

function buildUpdateCounterfeitTwinRecord({db, admin}) {
  return onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Oturum acmaniz gerekir.");
    }

    const data = request.data || {};
    const recordId = requiredId(data.recordId, "recordId");

    try {
      const payload = cleanPayload(data, admin);
      const recordRef = db.collection(COLLECTION).doc(recordId);

      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(recordRef);
        const existing = snapshot.data();

        if (!snapshot.exists || !existing) {
          throw new HttpsError("not-found", "Sahte ikiz kaydi bulunamadi.");
        }
        if (existing.tenantId !== uid || existing.brandId !== uid) {
          throw new HttpsError(
              "permission-denied",
              "Bu sahte ikiz kaydina erisim yetkiniz yok.",
          );
        }
        if (existing.status === "archived") {
          throw new HttpsError(
              "failed-precondition",
              "Arsivlenmis sahte ikiz kaydi guncellenemez.",
          );
        }

        const lifecycle = lifecycleFields(payload, existing, admin);
        transaction.update(recordRef, {
          ...payload,
          ...lifecycle,
          updatedAt: admin.firestore.Timestamp.now(),
          updatedBy: uid,
        });
      });

      logger.info("Counterfeit twin record updated", {
        recordId,
        tenantId: uid,
        status: payload.status,
      });

      return {recordId};
    } catch (error) {
      logger.error("Counterfeit twin record update failed", {
        recordId,
        tenantId: uid,
        error,
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
          "internal",
          "Sahte ikiz kaydi guncellenirken sunucu hatasi olustu.",
      );
    }
  });
}

module.exports = {
  buildCreateCounterfeitTwinRecord,
  buildUpdateCounterfeitTwinRecord,
};
