import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  Timestamp,
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

const projectId = 'demo-markakalkan-rst-0h';
const tenantA = 'tenant-a';
const tenantB = 'tenant-b';

let environment;

function record({
  tenantId,
  recordCode = 'OWN-001',
  status = 'draft',
  assetId = 'asset-1',
  documentIds = [],
  relationshipIds = [],
  transferChainRecordIds = [],
  rightId = null,
  sourceOwnershipRecordId = null,
  previousOwnershipRecordId = null,
  nextOwnershipRecordId = null,
  createdAt = Timestamp.fromMillis(1704067200000),
  createdBy = tenantId,
} = {}) {
  return {
    tenantId,
    brandId: 'brand-1',
    assetId,
    recordCode,
    ownershipKind: 'legal_owner',
    partyType: 'company',
    partyName: 'Marka Sahibi A.Ş.',
    partyId: 'party-1',
    partyExternalId: null,
    partyCountryCode: 'TR',
    partyRegistrationNumber: null,
    partyTaxNumber: null,
    partyContactEmail: 'legal@example.com',
    acquisitionType: 'original_creation',
    status,
    ownershipPercentage: 100,
    jurisdictionScope: 'national',
    countryCodes: ['TR'],
    regionCode: null,
    rightId,
    sourceOwnershipRecordId,
    previousOwnershipRecordId,
    nextOwnershipRecordId,
    agreementNumber: null,
    agreementDate: null,
    effectiveFrom: Timestamp.fromMillis(1704067200000),
    effectiveUntil: null,
    isExclusive: true,
    isPrimaryOwner: true,
    isBeneficialOwner: false,
    isOwnershipVerified: false,
    verificationDate: null,
    verifiedBy: null,
    documentIds,
    relationshipIds,
    transferChainRecordIds,
    notes: null,
    metadata: {},
    createdAt,
    createdBy,
    updatedAt: null,
    updatedBy: null,
  };
}

function authenticatedDb(tenantId) {
  return environment.authenticatedContext(tenantId).firestore();
}

async function seed(id, data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'ip_ownership_records', id),
      data,
    );
  });
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
});

after(async () => {
  await environment.cleanup();
});

test('kendi tenant kaydı okunabilir', async () => {
  await seed(
    'own-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-READ',
    }),
  );

  await assertSucceeds(
    getDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'own-record',
      ),
    ),
  );
});

test('yabancı tenant kaydı okunamaz', async () => {
  await seed(
    'foreign-record',
    record({
      tenantId: tenantB,
      recordCode: 'FOREIGN-READ',
    }),
  );

  await assertFails(
    getDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'foreign-record',
      ),
    ),
  );
});

test('geçerli kayıt oluşturulabilir', async () => {
  await assertSucceeds(
    setDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'created-record',
      ),
      record({
        tenantId: tenantA,
        recordCode: 'OWN-CREATE',
        createdAt: serverTimestamp(),
      }),
    ),
  );
});

test('başka tenant adına kayıt oluşturulamaz', async () => {
  await assertFails(
    setDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'foreign-created-record',
      ),
      record({
        tenantId: tenantB,
        recordCode: 'FOREIGN-CREATE',
        createdAt: serverTimestamp(),
        createdBy: tenantA,
      }),
    ),
  );
});

test('assetId değiştirilemez', async () => {
  await seed(
    'immutable-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-IMMUTABLE',
    }),
  );

  await assertFails(
    updateDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'immutable-record',
      ),
      {
        assetId: 'asset-2',
        updatedAt: serverTimestamp(),
        updatedBy: tenantA,
      },
    ),
  );
});

test('geçerli durum güncellemesi yapılabilir', async () => {
  await seed(
    'status-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-STATUS',
    }),
  );

  await assertSucceeds(
    updateDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'status-record',
      ),
      {
        status: 'under_review',
        updatedAt: serverTimestamp(),
        updatedBy: tenantA,
      },
    ),
  );
});

test('doğrulama alanları güncellenebilir', async () => {
  await seed(
    'verification-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-VERIFY',
      status: 'active',
      documentIds: ['document-1'],
    }),
  );

  await assertSucceeds(
    updateDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'verification-record',
      ),
      {
        isOwnershipVerified: true,
        verificationDate: serverTimestamp(),
        verifiedBy: tenantA,
        updatedAt: serverTimestamp(),
        updatedBy: tenantA,
      },
    ),
  );
});

test('bağlantısız taslak kayıt silinebilir', async () => {
  await seed(
    'clean-draft',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-DELETE-DRAFT',
    }),
  );

  await assertSucceeds(
    deleteDoc(
      doc(
        authenticatedDb(tenantA),
        'ip_ownership_records',
        'clean-draft',
      ),
    ),
  );
});

test('aktif ve bağlantılı kayıtlar silinemez', async () => {
  await seed(
    'active-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-ACTIVE',
      status: 'active',
    }),
  );

  await seed(
    'linked-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-LINKED',
      documentIds: ['document-1'],
    }),
  );

  const db = authenticatedDb(tenantA);

  await assertFails(
    deleteDoc(
      doc(db, 'ip_ownership_records', 'active-record'),
    ),
  );

  await assertFails(
    deleteDoc(
      doc(db, 'ip_ownership_records', 'linked-record'),
    ),
  );
});

test('tenant filtreli sorgu yalnız kendi kayıtlarını döndürür', async () => {
  await seed(
    'tenant-a-record',
    record({
      tenantId: tenantA,
      recordCode: 'OWN-TENANT-A',
    }),
  );

  await seed(
    'tenant-b-record',
    record({
      tenantId: tenantB,
      recordCode: 'OWN-TENANT-B',
    }),
  );

  const snapshot = await assertSucceeds(
    getDocs(
      query(
        collection(
          authenticatedDb(tenantA),
          'ip_ownership_records',
        ),
        where('tenantId', '==', tenantA),
      ),
    ),
  );

  assert.equal(snapshot.size, 1);
  assert.equal(snapshot.docs[0].id, 'tenant-a-record');
});
