import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  CapabilityAccessContextV1 anonymous() => CapabilityAccessContextV1(
    loggedIn: false,
    verifiedBrand: false,
    subscriptionActive: false,
    operationAuthorityGranted: false,
  );

  CapabilityAccessContextV1 loggedIn({
    bool verifiedBrand = false,
    bool subscriptionActive = false,
    bool operationAuthorityGranted = false,
    List<String> grantedRoleCodes = const [],
    List<String> grantedApprovalCodes = const [],
  }) => CapabilityAccessContextV1(
    loggedIn: true,
    verifiedBrand: verifiedBrand,
    subscriptionActive: subscriptionActive,
    operationAuthorityGranted: operationAuthorityGranted,
    grantedRoleCodes: grantedRoleCodes,
    grantedApprovalCodes: grantedApprovalCodes,
  );

  test('public risk visibility is free by default', () {
    final policy = CapabilityAccessPolicyV1.defaultFor(
      RiskCapabilityCodeV1.publicRiskVisibility,
    );
    expect(policy.isFree, isTrue);
    expect(
      evaluateCapabilityAccessV1(policy: policy, context: anonymous()).granted,
      isTrue,
    );
  });

  test('FREE cannot be mixed with another access requirement', () {
    expect(
      () => CapabilityAccessPolicyV1(
        capabilityCode: RiskCapabilityCodeV1.publicRiskVisibility,
        requirements: const [
          AccessRequirementCodeV1.free,
          AccessRequirementCodeV1.loginRequired,
        ],
      ),
      throwsFormatException,
    );
  });

  test('duplicate requirements fail closed', () {
    expect(
      () => CapabilityAccessPolicyV1(
        capabilityCode: RiskCapabilityCodeV1.detailedRiskAnalysis,
        requirements: const [
          AccessRequirementCodeV1.loginRequired,
          AccessRequirementCodeV1.loginRequired,
        ],
      ),
      throwsFormatException,
    );
  });

  test('detailed risk analysis requires login by default', () {
    final policy = CapabilityAccessPolicyV1.defaultFor(
      RiskCapabilityCodeV1.detailedRiskAnalysis,
    );

    final denied = evaluateCapabilityAccessV1(
      policy: policy,
      context: anonymous(),
    );
    expect(denied.granted, isFalse);
    expect(denied.missingRequirements, [AccessRequirementCodeV1.loginRequired]);

    final granted = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(),
    );
    expect(granted.granted, isTrue);
  });

  test('evidence export requires verified brand by default', () {
    final policy = CapabilityAccessPolicyV1.defaultFor(
      RiskCapabilityCodeV1.evidenceExport,
    );
    final decision = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(),
    );

    expect(decision.granted, isFalse);
    expect(decision.missingRequirements, [
      AccessRequirementCodeV1.verifiedBrandRequired,
    ]);
  });

  test('subscription is additional and never replaces brand verification', () {
    final policy = CapabilityAccessPolicyV1(
      capabilityCode: RiskCapabilityCodeV1.evidenceExport,
      requirements: const [
        AccessRequirementCodeV1.verifiedBrandRequired,
        AccessRequirementCodeV1.subscriptionRequired,
      ],
      subscriptionPlanCode: 'risk_pro_v1',
    );

    final decision = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(subscriptionActive: true),
    );

    expect(decision.granted, isFalse);
    expect(decision.missingRequirements, [
      AccessRequirementCodeV1.verifiedBrandRequired,
    ]);
  });

  test('subscription does not replace operation authority', () {
    final policy = CapabilityAccessPolicyV1(
      capabilityCode: RiskCapabilityCodeV1.legalAction,
      requirements: const [
        AccessRequirementCodeV1.subscriptionRequired,
        AccessRequirementCodeV1.operationAuthorityRequired,
      ],
    );

    final decision = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(subscriptionActive: true),
    );

    expect(decision.granted, isFalse);
    expect(decision.missingRequirements, [
      AccessRequirementCodeV1.operationAuthorityRequired,
    ]);
  });

  test('required role and approval codes are evaluated fail closed', () {
    final policy = CapabilityAccessPolicyV1(
      capabilityCode: RiskCapabilityCodeV1.legalAction,
      requirements: const [AccessRequirementCodeV1.operationAuthorityRequired],
      requiredRoleCodes: const ['legal_operator'],
      requiredApprovalCodes: const ['human_review_approved'],
    );

    final denied = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(operationAuthorityGranted: true),
    );
    expect(denied.granted, isFalse);
    expect(denied.missingRoleCodes, ['legal_operator']);
    expect(denied.missingApprovalCodes, ['human_review_approved']);

    final granted = evaluateCapabilityAccessV1(
      policy: policy,
      context: loggedIn(
        operationAuthorityGranted: true,
        grantedRoleCodes: const ['legal_operator'],
        grantedApprovalCodes: const ['human_review_approved'],
      ),
    );
    expect(granted.granted, isTrue);
  });

  test(
    'consequential defaults require authority but not paid subscription',
    () {
      for (final capability in const [
        RiskCapabilityCodeV1.legalAction,
        RiskCapabilityCodeV1.customsAction,
        RiskCapabilityCodeV1.platformIntervention,
      ]) {
        final policy = CapabilityAccessPolicyV1.defaultFor(capability);
        expect(policy.requiresOperationAuthority, isTrue);
        expect(policy.requiresSubscription, isFalse);
      }
    },
  );

  test('subscription plan code cannot exist without subscription gate', () {
    expect(
      () => CapabilityAccessPolicyV1(
        capabilityCode: RiskCapabilityCodeV1.detailedRiskAnalysis,
        requirements: const [AccessRequirementCodeV1.loginRequired],
        subscriptionPlanCode: 'risk_pro_v1',
      ),
      throwsFormatException,
    );
  });

  test('privileged facts without login fail closed', () {
    expect(
      () => CapabilityAccessContextV1(
        loggedIn: false,
        verifiedBrand: true,
        subscriptionActive: false,
        operationAuthorityGranted: false,
      ),
      throwsFormatException,
    );
    expect(
      () => CapabilityAccessContextV1(
        loggedIn: false,
        verifiedBrand: false,
        subscriptionActive: false,
        operationAuthorityGranted: false,
        grantedRoleCodes: const ['role'],
      ),
      throwsFormatException,
    );
  });

  test('policy JSON round-trips stable language-independent codes', () {
    final original = CapabilityAccessPolicyV1(
      capabilityCode: RiskCapabilityCodeV1.caseCreation,
      requirements: const [
        AccessRequirementCodeV1.verifiedBrandRequired,
        AccessRequirementCodeV1.subscriptionRequired,
      ],
      subscriptionPlanCode: 'risk_case_v1',
      requiredRoleCodes: const ['brand_manager'],
      requiredApprovalCodes: const ['case_create'],
    );

    final json = original.toJson();
    expect(json['capabilityCode'], 'CASE_CREATION');
    expect(json['requirements'], [
      'VERIFIED_BRAND_REQUIRED',
      'SUBSCRIPTION_REQUIRED',
    ]);

    final restored = CapabilityAccessPolicyV1.fromJson(json);
    expect(restored.toJson(), json);
  });

  test('unknown access requirement code is rejected', () {
    expect(
      () => CapabilityAccessPolicyV1.fromJson({
        'contractVersion': capabilityAccessPolicyContractVersionV1,
        'capabilityCode': 'DETAILED_RISK_ANALYSIS',
        'requirements': ['MAGIC_ACCESS'],
        'requiredRoleCodes': <String>[],
        'requiredApprovalCodes': <String>[],
      }),
      throwsFormatException,
    );
  });

  test('policy collections are immutable snapshots', () {
    final requirements = <AccessRequirementCodeV1>[
      AccessRequirementCodeV1.verifiedBrandRequired,
    ];
    final roles = <String>['brand_manager'];

    final policy = CapabilityAccessPolicyV1(
      capabilityCode: RiskCapabilityCodeV1.caseCreation,
      requirements: requirements,
      requiredRoleCodes: roles,
    );

    requirements.add(AccessRequirementCodeV1.subscriptionRequired);
    roles.add('other');

    expect(policy.requirements, [
      AccessRequirementCodeV1.verifiedBrandRequired,
    ]);
    expect(policy.requiredRoleCodes, ['brand_manager']);
    expect(() => policy.requiredRoleCodes.add('x'), throwsUnsupportedError);
  });
}
