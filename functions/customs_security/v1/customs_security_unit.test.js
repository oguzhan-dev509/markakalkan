/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  CONTRACT,
  fingerprint,
  interventionCreateRequest,
  interventionTransitionRequest,
  profileCreateRequest,
} = require("./contracts");
const {READ_OPTIONS, WRITE_OPTIONS, createHandler} = require("./callable");
const {createCustomsSecurityService} = require("./service");

function assertNoUndefined(value, path = "root") {
  if (value === undefined) throw new Error(`undefined firestore value at ${path}`);
  if (Array.isArray(value)) value.forEach((item, index) => assertNoUndefined(item, `${path}[${index}]`));
  else if (value && typeof value === "object" && !(value instanceof Date)) {
    for (const [key, item] of Object.entries(value)) assertNoUndefined(item, `${path}.${key}`);
  }
}

class Snapshot {
  constructor(id, data, path, exists = true) {
    this.id = id;
    this._data = data;
    this.exists = exists;
    this.ref = {path};
  }
  data() {
    return this._data;
  }
}

class Query {
  constructor(store, name, filters = [], maximum = 1000) {
    this.store = store;
    this.name = name;
    this.filters = filters;
    this.maximum = maximum;
  }
  where(field, op, value) {
    assert.equal(op, "==");
    return new Query(this.store, this.name, [...this.filters, [field, value]], this.maximum);
  }
  limit(value) {
    return new Query(this.store, this.name, this.filters, value);
  }
  async get() {
    return {
      docs: (this.store.collections[this.name] || [])
          .filter((item) => this.filters.every(([field, value]) => item.data[field] === value))
          .slice(0, this.maximum)
          .map((item) => new Snapshot(item.id, item.data, `${this.name}/${item.id}`)),
    };
  }
}

class Ref {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    this.id = path.split("/").at(-1);
  }
  async get() {
    return this.store.snapshot(this.path);
  }
}

class Collection extends Query {
  doc(id) {
    return new Ref(this.store, `${this.name}/${id}`);
  }
}

class Transaction {
  constructor(store) {
    this.store = store;
    this.pending = [];
  }
  async get(reference) {
    if (reference instanceof Query) return reference.get();
    return this.store.snapshot(reference.path);
  }
  create(reference, data) {
    assertNoUndefined(data);
    this.pending.push({type: "create", path: reference.path, data});
  }
  update(reference, data) {
    assertNoUndefined(data);
    this.pending.push({type: "update", path: reference.path, data});
  }
  commit() {
    const next = structuredClone(this.store.collections);
    for (const entry of this.pending) {
      const parts = entry.path.split("/");
      const id = parts.pop();
      const name = parts.join("/");
      next[name] ||= [];
      if (entry.type === "create") {
        if (next[name].some((item) => item.id === id)) throw new Error("document already exists");
        next[name].push({id, data: structuredClone(entry.data)});
      } else {
        const current = next[name].find((item) => item.id === id);
        if (!current) throw new Error("document missing");
        current.data = {...current.data, ...structuredClone(entry.data)};
      }
    }
    this.store.collections = next;
    this.store.writes += this.pending.length;
  }
}

class FakeDb {
  constructor(collections, {transactionFailure = false} = {}) {
    this.collections = structuredClone(collections);
    this.transactionFailure = transactionFailure;
    this.writes = 0;
  }
  collection(name) {
    return new Collection(this, name);
  }
  snapshot(path) {
    const parts = path.split("/");
    const id = parts.pop();
    const name = parts.join("/");
    const item = (this.collections[name] || []).find((entry) => entry.id === id);
    return item ?
      new Snapshot(id, item.data, path, true) :
      new Snapshot(id, {}, path, false);
  }
  async runTransaction(callback) {
    const transaction = new Transaction(this);
    const result = await callback(transaction);
    if (this.transactionFailure) throw new Error("simulated transaction failure");
    if (result.transactionCommitted !== false) transaction.commit();
    return result;
  }
}

const baseCollections = () => ({
  tenant_memberships: [{
    id: "membership-1",
    data: {
      uid: "user-1",
      tenantId: "tenant-1",
      status: "active",
      role: "owner",
    },
  }],
  canonical_brands: [{
    id: "brand-1",
    data: {
      tenantId: "tenant-1",
      status: "active",
    },
  }],
  customs_protection_profiles: [],
  customs_border_interventions: [],
  customs_intervention_events: [],
});

const times = [
  "2026-07-25T05:00:00.000Z",
  "2026-07-25T05:01:00.000Z",
  "2026-07-25T05:02:00.000Z",
  "2026-07-25T05:03:00.000Z",
  "2026-07-25T05:04:00.000Z",
  "2026-07-25T05:05:00.000Z",
  "2026-07-25T05:06:00.000Z",
  "2026-07-25T05:07:00.000Z",
  "2026-07-25T05:08:00.000Z",
  "2026-07-25T05:09:00.000Z",
];

function clock() {
  let index = 0;
  return {now: () => times[Math.min(index++, times.length - 1)]};
}

const resolveContext = async ({uid}) => ({
  uid,
  tenantId: "tenant-1",
  brandId: "brand-1",
  membershipId: "membership-1",
});

const profilePayload = (requestId = "123e4567-e89b-42d3-a456-426614174301") => ({
  contractVersion: CONTRACT.profileCreateRequest,
  profileName: "Bosch Türkiye Gümrük Koruma Profili",
  rightHolderName: "Robert Bosch GmbH",
  rightHolderReferenceIds: ["marka-tescil-1"],
  protectedProductIds: ["bosch-fren-balatasi"],
  hsCodes: ["870830"],
  originCountries: ["DE"],
  authorizedImportCountries: ["TR"],
  authenticationInstructions: "Seri numarası, ambalaj ve güvenlik işaretleri birlikte doğrulanmalıdır.",
  serialVerificationMethods: ["MarkaKalkan seri doğrulaması"],
  securityFeatureSummaries: ["Lazer baskılı seri numarası"],
  riskCountryCodes: ["CN"],
  riskRouteSummaries: ["Çin - transit merkez - Türkiye"],
  validFrom: "2026-07-25T00:00:00.000Z",
  validUntil: "2027-07-25T00:00:00.000Z",
  requestId,
});

function interventionPayload(profileId, requestId = "123e4567-e89b-42d3-a456-426614174401") {
  return {
    contractVersion: CONTRACT.interventionCreateRequest,
    protectionProfileId: profileId,
    priority: "high",
    sourceType: "customs_notification",
    countryCode: "TR",
    customsAuthorityName: "İstanbul Gümrük Müdürlüğü",
    borderPointType: "seaport",
    borderPointName: "Ambarlı Limanı",
    containerReference: "CONT-123456",
    declaredProductDescription: "Otomotiv fren balatası",
    declaredHsCode: "870830",
    declaredQuantity: 1000,
    declaredUnit: "unit",
    declaredValue: 12000,
    declaredCurrency: "USD",
    suspicionReasons: ["Ambalaj ve seri numarası uyumsuzluğu"],
    authenticationResult: "likely_counterfeit",
    unusualReleaseFlag: false,
    requestId,
  };
}

async function createActiveProfile(service) {
  const created = await service.createProfile(profilePayload(), {uid: "user-1"});
  await service.transitionProfile({
    contractVersion: CONTRACT.profileTransitionRequest,
    profileId: created.profile.profileId,
    nextStatus: "under_review",
    reason: "Profil hak ve ürün kapsamı için incelemeye alındı.",
    requestId: "123e4567-e89b-42d3-a456-426614174302",
  }, {uid: "user-1"});
  await service.transitionProfile({
    contractVersion: CONTRACT.profileTransitionRequest,
    profileId: created.profile.profileId,
    nextStatus: "active",
    reason: "Hak sahipliği ve ürün doğrulama bilgileri yetkili kişi tarafından onaylandı.",
    requestId: "123e4567-e89b-42d3-a456-426614174303",
  }, {uid: "user-1"});
  return created.profile.profileId;
}

test("contracts are strict bounded and legally neutral", () => {
  const profile = profileCreateRequest(profilePayload());
  assert.equal(profile.originCountries[0], "DE");
  assert.equal(fingerprint(profile).length, 64);
  assert.throws(() => profileCreateRequest({...profilePayload(), unknown: true}), /contract/);
  assert.throws(() => profileCreateRequest({...profilePayload(), requestId: "bad"}), /requestId/);
  assert.throws(() => profileCreateRequest({...profilePayload(), validUntil: "2025-01-01"}), /invalid/);
  assert.throws(() => interventionCreateRequest({...interventionPayload("profile-1"), unusualReleaseFlag: "yes"}), /unusualReleaseFlag/);
  assert.throws(() => interventionCreateRequest({...interventionPayload("profile-1"), declaredCurrency: null}), /provided together/);
  assert.throws(() => interventionTransitionRequest({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId: "intervention-1",
    nextStatus: "smuggler_confirmed",
    reason: "Bu ifade hukuken güvenli bir durum değildir.",
    requestId: "123e4567-e89b-42d3-a456-426614174402",
  }), /unsupported/);
});

test("profile create is atomic idempotent and fingerprint protected", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const first = await service.createProfile(profilePayload(), {uid: "user-1"});
  const writes = db.writes;
  const duplicate = await service.createProfile(profilePayload(), {uid: "user-1"});
  assert.match(first.profile.profileNumber, /^GKP-2026-[A-F0-9]{8}$/);
  assert.equal(first.profile.status, "draft");
  assert.equal(duplicate.duplicate, true);
  assert.equal(db.writes, writes);
  assert.equal(db.collections.customs_protection_profiles.length, 1);
  assert.equal(db.collections.customs_intervention_events.length, 1);
  await assert.rejects(
      () => service.createProfile({...profilePayload(), profileName: "Farklı profil adı"}, {uid: "user-1"}),
      /fingerprint/,
  );
});

test("profile lifecycle requires review rights and product basis", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const created = await service.createProfile(profilePayload(), {uid: "user-1"});
  await assert.rejects(() => service.transitionProfile({
    contractVersion: CONTRACT.profileTransitionRequest,
    profileId: created.profile.profileId,
    nextStatus: "active",
    reason: "Taslak profil doğrudan etkinleştirilmemelidir.",
    requestId: "123e4567-e89b-42d3-a456-426614174304",
  }, {uid: "user-1"}), /transition/);
  await service.transitionProfile({
    contractVersion: CONTRACT.profileTransitionRequest,
    profileId: created.profile.profileId,
    nextStatus: "under_review",
    reason: "Hak ve ürün doğrulaması için inceleme.",
    requestId: "123e4567-e89b-42d3-a456-426614174305",
  }, {uid: "user-1"});
  const active = await service.transitionProfile({
    contractVersion: CONTRACT.profileTransitionRequest,
    profileId: created.profile.profileId,
    nextStatus: "active",
    reason: "Hak ve ürün dayanakları yetkili insan değerlendirmesiyle doğrulandı.",
    requestId: "123e4567-e89b-42d3-a456-426614174306",
  }, {uid: "user-1"});
  assert.equal(active.profile.status, "active");
  assert.equal(db.collections.customs_intervention_events.length, 3);
});

test("border intervention requires active scoped profile", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const profile = await service.createProfile(profilePayload(), {uid: "user-1"});
  await assert.rejects(
      () => service.createIntervention(interventionPayload(profile.profile.profileId), {uid: "user-1"}),
      /active protection profile/,
  );
  const activeProfileId = await createActiveProfile(service);
  const created = await service.createIntervention(interventionPayload(activeProfileId), {uid: "user-1"});
  assert.match(created.intervention.interventionNumber, /^SGM-2026-[A-F0-9]{8}$/);
  assert.equal(created.intervention.status, "draft");
  assert.equal(created.intervention.integrityStatus, "no_integrity_signal");
});

test("intervention lifecycle blocks unsupported shortcuts and requires human basis", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const profileId = await createActiveProfile(service);
  const created = await service.createIntervention(interventionPayload(profileId), {uid: "user-1"});
  const interventionId = created.intervention.interventionId;
  await assert.rejects(() => service.transitionIntervention({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId,
    nextStatus: "destroyed",
    reason: "Taslak dosya doğrudan imha sonucuna taşınamaz.",
    decisionReference: "Karar 1",
    requestId: "123e4567-e89b-42d3-a456-426614174410",
  }, {uid: "user-1"}), /transition/);
  const transitions = [
    ["risk_review", "Risk göstergeleri insan incelemesine alındı.", "411"],
    ["under_preliminary_review", "Sevkiyat ve taraf kayıtları ön incelemeye alındı.", "412"],
    ["authentication_in_progress", "Ürün doğrulama süreci marka uzmanına yönlendirildi.", "413"],
  ];
  for (const [nextStatus, reason, suffix] of transitions) {
    await service.transitionIntervention({
      contractVersion: CONTRACT.interventionTransitionRequest,
      interventionId,
      nextStatus,
      reason,
      requestId: `123e4567-e89b-42d3-a456-426614174${suffix}`,
    }, {uid: "user-1"});
  }
  await assert.rejects(() => service.transitionIntervention({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId,
    nextStatus: "infringement_confirmed",
    reason: "Kesinleştirme insan değerlendirme referansı olmadan yapılamaz.",
    requestId: "123e4567-e89b-42d3-a456-426614174414",
  }, {uid: "user-1"}), /human assessment/);
  const confirmed = await service.transitionIntervention({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId,
    nextStatus: "infringement_confirmed",
    reason: "Ürün doğrulama uzmanı sahte ürün bulgusunu delil referansıyla doğruladı.",
    humanAssessmentReference: "UZMAN-2026-001",
    requestId: "123e4567-e89b-42d3-a456-426614174415",
  }, {uid: "user-1"});
  assert.equal(confirmed.intervention.status, "infringement_confirmed");
  assert.equal(confirmed.intervention.approvedByUid, "user-1");
});

test("destruction release and authority referral require decision references", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const profileId = await createActiveProfile(service);
  const created = await service.createIntervention(interventionPayload(profileId), {uid: "user-1"});
  const interventionId = created.intervention.interventionId;
  const sequence = [
    ["risk_review", "Risk değerlendirmesi yapıldı.", "421"],
    ["under_preliminary_review", "Ön inceleme tamamlandı.", "422"],
    ["temporarily_detained", "Sevkiyat geçici olarak alıkondu.", "423"],
  ];
  for (const [nextStatus, reason, suffix] of sequence) {
    await service.transitionIntervention({
      contractVersion: CONTRACT.interventionTransitionRequest,
      interventionId,
      nextStatus,
      reason,
      requestId: `123e4567-e89b-42d3-a456-426614174${suffix}`,
    }, {uid: "user-1"});
  }
  await assert.rejects(() => service.transitionIntervention({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId,
    nextStatus: "released",
    reason: "Serbest bırakma kararı referanssız uygulanamaz.",
    requestId: "123e4567-e89b-42d3-a456-426614174424",
  }, {uid: "user-1"}), /decision reference/);
  const released = await service.transitionIntervention({
    contractVersion: CONTRACT.interventionTransitionRequest,
    interventionId,
    nextStatus: "released",
    reason: "Yetkili karar doğrultusunda sevkiyat serbest bırakıldı.",
    decisionReference: "GMRK-KARAR-2026-15",
    requestId: "123e4567-e89b-42d3-a456-426614174425",
  }, {uid: "user-1"});
  assert.equal(released.intervention.status, "released");
  assert.equal(released.intervention.approvedByUid, "user-1");
});

test("list and detail remain tenant scoped read-only with verified event chain", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const profileId = await createActiveProfile(service);
  const created = await service.createIntervention(interventionPayload(profileId), {uid: "user-1"});
  db.collections.customs_border_interventions.push({
    id: "foreign",
    data: {
      tenantId: "tenant-other",
      canonicalBrandId: "brand-other",
      interventionNumber: "GIZLI",
      status: "draft",
      updatedAt: "2026-07-25T06:00:00.000Z",
    },
  });
  const profiles = await service.listProfiles({
    contractVersion: CONTRACT.profileListRequest,
    pageSize: 25,
  }, {uid: "user-1"});
  const interventions = await service.listInterventions({
    contractVersion: CONTRACT.interventionListRequest,
    pageSize: 25,
  }, {uid: "user-1"});
  const detail = await service.interventionDetail({
    contractVersion: CONTRACT.interventionDetailRequest,
    interventionId: created.intervention.interventionId,
  }, {uid: "user-1"});
  assert.equal(profiles.readOnly, true);
  assert.equal(interventions.items.length, 1);
  assert.equal(JSON.stringify(interventions).includes("GIZLI"), false);
  assert.equal(detail.integrityStatus, "verified");
  assert.equal(detail.events.length, 1);
  assert.equal(db.writes > 0, true);
});

test("owner and App Check gates fail closed", async () => {
  assert.deepEqual(READ_OPTIONS, {
    region: "europe-west3",
    enforceAppCheck: false,
    maxInstances: 3,
  });
  assert.deepEqual(WRITE_OPTIONS, {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 1,
  });
  const db = new FakeDb(baseCollections());
  const log = {info: () => {}, error: () => {}};
  const writeHandler = createHandler("createProfile", {
    db,
    clock: clock(),
    resolveContext,
    appCheck: true,
    log,
  });
  await assert.rejects(
      () => writeHandler({data: profilePayload()}),
      (error) => error instanceof HttpsError && error.code === "unauthenticated",
  );
  await assert.rejects(
      () => writeHandler({auth: {uid: "user-1"}, data: profilePayload()}),
      (error) => error instanceof HttpsError && error.code === "failed-precondition",
  );
  db.collections.tenant_memberships[0].data.role = "member";
  await assert.rejects(
      () => writeHandler({
        auth: {uid: "user-1"},
        app: {appId: "verified"},
        data: profilePayload(),
      }),
      (error) => error instanceof HttpsError && error.code === "permission-denied",
  );
});

test("transaction failure leaves no partial KTG writes", async () => {
  const db = new FakeDb(baseCollections(), {transactionFailure: true});
  const before = structuredClone(db.collections);
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  await assert.rejects(
      () => service.createProfile(profilePayload(), {uid: "user-1"}),
      /simulated transaction failure/,
  );
  assert.deepEqual(db.collections, before);
  assert.equal(db.writes, 0);
});

test("same request id with changed intervention payload is rejected", async () => {
  const db = new FakeDb(baseCollections());
  const service = createCustomsSecurityService({db, clock: clock(), resolveContext});
  const profileId = await createActiveProfile(service);
  const payload = interventionPayload(profileId);
  await service.createIntervention(payload, {uid: "user-1"});
  await assert.rejects(
      () => service.createIntervention({...payload, borderPointName: "Farklı Liman"}, {uid: "user-1"}),
      /fingerprint/,
  );
});
