'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const a = require('./authorization');

function req(roles = [], extra = {}) {
  return {
    auth: {
      uid: 'u1',
      token: {
        odlaAuthority: {
          roles,
          tenantId: 't1',
          brandUids: ['b1'],
          assignedLaboratoryIds: ['l1'],
          ...extra,
        },
      },
    },
    data: {role: 'authorized_reviewer'},
  };
}
function auth(roles = []) { return a.assertAuthenticatedRequest(req(roles)); }

test('ODLA-BE-AUTH-001 missing auth is denied', () =>
  assert.throws(() => a.assertAuthenticatedRequest({}), /Firebase authentication required/));
test('ODLA-BE-AUTH-002 unknown role is denied', () =>
  assert.throws(() => a.assertActionAuthorized(auth(['not_a_role']), 'read_workspace')));
test('ODLA-BE-AUTH-003 client-supplied role without trusted authority object is denied', () => {
  const r = {auth: {uid: 'u1', token: {}}, data: {role: 'authorized_reviewer'}};
  const x = a.assertAuthenticatedRequest(r);
  assert.throws(() => a.assertActionAuthorized(x, 'adjudicate_finding'));
});
test('ODLA-BE-AUTH-004 cross-tenant access is denied', () =>
  assert.throws(() => a.assertTenantMatch(auth(['verified_rightsholder']), {tenantId: 't2'})));
test('ODLA-BE-AUTH-005 cross-brand access is denied where brand scope is present', () =>
  assert.throws(() => a.assertTenantMatch(auth(['verified_rightsholder']), {brandUid: 'b2'})));
test('ODLA-BE-AUTH-006 verified rightsholder can create case', () =>
  assert.equal(a.assertActionAuthorized(auth(['verified_rightsholder']), 'create_case'), true));
test('ODLA-BE-AUTH-007 authorized representative can create case', () =>
  assert.equal(a.assertActionAuthorized(auth(['authorized_representative']), 'create_case'), true));
test('ODLA-BE-AUTH-008 normal reporter cannot create laboratory request', () => {
  const x = a.assertAuthenticatedRequest(req([]));
  assert.throws(() => a.assertActionAuthorized(x, 'create_test_request'));
});
test('ODLA-BE-AUTH-009 assigned laboratory can record only assigned result', () =>
  assert.equal(a.assertAssignedLaboratory(auth(['assigned_laboratory']), 'l1'), true));
test('ODLA-BE-AUTH-010 assigned laboratory cannot adjudicate finding', () =>
  assert.throws(() => a.assertActionAuthorized(auth(['assigned_laboratory']), 'adjudicate_finding')));
test('ODLA-BE-AUTH-011 authorized reviewer can adjudicate finding', () =>
  assert.equal(a.assertActionAuthorized(auth(['authorized_reviewer']), 'adjudicate_finding'), true));
test('ODLA-BE-AUTH-012 unknown action fails closed', () =>
  assert.throws(() => a.assertActionAuthorized(auth(['authorized_reviewer']), 'unknown_action')));
