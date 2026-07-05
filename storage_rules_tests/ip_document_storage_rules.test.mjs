import {
  after,
  before,
  beforeEach,
  test,
} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  deleteObject,
  getBytes,
  getMetadata,
  ref,
  uploadBytes,
} from 'firebase/storage';

const projectId = 'markakalkan-app';
const bucketName = 'markakalkan-app.firebasestorage.app';

const tenantA = 'tenant-a';
const tenantB = 'tenant-b';

const shaA =
  '9f64a747e1b97f131fabb6b447296c9b' +
  '6f0201e79fb3c5356e6c77e89b6a806a';

let testEnvironment;

function storageFor(uid) {
  return testEnvironment
    .authenticatedContext(uid)
    .storage(`gs://${bucketName}`);
}

function unauthenticatedStorage() {
  return testEnvironment
    .unauthenticatedContext()
    .storage(`gs://${bucketName}`);
}

function documentPath({
  tenantId = tenantA,
  documentId = 'document-1',
  sha256 = shaA,
  extension = 'pdf',
} = {}) {
  return [
    'tenants',
    tenantId,
    'ip_documents',
    documentId,
    `${sha256}.${extension}`,
  ].join('/');
}

function validMetadata({
  tenantId = tenantA,
  documentId = 'document-1',
  uploadedBy = tenantA,
  sha256 = shaA,
  contentType = 'application/pdf',
} = {}) {
  return {
    contentType,
    cacheControl: 'private, no-store, max-age=0',
    customMetadata: {
      tenantId,
      documentId,
      uploadedBy,
      originalFileName: 'Marka Tescil Belgesi.pdf',
      sha256,
      hashAlgorithm: 'SHA-256',
    },
  };
}

async function seedObject({
  path = documentPath(),
  metadata = validMetadata(),
  bytes = new Uint8Array([1, 2, 3, 4]),
} = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const storage = context.storage(`gs://${bucketName}`);

    await uploadBytes(
      ref(storage, path),
      bytes,
      metadata,
    );
  });
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    storage: {
      rules: fs.readFileSync('../storage.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearStorage();
});

after(async () => {
  await testEnvironment.cleanup();
});

test('tenant sahibi geçerli belge yükleyebilir', async () => {
  const storage = storageFor(tenantA);
  const path = documentPath();

  const result = await assertSucceeds(
    uploadBytes(
      ref(storage, path),
      new Uint8Array([1, 2, 3, 4]),
      validMetadata(),
    ),
  );

  assert.equal(result.ref.fullPath, path);
});

test('anonim kullanıcı belge yükleyemez', async () => {
  const storage = unauthenticatedStorage();

  await assertFails(
    uploadBytes(
      ref(storage, documentPath()),
      new Uint8Array([1]),
      validMetadata(),
    ),
  );
});

test('kullanıcı başka tenant yoluna belge yükleyemez', async () => {
  const storage = storageFor(tenantA);

  await assertFails(
    uploadBytes(
      ref(storage, documentPath({tenantId: tenantB})),
      new Uint8Array([1]),
      validMetadata({
        tenantId: tenantB,
        uploadedBy: tenantA,
      }),
    ),
  );
});

test('izin verilmeyen MIME türü reddedilir', async () => {
  const storage = storageFor(tenantA);

  await assertFails(
    uploadBytes(
      ref(storage, documentPath()),
      new Uint8Array([1]),
      validMetadata({
        contentType: 'application/x-msdownload',
      }),
    ),
  );
});

test('25 MB sınırını aşan belge reddedilir', async () => {
  const storage = storageFor(tenantA);
  const oversizedBytes = new Uint8Array(25 * 1024 * 1024 + 1);

  await assertFails(
    uploadBytes(
      ref(storage, documentPath()),
      oversizedBytes,
      validMetadata(),
    ),
  );
});

test('zorunlu SHA-256 metadata alanı olmayan belge reddedilir', async () => {
  const storage = storageFor(tenantA);
  const metadata = validMetadata();

  delete metadata.customMetadata.sha256;

  await assertFails(
    uploadBytes(
      ref(storage, documentPath()),
      new Uint8Array([1]),
      metadata,
    ),
  );
});

test('geçersiz SHA-256 biçimi reddedilir', async () => {
  const storage = storageFor(tenantA);

  await assertFails(
    uploadBytes(
      ref(storage, documentPath({sha256: 'invalid-hash'})),
      new Uint8Array([1]),
      validMetadata({sha256: 'invalid-hash'}),
    ),
  );
});

test('dosya adı ile SHA-256 metadata uyuşmazlığı reddedilir', async () => {
  const storage = storageFor(tenantA);

  await assertFails(
    uploadBytes(
      ref(storage, documentPath()),
      new Uint8Array([1]),
      validMetadata({
        sha256: 'a'.repeat(64),
      }),
    ),
  );
});

test('tenant sahibi kendi belgesini okuyabilir', async () => {
  const path = documentPath();

  await seedObject({path});

  const storage = storageFor(tenantA);

  const bytes = await assertSucceeds(
    getBytes(ref(storage, path)),
  );

  assert.equal(bytes.byteLength, 4);

  const metadata = await assertSucceeds(
    getMetadata(ref(storage, path)),
  );

  assert.equal(metadata.customMetadata.tenantId, tenantA);
});

test('başka tenant belgeyi okuyamaz veya silemez', async () => {
  const path = documentPath();

  await seedObject({path});

  const foreignStorage = storageFor(tenantB);

  await assertFails(
    getBytes(ref(foreignStorage, path)),
  );

  await assertFails(
    deleteObject(ref(foreignStorage, path)),
  );
});

test('tenant sahibi belgeyi silebilir fakat üzerine yazamaz', async () => {
  const path = documentPath();

  await seedObject({path});

  const storage = storageFor(tenantA);

  await assertFails(
    uploadBytes(
      ref(storage, path),
      new Uint8Array([5, 6, 7]),
      validMetadata(),
    ),
  );

  await assertSucceeds(
    deleteObject(ref(storage, path)),
  );
});