/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {
  CONTRACT,
  createRequest,
  packageRequest,
} = require("./contracts");
const {
  createAuthoritySubmissionService,
} = require("./service");

class Snapshot {
  constructor(id, value) {
    this.id = id;
    this._value = value;
    this.exists = value != null;
  }

  data() {
    return this._value == null ? undefined : structuredClone(this._value);
  }
}

class DocumentRef {
  constructor(db, collectionName, id) {
    this.db = db;
    this.collectionName = collectionName;
    this.id = id;
  }

  async get() {
    return this.db.snapshot(this.collectionName, this.id);
  }
}

class Query {
  constructor(db, collectionName, filters = []) {
    this.db = db;
    this.collectionName = collectionName;
    this.filters = filters;
  }

  where(field, operator, value) {
    assert.equal(operator, "==");
    return new Query(this.db, this.collectionName, [...this.filters, {field, value}]);
  }

  async get() {
    const records = this.db.collections[this.collectionName] || [];
    return {
      docs: records
          .filter((record) => this.filters.every((filter) => record.data[filter.field] === filter.value))
          .map((record) => new Snapshot(record.id, record.data)),
    };
  }
}

class CollectionRef extends Query {
  doc(id) {
    return new DocumentRef(this.db, this.collectionName, id);
  }
}

class Transaction {
  constructor(db) {
    this.db = db;
    this.operations = [];
  }

  async get(ref) {
    return this.db.snapshot(ref.collectionName, ref.id);
  }

  create(ref, data) {
    this.operations.push({type: "create", ref, data: structuredClone(data)});
  }

  update(ref, data) {
    this.operations.push({type: "update", ref, data: structuredClone(data)});
  }

  commit() {
    for (const operation of this.operations) {
      const records = this.db.collections[operation.ref.collectionName] || [];
      const index = records.findIndex((record) => record.id === operation.ref.id);
      if (operation.type === "create") {
        if (index >= 0) throw new Error("document already exists");
        records.push({id: operation.ref.id, data: structuredClone(operation.data)});
      } else {
        if (index < 0) throw new Error("document not found");
        records[index] = {
          id: records[index].id,
          data: {...records[index].data, ...structuredClone(operation.data)},
        };
      }
      this.db.collections[operation.ref.collectionName] = records;
    }
  }
}

class FakeDb {
  constructor(collections, {transactionFailure = false} = {}) {
    this.collections = structuredClone(collections);
    this.transactionFailure = transactionFailure;
  }

  collection(name) {
    if (!this.collections[name]) this.collections[name] = [];
    return new CollectionRef(this, name);
  }

  snapshot(collectionName, id) {
    const record = (this.collections[collectionName] || []).find((item) => item.id === id);
    return new Snapshot(id, record?.data || null);
  }

  async runTransaction(callback) {
    const transaction = new Transaction(this);
    const result = await callback(transaction);
    if (this.transactionFailure) throw new Error("simulated transaction failure");
    if (result.transactionCommitted !== false) transaction.commit();
    return result;
  }
}

const clock = {now: () => "2026-07-25T16:00:00.000Z"};
const resolveContext = async () => ({
  tenantId: "tenant-1",
  brandId: "brand-1",
  membershipId: "membership-1",
});

function baseCollections() {
  return {
    tenant_memberships: [{
      id: "membership-1",
      data: {
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        status: "active",
        role: "owner",
      },
    }],
    customs_protection_profiles: [{
      id: "profile-1",
      data: {
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        profileNumber: "GKP-2026-TEST0001",
        profileName: "Test Gümrük Profili",
        status: "active",
        rightHolderName: "MarkaKalkan Test",
        rightHolderReferenceIds: ["TR-MARKA-1"],
        authorizedRepresentativeIds: [],
        authorizedManufacturerIds: ["manufacturer-1"],
        authorizedImporterIds: ["importer-1"],
        protectedProductIds: ["product-1"],
        hsCodes: ["870830"],
        productCategories: ["Otomotiv yedek parça"],
        originCountries: ["DE"],
        authorizedImportCountries: ["TR"],
        authenticationInstructions: "Seri ve ambalaj birlikte doğrulanır.",
        serialVerificationMethods: ["Seri numarası"],
        securityFeatureSummaries: ["Hologram"],
        counterfeitTwinRecordIds: ["twin-1"],
        productionAssetIds: ["asset-1"],
        riskCountryCodes: ["CN"],
        riskRouteSummaries: ["Doğu Asya - Türkiye"],
        emergencyContactIds: ["contact-1"],
        validFrom: "2026-01-01T00:00:00.000Z",
        validUntil: "2027-01-01T00:00:00.000Z",
      },
    }],
    customs_border_interventions: [{
      id: "intervention-1",
      data: {
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        interventionNumber: "SGM-2026-TEST0001",
        protectionProfileId: "profile-1",
        status: "infringement_confirmed",
        priority: "high",
        sourceType: "customs_notification",
        countryCode: "TR",
        customsAuthorityName: "İstanbul Gümrük Müdürlüğü",
        borderPointType: "seaport",
        borderPointName: "Ambarlı Limanı",
        shipmentReference: "SHIP-1",
        containerReference: "CONT-1",
        cargoReference: null,
        trackingReferences: ["TRACK-1"],
        declaredProductDescription: "Fren balatası",
        declaredHsCode: "870830",
        declaredQuantity: 500,
        declaredUnit: "unit",
        suspectedProductIds: ["product-1"],
        counterfeitTwinRecordIds: ["twin-1"],
        sourceRiskSignalIds: ["risk-1"],
        notificationReceivedAt: "2026-07-25T08:00:00.000Z",
        responseDeadlineAt: "2026-07-28T23:59:59.000Z",
        actionDeadlineAt: "2026-07-30T23:59:59.000Z",
        suspicionReasons: ["Güvenlik işareti uyuşmuyor"],
        authenticationResult: "confirmed_counterfeit",
        decisionSummary: "İnsan incelemesi tamamlandı.",
        decisionReason: "Doğrulama işaretleri uyuşmadı.",
        caseId: "case-1",
        legalMatterId: "legal-1",
        integrityStatus: "no_integrity_signal",
      },
    }],
    customs_authority_submissions: [],
    customs_submission_packages: [],
    customs_submission_responses: [],
    customs_submission_events: [],
  };
}

function serviceFor(db) {
  return createAuthoritySubmissionService({db, clock, resolveContext});
}

function id(suffix) {
  return `00000000-0000-4000-8000-${String(suffix).padStart(12, "0")}`;
}

function createPayload(requestId = id(1), overrides = {}) {
  return {
    contractVersion: CONTRACT.createRequest,
    submissionType: "fsmh_protection_application",
    targetAuthority: "fsmh_program",
    targetUnit: "Ticaret Bakanlığı FSMH Programı",
    channelType: "fsmh_portal",
    protectionProfileId: "profile-1",
    interventionId: null,
    caseId: null,
    legalMatterId: null,
    incidentReference: "FSMH-TEST-2026-001",
    title: "FSMH resmî başvuru test dosyası",
    authoritySummary: "Hak sahibi, ürün ve doğrulama bilgilerini içeren insan incelemeli resmî başvuru taslağıdır.",
    humanReviewReference: null,
    rightsHolderApprovalReference: null,
    dataMinimizationConfirmed: false,
    nonAccusatoryLanguageConfirmed: false,
    requestId,
    ...overrides,
  };
}

function updatePayload(submissionId, requestId = id(2), overrides = {}) {
  return {
    contractVersion: CONTRACT.updateRequest,
    submissionId,
    targetUnit: "Ticaret Bakanlığı FSMH Programı",
    channelType: "fsmh_portal",
    title: "FSMH resmî başvuru test dosyası",
    authoritySummary: "İnsan incelemesi tamamlanan ve veri minimizasyonu uygulanan resmî başvuru taslağıdır.",
    humanReviewReference: "INCELEME-2026-001",
    rightsHolderApprovalReference: "HAK-SAHIBI-ONAY-2026-001",
    dataMinimizationConfirmed: true,
    nonAccusatoryLanguageConfirmed: true,
    requestId,
    ...overrides,
  };
}

function transitionPayload(submissionId, nextStatus, requestId, overrides = {}) {
  return {
    contractVersion: CONTRACT.transitionRequest,
    submissionId,
    nextStatus,
    reason: `Test kapsamında ${nextStatus} durumuna güvenli geçiş yapılıyor.`,
    submittedAt: null,
    externalSubmissionStatement: null,
    requestId,
    ...overrides,
  };
}

function packagePayload(submissionId, requestId = id(6)) {
  return {
    contractVersion: CONTRACT.packageRequest,
    submissionId,
    packageType: "fsmh_application_package",
    coverLetterText: "Ticaret Bakanlığına sunulmak üzere yetkili insan incelemesi ve hak sahibi onayı ile hazırlanan başvuru üst yazısıdır.",
    authoritySummary: "Korunan ürünler, hak referansları, doğrulama talimatları ve risk bilgileri güvenli paket içinde sunulmaktadır.",
    legalNeutralityStatement: "Bu paket yalnız doğrulanabilir olguları ve insan değerlendirmesini içerir; otomatik suç isnadı oluşturmaz.",
    documentManifest: [{
      referenceId: "document-1",
      title: "Marka tescil belgesi",
      sha256: "a".repeat(64),
      mimeType: "application/pdf",
      sizeBytes: 1000,
    }],
    evidenceManifest: [{
      referenceId: "evidence-1",
      title: "Ürün doğrulama kılavuzu",
      sha256: "b".repeat(64),
      mimeType: "application/pdf",
      sizeBytes: 2000,
    }],
    redactionManifest: [{
      fieldPath: "contact.phone",
      action: "mask",
      reason: "Kişisel veri minimizasyonu",
    }],
    requestId,
  };
}

async function approvedSubmission(service) {
  const created = await service.createSubmission(createPayload(), {uid: "user-1"});
  const submissionId = created.submission.submissionId;
  await service.updateSubmission(updatePayload(submissionId), {uid: "user-1"});
  await service.transitionSubmission(transitionPayload(submissionId, "awaiting_human_review", id(3)), {uid: "user-1"});
  await service.transitionSubmission(transitionPayload(submissionId, "awaiting_rights_holder_approval", id(4)), {uid: "user-1"});
  await service.transitionSubmission(transitionPayload(submissionId, "approved_for_package", id(5)), {uid: "user-1"});
  return submissionId;
}

test("contracts reject unknown fields and packages without manifests", () => {
  assert.throws(() => createRequest({...createPayload(), extra: true}), /contract/);
  assert.throws(() => packageRequest({...packagePayload("submission-1"), documentManifest: [], evidenceManifest: []}), /manifest/);
});

test("create is atomic, business-key idempotent and fingerprint protected", async () => {
  const db = new FakeDb(baseCollections());
  const service = serviceFor(db);
  const first = await service.createSubmission(createPayload(), {uid: "user-1"});
  const duplicate = await service.createSubmission(createPayload(), {uid: "user-1"});
  assert.equal(first.duplicate, false);
  assert.equal(duplicate.duplicate, true);
  assert.equal(first.submission.status, "draft");
  assert.equal(db.collections.customs_authority_submissions.length, 1);
  assert.equal(db.collections.customs_submission_events.length, 1);
  await assert.rejects(
      () => service.createSubmission(createPayload(id(99), {title: "Aynı iş anahtarı için farklı içerik taşıyan resmî dosya"}), {uid: "user-1"}),
      /fingerprint/,
  );
});

test("source and owner gates fail closed", async () => {
  const inactive = baseCollections();
  inactive.customs_protection_profiles[0].data.status = "draft";
  await assert.rejects(() => serviceFor(new FakeDb(inactive)).createSubmission(createPayload(), {uid: "user-1"}), /active protection profile/);

  const member = baseCollections();
  member.tenant_memberships[0].data.role = "member";
  await assert.rejects(() => serviceFor(new FakeDb(member)).createSubmission(createPayload(), {uid: "user-1"}), /owner/);

  await assert.rejects(() => serviceFor(new FakeDb(baseCollections())).createSubmission(createPayload(), {}), /authentication/);
});

test("lifecycle requires human review, rights-holder approval and safe-language gates", async () => {
  const db = new FakeDb(baseCollections());
  const service = serviceFor(db);
  const created = await service.createSubmission(createPayload(), {uid: "user-1"});
  const submissionId = created.submission.submissionId;
  await service.transitionSubmission(transitionPayload(submissionId, "awaiting_human_review", id(20)), {uid: "user-1"});
  await assert.rejects(
      () => service.transitionSubmission(transitionPayload(submissionId, "awaiting_rights_holder_approval", id(21)), {uid: "user-1"}),
      /human review/,
  );
  await service.updateSubmission(updatePayload(submissionId, id(22), {
    rightsHolderApprovalReference: null,
    dataMinimizationConfirmed: false,
    nonAccusatoryLanguageConfirmed: false,
  }), {uid: "user-1"});
  await service.transitionSubmission(transitionPayload(submissionId, "awaiting_rights_holder_approval", id(23)), {uid: "user-1"});
  await assert.rejects(
      () => service.transitionSubmission(transitionPayload(submissionId, "approved_for_package", id(24)), {uid: "user-1"}),
      /approval|required|minimization/,
  );
  await service.updateSubmission(updatePayload(submissionId, id(25)), {uid: "user-1"});
  const approved = await service.transitionSubmission(transitionPayload(submissionId, "approved_for_package", id(26)), {uid: "user-1"});
  assert.equal(approved.submission.status, "approved_for_package");
  await assert.rejects(
      () => service.transitionSubmission(transitionPayload(submissionId, "package_generated", id(27)), {uid: "user-1"}),
      /generate package/,
  );
});

test("package generation freezes minimized source snapshot and aggregate hash", async () => {
  const db = new FakeDb(baseCollections());
  const service = serviceFor(db);
  const submissionId = await approvedSubmission(service);
  const generated = await service.generatePackage(packagePayload(submissionId), {uid: "user-1"});
  const duplicate = await service.generatePackage(packagePayload(submissionId), {uid: "user-1"});
  assert.equal(generated.duplicate, false);
  assert.equal(duplicate.duplicate, true);
  assert.equal(generated.submission.status, "package_generated");
  assert.equal(generated.package.immutable, true);
  assert.match(generated.package.aggregateHash, /^[0-9a-f]{64}$/);
  assert.equal(generated.package.sourceSnapshot.profile.profileId, "profile-1");
  assert.equal(Object.hasOwn(generated.package.sourceSnapshot.profile, "tenantId"), false);
  assert.equal(db.collections.customs_submission_packages.length, 1);
});

test("external submission, receipt and authority response remain human-controlled", async () => {
  const db = new FakeDb(baseCollections());
  const service = serviceFor(db);
  const submissionId = await approvedSubmission(service);
  await service.generatePackage(packagePayload(submissionId), {uid: "user-1"});
  await assert.rejects(
      () => service.transitionSubmission(transitionPayload(submissionId, "submitted_externally", id(30)), {uid: "user-1"}),
      /external submission statement/,
  );
  const submitted = await service.transitionSubmission(transitionPayload(submissionId, "submitted_externally", id(31), {
    submittedAt: "2026-07-25T16:05:00.000Z",
    externalSubmissionStatement: "Yetkili kullanıcı paketi FSMH portalında elektronik imza ile gönderdiğini beyan eder.",
  }), {uid: "user-1"});
  assert.equal(submitted.submission.status, "submitted_externally");

  const receipt = await service.recordReceipt({
    contractVersion: CONTRACT.receiptRequest,
    submissionId,
    officialReferenceNumber: "FSMH-2026-0001",
    receivedAt: "2026-07-25T16:10:00.000Z",
    channelType: "fsmh_portal",
    receiptDocumentReference: "receipt-1",
    receiptDocumentHash: "c".repeat(64),
    summary: "Başvurunun sistem tarafından teslim alındığı doğrulandı.",
    requestId: id(32),
  }, {uid: "user-1"});
  assert.equal(receipt.submission.status, "receipt_recorded");
  assert.equal(receipt.response.immutable, true);

  const response = await service.appendResponse({
    contractVersion: CONTRACT.responseRequest,
    submissionId,
    responseType: "information_request",
    authorityReference: "FSMH-2026-0001",
    receivedAt: "2026-07-26T08:00:00.000Z",
    summary: "Kurum ek ürün görseli ve yetki belgesi talep etti.",
    attachmentReferences: ["authority-letter-1"],
    attachmentHashes: ["d".repeat(64)],
    requestedDueAt: "2026-08-01T23:59:59.000Z",
    outcomeCode: "pending",
    requestId: id(33),
  }, {uid: "user-1"});
  assert.equal(response.submission.status, "additional_information_requested");
  assert.equal(db.collections.customs_submission_responses.length, 2);
});

test("list and detail are tenant-scoped read-only with verified chain", async () => {
  const db = new FakeDb(baseCollections());
  const service = serviceFor(db);
  const submissionId = await approvedSubmission(service);
  await service.generatePackage(packagePayload(submissionId), {uid: "user-1"});
  const list = await service.listSubmissions({
    contractVersion: CONTRACT.listRequest,
    status: "package_generated",
    targetAuthority: null,
    pageSize: 25,
    pageToken: null,
  }, {uid: "user-1"});
  assert.equal(list.readOnly, true);
  assert.equal(list.writesPerformed, 0);
  assert.equal(list.items.length, 1);
  const detail = await service.submissionDetail({
    contractVersion: CONTRACT.detailRequest,
    submissionId,
  }, {uid: "user-1"});
  assert.equal(detail.readOnly, true);
  assert.equal(detail.integrityStatus, "verified");
  assert.equal(detail.packages.length, 1);
  assert.equal(detail.events.length, 6);

  db.collections.customs_authority_submissions[0].data.tenantId = "tenant-other";
  await assert.rejects(() => service.submissionDetail({
    contractVersion: CONTRACT.detailRequest,
    submissionId,
  }, {uid: "user-1"}), /not found/);
});

test("transaction failure leaves no partial authority-submission writes", async () => {
  const db = new FakeDb(baseCollections(), {transactionFailure: true});
  await assert.rejects(
      () => serviceFor(db).createSubmission(createPayload(), {uid: "user-1"}),
      /simulated transaction failure/,
  );
  assert.equal(db.collections.customs_authority_submissions.length, 0);
  assert.equal(db.collections.customs_submission_events.length, 0);
});
