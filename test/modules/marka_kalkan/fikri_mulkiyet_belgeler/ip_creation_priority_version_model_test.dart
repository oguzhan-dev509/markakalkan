import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_creation_priority_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_creation_priority_version_model.dart';

void main() {
  group('IpCreationPriorityVersionModel', () {
    final createdAt = DateTime.utc(2026, 7, 8, 12);

    IpCreationPriorityVersionModel buildVersion({
      int versionNumber = 1,
      IpCreationSealStatus sealStatus = IpCreationSealStatus.unsealed,
      String? previousVersionId,
      String? previousVersionHash,
      String? contentHash,
    }) {
      return IpCreationPriorityVersionModel(
        id: 'version-$versionNumber',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        recordId: 'record-1',
        versionNumber: versionNumber,
        title: 'Yaratım sürümü $versionNumber',
        summary: 'Kısa özet',
        description: 'Ayrıntılı yaratım açıklaması',
        originalElements: 'Özgün teknik ve yaratıcı unsurlar',
        problemStatement: 'Çözülmek istenen problem',
        developmentStage: IpCreationDevelopmentStage.prototype,
        sealStatus: sealStatus,
        previousVersionId: previousVersionId,
        previousVersionHash: previousVersionHash,
        contentHash: contentHash,
        fileManifest: const <Map<String, dynamic>>[
          <String, dynamic>{
            'fileName': 'taslak.pdf',
            'sha256Hash':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'sizeBytes': 1024,
          },
        ],
        createdAt: createdAt,
        createdBy: 'user-1',
      );
    }

    test('first version has valid empty chain link', () {
      final version = buildVersion();

      expect(version.hasCompleteIdentity, isTrue);
      expect(version.hasValidChainLink, isTrue);
      expect(version.isSealed, isFalse);
      expect(version.hasCryptographicFingerprint, isFalse);
    });

    test('later version requires previous version id and hash', () {
      final valid = buildVersion(
        versionNumber: 2,
        previousVersionId: 'version-1',
        previousVersionHash:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );

      final missingHash = buildVersion(
        versionNumber: 2,
        previousVersionId: 'version-1',
      );

      expect(valid.hasValidChainLink, isTrue);
      expect(missingHash.hasValidChainLink, isFalse);
    });

    test('sealed version detects cryptographic fingerprint', () {
      final version = buildVersion(
        sealStatus: IpCreationSealStatus.timestamped,
        contentHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );

      expect(version.isSealed, isTrue);
      expect(version.hasCryptographicFingerprint, isTrue);
    });

    test('preserves file manifest and serializes enum values', () {
      final map = buildVersion().toMap();
      final manifest = map['fileManifest'] as List<dynamic>;

      expect(map['developmentStage'], 'prototype');
      expect(map['sealStatus'], 'unsealed');
      expect(map['hashAlgorithm'], 'SHA-256');
      expect(manifest, hasLength(1));
      expect(
        (manifest.first as Map<String, dynamic>)['fileName'],
        'taslak.pdf',
      );
    });

    test('deserializes chain, timestamps and manifest', () {
      final version = IpCreationPriorityVersionModel.fromMap(
        id: 'version-3',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'recordId': 'record-1',
          'versionNumber': 3,
          'title': 'Üçüncü sürüm',
          'developmentStage': 'testing',
          'sealStatus': 'sealed',
          'previousVersionId': 'version-2',
          'previousVersionHash':
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          'contentHash':
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'fileManifest': <Map<String, dynamic>>[
            <String, dynamic>{'fileName': 'prototip.png'},
          ],
          'sealedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 8, 13)),
          'createdAt': Timestamp.fromDate(createdAt),
          'createdBy': 'user-1',
        },
      );

      expect(version.developmentStage, IpCreationDevelopmentStage.testing);
      expect(version.sealStatus, IpCreationSealStatus.sealed);
      expect(version.hasValidChainLink, isTrue);
      expect(version.hasCryptographicFingerprint, isTrue);
      expect(version.fileManifest.single['fileName'], 'prototip.png');
      expect(version.sealedAt?.toUtc(), DateTime.utc(2026, 7, 8, 13));
    });

    test('create map uses server timestamp', () {
      final map = buildVersion().toCreateMap();

      expect(map['createdAt'], isA<FieldValue>());
    });
  });
}
