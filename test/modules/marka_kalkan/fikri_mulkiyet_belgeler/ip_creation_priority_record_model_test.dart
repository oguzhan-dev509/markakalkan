import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_creation_priority_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_creation_priority_record_model.dart';

void main() {
  group('IpCreationPriorityRecordModel', () {
    final createdAt = DateTime.utc(2026, 7, 8, 12);

    IpCreationPriorityRecordModel buildRecord({
      IpCreationType creationType = IpCreationType.invention,
      IpCreationPriorityStatus status = IpCreationPriorityStatus.draft,
      IpCreationConfidentialityLevel confidentialityLevel =
          IpCreationConfidentialityLevel.private,
      IpCreationSealStatus sealStatus = IpCreationSealStatus.unsealed,
      DateTime? sealedAt,
      DateTime? archivedAt,
    }) {
      return IpCreationPriorityRecordModel(
        id: 'record-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        recordCode: ' yop-001 ',
        title: 'Yeni nesil ambalaj buluşu',
        summary: 'Ambalaj güvenliğini artıran yaratım.',
        creatorName: 'Örnek Yaratıcı',
        creationType: creationType,
        status: status,
        confidentialityLevel: confidentialityLevel,
        sealStatus: sealStatus,
        currentVersion: 2,
        activeVersionId: 'version-2',
        coCreatorIds: const <String>[' creator-2 ', 'creator-2', 'creator-3'],
        authorizedUserIds: const <String>[' user-2 ', 'user-2'],
        tags: const <String>[' ambalaj ', 'buluş', 'ambalaj'],
        relatedAssetIds: const <String>['asset-1'],
        evidencePackageIds: const <String>['evidence-1'],
        firstThoughtAt: DateTime.utc(2026, 7, 1),
        sealedAt: sealedAt,
        archivedAt: archivedAt,
        createdAt: createdAt,
        createdBy: 'user-1',
      );
    }

    test('normalizes record code and cleans repeated relation values', () {
      final record = buildRecord();
      final map = record.toMap();

      expect(record.normalizedRecordCode, 'YOP-001');
      expect(map['recordCodeNormalized'], 'YOP-001');
      expect(map['coCreatorIds'], <String>['creator-2', 'creator-3']);
      expect(map['authorizedUserIds'], <String>['user-2']);
      expect(map['tags'], <String>['ambalaj', 'buluş']);
    });

    test('detects sealed lifecycle and new version eligibility', () {
      final sealed = buildRecord(
        status: IpCreationPriorityStatus.sealed,
        sealStatus: IpCreationSealStatus.sealed,
        sealedAt: DateTime.utc(2026, 7, 8, 13),
      );

      expect(sealed.isSealed, isTrue);
      expect(sealed.isArchived, isFalse);
      expect(sealed.canCreateNewVersion, isTrue);

      final archived = buildRecord(
        status: IpCreationPriorityStatus.archived,
        sealStatus: IpCreationSealStatus.timestamped,
        sealedAt: DateTime.utc(2026, 7, 8, 13),
        archivedAt: DateTime.utc(2026, 7, 9),
      );

      expect(archived.isSealed, isTrue);
      expect(archived.isArchived, isTrue);
      expect(archived.canCreateNewVersion, isFalse);
    });

    test(
      'requires patent disclosure warning for public technical creations',
      () {
        final publicInvention = buildRecord(
          creationType: IpCreationType.invention,
          confidentialityLevel: IpCreationConfidentialityLevel.publicStatement,
        );

        final privateInvention = buildRecord(
          creationType: IpCreationType.invention,
        );

        final publicLiteraryWork = buildRecord(
          creationType: IpCreationType.literaryWork,
          confidentialityLevel: IpCreationConfidentialityLevel.publicStatement,
        );

        expect(publicInvention.patentDisclosureWarningRequired, isTrue);
        expect(privateInvention.patentDisclosureWarningRequired, isFalse);
        expect(publicLiteraryWork.patentDisclosureWarningRequired, isFalse);
      },
    );

    test('deserializes enums, timestamps and version identity', () {
      final record = IpCreationPriorityRecordModel.fromMap(
        id: 'record-2',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'recordCode': 'YOP-002',
          'title': 'Görsel eser taslağı',
          'creationType': 'visual_work',
          'status': 'developing',
          'confidentialityLevel': 'selected_people',
          'sealStatus': 'timestamp_pending',
          'currentVersion': 3,
          'activeVersionId': 'version-3',
          'firstThoughtAt': Timestamp.fromDate(DateTime.utc(2026, 7, 2)),
          'sealedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 3)),
          'createdAt': Timestamp.fromDate(createdAt),
          'createdBy': 'user-1',
        },
      );

      expect(record.creationType, IpCreationType.visualWork);
      expect(record.status, IpCreationPriorityStatus.developing);
      expect(
        record.confidentialityLevel,
        IpCreationConfidentialityLevel.selectedPeople,
      );
      expect(record.sealStatus, IpCreationSealStatus.timestampPending);
      expect(record.currentVersion, 3);
      expect(record.firstThoughtAt?.toUtc(), DateTime.utc(2026, 7, 2));
      expect(record.sealedAt?.toUtc(), DateTime.utc(2026, 7, 3));
      expect(record.isSealed, isTrue);
    });

    test('create map uses server timestamps', () {
      final map = buildRecord().toCreateMap();

      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}
