const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

const OWNERS_COLLECTION = "ip_creation_registry_owners";
const NUMBERS_COLLECTION = "ip_creation_registry_owner_numbers";
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_GENERATION_ATTEMPTS = 8;

function randomGroup(length = 4) {
  const bytes = crypto.randomBytes(length);
  let value = "";

  for (let index = 0; index < length; index += 1) {
    value += ALPHABET[bytes[index] % ALPHABET.length];
  }

  return value;
}

function createOwnerNumber() {
  return `MK-SH-${randomGroup()}-${randomGroup()}`;
}

function buildEnsureIpCreationRegistryOwnerIdentity({db, admin}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const uid = request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Sicil sahibi kimliği için oturum açmalısınız.",
          );
        }

        const ownerRef = db.collection(OWNERS_COLLECTION).doc(uid);
        const token = request.auth?.token ?? {};
        const email =
          typeof token.email === "string" ? token.email.trim() : null;
        const emailVerified = token.email_verified === true;

        try {
          for (
            let attempt = 0;
            attempt < MAX_GENERATION_ATTEMPTS;
            attempt += 1
          ) {
            const candidate = createOwnerNumber();
            const numberRef = db.collection(NUMBERS_COLLECTION).doc(candidate);

            try {
              const result = await db.runTransaction(async (transaction) => {
                const ownerSnapshot = await transaction.get(ownerRef);
                const owner = ownerSnapshot.data();

                if (ownerSnapshot.exists && owner) {
                  const existingNumber = owner.registryOwnerNumber;

                  if (
                    typeof existingNumber !== "string" ||
                    !/^MK-SH-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(existingNumber)
                  ) {
                    throw new HttpsError(
                        "failed-precondition",
                        "Mevcut sicil sahibi kimliği geçersiz.",
                    );
                  }

                  return {
                    registryOwnerNumber: existingNumber,
                    created: false,
                  };
                }

                const numberSnapshot = await transaction.get(numberRef);

                if (numberSnapshot.exists) {
                  const collisionError = new Error("OWNER_NUMBER_COLLISION");
                  collisionError.code = "OWNER_NUMBER_COLLISION";
                  throw collisionError;
                }

                const now = admin.firestore.Timestamp.now();

                transaction.create(ownerRef, {
                  tenantId: uid,
                  registryOwnerNumber: candidate,
                  emailAtCreation: email,
                  emailVerifiedAtCreation: emailVerified,
                  createdAt: now,
                  createdBy: uid,
                  updatedAt: now,
                });

                transaction.create(numberRef, {
                  registryOwnerNumber: candidate,
                  ownerUid: uid,
                  createdAt: now,
                });

                return {
                  registryOwnerNumber: candidate,
                  created: true,
                };
              });

              logger.info("IP creation registry owner identity ensured", {
                tenantId: uid,
                registryOwnerNumber: result.registryOwnerNumber,
                created: result.created,
              });

              return result;
            } catch (error) {
              if (error?.code === "OWNER_NUMBER_COLLISION") {
                continue;
              }

              throw error;
            }
          }

          throw new HttpsError(
              "resource-exhausted",
              "Benzersiz sicil sahibi numarası üretilemedi.",
          );
        } catch (error) {
          logger.error("IP creation registry owner identity failed", {
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Sicil sahibi kimliği oluşturulurken sunucu hatası oluştu.",
          );
        }
      },
  );
}

module.exports = {
  buildEnsureIpCreationRegistryOwnerIdentity,
};
