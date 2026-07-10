const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  ROLES,
  requireAuthenticatedUser,
  requirePlatformRole,
} = require("../common/platform_admin");

const REPORTS = "counterfeit_twin_reports";
const PUBLIC_COMPARISONS = "counterfeit_twin_public_comparisons";

function text(value, fieldName, maxLength, required = false) {
  if (value === null || value === undefined) {
    if (required) {
      throw new HttpsError("invalid-argument", `${fieldName} zorunludur.`);
    }
    return "";
  }
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }
  const cleaned = value.trim();
  if ((required && !cleaned) || cleaned.length > maxLength) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return cleaned;
}

function stringList(value, fieldName, maxItems = 12, maxLength = 1000) {
  if (value === null || value === undefined) return [];
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return [...new Set(value.map((item) =>
    text(item, fieldName, maxLength, true),
  ))];
}

function positiveAmount(value, fieldName) {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return Math.round(value * 100) / 100;
}

function cleanReportPayload(data) {
  return {
    originalBrandName: text(
        data.originalBrandName,
        "originalBrandName",
        240,
        true,
    ),
    originalProductName: text(
        data.originalProductName,
        "originalProductName",
        500,
        true,
    ),
    originalCountry: text(data.originalCountry, "originalCountry", 120),
    originalImageUrls: stringList(
        data.originalImageUrls,
        "originalImageUrls",
    ),
    suspectedBrandName: text(
        data.suspectedBrandName,
        "suspectedBrandName",
        240,
    ),
    suspectedProductName: text(
        data.suspectedProductName,
        "suspectedProductName",
        500,
        true,
    ),
    claimedOriginCountry: text(
        data.claimedOriginCountry,
        "claimedOriginCountry",
        120,
    ),
    allegedSupplyCountry: text(
        data.allegedSupplyCountry,
        "allegedSupplyCountry",
        120,
    ),
    suspectedImageUrls: stringList(
        data.suspectedImageUrls,
        "suspectedImageUrls",
    ),
    platformName: text(data.platformName, "platformName", 160, true),
    storeDisplayName: text(
        data.storeDisplayName,
        "storeDisplayName",
        240,
    ),
    listingUrl: text(data.listingUrl, "listingUrl", 1200),
    authorizedPriceMin: positiveAmount(
        data.authorizedPriceMin,
        "authorizedPriceMin",
    ),
    authorizedPriceMax: positiveAmount(
        data.authorizedPriceMax,
        "authorizedPriceMax",
    ),
    suspectedPrice: positiveAmount(data.suspectedPrice, "suspectedPrice"),
    currency: text(data.currency || "TRY", "currency", 12, true).toUpperCase(),
    differenceNotes: stringList(
        data.differenceNotes,
        "differenceNotes",
        20,
        500,
    ),
    evidenceNotes: text(data.evidenceNotes, "evidenceNotes", 5000, true),
  };
}

function buildSubmitCounterfeitTwinReport({db, admin}) {
  return onCall(async (request) => {
    const actor = requireAuthenticatedUser(request);
    const payload = cleanReportPayload(request.data || {});
    const now = admin.firestore.Timestamp.now();
    const reportRef = db.collection(REPORTS).doc();
    await reportRef.create({
      ...payload,
      reporterUid: actor.uid,
      reporterEmail: actor.email,
      status: "submitted",
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      reviewedByUid: null,
      reviewedByEmail: null,
      reviewNote: "",
      counterfeitTwinRecordId: null,
      publicComparisonId: null,
    });
    logger.info("Counterfeit twin report submitted", {
      reportId: reportRef.id,
      reporterUid: actor.uid,
    });
    return {reportId: reportRef.id, status: "submitted"};
  });
}

function buildListCounterfeitTwinReportsForAdmin({db}) {
  return onCall(async (request) => {
    await requirePlatformRole(request, db, ROLES.counterfeitTwinReviewer);
    const snapshot = await db.collection(REPORTS)
        .orderBy("createdAt", "desc")
        .limit(200)
        .get();
    return {
      reports: snapshot.docs.map((doc) => {
        const data = doc.data();
        const {createdAt, updatedAt, reviewedAt, ...safeData} = data;
        return {
          id: doc.id,
          ...safeData,
          createdAtMillis: createdAt?.toMillis?.() ?? null,
          updatedAtMillis: updatedAt?.toMillis?.() ?? null,
          reviewedAtMillis: reviewedAt?.toMillis?.() ?? null,
        };
      }),
    };
  });
}

function buildReviewCounterfeitTwinReport({db, admin}) {
  return onCall(async (request) => {
    const decision = text(request.data?.decision, "decision", 40, true);
    const role = decision === "published" ?
      ROLES.counterfeitTwinPublisher :
      ROLES.counterfeitTwinReviewer;
    const actor = await requirePlatformRole(request, db, role);
    if (!["under_review", "rejected", "published"].includes(decision)) {
      throw new HttpsError("invalid-argument", "Gecersiz karar.");
    }
    const reportId = text(request.data?.reportId, "reportId", 240, true);
    if (reportId.includes("/")) {
      throw new HttpsError("invalid-argument", "reportId gecersiz.");
    }
    const reviewNote = text(request.data?.reviewNote, "reviewNote", 5000);
    if (decision === "rejected" && !reviewNote) {
      throw new HttpsError("invalid-argument", "Ret gerekcesi zorunludur.");
    }

    const reportRef = db.collection(REPORTS).doc(reportId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Bildirim bulunamadi.");
      }
      const report = snapshot.data() || {};
      if (!["submitted", "under_review"].includes(report.status)) {
        throw new HttpsError(
            "failed-precondition",
            "Bildirim bu karar icin uygun durumda degil.",
        );
      }
      const now = admin.firestore.Timestamp.now();
      const update = {
        status: decision,
        reviewNote,
        reviewedAt: now,
        reviewedByUid: actor.uid,
        reviewedByEmail: actor.email,
        updatedAt: now,
      };

      if (decision === "published") {
        const publicRef = db.collection(PUBLIC_COMPARISONS).doc();
        transaction.create(publicRef, {
          reportId,
          counterfeitTwinRecordId: null,
          title: `${report.originalBrandName}: Gercek Urun - Sahte Ikiz`,
          originalBrandName: report.originalBrandName,
          originalProductName: report.originalProductName,
          originalCountry: report.originalCountry || "",
          originalImageUrls: report.originalImageUrls || [],
          suspectedBrandName:
            report.suspectedBrandName || report.originalBrandName,
          suspectedProductName: report.suspectedProductName,
          claimedOriginCountry: report.claimedOriginCountry || "",
          allegedSupplyCountry: report.allegedSupplyCountry || "",
          suspectedImageUrls: report.suspectedImageUrls || [],
          platformName: report.platformName,
          storeDisplayName: report.storeDisplayName || "",
          authorizedPriceMin: report.authorizedPriceMin ?? null,
          authorizedPriceMax: report.authorizedPriceMax ?? null,
          suspectedPrice: report.suspectedPrice ?? null,
          currency: report.currency || "TRY",
          differenceNotes: report.differenceNotes || [],
          publicSummary: reviewNote,
          verificationLabel: "delille_dogrulandi",
          publishedAt: now,
        });
        update.counterfeitTwinRecordId = null;
        update.publicComparisonId = publicRef.id;
      }

      transaction.update(reportRef, update);
    });

    logger.info("Counterfeit twin report reviewed", {
      reportId,
      decision,
      adminUid: actor.uid,
    });
    return {reportId, status: decision};
  });
}

function buildListPublicCounterfeitTwinComparisons({db}) {
  return onCall(async () => {
    const snapshot = await db.collection(PUBLIC_COMPARISONS)
        .orderBy("publishedAt", "desc")
        .limit(100)
        .get();
    return {
      comparisons: snapshot.docs.map((doc) => {
        const data = doc.data();
        const {publishedAt, ...safeData} = data;
        return {
          id: doc.id,
          ...safeData,
          publishedAtMillis: publishedAt?.toMillis?.() ?? null,
        };
      }),
    };
  });
}

module.exports = {
  buildSubmitCounterfeitTwinReport,
  buildListCounterfeitTwinReportsForAdmin,
  buildReviewCounterfeitTwinReport,
  buildListPublicCounterfeitTwinComparisons,
};
