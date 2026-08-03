/* eslint-disable max-len */
"use strict";

const SUBSCRIPTION_REQUESTS_COLLECTION =
  "subscription_service_requests";

function createSubscriptionRequestFirestoreAdapter(db) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("db must be a Firestore-compatible object");
  }

  return Object.freeze({
    async createSubscriptionRequestAtomic({subscriptionRequest}) {
      const reference = db
          .collection(SUBSCRIPTION_REQUESTS_COLLECTION)
          .doc(subscriptionRequest.subscriptionRequestId);

      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        if (snapshot.exists) {
          return Object.freeze({
            subscriptionRequest: Object.freeze(snapshot.data()),
            idempotentReplay: true,
          });
        }

        transaction.create(reference, subscriptionRequest);
        return Object.freeze({
          subscriptionRequest,
          idempotentReplay: false,
        });
      });
    },
  });
}

module.exports = Object.freeze({
  SUBSCRIPTION_REQUESTS_COLLECTION,
  createSubscriptionRequestFirestoreAdapter,
});
