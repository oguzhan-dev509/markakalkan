part of 'shared_risk_contracts_v1.dart';

const String evidenceQualityRefContractVersionV1 = 'evidence-quality-ref-v1';

enum EvidenceQualityLevelV1 {
  verifiedPrimary,
  corroborated,
  singleSource,
  insufficient,
  unavailable,
}

String _evidenceQualityLevelValue(EvidenceQualityLevelV1 value) =>
    switch (value) {
      EvidenceQualityLevelV1.verifiedPrimary => 'verified_primary',
      EvidenceQualityLevelV1.corroborated => 'corroborated',
      EvidenceQualityLevelV1.singleSource => 'single_source',
      EvidenceQualityLevelV1.insufficient => 'insufficient',
      EvidenceQualityLevelV1.unavailable => 'unavailable',
    };

EvidenceQualityLevelV1 _evidenceQualityLevelFrom(Object? value) =>
    _enumValue(value, {
      'verified_primary': EvidenceQualityLevelV1.verifiedPrimary,
      'corroborated': EvidenceQualityLevelV1.corroborated,
      'single_source': EvidenceQualityLevelV1.singleSource,
      'insufficient': EvidenceQualityLevelV1.insufficient,
      'unavailable': EvidenceQualityLevelV1.unavailable,
    }, 'level');

final class EvidenceQualityRefV1 {
  EvidenceQualityRefV1({
    required this.level,
    Iterable<String> reasonCodes = const [],
    Map<String, Object?> evaluatedFrom = const {},
    String? evaluatorVersion,
  }) : reasonCodes = List<String>.unmodifiable(
         reasonCodes.map((item) => _requiredString(item, 'reasonCodes')),
       ),
       evaluatedFrom = _metadata(evaluatedFrom, 'evaluatedFrom'),
       evaluatorVersion = _optionalString(evaluatorVersion, 'evaluatorVersion');

  final String contractVersion = evidenceQualityRefContractVersionV1;
  final EvidenceQualityLevelV1 level;
  final List<String> reasonCodes;
  final Map<String, Object?> evaluatedFrom;
  final String? evaluatorVersion;

  factory EvidenceQualityRefV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != evidenceQualityRefContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }

    return EvidenceQualityRefV1(
      level: _evidenceQualityLevelFrom(json['level']),
      reasonCodes: _stringList(json['reasonCodes'], 'reasonCodes'),
      evaluatedFrom: json['evaluatedFrom'] == null
          ? const {}
          : _requiredMap(json['evaluatedFrom'], 'evaluatedFrom'),
      evaluatorVersion: _optionalString(
        json['evaluatorVersion'],
        'evaluatorVersion',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'level': _evidenceQualityLevelValue(level),
    'reasonCodes': reasonCodes,
    if (evaluatedFrom.isNotEmpty) 'evaluatedFrom': evaluatedFrom,
    if (evaluatorVersion != null) 'evaluatorVersion': evaluatorVersion,
  };
}
