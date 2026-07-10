const {HttpsError} = require("firebase-functions/v2/https");

const ADMIN_COLLECTION = "platform_admins";

const ROLES = Object.freeze({
  superAdmin: "super_admin",
  brandApplicationReviewer: "brand_application_reviewer",
  counterfeitTwinReviewer: "counterfeit_twin_reviewer",
  counterfeitTwinPublisher: "counterfeit_twin_publisher",
});

function requireAuthenticatedUser(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Oturum acmaniz gerekir.");
  }
  return {
    uid,
    email: (request.auth?.token?.email || "").trim().toLowerCase(),
  };
}

async function getPlatformAdminAccess(request, db) {
  const actor = requireAuthenticatedUser(request);
  const snapshot = await db.collection(ADMIN_COLLECTION).doc(actor.uid).get();
  if (!snapshot.exists) {
    return {...actor, active: false, roles: []};
  }
  const data = snapshot.data() || {};
  const roles = Array.isArray(data.roles) ?
    [...new Set(data.roles.filter((item) => typeof item === "string"))] :
    [];
  return {
    ...actor,
    active: data.active === true,
    roles,
    displayName: typeof data.displayName === "string" ?
      data.displayName.trim() :
      "",
  };
}

async function requirePlatformRole(request, db, requiredRole) {
  const access = await getPlatformAdminAccess(request, db);
  const authorized = access.active === true &&
    (
      access.roles.includes(ROLES.superAdmin) ||
      access.roles.includes(requiredRole)
    );
  if (!authorized) {
    throw new HttpsError(
        "permission-denied",
        "Bu yonetim islemi icin yetkiniz yok.",
    );
  }
  return access;
}

module.exports = {
  ADMIN_COLLECTION,
  ROLES,
  requireAuthenticatedUser,
  getPlatformAdminAccess,
  requirePlatformRole,
};
