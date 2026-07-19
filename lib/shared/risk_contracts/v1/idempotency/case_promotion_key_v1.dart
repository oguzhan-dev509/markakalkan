part of 'idempotency_v1.dart';

enum TargetCaseNamespace {
  traceabilityCase,
  ipEnforcementCase,
  futureUnifiedCase,
}

String _targetNamespaceValue(TargetCaseNamespace value) => switch (value) {
  TargetCaseNamespace.traceabilityCase => 'traceability_case',
  TargetCaseNamespace.ipEnforcementCase => 'ip_enforcement_case',
  TargetCaseNamespace.futureUnifiedCase => 'future_unified_case',
};

final class CasePromotionKeyV1 {
  CasePromotionKeyV1({
    required String caseCandidateId,
    required this.targetCaseNamespace,
  }) : caseCandidateId = _requiredPart(caseCandidateId, 'caseCandidateId') {
    canonicalKey = _canonicalEncoding([
      contractVersion,
      this.caseCandidateId,
      _targetNamespaceValue(targetCaseNamespace),
    ]);
  }

  final String contractVersion = casePromotionKeyContractVersionV1;
  final String caseCandidateId;
  final TargetCaseNamespace targetCaseNamespace;
  late final String canonicalKey;

  factory CasePromotionKeyV1.fromNamespace({
    required String caseCandidateId,
    required String targetCaseNamespace,
  }) {
    final target = switch (_requiredPart(
      targetCaseNamespace,
      'targetCaseNamespace',
    )) {
      'traceability_case' => TargetCaseNamespace.traceabilityCase,
      'ip_enforcement_case' => TargetCaseNamespace.ipEnforcementCase,
      'future_unified_case' => TargetCaseNamespace.futureUnifiedCase,
      final value => throw FormatException(
        'Unsupported targetCaseNamespace: $value',
      ),
    };
    return CasePromotionKeyV1(
      caseCandidateId: caseCandidateId,
      targetCaseNamespace: target,
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'caseCandidateId': caseCandidateId,
    'targetCaseNamespace': _targetNamespaceValue(targetCaseNamespace),
    'canonicalKey': canonicalKey,
  };
}
