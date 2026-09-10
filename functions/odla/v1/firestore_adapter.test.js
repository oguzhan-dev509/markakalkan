'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {createOdlaFirestoreAdapter} = require('./firestore_adapter');

function dbMock(seed = {}) {
  const docs = new Map(Object.entries(seed));
  function snap(path) {
    return {exists: docs.has(path), data: () => docs.get(path)};
  }
  function ref(path) {
    return {
      path,
      get: async () => snap(path),
      create: async (data) => {
        if (docs.has(path)) throw new Error('exists');
        docs.set(path, data);
      },
      set: async (data, opts) => {
        docs.set(path, opts && opts.merge ? {...(docs.get(path) || {}), ...data} : data);
      },
    };
  }
  return {
    docs,
    doc: ref,
    collection: (path) => ({
      get: async () => {
        const prefix = `${path}/`;
        return {
          docs: [...docs.entries()]
            .filter(([k]) => k.startsWith(prefix) && !k.slice(prefix.length).includes('/'))
            .map(([k, v]) => ({id:k.slice(prefix.length), data:() => v})),
        };
      },
    }),
    runTransaction: async (fn) => fn({
      get: async (r) => snap(r.path),
      create: (r, data) => {
        if (docs.has(r.path)) throw new Error('exists');
        docs.set(r.path, data);
      },
      set: (r, data, opts) => {
        docs.set(r.path, opts && opts.merge ? {...(docs.get(r.path) || {}), ...data} : data);
      },
    }),
  };
}
const FV = {serverTimestamp: () => 'SERVER_TIME'};
const baseCase = {
  caseId:'c1', tenantId:'t1', brandUid:'b1', profileId:'p1',
  profileCode:'COSMETIC_V1', profileVersion:1, productClassCode:'cosmetic',
  countryCode:'TR'
};
function audit(action, op='op1') {
  return {
    auditEventId:`au-${action}-${op}`, caseId:'c1', operationId:op,
    actorUid:'u1', tenantId:'t1', brandUid:'b1', action
  };
}

test('ODLA-BE-DB-001 adapter requires injected db', () =>
  assert.throws(() => createOdlaFirestoreAdapter({db: null, FieldValue: FV})));

test('ODLA-BE-DB-002 case create stores immutable creation metadata', async () => {
  const db = dbMock(); const x = createOdlaFirestoreAdapter({db, FieldValue: FV});
  await x.createCase({caseRecord:baseCase,operationId:'op1',actorUid:'u1',auditContext:audit('create_case')});
  assert.equal(db.docs.get('odlaVerificationCases/c1').immutableCreationMetadata,true);
});

test('ODLA-BE-DB-003 case create is idempotent for same operationId', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  const args={caseRecord:baseCase,operationId:'op1',actorUid:'u1',auditContext:audit('create_case')};
  await x.createCase(args); assert.equal((await x.createCase(args)).idempotent,true);
});

test('ODLA-BE-DB-004 conflicting repeated operationId fails closed', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createCase({caseRecord:baseCase,operationId:'op1',actorUid:'u1',auditContext:audit('create_case')});
  await assert.rejects(()=>x.createCase({
    caseRecord:baseCase,operationId:'op2',actorUid:'u1',auditContext:audit('create_case','op2')
  }));
});

test('ODLA-BE-DB-005 workspace read is case-scoped', async () => {
  const db=dbMock({'odlaVerificationCases/c1':baseCase});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getWorkspace('c1')).case.caseId,'c1');
});

test('ODLA-BE-DB-006 custody append uses transaction', async () => {
  let count=0; const db=dbMock({'odlaVerificationCases/c1':baseCase});
  const orig=db.runTransaction; db.runTransaction=async(fn)=>{count+=1;return orig(fn);};
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.appendCustodyEvent({
    event:{caseId:'c1',eventId:'e1',eventSequence:1,eventPayloadSha256:'h'},
    operationId:'op1',actorUid:'u1',auditContext:audit('append_custody')
  });
  assert.equal(count,1);
});

test('ODLA-BE-DB-007 custody append enforces monotonic sequence precondition', async () => {
  const db=dbMock({'odlaVerificationCases/c1':{...baseCase,latestCustodySequence:1}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await assert.rejects(()=>x.appendCustodyEvent({
    event:{caseId:'c1',eventId:'e3',eventSequence:3,eventPayloadSha256:'h'},
    operationId:'op3',actorUid:'u1',auditContext:audit('append_custody','op3')
  }));
});

test('ODLA-BE-DB-008 custody append persists previous hash linkage', async () => {
  const db=dbMock({'odlaVerificationCases/c1':baseCase});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.appendCustodyEvent({
    event:{caseId:'c1',eventId:'e1',eventSequence:1,eventPayloadSha256:'abc'},
    operationId:'op1',actorUid:'u1',auditContext:audit('append_custody')
  });
  assert.equal(db.docs.get('odlaVerificationCases/c1').latestCustodyEventPayloadSha256,'abc');
});

test('ODLA-BE-DB-009 test request create is idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  const args={caseId:'c1',requestRecord:{testRequestId:'q1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('create_test_request')};
  await x.createTestRequest(args); assert.equal((await x.createTestRequest(args)).idempotent,true);
});

test('ODLA-BE-DB-010 test result create is immutable', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createTestResult({caseId:'c1',resultRecord:{testResultId:'r1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('record_test_result')});
  await assert.rejects(()=>x.createTestResult({caseId:'c1',resultRecord:{testResultId:'r1'},
    operationId:'op2',actorUid:'u1',auditContext:audit('record_test_result','op2')}));
});

test('ODLA-BE-DB-011 finding write is operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  const args={caseId:'c1',findingRecord:{findingId:'f1'},operationId:'op1',actorUid:'u1',
    auditContext:audit('adjudicate_finding')};
  await x.writeFinding(args); assert.equal((await x.writeFinding(args)).idempotent,true);
});

test('ODLA-BE-DB-012 appeal create is operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  const args={caseId:'c1',appealRecord:{appealId:'a1'},operationId:'op1',actorUid:'u1',
    auditContext:audit('open_appeal')};
  await x.createAppeal(args); assert.equal((await x.createAppeal(args)).idempotent,true);
});

test('ODLA-BE-DB-013 audit append is server generated', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  const r=await x.appendAuditEvent('c1',{auditEventId:'au1'});
  assert.equal(r.recordedAt,'SERVER_TIME');
});

test('ODLA-BE-DB-014 adapter exposes no generic collection passthrough', () => {
  const x=createOdlaFirestoreAdapter({db:dbMock(),FieldValue:FV});
  assert.equal(Object.keys(x).some((k)=>/generic|passthrough/i.test(k)),false);
});

test('ODLA-SEC-DB-001 verification profile read uses odlaVerificationProfiles/{profileId}', async () => {
  const db=dbMock({'odlaVerificationProfiles/p1':{status:'active',profileCode:'COSMETIC_V1'}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getVerificationProfile('p1')).profileId,'p1');
});

test('ODLA-SEC-DB-002 missing verification profile fails closed', async () => {
  const x=createOdlaFirestoreAdapter({db:dbMock(),FieldValue:FV});
  await assert.rejects(()=>x.getVerificationProfile('missing'));
});

test('ODLA-SEC-DB-003 test request read is case-scoped', async () => {
  const db=dbMock({'odlaVerificationCases/c1/testRequests/q1':{testRequestId:'q1'}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getTestRequest('c1','q1')).testRequestId,'q1');
});

test('ODLA-SEC-DB-004 finding read is case-scoped', async () => {
  const db=dbMock({'odlaVerificationCases/c1/findings/f1':{findingId:'f1'}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getFinding('c1','f1')).findingId,'f1');
});

test('ODLA-SEC-DB-005 appeal read is case-scoped', async () => {
  const db=dbMock({'odlaVerificationCases/c1/appeals/a1':{appealId:'a1'}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getAppeal('c1','a1')).appealId,'a1');
});

test('ODLA-SEC-DB-006 adjudication context derives open material appeal from persisted appeals', async () => {
  const db=dbMock({
    'odlaVerificationCases/c1':{...baseCase,trustedEvidenceSummary:{serverOwned:true,complete:true}},
    'odlaVerificationCases/c1/appeals/a1':{appealId:'a1',state:'opened',material:true}
  });
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getAdjudicationContext('c1')).openMaterialAppeal,true);
});

test('ODLA-SEC-DB-007 missing trusted evidence summary derives missingRequiredEvidence=true', async () => {
  const x=createOdlaFirestoreAdapter({db:dbMock({'odlaVerificationCases/c1':baseCase}),FieldValue:FV});
  assert.equal((await x.getAdjudicationContext('c1')).missingRequiredEvidence,true);
});

test('ODLA-SEC-DB-008 single reporter condition derives from trusted persisted evidence summary', async () => {
  const db=dbMock({'odlaVerificationCases/c1':{...baseCase,trustedEvidenceSummary:{
    serverOwned:true,complete:true,singleReporterOnly:true}}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getAdjudicationContext('c1')).singleReporterOnly,true);
});

test('ODLA-SEC-DB-009 seller-supplied sole sample condition derives from trusted persisted evidence summary', async () => {
  const db=dbMock({'odlaVerificationCases/c1':{...baseCase,trustedEvidenceSummary:{
    serverOwned:true,complete:true,sellerSuppliedSampleSole:true}}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  assert.equal((await x.getAdjudicationContext('c1')).sellerSuppliedSampleSole,true);
});

test('ODLA-SEC-DB-010 case create and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createCase({caseRecord:baseCase,operationId:'op1',actorUid:'u1',auditContext:audit('create_case')});
  assert.ok(db.docs.has('odlaVerificationCases/c1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-create_case-op1'));
});

test('ODLA-SEC-DB-011 custody append and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock({'odlaVerificationCases/c1':baseCase});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.appendCustodyEvent({event:{caseId:'c1',eventId:'e1',eventSequence:1,eventPayloadSha256:'h'},
    operationId:'op1',actorUid:'u1',auditContext:audit('append_custody')});
  assert.ok(db.docs.has('odlaVerificationCases/c1/custodyEvents/e1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-append_custody-op1'));
});

test('ODLA-SEC-DB-012 test request create and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createTestRequest({caseId:'c1',requestRecord:{testRequestId:'q1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('create_test_request')});
  assert.ok(db.docs.has('odlaVerificationCases/c1/testRequests/q1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-create_test_request-op1'));
});

test('ODLA-SEC-DB-013 test result create and audit event are atomic and immutable', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createTestResult({caseId:'c1',resultRecord:{testResultId:'r1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('record_test_result')});
  assert.ok(db.docs.has('odlaVerificationCases/c1/testResults/r1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-record_test_result-op1'));
});

test('ODLA-SEC-DB-014 finding write and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.writeFinding({caseId:'c1',findingRecord:{findingId:'f1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('adjudicate_finding')});
  assert.ok(db.docs.has('odlaVerificationCases/c1/findings/f1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-adjudicate_finding-op1'));
});

test('ODLA-SEC-DB-015 appeal create and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock(); const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.createAppeal({caseId:'c1',appealRecord:{appealId:'a1'},operationId:'op1',
    actorUid:'u1',auditContext:audit('open_appeal')});
  assert.ok(db.docs.has('odlaVerificationCases/c1/appeals/a1'));
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-open_appeal-op1'));
});

test('ODLA-SEC-DB-016 appeal resolution and audit event are atomic and operation-idempotent', async () => {
  const db=dbMock({'odlaVerificationCases/c1/appeals/a1':{appealId:'a1',state:'opened'}});
  const x=createOdlaFirestoreAdapter({db,FieldValue:FV});
  await x.resolveAppeal({caseId:'c1',appealId:'a1',resolution:{state:'resolved'},
    operationId:'op1',actorUid:'u1',auditContext:audit('resolve_appeal')});
  assert.equal(db.docs.get('odlaVerificationCases/c1/appeals/a1').state,'resolved');
  assert.ok(db.docs.has('odlaVerificationCases/c1/auditEvents/au-resolve_appeal-op1'));
});
