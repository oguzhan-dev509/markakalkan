part of 'shared_risk_contracts_v1.dart';

const String capabilityAccessPolicyContractVersionV1 =
    'capability-access-policy-v1';

enum AccessRequirementCodeV1 {
  free,
  loginRequired,
  verifiedBrandRequired,
  subscriptionRequired,
  operationAuthorityRequired,
}

enum RiskCapabilityCodeV1 {
  publicRiskVisibility,
  detailedRiskAnalysis,
  evidenceExport,
  caseCreation,
  legalAction,
  customsAction,
  platformIntervention,
}

String _accessRequirementValue(AccessRequirementCodeV1 value) =>
    switch (value) {
      AccessRequirementCodeV1.free => 'FREE',
      AccessRequirementCodeV1.loginRequired => 'LOGIN_REQUIRED',
      AccessRequirementCodeV1.verifiedBrandRequired =>
        'VERIFIED_BRAND_REQUIRED',
      AccessRequirementCodeV1.subscriptionRequired => 'SUBSCRIPTION_REQUIRED',
      AccessRequirementCodeV1.operationAuthorityRequired =>
        'OPERATION_AUTHORITY_REQUIRED',
    };

AccessRequirementCodeV1 _accessRequirementFrom(Object? value) =>
    _enumValue(value, {
      'FREE': AccessRequirementCodeV1.free,
      'LOGIN_REQUIRED': AccessRequirementCodeV1.loginRequired,
      'VERIFIED_BRAND_REQUIRED': AccessRequirementCodeV1.verifiedBrandRequired,
      'SUBSCRIPTION_REQUIRED': AccessRequirementCodeV1.subscriptionRequired,
      'OPERATION_AUTHORITY_REQUIRED':
          AccessRequirementCodeV1.operationAuthorityRequired,
    }, 'accessRequirementCode');

String _riskCapabilityValue(RiskCapabilityCodeV1 value) => switch (value) {
  RiskCapabilityCodeV1.publicRiskVisibility => 'PUBLIC_RISK_VISIBILITY',
  RiskCapabilityCodeV1.detailedRiskAnalysis => 'DETAILED_RISK_ANALYSIS',
  RiskCapabilityCodeV1.evidenceExport => 'EVIDENCE_EXPORT',
  RiskCapabilityCodeV1.caseCreation => 'CASE_CREATION',
  RiskCapabilityCodeV1.legalAction => 'LEGAL_ACTION',
  RiskCapabilityCodeV1.customsAction => 'CUSTOMS_ACTION',
  RiskCapabilityCodeV1.platformIntervention => 'PLATFORM_INTERVENTION',
};

RiskCapabilityCodeV1 _riskCapabilityFrom(Object? value) => _enumValue(value, {
  'PUBLIC_RISK_VISIBILITY': RiskCapabilityCodeV1.publicRiskVisibility,
  'DETAILED_RISK_ANALYSIS': RiskCapabilityCodeV1.detailedRiskAnalysis,
  'EVIDENCE_EXPORT': RiskCapabilityCodeV1.evidenceExport,
  'CASE_CREATION': RiskCapabilityCodeV1.caseCreation,
  'LEGAL_ACTION': RiskCapabilityCodeV1.legalAction,
  'CUSTOMS_ACTION': RiskCapabilityCodeV1.customsAction,
  'PLATFORM_INTERVENTION': RiskCapabilityCodeV1.platformIntervention,
}, 'capabilityCode');

List<AccessRequirementCodeV1> _accessRequirements(
  Iterable<AccessRequirementCodeV1> values,
) {
  final input = List<AccessRequirementCodeV1>.from(values);
  if (input.isEmpty) {
    throw const FormatException('requirements must not be empty');
  }
  final unique = input.toSet();
  if (unique.length != input.length) {
    throw const FormatException('requirements must not contain duplicates');
  }
  if (unique.contains(AccessRequirementCodeV1.free) && unique.length != 1) {
    throw const FormatException('FREE must be the only access requirement');
  }
  return List<AccessRequirementCodeV1>.unmodifiable(input);
}

List<String> _uniqueCodes(Iterable<String> values, String field) {
  final normalized = values
      .map((value) => _requiredString(value, field))
      .toList(growable: false);
  if (normalized.toSet().length != normalized.length) {
    throw FormatException('$field must not contain duplicates');
  }
  return List<String>.unmodifiable(normalized);
}

final class CapabilityAccessPolicyV1 {
  CapabilityAccessPolicyV1({
    required this.capabilityCode,
    required Iterable<AccessRequirementCodeV1> requirements,
    String? subscriptionPlanCode,
    Iterable<String> requiredRoleCodes = const [],
    Iterable<String> requiredApprovalCodes = const [],
  }) : requirements = _accessRequirements(requirements),
       subscriptionPlanCode = _optionalString(
         subscriptionPlanCode,
         'subscriptionPlanCode',
       ),
       requiredRoleCodes = _uniqueCodes(requiredRoleCodes, 'requiredRoleCodes'),
       requiredApprovalCodes = _uniqueCodes(
         requiredApprovalCodes,
         'requiredApprovalCodes',
       ) {
    if (this.subscriptionPlanCode != null &&
        !this.requirements.contains(
          AccessRequirementCodeV1.subscriptionRequired,
        )) {
      throw const FormatException(
        'subscriptionPlanCode requires SUBSCRIPTION_REQUIRED',
      );
    }
  }

  final String contractVersion = capabilityAccessPolicyContractVersionV1;
  final RiskCapabilityCodeV1 capabilityCode;
  final List<AccessRequirementCodeV1> requirements;
  final String? subscriptionPlanCode;
  final List<String> requiredRoleCodes;
  final List<String> requiredApprovalCodes;

  bool get isFree =>
      requirements.length == 1 &&
      requirements.single == AccessRequirementCodeV1.free;

  bool get requiresSubscription =>
      requirements.contains(AccessRequirementCodeV1.subscriptionRequired);

  bool get requiresVerifiedBrand =>
      requirements.contains(AccessRequirementCodeV1.verifiedBrandRequired);

  bool get requiresOperationAuthority =>
      requirements.contains(AccessRequirementCodeV1.operationAuthorityRequired);

  factory CapabilityAccessPolicyV1.defaultFor(
    RiskCapabilityCodeV1 capabilityCode,
  ) {
    final requirements = switch (capabilityCode) {
      RiskCapabilityCodeV1.publicRiskVisibility => const [
        AccessRequirementCodeV1.free,
      ],
      RiskCapabilityCodeV1.detailedRiskAnalysis => const [
        AccessRequirementCodeV1.loginRequired,
      ],
      RiskCapabilityCodeV1.evidenceExport => const [
        AccessRequirementCodeV1.verifiedBrandRequired,
      ],
      RiskCapabilityCodeV1.caseCreation => const [
        AccessRequirementCodeV1.verifiedBrandRequired,
      ],
      RiskCapabilityCodeV1.legalAction => const [
        AccessRequirementCodeV1.operationAuthorityRequired,
      ],
      RiskCapabilityCodeV1.customsAction => const [
        AccessRequirementCodeV1.operationAuthorityRequired,
      ],
      RiskCapabilityCodeV1.platformIntervention => const [
        AccessRequirementCodeV1.operationAuthorityRequired,
      ],
    };
    return CapabilityAccessPolicyV1(
      capabilityCode: capabilityCode,
      requirements: requirements,
    );
  }

  factory CapabilityAccessPolicyV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != capabilityAccessPolicyContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    final rawRequirements = json['requirements'];
    if (rawRequirements is! List) {
      throw const FormatException('requirements must be an array');
    }
    return CapabilityAccessPolicyV1(
      capabilityCode: _riskCapabilityFrom(json['capabilityCode']),
      requirements: rawRequirements.map(_accessRequirementFrom),
      subscriptionPlanCode: _optionalString(
        json['subscriptionPlanCode'],
        'subscriptionPlanCode',
      ),
      requiredRoleCodes: _stringList(
        json['requiredRoleCodes'] ?? const <String>[],
        'requiredRoleCodes',
      ),
      requiredApprovalCodes: _stringList(
        json['requiredApprovalCodes'] ?? const <String>[],
        'requiredApprovalCodes',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'contractVersion': contractVersion,
    'capabilityCode': _riskCapabilityValue(capabilityCode),
    'requirements': requirements.map(_accessRequirementValue).toList(),
    if (subscriptionPlanCode != null)
      'subscriptionPlanCode': subscriptionPlanCode,
    'requiredRoleCodes': requiredRoleCodes,
    'requiredApprovalCodes': requiredApprovalCodes,
  };
}

final class CapabilityAccessContextV1 {
  CapabilityAccessContextV1({
    required this.loggedIn,
    required this.verifiedBrand,
    required this.subscriptionActive,
    required this.operationAuthorityGranted,
    Iterable<String> grantedRoleCodes = const [],
    Iterable<String> grantedApprovalCodes = const [],
  }) : grantedRoleCodes = _uniqueCodes(grantedRoleCodes, 'grantedRoleCodes'),
       grantedApprovalCodes = _uniqueCodes(
         grantedApprovalCodes,
         'grantedApprovalCodes',
       ) {
    if (!loggedIn &&
        (verifiedBrand ||
            subscriptionActive ||
            operationAuthorityGranted ||
            this.grantedRoleCodes.isNotEmpty ||
            this.grantedApprovalCodes.isNotEmpty)) {
      throw const FormatException('privileged access facts require login');
    }
  }

  final bool loggedIn;
  final bool verifiedBrand;
  final bool subscriptionActive;
  final bool operationAuthorityGranted;
  final List<String> grantedRoleCodes;
  final List<String> grantedApprovalCodes;
}

final class CapabilityAccessDecisionV1 {
  CapabilityAccessDecisionV1({
    required this.granted,
    required Iterable<AccessRequirementCodeV1> missingRequirements,
    required Iterable<String> missingRoleCodes,
    required Iterable<String> missingApprovalCodes,
  }) : missingRequirements = List<AccessRequirementCodeV1>.unmodifiable(
         missingRequirements,
       ),
       missingRoleCodes = List<String>.unmodifiable(missingRoleCodes),
       missingApprovalCodes = List<String>.unmodifiable(missingApprovalCodes);

  final bool granted;
  final List<AccessRequirementCodeV1> missingRequirements;
  final List<String> missingRoleCodes;
  final List<String> missingApprovalCodes;
}

CapabilityAccessDecisionV1 evaluateCapabilityAccessV1({
  required CapabilityAccessPolicyV1 policy,
  required CapabilityAccessContextV1 context,
}) {
  final missingRequirements = <AccessRequirementCodeV1>[];

  for (final requirement in policy.requirements) {
    final satisfied = switch (requirement) {
      AccessRequirementCodeV1.free => true,
      AccessRequirementCodeV1.loginRequired => context.loggedIn,
      AccessRequirementCodeV1.verifiedBrandRequired => context.verifiedBrand,
      AccessRequirementCodeV1.subscriptionRequired =>
        context.subscriptionActive,
      AccessRequirementCodeV1.operationAuthorityRequired =>
        context.operationAuthorityGranted,
    };
    if (!satisfied) {
      missingRequirements.add(requirement);
    }
  }

  final roles = context.grantedRoleCodes.toSet();
  final approvals = context.grantedApprovalCodes.toSet();
  final missingRoleCodes = policy.requiredRoleCodes
      .where((code) => !roles.contains(code))
      .toList(growable: false);
  final missingApprovalCodes = policy.requiredApprovalCodes
      .where((code) => !approvals.contains(code))
      .toList(growable: false);

  return CapabilityAccessDecisionV1(
    granted:
        missingRequirements.isEmpty &&
        missingRoleCodes.isEmpty &&
        missingApprovalCodes.isEmpty,
    missingRequirements: missingRequirements,
    missingRoleCodes: missingRoleCodes,
    missingApprovalCodes: missingApprovalCodes,
  );
}
