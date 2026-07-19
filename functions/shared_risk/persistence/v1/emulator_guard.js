const EMULATOR_PROJECT_ID = "demo-markakalkan-rst-0h";

function assertFirestoreEmulatorV1({projectId = EMULATOR_PROJECT_ID,
  emulatorHost = process.env.FIRESTORE_EMULATOR_HOST} = {}) {
  if (projectId !== EMULATOR_PROJECT_ID) {
    throw new Error("Only the dedicated MK-RST-0H emulator project is allowed");
  }
  if (typeof emulatorHost !== "string" || emulatorHost.length === 0) {
    throw new Error("FIRESTORE_EMULATOR_HOST is required");
  }
  const host = emulatorHost.split(":")[0].toLowerCase();
  if (host !== "127.0.0.1" && host !== "localhost" && host !== "::1") {
    throw new Error("Firestore emulator must be bound to loopback");
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("Production credentials are forbidden in emulator tests");
  }
  return Object.freeze({projectId, emulatorHost});
}

module.exports = {EMULATOR_PROJECT_ID, assertFirestoreEmulatorV1};
