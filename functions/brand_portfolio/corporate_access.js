const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const APPLICATIONS = "brandApplications";
const BRANDS = "brands";

function cleanText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function applicationSummary(doc) {
  const data = doc.data() || {};
  return {
    applicationId: doc.id,
    brandName: cleanText(data.brandName),
    companyName: cleanText(data.companyName),
    status: cleanText(data.status) || "pending",
    reviewNote: cleanText(data.reviewNote),
    createdAtMillis: data.createdAt?.toMillis?.() ?? null,
    reviewedAtMillis: data.reviewedAt?.toMillis?.() ?? null,
  };
}

function buildGetMyCorporateAccess({db}) {
  return onCall({enforceAppCheck: false, maxInstances: 3}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
          "unauthenticated",
          "Kurumsal erisim icin oturum acmalisiniz.",
      );
    }

    try {
      const brandSnapshot = await db.collection(BRANDS).doc(uid).get();
      if (brandSnapshot.exists) {
        const brand = brandSnapshot.data() || {};
        const brandStatus = cleanText(brand.status) || "active";
        const accessGranted = brandStatus === "active";

        return {
          accessGranted,
          state: accessGranted ? "active" : "inactive",
          brand: {
            brandName: cleanText(brand.brandName),
            companyName: cleanText(brand.companyName),
            status: brandStatus,
          },
          application: null,
        };
      }

      const applicationsSnapshot = await db.collection(APPLICATIONS)
          .where("applicantUid", "==", uid)
          .limit(100)
          .get();

      const applications = applicationsSnapshot.docs
          .map(applicationSummary)
          .sort(
              (a, b) =>
                (b.createdAtMillis || 0) - (a.createdAtMillis || 0),
          );

      const latest = applications[0] || null;
      if (!latest) {
        return {
          accessGranted: false,
          state: "none",
          brand: null,
          application: null,
        };
      }

      const rawStatus = cleanText(latest.status).toLowerCase();
      let state = "pending";
      if (rawStatus === "under_review" || rawStatus === "reviewing") {
        state = "under_review";
      } else if (rawStatus === "rejected") {
        state = "rejected";
      } else if (rawStatus === "approved") {
        state = "approved_pending_activation";
      }

      return {
        accessGranted: false,
        state,
        brand: null,
        application: latest,
      };
    } catch (error) {
      logger.error("Corporate access could not be resolved", {uid, error});
      throw new HttpsError(
          "internal",
          "Kurumsal erisim durumu yuklenemedi.",
      );
    }
  });
}

module.exports = {buildGetMyCorporateAccess};
