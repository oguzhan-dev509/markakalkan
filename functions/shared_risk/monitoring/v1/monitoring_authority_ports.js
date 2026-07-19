const {immutableSnapshot} = require("../../persistence/v1/storage_contracts");

function timestampJson(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  return value;
}

function jsonData(value) {
  if (Array.isArray(value)) return value.map(jsonData);
  if (value && typeof value === "object" &&
      typeof value.toDate !== "function") {
    return Object.fromEntries(Object.entries(value).map(([key, child]) =>
      [key, jsonData(child)]));
  }
  return timestampJson(value);
}

function createPlatformAdminAuthorityPortV1(db) {
  return Object.freeze({async load(uid) {
    const snapshot = await db.collection("platform_admins").doc(uid).get();
    return immutableSnapshot({exists: snapshot.exists,
      data: snapshot.exists ? jsonData(snapshot.data() || {}) : null});
  }});
}

function authoritativeSnapshot(snapshot, collection) {
  if (!snapshot.exists) return Object.freeze({exists: false});
  return immutableSnapshot({exists: true, id: snapshot.id,
    data: jsonData(snapshot.data() || {}),
    documentPath: `${collection}/${snapshot.id}`,
    updateTime: snapshot.updateTime.toDate().toISOString()});
}

function createMonitoringSignalAuthorityPortV1(db) {
  return Object.freeze({
    reference(id) {
      return db.collection("monitoring_signals").doc(id);
    },
    async load(id) {
      return authoritativeSnapshot(await this.reference(id).get(),
          "monitoring_signals");
    },
  });
}

function createMonitoringEventAuthorityPortV1(db) {
  return Object.freeze({async load(id) {
    const snapshot = await db.collection("monitoring_events").doc(id).get();
    const result = authoritativeSnapshot(snapshot, "monitoring_events");
    return result.exists ? immutableSnapshot({...result,
      data: {...result.data, id: result.id}}) : result;
  }});
}

function fixedServerClockPortV1(time) {
  return Object.freeze({now: () => time});
}

module.exports = {createMonitoringEventAuthorityPortV1,
  createMonitoringSignalAuthorityPortV1, createPlatformAdminAuthorityPortV1,
  fixedServerClockPortV1};
