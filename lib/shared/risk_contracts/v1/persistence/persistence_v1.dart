library;

import '../idempotency/idempotency_v1.dart';
import '../identity/identity_v1.dart';
import '../shared_risk_contracts_v1.dart';

part 'persistence_readiness_contracts_v1.dart';
part 'persistence_readiness_policy_v1.dart';
part 'risk_signal_persistence_readiness_v1.dart';
part 'risk_assessment_persistence_readiness_v1.dart';
part 'case_candidate_persistence_readiness_v1.dart';

const String persistenceReadinessContractVersionV1 =
    'persistence-readiness-decision-v1';
const String riskPersistenceReadinessPolicyVersionV1 =
    'mk-risk-persistence-readiness-v1';

enum PersistenceSubjectTypeV1 { riskSignal, riskAssessment, caseCandidate }

enum PersistenceReadinessIssueSeverityV1 { blocker, warning }

String _subjectTypeValue(PersistenceSubjectTypeV1 value) => switch (value) {
  PersistenceSubjectTypeV1.riskSignal => 'risk_signal',
  PersistenceSubjectTypeV1.riskAssessment => 'risk_assessment',
  PersistenceSubjectTypeV1.caseCandidate => 'case_candidate',
};

String _required(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

Object? _freeze(Object? value, String field) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((item) => _freeze(item, field)),
    );
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw FormatException('$field key is invalid');
      result[entry.key as String] = _freeze(entry.value, field);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw FormatException('$field contains a non-JSON value');
}
