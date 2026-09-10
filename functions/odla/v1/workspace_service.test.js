'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {createOdlaWorkspaceService} = require('./workspace_service');

function authority(role='verified_rightsholder') {
  return {uid:'u1',roles:[role],tenantId:'t1',brandUids:['b1'],assignedLaboratoryIds:['l1','l2']};
}
const ov = {status:'active',countryCode:'TR',productClassCode:'cosmetic',overrideVersion:1};
const profile = {
  profileId:'p1',status:'active',profileCode:'COSMETIC_V1',profileVersion:1,
  productClassCode:'cosmetic',jurisdictionOverrides:{TR:ov}
};
const baseCase = {
  caseId:'c1',tenantId:'t1',brandUid:'b1',profileId:'p1',
  profileCode:'COSMETIC_V1',profileVersion:1,productClassCode:'cosmetic',countryCode:'TR'
};
const lab = {
  laboratoryId:'l1',status:'active',productClassCodes:['cosmetic'],
  testMethodCodes:['METHOD1'],scopeCodes:['SCOPE1'],chainOfCustodySupported:true,
  ownerType:'INDEPENDENT',
};

function defaultRequest(id='q1') {
  if (id === 'q2') return {
    testRequestId:'q2',sampleId:'s1',laboratoryId:'l2',
    testQuestionCode:'FORMULATION_OR_REFERENCE_CONSISTENCY',
    methodCode:'METHOD1',appealId:'a1'
  };
  return {
    testRequestId:id,sampleId:'s1',laboratoryId:'l1',
    testQuestionCode:'FORMULATION_OR_REFERENCE_CONSISTENCY',
    methodCode:'METHOD1'
  };
}

function adapter(overrides={}) {
  const calls=[];
  return {
    calls,
    createCase:async(args)=>{calls.push(['createCase',args]);return{data:args.caseRecord,idempotent:false};},
    getWorkspace:async()=>({case:{...baseCase}}),
    getVerificationProfile:async()=>({...profile}),
    getLatestCustodyEvent:async()=>null,
    appendCustodyEvent:async(args)=>{calls.push(['appendCustodyEvent',args]);return{data:args.event,idempotent:false};},
    getLaboratory:async(id)=>({...lab,laboratoryId:id}),
    createTestRequest:async(args)=>{calls.push(['createTestRequest',args]);return{data:args.requestRecord,idempotent:false};},
    getTestRequest:async(_caseId,id)=>defaultRequest(id),
    createTestResult:async(args)=>{calls.push(['createTestResult',args]);return{data:args.resultRecord,idempotent:false};},
    writeFinding:async(args)=>{calls.push(['writeFinding',args]);return{data:args.findingRecord,idempotent:false};},
    getFinding:async(_caseId,id)=>({findingId:id,primaryLaboratoryId:'l1'}),
    createAppeal:async(args)=>{calls.push(['createAppeal',args]);return{data:args.appealRecord,idempotent:false};},
    getAppeal:async(_caseId,id)=>({
      appealId:id,challengedFindingId:'f1',originalPrimaryLaboratoryId:'l1',
      appealTestRequestId:'q2',state:'opened',material:true
    }),
    resolveAppeal:async(args)=>{calls.push(['resolveAppeal',args]);return{data:args.resolution,idempotent:false};},
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:false,sellerSuppliedSampleSole:false,source:'server_persisted_odla_state'
    }),
    ...overrides,
  };
}
function caseData() {
  return {operationId:'op1',caseId:'c1',tenantId:'t1',brandUid:'b1',profileId:'p1',
    countryCode:'TR',profileCode:'CLIENT_IGNORED',productClassCode:'CLIENT_IGNORED',
    jurisdictionOverride:{...ov,source:'CLIENT_IGNORED'}};
}
function testReqData() {
  return {...caseData(),testRequestId:'q1',sampleId:'s1',laboratoryId:'l1',
    testQuestionCode:'FORMULATION_OR_REFERENCE_CONSISTENCY',methodCode:'METHOD1'};
}
function resultData() {
  return {operationId:'op-r',tenantId:'t1',brandUid:'b1',caseId:'c1',
    testResultId:'r1',testRequestId:'q1',sampleId:'s1',laboratoryId:'l1',
    laboratoryReportId:'rep1',reportSha256:'a'.repeat(64),resultCode:'CONSISTENT'};
}
function findingData() {
  return {operationId:'op-f',tenantId:'t1',brandUid:'b1',caseId:'c1',
    findingId:'f1',findingVersion:1,findingInputs:{rightsholderConfirmed:true}};
}
function appealOpenData() {
  return {operationId:'op-a',tenantId:'t1',brandUid:'b1',caseId:'c1',
    appealId:'a1',challengedFindingId:'f1',groundCode:'request_second_independent_lab'};
}
function appealResolveData() {
  return {operationId:'op-ar',tenantId:'t1',brandUid:'b1',caseId:'c1',
    appealId:'a1',conflictingLaboratoryResults:false,
    findingInputs:{rightsholderConfirmed:true}};
}

test('ODLA-BE-SVC-001 create case requires authorized requester', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  await assert.rejects(()=>s.createOdlaVerificationCase({
    authority:authority('assigned_laboratory'),data:caseData()
  }));
});

test('ODLA-BE-SVC-002 workspace read returns authorization-scoped DTO', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  assert.equal((await s.getOdlaVerificationWorkspace({
    authority:authority(),data:{caseId:'c1',tenantId:'t1',brandUid:'b1'}
  })).case.caseId,'c1');
});

test('ODLA-BE-SVC-003 custody sequence gap is rejected', async () => {
  const prev={tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',eventSequence:1,eventType:'sealed',
    occurredAt:'2026-01-01T00:00:00Z',recordedAt:'2026-01-01T00:00:00Z',actorType:'operator',
    actorId:'u0',locationCode:'TR',sealId:'S1',previousEventId:null,previousEventPayloadSha256:null,
    evidenceRefs:[],appendOnly:true,eventId:'x',eventPayloadSha256:'y'};
  const s=createOdlaWorkspaceService({adapter:adapter({getLatestCustodyEvent:async()=>prev})});
  await assert.rejects(()=>s.appendOdlaChainOfCustodyEvent({authority:authority(),data:{
    operationId:'op2',tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',eventSequence:3,
    eventType:'transported',occurredAt:'2026-01-02T00:00:00Z',recordedAt:'2026-01-02T00:00:00Z',
    actorType:'operator',locationCode:'TR',sealId:'S1',evidenceRefs:[]
  }}));
});

test('ODLA-BE-SVC-004 custody previous-hash mismatch is rejected', async () => {
  const core=require('../chain_of_custody');
  const prev=core.buildCustodyEvent({tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',
    eventSequence:1,eventType:'sealed',occurredAt:'2026-01-01T00:00:00Z',recordedAt:'2026-01-01T00:00:00Z',
    actorType:'operator',actorId:'u0',locationCode:'TR',sealId:'S1',evidenceRefs:[]});
  const tampered={...prev,eventPayloadSha256:'0'.repeat(64)};
  const s=createOdlaWorkspaceService({adapter:adapter({getLatestCustodyEvent:async()=>tampered})});
  await assert.rejects(()=>s.appendOdlaChainOfCustodyEvent({authority:authority(),data:{
    operationId:'op2',tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',eventSequence:2,
    eventType:'transported',occurredAt:'2026-01-02T00:00:00Z',recordedAt:'2026-01-02T00:00:00Z',
    actorType:'operator',locationCode:'TR',sealId:'S1',evidenceRefs:[]
  }}));
});

test('ODLA-BE-SVC-005 seal continuity failure is denied or explicitly escalated', async () => {
  const core=require('../chain_of_custody');
  const prev=core.buildCustodyEvent({tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',
    eventSequence:1,eventType:'sealed',occurredAt:'2026-01-01T00:00:00Z',recordedAt:'2026-01-01T00:00:00Z',
    actorType:'operator',actorId:'u0',locationCode:'TR',sealId:'S1',evidenceRefs:[]});
  const s=createOdlaWorkspaceService({adapter:adapter({getLatestCustodyEvent:async()=>prev})});
  await assert.rejects(()=>s.appendOdlaChainOfCustodyEvent({authority:authority(),data:{
    operationId:'op2',tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',eventSequence:2,
    eventType:'lab_opened',occurredAt:'2026-01-02T00:00:00Z',recordedAt:'2026-01-02T00:00:00Z',
    actorType:'laboratory',locationCode:'TR',sealId:'S2',evidenceRefs:[]
  }}));
});

test('ODLA-BE-SVC-006 lab product-method-scope mismatch is rejected', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getLaboratory:async()=>({...lab,testMethodCodes:['OTHER']})
  })});
  await assert.rejects(()=>s.createOdlaTestRequest({authority:authority(),data:testReqData()}));
});

test('ODLA-BE-SVC-007 normal reporter cannot order lab', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  await assert.rejects(()=>s.createOdlaTestRequest({
    authority:{...authority(),roles:[]},data:testReqData()
  }));
});

test('ODLA-BE-SVC-008 seller-supplied sample cannot be sole final evidence', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:false,sellerSuppliedSampleSole:true
    })
  })});
  await assert.rejects(()=>s.adjudicateOdlaFinding({
    authority:authority('authorized_reviewer'),data:findingData()
  }));
});

test('ODLA-BE-SVC-009 brand-owned lab evidence remains explicitly classified', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getLaboratory:async()=>({...lab,ownerType:'RIGHTSHOLDER'}),
    createTestRequest:async({requestRecord})=>{
      captured=requestRecord;return{data:requestRecord,idempotent:false};
    }
  })});
  await s.createOdlaTestRequest({authority:authority(),data:testReqData()});
  assert.equal(captured.laboratoryEvidenceClass,'BRAND_OWNED');
});

test('ODLA-BE-SVC-010 quality nonconformance alone cannot become counterfeit', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    writeFinding:async({findingRecord})=>{
      captured=findingRecord;return{data:findingRecord,idempotent:false};
    }
  })});
  await s.adjudicateOdlaFinding({authority:authority('authorized_reviewer'),data:{
    ...findingData(),findingInputs:{qualityNonconforming:true}
  }});
  assert.equal(captured.findingCode,'QUALITY_NONCONFORMING');
  assert.equal(captured.permanentFinalityAllowed,false);
});

test('ODLA-BE-SVC-011 single reporter cannot create final counterfeit finding', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:true,sellerSuppliedSampleSole:false
    })
  })});
  await assert.rejects(()=>s.adjudicateOdlaFinding({
    authority:authority('authorized_reviewer'),data:findingData()
  }));
});

test('ODLA-BE-SVC-012 open material appeal blocks permanent adverse finality', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:true,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:false,sellerSuppliedSampleSole:false
    }),
    writeFinding:async({findingRecord})=>{
      captured=findingRecord;return{data:findingRecord,idempotent:false};
    }
  })});
  await s.adjudicateOdlaFinding({
    authority:authority('authorized_reviewer'),data:findingData()
  });
  assert.equal(captured.permanentFinalityAllowed,false);
});

test('ODLA-BE-SVC-013 appeal cannot reuse original primary laboratory', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAppeal:async()=>({
      appealId:'a1',originalPrimaryLaboratoryId:'l1',
      appealTestRequestId:'q2',state:'opened',material:true
    }),
    getTestRequest:async()=>({testRequestId:'q2',laboratoryId:'l1',sampleId:'s1',appealId:'a1'})
  })});
  await assert.rejects(()=>s.resolveOdlaAppeal({
    authority:authority('authorized_reviewer'),data:appealResolveData()
  }));
});

test('ODLA-BE-SVC-014 conflicting laboratory results enter conflict review', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  const r=await s.resolveOdlaAppeal({
    authority:authority('authorized_reviewer'),
    data:{...appealResolveData(),conflictingLaboratoryResults:true}
  });
  assert.equal(r.data.state,'conflict_review');
});

test('ODLA-SEC-SVC-001 case creation requires server-loaded profileId', async () => {
  let seen=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getVerificationProfile:async(id)=>{seen=id;return{...profile};}
  })});
  await s.createOdlaVerificationCase({authority:authority(),data:caseData()});
  assert.equal(seen,'p1');
});

test('ODLA-SEC-SVC-002 client jurisdictionOverride is never authoritative', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    createCase:async({caseRecord})=>{captured=caseRecord;return{data:caseRecord,idempotent:false};}
  })});
  await s.createOdlaVerificationCase({authority:authority(),data:{
    ...caseData(),jurisdictionOverride:{status:'active',countryCode:'TR',productClassCode:'pharmaceutical'}
  }});
  assert.equal(captured.productClassCode,'cosmetic');
});

test('ODLA-SEC-SVC-003 case profile code version and product class derive from trusted profile document', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    createCase:async({caseRecord})=>{captured=caseRecord;return{data:caseRecord,idempotent:false};}
  })});
  await s.createOdlaVerificationCase({authority:authority(),data:{
    ...caseData(),profileCode:'FORGED',productClassCode:'forged'
  }});
  assert.equal(captured.profileCode,'COSMETIC_V1');
  assert.equal(captured.profileVersion,1);
  assert.equal(captured.productClassCode,'cosmetic');
});

test('ODLA-SEC-SVC-004 test request policy derives from persisted case plus trusted profile', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    createTestRequest:async({requestRecord})=>{captured=requestRecord;return{data:requestRecord,idempotent:false};}
  })});
  await s.createOdlaTestRequest({authority:authority(),data:{
    ...testReqData(),profileCode:'FORGED',productClassCode:'forged',
    jurisdictionOverride:{status:'active',countryCode:'TR',productClassCode:'pharmaceutical'}
  }});
  assert.equal(captured.profileCode,'COSMETIC_V1');
  assert.equal(captured.profileId,'p1');
});

test('ODLA-SEC-SVC-005 result for nonexistent persisted test request is rejected', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getTestRequest:async()=>{throw Object.assign(new Error('missing'),{code:'not-found'});}
  })});
  await assert.rejects(()=>s.recordOdlaTestResult({
    authority:authority('assigned_laboratory'),data:resultData()
  }));
});

test('ODLA-SEC-SVC-006 result sampleId mismatch against persisted test request is rejected', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  await assert.rejects(()=>s.recordOdlaTestResult({
    authority:authority('assigned_laboratory'),data:{...resultData(),sampleId:'wrong'}
  }),/TEST_RESULT_SAMPLE_BINDING_MISMATCH/);
});

test('ODLA-SEC-SVC-007 result laboratoryId mismatch against persisted test request is rejected', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter()});
  await assert.rejects(()=>s.recordOdlaTestResult({
    authority:authority('assigned_laboratory'),data:{...resultData(),laboratoryId:'l2'}
  }),/TEST_RESULT_LAB_BINDING_MISMATCH/);
});

test('ODLA-SEC-SVC-008 assigned-laboratory authorization uses persisted request laboratoryId', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getTestRequest:async()=>({...defaultRequest(),laboratoryId:'l2'})
  })});
  const a={...authority('assigned_laboratory'),assignedLaboratoryIds:['l1']};
  await assert.rejects(()=>s.recordOdlaTestResult({
    authority:a,data:{...resultData(),laboratoryId:undefined}
  }));
});

test('ODLA-SEC-SVC-009 persisted open material appeal blocks permanent finality', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:true,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:false,sellerSuppliedSampleSole:false
    }),
    writeFinding:async({findingRecord})=>{captured=findingRecord;return{data:findingRecord};}
  })});
  await s.adjudicateOdlaFinding({authority:authority('authorized_reviewer'),data:{
    ...findingData(),openMaterialAppeal:false
  }});
  assert.equal(captured.permanentFinalityAllowed,false);
});

test('ODLA-SEC-SVC-010 missing trusted evidence summary blocks permanent finality', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:true,
      singleReporterOnly:false,sellerSuppliedSampleSole:false
    }),
    writeFinding:async({findingRecord})=>{captured=findingRecord;return{data:findingRecord};}
  })});
  await s.adjudicateOdlaFinding({authority:authority('authorized_reviewer'),data:{
    ...findingData(),missingRequiredEvidence:false
  }});
  assert.equal(captured.permanentFinalityAllowed,false);
});

test('ODLA-SEC-SVC-011 persisted single-reporter-only evidence blocks permanent finality', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:true,sellerSuppliedSampleSole:false
    })
  })});
  await assert.rejects(()=>s.adjudicateOdlaFinding({
    authority:authority('authorized_reviewer'),
    data:{...findingData(),evidence:{singleReporterOnly:false}}
  }));
});

test('ODLA-SEC-SVC-012 persisted seller-supplied-sole-sample evidence blocks permanent finality', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAdjudicationContext:async()=>({
      openMaterialAppeal:false,unresolvedIntegrityConflict:false,missingRequiredEvidence:false,
      singleReporterOnly:false,sellerSuppliedSampleSole:true
    })
  })});
  await assert.rejects(()=>s.adjudicateOdlaFinding({
    authority:authority('authorized_reviewer'),
    data:{...findingData(),evidence:{sellerSuppliedSampleSole:false}}
  }));
});

test('ODLA-SEC-SVC-013 opening appeal against nonexistent challenged finding is rejected', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getFinding:async()=>{throw Object.assign(new Error('missing'),{code:'not-found'});}
  })});
  await assert.rejects(()=>s.openOdlaAppeal({authority:authority(),data:appealOpenData()}));
});

test('ODLA-SEC-SVC-014 appeal stores original primary laboratory only from persisted challenged finding', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    getFinding:async()=>({findingId:'f1',primaryLaboratoryId:'SERVER-LAB'}),
    createAppeal:async({appealRecord})=>{captured=appealRecord;return{data:appealRecord};}
  })});
  await s.openOdlaAppeal({authority:authority(),data:{
    ...appealOpenData(),originalPrimaryLaboratoryId:'CLIENT-LAB'
  }});
  assert.equal(captured.originalPrimaryLaboratoryId,'SERVER-LAB');
});

test('ODLA-SEC-SVC-015 appeal-linked test request uses persisted appeal primary lab and rejects same lab', async () => {
  const s=createOdlaWorkspaceService({adapter:adapter({
    getAppeal:async()=>({
      appealId:'a1',state:'opened',material:true,originalPrimaryLaboratoryId:'l1'
    })
  })});
  await assert.rejects(()=>s.createOdlaTestRequest({authority:authority(),data:{
    ...testReqData(),appealId:'a1',laboratoryId:'l1'
  }}),/APPEAL_LAB_NOT_INDEPENDENT/);
});

test('ODLA-SEC-SVC-016 appeal resolution uses persisted appeal and persisted appeal test request identities', async () => {
  let captured=null;
  const s=createOdlaWorkspaceService({adapter:adapter({
    resolveAppeal:async(args)=>{captured=args;return{data:args.resolution};}
  })});
  await s.resolveOdlaAppeal({authority:authority('authorized_reviewer'),data:{
    ...appealResolveData(),originalPrimaryLaboratoryId:'CLIENT-A',
    appealLaboratoryId:'CLIENT-B'
  }});
  assert.equal(captured.resolution.originalPrimaryLaboratoryId,'l1');
  assert.equal(captured.resolution.appealLaboratoryId,'l2');
});

test('ODLA-SEC-SVC-017 case creation passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.createOdlaVerificationCase({authority:authority(),data:caseData()});
  const ctx=a.calls.find((x)=>x[0]==='createCase')[1].auditContext;
  assert.equal(ctx.action,'create_case'); assert.equal(ctx.source,'odla_server_trusted_context');
});

test('ODLA-SEC-SVC-018 custody append passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.appendOdlaChainOfCustodyEvent({authority:authority(),data:{
    operationId:'op-c',tenantId:'t1',brandUid:'b1',caseId:'c1',sampleId:'s1',eventSequence:1,
    eventType:'sealed',occurredAt:'2026-01-01T00:00:00Z',recordedAt:'2026-01-01T00:00:00Z',
    actorType:'operator',locationCode:'TR',sealId:'S1',evidenceRefs:[]
  }});
  assert.equal(a.calls.find((x)=>x[0]==='appendCustodyEvent')[1].auditContext.action,'append_custody');
});

test('ODLA-SEC-SVC-019 test request creation passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.createOdlaTestRequest({authority:authority(),data:testReqData()});
  assert.equal(a.calls.find((x)=>x[0]==='createTestRequest')[1].auditContext.action,'create_test_request');
});

test('ODLA-SEC-SVC-020 result recording passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.recordOdlaTestResult({authority:authority('assigned_laboratory'),data:resultData()});
  assert.equal(a.calls.find((x)=>x[0]==='createTestResult')[1].auditContext.action,'record_test_result');
});

test('ODLA-SEC-SVC-021 finding adjudication passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.adjudicateOdlaFinding({authority:authority('authorized_reviewer'),data:findingData()});
  assert.equal(a.calls.find((x)=>x[0]==='writeFinding')[1].auditContext.action,'adjudicate_finding');
});

test('ODLA-SEC-SVC-022 appeal opening passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.openOdlaAppeal({authority:authority(),data:appealOpenData()});
  assert.equal(a.calls.find((x)=>x[0]==='createAppeal')[1].auditContext.action,'open_appeal');
});

test('ODLA-SEC-SVC-023 appeal resolution passes server-generated audit context to adapter', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.resolveOdlaAppeal({authority:authority('authorized_reviewer'),data:appealResolveData()});
  assert.equal(a.calls.find((x)=>x[0]==='resolveAppeal')[1].auditContext.action,'resolve_appeal');
});

test('ODLA-SEC-SVC-024 client-supplied audit or trust fields cannot override server-generated audit context', async () => {
  const a=adapter(); const s=createOdlaWorkspaceService({adapter:a});
  await s.createOdlaVerificationCase({authority:authority(),data:{
    ...caseData(),auditEventId:'CLIENT',action:'CLIENT',actorUid:'CLIENT',
    trustedEvidenceSummary:{serverOwned:true,complete:true}
  }});
  const ctx=a.calls.find((x)=>x[0]==='createCase')[1].auditContext;
  assert.notEqual(ctx.auditEventId,'CLIENT');
  assert.equal(ctx.actorUid,'u1');
  assert.equal(ctx.action,'create_case');
});
