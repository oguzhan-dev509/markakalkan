import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  CanonicalEntityRef entity(
    String module,
    String entityType,
    String entityId,
  ) => CanonicalEntityRef(
    module: module,
    entityType: entityType,
    entityId: entityId,
  );

  ProvenanceEnvelope provenance() => ProvenanceEnvelope(
    producerModule: 'risk_scan',
    adaptedAt: DateTime.utc(2026, 9, 2, 4, 50),
  );

  RelationEdgeV1 edge({
    RelationDirectionalityV1 directionality = RelationDirectionalityV1.directed,
    ConfidenceValue? confidence,
    List<EvidenceRef> evidenceRefs = const [],
  }) => RelationEdgeV1(
    edgeId: 'rel-001',
    sourceEntityRef: entity('brand_registry', 'brand', 'brand-001'),
    targetEntityRef: entity('digital_market', 'listing', 'listing-009'),
    relationType: NamespacedValue(
      namespace: 'markakalkan.relation',
      value: 'potential_counterfeit_of',
    ),
    directionality: directionality,
    confidence: confidence,
    evidenceRefs: evidenceRefs,
    observedAt: DateTime.utc(2026, 9, 2, 4, 45),
    createdAt: DateTime.utc(2026, 9, 2, 4, 50),
    provenance: provenance(),
  );

  test('stores canonical source and target entity references', () {
    final value = edge();

    expect(value.sourceEntityRef.module, 'brand_registry');
    expect(value.sourceEntityRef.entityType, 'brand');
    expect(value.sourceEntityRef.entityId, 'brand-001');
    expect(value.targetEntityRef.module, 'digital_market');
    expect(value.targetEntityRef.entityType, 'listing');
    expect(value.targetEntityRef.entityId, 'listing-009');
  });

  test('relation type is language-independent namespaced data', () {
    final value = edge();

    expect(value.relationType.namespace, 'markakalkan.relation');
    expect(value.relationType.value, 'potential_counterfeit_of');
  });

  test('directed and undirected values persist with stable codes', () {
    final directed = edge().toJson();
    final undirected = edge(
      directionality: RelationDirectionalityV1.undirected,
    ).toJson();

    expect(directed['directionality'], 'DIRECTED');
    expect(undirected['directionality'], 'UNDIRECTED');
  });

  test('JSON round-trip preserves the canonical relation edge', () {
    final original = edge(
      confidence: ConfidenceValue(normalizedScore: 0.82),
      evidenceRefs: [
        EvidenceRef(
          evidenceType: 'screenshot',
          referenceType: 'storage_object',
          referenceId: 'evidence-001',
          sourceModule: 'digital_market',
        ),
      ],
    );

    final restored = RelationEdgeV1.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
  });

  test('unknown contract version fails closed', () {
    final json = edge().toJson();
    json['contractVersion'] = 'relation-edge-v999';

    expect(
      () => RelationEdgeV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('unknown directionality fails closed', () {
    final json = edge().toJson();
    json['directionality'] = 'SIDEWAYS';

    expect(
      () => RelationEdgeV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('empty edge id fails closed', () {
    expect(
      () => RelationEdgeV1(
        edgeId: '',
        sourceEntityRef: entity('a', 'type', '1'),
        targetEntityRef: entity('b', 'type', '2'),
        relationType: NamespacedValue(namespace: 'x', value: 'y'),
        directionality: RelationDirectionalityV1.directed,
        createdAt: DateTime.utc(2026, 9, 2),
        provenance: provenance(),
      ),
      throwsFormatException,
    );
  });

  test('empty relation namespace fails closed through NamespacedValue', () {
    expect(
      () => RelationEdgeV1(
        edgeId: 'rel-002',
        sourceEntityRef: entity('a', 'type', '1'),
        targetEntityRef: entity('b', 'type', '2'),
        relationType: NamespacedValue(namespace: '', value: 'linked_to'),
        directionality: RelationDirectionalityV1.directed,
        createdAt: DateTime.utc(2026, 9, 2),
        provenance: provenance(),
      ),
      throwsFormatException,
    );
  });

  test('evidence list is an immutable snapshot', () {
    final evidence = <EvidenceRef>[
      EvidenceRef(
        evidenceType: 'url',
        referenceType: 'web',
        referenceId: 'https://example.test/item',
        sourceModule: 'digital_market',
      ),
    ];

    final value = edge(evidenceRefs: evidence);
    evidence.clear();

    expect(value.evidenceRefs, hasLength(1));
    expect(
      () => value.evidenceRefs.add(
        EvidenceRef(
          evidenceType: 'url',
          referenceType: 'web',
          referenceId: 'x',
          sourceModule: 'x',
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('confidence is optional and does not define relation truth', () {
    final withoutConfidence = edge();
    final withConfidence = edge(
      confidence: ConfidenceValue(normalizedScore: 0.55),
    );

    expect(withoutConfidence.confidence, isNull);
    expect(withConfidence.confidence!.normalizedScore, 0.55);
  });

  test('evidence is optional and kept separate from relation identity', () {
    final value = edge();

    expect(value.evidenceRefs, isEmpty);
    expect(value.edgeId, 'rel-001');
    expect(value.relationType.value, 'potential_counterfeit_of');
  });

  test('source and target may come from different modules', () {
    final value = edge();

    expect(value.sourceEntityRef.module, isNot(value.targetEntityRef.module));
  });
}
