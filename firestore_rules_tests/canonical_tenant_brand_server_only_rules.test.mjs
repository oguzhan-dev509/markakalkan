import {after, before, beforeEach, test} from 'node:test';
import fs from 'node:fs';
import {assertFails, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

const projectId = 'demo-markakalkan-rst-0k';
const collections = ['tenants', 'canonical_brands', 'tenant_memberships',
  'tenant_brand_provisioning_receipts',
  'tenant_brand_provisioning_audit_events'];
let environment;
before(async () => {
  if (!/^(127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(
    process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('loopback emulator required');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) throw new Error('production credentials forbidden');
  environment = await initializeTestEnvironment({projectId, firestore: {
    rules: fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());
for (const collection of collections) {
  test(`${collection}: all client access is denied`, async () => {
    const unauth = environment.unauthenticatedContext().firestore();
    const auth = environment.authenticatedContext('super-1').firestore();
    await assertFails(setDoc(doc(unauth, collection, 'record-1'), {value: 1}));
    await assertFails(setDoc(doc(auth, collection, 'record-1'), {value: 1}));
    await environment.withSecurityRulesDisabled(async (context) =>
      setDoc(doc(context.firestore(), collection, 'record-1'), {value: 1}));
    await assertFails(getDoc(doc(auth, collection, 'record-1')));
    await assertFails(updateDoc(doc(auth, collection, 'record-1'), {value: 2}));
    await assertFails(deleteDoc(doc(auth, collection, 'record-1')));
  });
}
