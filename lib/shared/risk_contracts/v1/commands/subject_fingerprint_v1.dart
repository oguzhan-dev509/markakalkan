part of 'commands_v1.dart';

final class SubjectFingerprintV1 {
  SubjectFingerprintV1({required String algorithm, required String value})
    : algorithm = _required(algorithm, 'algorithm'),
      value = _required(value, 'value');
  final String algorithm;
  final String value;
  Map<String, Object?> toJson() => {'algorithm': algorithm, 'value': value};
}

final class SubjectFingerprintBuilderV1 {
  const SubjectFingerprintBuilderV1();

  SubjectFingerprintV1 riskSignal(RiskSignalContractV1 subject) =>
      _build(subject.toJson());
  SubjectFingerprintV1 riskAssessment(RiskAssessmentContractV1 subject) =>
      _build(subject.toJson());
  SubjectFingerprintV1 caseCandidate(CaseCandidateContractV1 subject) =>
      _build(subject.toJson());
  SubjectFingerprintV1 fromJson(Map<String, Object?> subject) =>
      _build(subject);

  SubjectFingerprintV1 _build(Map<String, Object?> subject) {
    final payload = jsonEncode(_canonical(subject));
    return SubjectFingerprintV1(
      algorithm: subjectFingerprintAlgorithmV1,
      value: sha256.convert(utf8.encode(payload)).toString(),
    );
  }

  Object? _canonical(Object? value, [String? key]) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final item in keys) item: _canonical(value[item], item)};
    }
    if (value is List) {
      final items = value.map((item) => _canonical(item)).toList();
      if (_setLikeKeys.contains(key)) {
        items.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      }
      return items;
    }
    return value;
  }

  static const _setLikeKeys = {
    'evidenceRefs',
    'relatedEntityRefs',
    'sourceSignalRefs',
    'sourceRiskRefs',
    'canonicalAssetRefs',
  };
}
