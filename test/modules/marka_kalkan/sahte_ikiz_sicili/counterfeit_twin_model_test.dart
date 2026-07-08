import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/constants/counterfeit_twin_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/models/counterfeit_twin_model.dart';

void main() {
  group('CounterfeitTwinModel', () {
    final createdAt = DateTime.utc(2026, 7, 8, 12);

    CounterfeitTwinModel buildModel({
      CounterfeitTwinStatus status = CounterfeitTwinStatus.suspected,
      CounterfeitTwinRiskLevel riskLevel = CounterfeitTwinRiskLevel.high,
      int overallSimilarityScore = 88,
      String? cloneFamilyId = 'family-1',
      String? waveId = 'wave-1',
      int recurrenceCount = 2,
    }) {
      return CounterfeitTwinModel(
        id: 'twin-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        recordCode: ' twin-001 ',
        title: 'Şüpheli ambalaj klonu',
        status: status,
        confidenceLevel: CounterfeitTwinConfidenceLevel.high,
        riskLevel: riskLevel,
        reviewStatus: CounterfeitTwinReviewStatus.inProgress,
        primaryCloneMethod: CounterfeitTwinCloneMethod.packagingImitation,
        cloneMethods: const <CounterfeitTwinCloneMethod>[
          CounterfeitTwinCloneMethod.packagingImitation,
          CounterfeitTwinCloneMethod.logoImitation,
          CounterfeitTwinCloneMethod.packagingImitation,
        ],
        originalProductId: 'product-1',
        originalBrandName: 'Örnek Marka',
        originalProductName: 'Örnek Ürün',
        suspectedBrandName: 'Ornek Marka',
        suspectedProductName: 'Ornek Urun',
        countryCode: ' tr ',
        visualSimilarityScore: 91,
        packagingSimilarityScore: 95,
        logoSimilarityScore: 86,
        nameSimilarityScore: 83,
        textSimilarityScore: 74,
        priceAnomalyScore: 67,
        overallSimilarityScore: overallSimilarityScore,
        listingIds: const <String>[' listing-1 ', 'listing-1', 'listing-2'],
        sellerIds: const <String>['seller-1'],
        monitoredPageIds: const <String>['page-1'],
        evidencePackageIds: const <String>['evidence-1'],
        cloneFamilyId: cloneFamilyId,
        waveId: waveId,
        relatedTwinRecordIds: const <String>['twin-2'],
        recurrenceCount: recurrenceCount,
        firstSeenAt: DateTime.utc(2026, 7, 1),
        lastSeenAt: DateTime.utc(2026, 7, 8),
        createdAt: createdAt,
        createdBy: 'user-1',
      );
    }

    test('normalizes record code and cleans repeated relation ids', () {
      final model = buildModel();
      final map = model.toMap();

      expect(model.normalizedRecordCode, 'TWIN-001');
      expect(map['recordCodeNormalized'], 'TWIN-001');
      expect(map['countryCode'], 'TR');
      expect(map['listingIds'], <String>['listing-1', 'listing-2']);
      expect(map['cloneMethods'], <String>[
        'packaging_imitation',
        'logo_imitation',
      ]);
    });

    test('detects high risk, digital evidence and tsunami wave links', () {
      final model = buildModel();

      expect(model.isHighRisk, isTrue);
      expect(model.hasDigitalEvidence, isTrue);
      expect(model.hasWaveLink, isTrue);
    });

    test('validates all similarity and anomaly scores in 0-100 range', () {
      expect(buildModel().hasValidScores, isTrue);
      expect(buildModel(overallSimilarityScore: 101).hasValidScores, isFalse);
    });

    test('deserializes enums, timestamps and recurrence data', () {
      final model = CounterfeitTwinModel.fromMap(
        id: 'twin-2',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'recordCode': 'TWIN-002',
          'title': 'Teyitli logo ve ambalaj klonu',
          'status': 'confirmed',
          'confidenceLevel': 'verified',
          'riskLevel': 'critical',
          'reviewStatus': 'completed',
          'primaryCloneMethod': 'mixed',
          'cloneMethods': <String>['logo_imitation', 'packaging_imitation'],
          'overallSimilarityScore': 96,
          'recurrenceCount': 4,
          'confirmedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 7)),
          'createdAt': Timestamp.fromDate(createdAt),
          'createdBy': 'user-1',
        },
      );

      expect(model.status, CounterfeitTwinStatus.confirmed);
      expect(model.confidenceLevel, CounterfeitTwinConfidenceLevel.verified);
      expect(model.primaryCloneMethod, CounterfeitTwinCloneMethod.mixed);
      expect(model.recurrenceCount, 4);
      expect(model.confirmedAt?.toUtc(), DateTime.utc(2026, 7, 7));
      expect(model.isConfirmed, isTrue);
    });

    test('update map protects immutable identity fields', () {
      final map = buildModel().toUpdateMap(actorId: 'user-2');

      expect(map.containsKey('tenantId'), isFalse);
      expect(map.containsKey('brandId'), isFalse);
      expect(map.containsKey('recordCode'), isFalse);
      expect(map.containsKey('recordCodeNormalized'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('createdBy'), isFalse);
      expect(map['updatedBy'], 'user-2');
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}
