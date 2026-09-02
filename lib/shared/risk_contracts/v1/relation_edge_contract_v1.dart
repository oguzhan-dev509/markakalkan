part of 'shared_risk_contracts_v1.dart';

const String relationEdgeContractVersionV1 = 'relation-edge-v1';

enum RelationDirectionalityV1 { directed, undirected }

String _relationDirectionalityValue(RelationDirectionalityV1 value) =>
    switch (value) {
      RelationDirectionalityV1.directed => 'DIRECTED',
      RelationDirectionalityV1.undirected => 'UNDIRECTED',
    };

RelationDirectionalityV1 _relationDirectionalityFrom(Object? value) =>
    _enumValue(value, {
      'DIRECTED': RelationDirectionalityV1.directed,
      'UNDIRECTED': RelationDirectionalityV1.undirected,
    }, 'directionality');

final class RelationEdgeV1 {
  RelationEdgeV1({
    required String edgeId,
    required this.sourceEntityRef,
    required this.targetEntityRef,
    required this.relationType,
    required this.directionality,
    required this.createdAt,
    required this.provenance,
    this.confidence,
    Iterable<EvidenceRef> evidenceRefs = const [],
    this.observedAt,
  }) : edgeId = _requiredString(edgeId, 'edgeId'),
       evidenceRefs = List<EvidenceRef>.unmodifiable(evidenceRefs);

  final String edgeId;
  final String contractVersion = relationEdgeContractVersionV1;
  final CanonicalEntityRef sourceEntityRef;
  final CanonicalEntityRef targetEntityRef;
  final NamespacedValue relationType;
  final RelationDirectionalityV1 directionality;
  final ConfidenceValue? confidence;
  final List<EvidenceRef> evidenceRefs;
  final DateTime? observedAt;
  final DateTime createdAt;
  final ProvenanceEnvelope provenance;

  factory RelationEdgeV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != relationEdgeContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }

    return RelationEdgeV1(
      edgeId: _requiredString(json['edgeId'], 'edgeId'),
      sourceEntityRef: CanonicalEntityRef.fromJson(
        _requiredMap(json['sourceEntityRef'], 'sourceEntityRef'),
      ),
      targetEntityRef: CanonicalEntityRef.fromJson(
        _requiredMap(json['targetEntityRef'], 'targetEntityRef'),
      ),
      relationType: NamespacedValue.fromJson(
        _requiredMap(json['relationType'], 'relationType'),
      ),
      directionality: _relationDirectionalityFrom(json['directionality']),
      confidence: json['confidence'] == null
          ? null
          : ConfidenceValue.fromJson(
              _requiredMap(json['confidence'], 'confidence'),
            ),
      evidenceRefs: _mapList(
        json['evidenceRefs'],
        'evidenceRefs',
      ).map(EvidenceRef.fromJson).toList(growable: false),
      observedAt: _optionalDate(json['observedAt'], 'observedAt'),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      provenance: ProvenanceEnvelope.fromJson(
        _requiredMap(json['provenance'], 'provenance'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'edgeId': edgeId,
    'contractVersion': contractVersion,
    'sourceEntityRef': sourceEntityRef.toJson(),
    'targetEntityRef': targetEntityRef.toJson(),
    'relationType': relationType.toJson(),
    'directionality': _relationDirectionalityValue(directionality),
    if (confidence != null) 'confidence': confidence!.toJson(),
    'evidenceRefs': evidenceRefs.map((item) => item.toJson()).toList(),
    if (observedAt != null) 'observedAt': observedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'provenance': provenance.toJson(),
  };
}
