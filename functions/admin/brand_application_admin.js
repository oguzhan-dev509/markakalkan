const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  ROLES,
  getPlatformAdminAccess,
  requirePlatformRole,
} = require("../common/platform_admin");

const APPLICATIONS = "brandApplications";
const BRANDS = "brands";

function cleanText(value, maxLength = 2000) {
  if (value === null || value === undefined) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Metin alani gecersiz.");
  }
  const cleaned = value.trim();
  if (cleaned.length > maxLength) {
    throw new HttpsError("invalid-argument", "Metin alani cok uzun.");
  }
  return cleaned;
}

function requiredId(value, fieldName) {
  const cleaned = cleanText(value, 240);
  if (!cleaned || cleaned.includes("/")) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return cleaned;
}

function buildGetMyPlatformAdminAccess({db}) {
  return onCall(async (request) => {
    const access = await getPlatformAdminAccess(request, db);
    return {
      active: access.active,
      roles: access.roles,
      displayName: access.displayName || "",
      email: access.email,
    };
  });
}

function buildListBrandApplicationsForAdmin({db}) {
  return onCall(async (request) => {
    await requirePlatformRole(
        request,
        db,
        ROLES.brandApplicationReviewer,
    );
    const snapshot = await db.collection(APPLICATIONS)
        .orderBy("createdAt", "desc")
        .limit(200)
        .get();
    return {
      applications: snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          applicantUid: cleanText(data.applicantUid, 240),
          applicantEmail: cleanText(data.applicantEmail, 240),
          companyName: cleanText(data.companyName, 300),
          brandName: cleanText(data.brandName, 240),
          businessType: cleanText(data.businessType, 120),
          sector: cleanText(data.sector, 160),
          authorizedPerson: cleanText(data.authorizedPerson, 240),
          phone: cleanText(data.phone, 80),
          taxNumber: cleanText(data.taxNumber, 80),
          website: cleanText(data.website, 500),
          problemDescription: cleanText(data.problemDescription, 3000),
          status: cleanText(data.status, 40) || "pending",
          reviewNote: cleanText(data.reviewNote, 3000),
          createdAtMillis: data.createdAt?.toMillis?.() ?? null,
          reviewedAtMillis: data.reviewedAt?.toMillis?.() ?? null,
        };
      }),
    };
  });
}

function buildReviewBrandApplication({db, admin}) {
  return onCall(async (request) => {
    const actor = await requirePlatformRole(
        request,
        db,
        ROLES.brandApplicationReviewer,
    );
    const applicationId = requiredId(
        request.data?.applicationId,
        "applicationId",
    );
    const decision = cleanText(request.data?.decision, 40);
    const reviewNote = cleanText(request.data?.reviewNote, 3000);
    if (!["under_review", "approved", "rejected"].includes(decision)) {
      throw new HttpsError("invalid-argument", "Gecersiz karar.");
    }
    if (decision === "rejected" && !reviewNote) {
      throw new HttpsError(
          "invalid-argument",
          "Ret karari icin gerekce zorunludur.",
      );
    }

    const applicationRef = db.collection(APPLICATIONS).doc(applicationId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(applicationRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Marka basvurusu bulunamadi.");
      }
      const data = snapshot.data() || {};
      const current = cleanText(data.status, 40) || "pending";
      if (!["pending", "under_review"].includes(current)) {
        throw new HttpsError(
            "failed-precondition",
            "Bu basvuru artik karara uygun durumda degil.",
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

      if (decision === "approved") {
        const applicantUid = requiredId(data.applicantUid, "applicantUid");
        const brandRef = db.collection(BRANDS).doc(applicantUid);
        const brandSnapshot = await transaction.get(brandRef);
        if (!brandSnapshot.exists) {
          transaction.create(brandRef, {
            ownerUid: applicantUid,
            applicantUid,
            applicationId,
            applicantEmail: cleanText(data.applicantEmail, 240),
            companyName: cleanText(data.companyName, 300),
            brandName: cleanText(data.brandName, 240),
            businessType: cleanText(data.businessType, 120),
            sector: cleanText(data.sector, 160),
            status: "active",
            createdAt: now,
            approvedAt: now,
            approvedByUid: actor.uid,
            approvedByEmail: actor.email,
          });
        }
        update.approvedAt = now;
      }

      transaction.update(applicationRef, update);
    });

    logger.info("Brand application reviewed", {
      applicationId,
      decision,
      adminUid: actor.uid,
    });
    return {applicationId, status: decision};
  });
}

module.exports = {
  buildGetMyPlatformAdminAccess,
  buildListBrandApplicationsForAdmin,
  buildReviewBrandApplication,
};
