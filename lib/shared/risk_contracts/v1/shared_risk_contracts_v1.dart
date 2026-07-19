library;

part 'common_references_v1.dart';
part 'risk_signal_contract_v1.dart';
part 'risk_assessment_contract_v1.dart';
part 'case_candidate_contract_v1.dart';

const String riskSignalContractVersionV1 = 'risk-signal-v1';
const String riskAssessmentContractVersionV1 = 'risk-assessment-v1';
const String caseCandidateContractVersionV1 = 'case-candidate-v1';

enum CanonicalSeverity { info, low, medium, high, critical }

enum IdentityResolutionStatus { resolved, partial, unresolved }

enum RiskSignalReviewStatus {
  newSignal,
  underReview,
  confirmed,
  dismissed,
  escalated,
  resolved,
  archived,
}

enum RiskAssessmentStatus {
  identified,
  underReview,
  accepted,
  mitigating,
  resolved,
  closed,
  archived,
}

enum CaseCandidateStatus {
  proposed,
  underReview,
  accepted,
  dismissed,
  promoted,
}

enum CaseCandidatePriority { low, medium, high, critical }

T _enumValue<T extends Enum>(
  Object? value,
  Map<String, T> values,
  String field,
) {
  final text = _requiredString(value, field);
  final result = values[text];
  if (result == null) throw FormatException('Unknown $field: $text');
  return result;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value.trim();
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _mapList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array');
  return List<Map<String, dynamic>>.unmodifiable(
    value.map((item) => _requiredMap(item, field)),
  );
}

List<String> _stringList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array');
  return List<String>.unmodifiable(
    value.map((item) => _requiredString(item, field)),
  );
}

DateTime _requiredDate(Object? value, String field) {
  final text = _requiredString(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) throw FormatException('$field must be ISO-8601');
  return parsed;
}

DateTime? _optionalDate(Object? value, String field) {
  if (value == null) return null;
  return _requiredDate(value, field);
}

num _requiredNumber(Object? value, String field) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$field must be a finite number');
  }
  return value;
}

Object? _freezeJson(Object? value, String field) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((item) => _freezeJson(item, field)),
    );
  }
  if (value is Map) {
    final output = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$field keys must be strings');
      }
      output[entry.key as String] = _freezeJson(entry.value, field);
    }
    return Map<String, Object?>.unmodifiable(output);
  }
  throw FormatException('$field contains a non-JSON value');
}

Map<String, Object?> _metadata(Object? value, String field) {
  if (value == null) return const <String, Object?>{};
  final frozen = _freezeJson(value, field);
  if (frozen is! Map<String, Object?>) {
    throw FormatException('$field must be an object');
  }
  return frozen;
}

String _severityValue(CanonicalSeverity value) => value.name;

CanonicalSeverity _severityFrom(Object? value) => _enumValue(value, {
  for (final item in CanonicalSeverity.values) item.name: item,
}, 'canonicalSeverity');

String _signalReviewValue(RiskSignalReviewStatus value) => switch (value) {
  RiskSignalReviewStatus.newSignal => 'new',
  RiskSignalReviewStatus.underReview => 'under_review',
  _ => value.name,
};

RiskSignalReviewStatus _signalReviewFrom(Object? value) => _enumValue(value, {
  'new': RiskSignalReviewStatus.newSignal,
  'under_review': RiskSignalReviewStatus.underReview,
  for (final item in RiskSignalReviewStatus.values.skip(2)) item.name: item,
}, 'reviewStatus');

String _riskStatusValue(RiskAssessmentStatus value) => switch (value) {
  RiskAssessmentStatus.underReview => 'under_review',
  _ => value.name,
};

RiskAssessmentStatus _riskStatusFrom(Object? value) => _enumValue(value, {
  'identified': RiskAssessmentStatus.identified,
  'under_review': RiskAssessmentStatus.underReview,
  'accepted': RiskAssessmentStatus.accepted,
  'mitigating': RiskAssessmentStatus.mitigating,
  'resolved': RiskAssessmentStatus.resolved,
  'closed': RiskAssessmentStatus.closed,
  'archived': RiskAssessmentStatus.archived,
}, 'status');

String _caseStatusValue(CaseCandidateStatus value) => switch (value) {
  CaseCandidateStatus.underReview => 'under_review',
  _ => value.name,
};

CaseCandidateStatus _caseStatusFrom(Object? value) => _enumValue(value, {
  'proposed': CaseCandidateStatus.proposed,
  'under_review': CaseCandidateStatus.underReview,
  'accepted': CaseCandidateStatus.accepted,
  'dismissed': CaseCandidateStatus.dismissed,
  'promoted': CaseCandidateStatus.promoted,
}, 'status');
