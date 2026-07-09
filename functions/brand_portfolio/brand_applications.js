const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

function cleanText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildListMyBrandApplications({db}) {
  return onCall({enforceAppCheck: false, maxInstances: 3}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
          "unauthenticated",
          "Markalarinizi goruntulemek icin oturum acmalisiniz.",
      );
    }
    try {
      const snapshot = await db.collection("brandApplications")
          .where("applicantUid", "==", uid).limit(100).get();
      const applications = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          brandName: cleanText(data.brandName),
          companyName: cleanText(data.companyName),
          sector: cleanText(data.sector),
          businessType: cleanText(data.businessType),
          status: cleanText(data.status) || "pending",
          createdAtMillis: data.createdAt?.toMillis?.() ?? null,
        };
      });
      applications.sort(
          (a, b) =>
            (b.createdAtMillis || 0) - (a.createdAtMillis || 0),
      );
      return {applications};
    } catch (error) {
      logger.error("Brand applications could not be listed", {uid, error});
      throw new HttpsError(
          "internal",
          "Marka listeniz yuklenirken sunucu hatasi olustu.",
      );
    }
  });
}

module.exports = {buildListMyBrandApplications};
