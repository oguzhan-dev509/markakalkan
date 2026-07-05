import fs from 'node:fs';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'markakalkan-trade-secret-rules-test';
const ownerUid = 'owner-tenant-1';
const otherUid = 'other-tenant-2';
const secretId = `${ownerUid}__ipsecret_1001`;

let testEnvironment;

function baseTradeSecret(overrides = {}) {
  return {
    tenantId: ownerUid,
    brandId: ownerUid,
    secretCode: 'TS-001',
    title: 'Özel Üretim Formülü',
    description: 'Ticari sır koruma dosyası',
    secretType: 'formula',
    status: 'active',
    confidentialityLevel: 'trade_secret',
    riskLevel: 'high',
    protectionMode: 'metadata_only',
    disclosureScope: 'need_to_know',
    legalBasisStatus: 'documented',
    compartmentalizationLevel: 'segmented',
    economicValueLevel: 'critical',
    primaryAssetId: null,
    relatedAssetIds: [],
    relatedDocumentIds: [],
    ndaDocumentIds: [],
    contractDocumentIds: [],
    evidenceRecordIds: [],
    protectionMeasureCodes: [],
    custodianUserIds: [ownerUid],
    authorizedUserIds: [ownerUid],
    authorizedPartnerIds: [],
    ownerDepartment: 'Ar-Ge',
    secretFingerprint: null,
    hashAlgorithm: null,
    encryptedSecretReference: null,
    externalSecureSystemReference: null,
    firstProtectedAt: null,
    lastAccessReviewAt: null,
    nextAccessReviewAt: null,
    lastRiskAssessmentAt: null,
    lastDisclosureAt: null,
    leakageSuspected: false,
    legalHoldActive: false,
    accessControlScore: 80,
    legalProtectionScore: 75,
    technicalProtectionScore: 70,
    operationalProtectionScore: 65,
    secretSecurityScore: 72,
    notes: null,
    metadata: {},
    createdAt: serverTimestamp(),
    createdBy: ownerUid,
    updatedAt: serverTimestamp(),
    updatedBy: ownerUid,
    ...overrides,
  };
}

async function seedTradeSecret(overrides = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'ip_trade_secrets', secretId),
      baseTradeSecret(overrides),
    );
  });
}

before(async () => {
  const rules = fs.readFileSync(
    path.resolve('..', 'firestore.rules'),
    'utf8',
  );

  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

test('tenant sahibi geçerli ticari sır kaydı oluşturabilir', async () => {
  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertSucceeds(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret(),
    ),
  );
});

test('başka tenant adına kayıt oluşturulamaz', async () => {
  const db = testEnvironment
    .authenticatedContext(otherUid)
    .firestore();

  await assertFails(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret(),
    ),
  );
});

test('açık metin formül üst alanda yazılamaz', async () => {
  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret({
        formulaContent: 'gizli bileşim',
      }),
    ),
  );
});

test('açık metin formül metadata içinde yazılamaz', async () => {
  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret({
        metadata: {
          formulaContent: 'gizli bileşim',
        },
      }),
    ),
  );
});

test('100 üzerindeki güvenlik skoru reddedilir', async () => {
  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret({
        secretSecurityScore: 101,
      }),
    ),
  );
});

test('şifreli kasa modunda şifreli referans zorunludur', async () => {
  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    setDoc(
      doc(db, 'ip_trade_secrets', secretId),
      baseTradeSecret({
        protectionMode: 'encrypted_vault',
        encryptedSecretReference: null,
      }),
    ),
  );
});

test('tenant sahibi kendi kaydını okuyabilir', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertSucceeds(
    getDoc(doc(db, 'ip_trade_secrets', secretId)),
  );
});

test('başka tenant kaydı okuyamaz', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(otherUid)
    .firestore();

  await assertFails(
    getDoc(doc(db, 'ip_trade_secrets', secretId)),
  );
});

test('tenant filtreli koleksiyon sorgusu çalışır', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  const snapshot = await assertSucceeds(
    getDocs(
      query(
        collection(db, 'ip_trade_secrets'),
        where('tenantId', '==', ownerUid),
      ),
    ),
  );

  assert.equal(snapshot.size, 1);
});

test('tenant filtresi olmayan koleksiyon sorgusu reddedilir', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    getDocs(collection(db, 'ip_trade_secrets')),
  );
});

test('değiştirilemez sır kodu güncellenemez', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    updateDoc(
      doc(db, 'ip_trade_secrets', secretId),
      {
        secretCode: 'TS-999',
        updatedAt: serverTimestamp(),
        updatedBy: ownerUid,
      },
    ),
  );
});

test('sızıntı şüphesi güvenli biçimde güncellenebilir', async () => {
  await seedTradeSecret();

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertSucceeds(
    updateDoc(
      doc(db, 'ip_trade_secrets', secretId),
      {
        leakageSuspected: true,
        status: 'compromised',
        updatedAt: serverTimestamp(),
        updatedBy: ownerUid,
      },
    ),
  );
});

test('hukuki muhafaza altındaki kayıt silinemez', async () => {
  await seedTradeSecret({
    legalHoldActive: true,
  });

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertFails(
    deleteDoc(doc(db, 'ip_trade_secrets', secretId)),
  );
});

test('hukuki muhafaza bulunmayan kayıt tenant sahibi tarafından silinebilir', async () => {
  await seedTradeSecret({
    legalHoldActive: false,
  });

  const db = testEnvironment
    .authenticatedContext(ownerUid)
    .firestore();

  await assertSucceeds(
    deleteDoc(doc(db, 'ip_trade_secrets', secretId)),
  );
});