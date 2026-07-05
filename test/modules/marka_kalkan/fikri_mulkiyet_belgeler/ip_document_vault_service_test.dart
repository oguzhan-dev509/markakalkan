import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_document_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_repository_ports.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_document_vault_service.dart';

void main() {
  const tenantId = 'tenant-a';
  const actorId = 'actor-a';

  group('IpDocumentVaultService oluşturma', () {
    test('geçerli belgeyi repository üzerinden oluşturur', () async {
      final repository = _FakeDocumentRepository();
      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final document = _document(id: 'document-1', createdBy: actorId);

      final result = await service.createDocument(document);

      expect(result, 'document-1');
      expect(repository.createdDocument, same(document));
    });

    test('farklı tenant belgesini reddeder', () async {
      final repository = _FakeDocumentRepository();
      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createDocument(
          _document(id: 'document-1', tenantId: 'tenant-b', createdBy: actorId),
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.createdDocument, isNull);
    });

    test(
      'SHA-256 bulunan fakat dosya referansı olmayan belgeyi reddeder',
      () async {
        final repository = _FakeDocumentRepository();
        final service = IpDocumentVaultService(
          repository: repository,
          tenantId: tenantId,
        );

        await expectLater(
          () => service.createDocument(
            _document(id: 'document-1', createdBy: actorId, sha256Hash: _hashA),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('ikinci sürümde previousVersionId yoksa reddeder', () async {
      final repository = _FakeDocumentRepository();
      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createDocument(
          _document(id: 'document-2', createdBy: actorId, versionNumber: 2),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('IpDocumentVaultService güncelleme', () {
    test('geçerli belge güncellemesini repositoryye aktarır', () async {
      final existing = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{existing.id: existing},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final updated = _document(
        id: 'document-1',
        createdBy: actorId,
        updatedBy: actorId,
        title: 'Güncellenmiş Belge',
      );

      await service.updateDocument(updated);

      expect(repository.updatedDocument, same(updated));
    });

    test('kilitli belgenin genel güncellemesini reddeder', () async {
      final existing = _document(
        id: 'document-1',
        createdBy: actorId,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{existing.id: existing},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.updateDocument(
          _document(id: 'document-1', createdBy: actorId, updatedBy: actorId),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'legal hold altındaki belgenin genel güncellemesini reddeder',
      () async {
        final existing = _document(
          id: 'document-1',
          createdBy: actorId,
          legalHoldActive: true,
          isLocked: true,
        );

        final repository = _FakeDocumentRepository(
          documents: <String, IpDocumentModel>{existing.id: existing},
        );

        final service = IpDocumentVaultService(
          repository: repository,
          tenantId: tenantId,
        );

        await expectLater(
          () => service.updateDocument(
            _document(id: 'document-1', createdBy: actorId, updatedBy: actorId),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('IpDocumentVaultService SHA-256 doğrulama', () {
    test('eşleşen hash bütünlük durumunu verified yapar', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        storagePath: 'tenants/tenant-a/documents/document-1.pdf',
        sha256Hash: _hashA,
        integrityStatus: IpEvidenceIntegrityStatus.fingerprinted,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final result = await service.verifySha256(
        documentId: document.id,
        calculatedSha256: _hashA.toUpperCase(),
        verifiedBy: actorId,
      );

      expect(result, isTrue);
      expect(
        repository.integrityUpdates.single.status,
        IpEvidenceIntegrityStatus.verified,
      );
      expect(repository.statusUpdates, isEmpty);
    });

    test('eşleşmeyen hash belgeyi compromised ve quarantined yapar', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        storagePath: 'tenants/tenant-a/documents/document-1.pdf',
        sha256Hash: _hashA,
        integrityStatus: IpEvidenceIntegrityStatus.fingerprinted,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final result = await service.verifySha256(
        documentId: document.id,
        calculatedSha256: _hashB,
        verifiedBy: actorId,
      );

      expect(result, isFalse);
      expect(
        repository.integrityUpdates.single.status,
        IpEvidenceIntegrityStatus.compromised,
      );
      expect(
        repository.statusUpdates.single.status,
        IpDocumentStatus.quarantined,
      );
    });

    test('hash bulunmayan belge doğrulanamaz', () async {
      final document = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.verifySha256(
          documentId: document.id,
          calculatedSha256: _hashA,
          verifiedBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('IpDocumentVaultService durum yönetimi', () {
    test('kanıt hazır olmayan belge verified durumuna geçirilemez', () async {
      final document = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.updateStatus(
          documentId: document.id,
          status: IpDocumentStatus.verified,
          updatedBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('legal hold altındaki belge karantinaya alınabilir', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        legalHoldActive: true,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await service.updateStatus(
        documentId: document.id,
        status: IpDocumentStatus.quarantined,
        updatedBy: actorId,
      );

      expect(
        repository.statusUpdates.single.status,
        IpDocumentStatus.quarantined,
      );
    });

    test('legal hold altındaki belge normal duruma geçirilemez', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        legalHoldActive: true,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.updateStatus(
          documentId: document.id,
          status: IpDocumentStatus.approved,
          updatedBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('IpDocumentVaultService legal hold', () {
    test('legal hold repository üzerinden etkinleştirilir', () async {
      final document = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await service.activateLegalHold(
        documentId: document.id,
        updatedBy: actorId,
      );

      expect(repository.activatedLegalHoldIds, <String>['document-1']);
    });

    test('zaten aktif legal hold tekrar repositoryye gönderilmez', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        legalHoldActive: true,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await service.activateLegalHold(
        documentId: document.id,
        updatedBy: actorId,
      );

      expect(repository.activatedLegalHoldIds, isEmpty);
    });

    test('aktif olmayan legal hold kaldırılamaz', () async {
      final document = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.releaseLegalHold(
          documentId: document.id,
          updatedBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('IpDocumentVaultService sürümleme', () {
    test('ilk sürümden ikinci sürümü atomik olarak oluşturur', () async {
      final previous = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final newVersion = _document(
        id: 'document-2',
        createdBy: actorId,
        versionNumber: 2,
        parentDocumentId: 'document-1',
        previousVersionId: 'document-1',
      );

      final result = await service.createNextVersion(
        previousDocumentId: previous.id,
        newVersion: newVersion,
        createdBy: actorId,
      );

      expect(result, 'document-2');
      expect(repository.atomicPreviousDocument, same(previous));
      expect(repository.atomicallyCreatedVersion, same(newVersion));
      expect(repository.atomicUpdatedBy, actorId);
    });

    test('üçüncü sürüm kök belge kimliğini korur', () async {
      final previous = _document(
        id: 'document-2',
        createdBy: actorId,
        versionNumber: 2,
        parentDocumentId: 'document-1',
        previousVersionId: 'document-1',
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      final newVersion = _document(
        id: 'document-3',
        createdBy: actorId,
        versionNumber: 3,
        parentDocumentId: 'document-1',
        previousVersionId: 'document-2',
      );

      final result = await service.createNextVersion(
        previousDocumentId: previous.id,
        newVersion: newVersion,
        createdBy: actorId,
      );

      expect(result, 'document-3');
      expect(
        repository.atomicallyCreatedVersion?.parentDocumentId,
        'document-1',
      );
    });

    test('kilitli belgeden yeni sürüm oluşturulamaz', () async {
      final previous = _document(
        id: 'document-1',
        createdBy: actorId,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createNextVersion(
          previousDocumentId: previous.id,
          newVersion: _document(
            id: 'document-2',
            createdBy: actorId,
            versionNumber: 2,
            parentDocumentId: 'document-1',
            previousVersionId: 'document-1',
          ),
          createdBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.atomicallyCreatedVersion, isNull);
    });

    test('legal hold altındaki belgeden yeni sürüm oluşturulamaz', () async {
      final previous = _document(
        id: 'document-1',
        createdBy: actorId,
        legalHoldActive: true,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createNextVersion(
          previousDocumentId: previous.id,
          newVersion: _document(
            id: 'document-2',
            createdBy: actorId,
            versionNumber: 2,
            parentDocumentId: 'document-1',
            previousVersionId: 'document-1',
          ),
          createdBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.atomicallyCreatedVersion, isNull);
    });

    test('ardıl sürümü bulunan belgeden yeniden sürüm oluşturulamaz', () async {
      final previous = _document(
        id: 'document-1',
        createdBy: actorId,
        supersedingDocumentId: 'document-2',
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createNextVersion(
          previousDocumentId: previous.id,
          newVersion: _document(
            id: 'document-3',
            createdBy: actorId,
            versionNumber: 2,
            parentDocumentId: 'document-1',
            previousVersionId: 'document-1',
          ),
          createdBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.atomicallyCreatedVersion, isNull);
    });

    test('hatalı kök veya previousVersionId zinciri reddedilir', () async {
      final previous = _document(
        id: 'document-2',
        createdBy: actorId,
        versionNumber: 2,
        parentDocumentId: 'document-1',
        previousVersionId: 'document-1',
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{previous.id: previous},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.createNextVersion(
          previousDocumentId: previous.id,
          newVersion: _document(
            id: 'document-3',
            createdBy: actorId,
            versionNumber: 3,
            parentDocumentId: 'wrong-root',
            previousVersionId: 'wrong-previous',
          ),
          createdBy: actorId,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.atomicallyCreatedVersion, isNull);
    });
  });

  group('IpDocumentVaultService güvenli silme', () {
    test('bağlantısız ve kilitsiz belge silinir', () async {
      final document = _document(id: 'document-1', createdBy: actorId);

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await service.deleteDocument(document.id);

      expect(repository.deletedIds, <String>['document-1']);
    });

    test('kilitli belge silinemez', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        isLocked: true,
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.deleteDocument(document.id),
        throwsA(isA<StateError>()),
      );
    });

    test('sürüm zincirindeki belge silinemez', () async {
      final document = _document(
        id: 'document-2',
        createdBy: actorId,
        versionNumber: 2,
        parentDocumentId: 'document-1',
        previousVersionId: 'document-1',
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.deleteDocument(document.id),
        throwsA(isA<StateError>()),
      );
    });

    test('varlık bağlantısı bulunan belge silinemez', () async {
      final document = _document(
        id: 'document-1',
        createdBy: actorId,
        relatedAssetIds: const <String>['asset-1'],
      );

      final repository = _FakeDocumentRepository(
        documents: <String, IpDocumentModel>{document.id: document},
      );

      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await expectLater(
        () => service.deleteDocument(document.id),
        throwsA(isA<StateError>()),
      );
    });

    test('mevcut olmayan belge silme çağrısı sessizce tamamlanır', () async {
      final repository = _FakeDocumentRepository();
      final service = IpDocumentVaultService(
        repository: repository,
        tenantId: tenantId,
      );

      await service.deleteDocument('missing-document');

      expect(repository.deletedIds, isEmpty);
    });
  });
}

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

IpDocumentModel _document({
  required String id,
  String tenantId = 'tenant-a',
  String brandId = 'brand-1',
  String documentCode = 'DOC-001',
  String title = 'Belge',
  required String createdBy,
  String? updatedBy,
  IpDocumentStatus status = IpDocumentStatus.draft,
  IpEvidenceIntegrityStatus integrityStatus =
      IpEvidenceIntegrityStatus.notAssessed,
  String? storagePath,
  String? sha256Hash,
  int versionNumber = 1,
  String? parentDocumentId,
  String? previousVersionId,
  String? supersedingDocumentId,
  bool legalHoldActive = false,
  bool isLocked = false,
  List<String> relatedAssetIds = const <String>[],
}) {
  return IpDocumentModel(
    id: id,
    tenantId: tenantId,
    brandId: brandId,
    documentCode: documentCode,
    title: title,
    documentType: IpDocumentType.registrationCertificate,
    status: status,
    confidentialityLevel: IpConfidentialityLevel.confidential,
    accessLevel: IpAccessLevel.none,
    integrityStatus: integrityStatus,
    riskLevel: IpRiskLevel.medium,
    createdAt: DateTime.utc(2026, 7, 5),
    createdBy: createdBy,
    updatedBy: updatedBy,
    storagePath: storagePath,
    sha256Hash: sha256Hash,
    fileName: storagePath == null ? null : 'document.pdf',
    originalFileName: storagePath == null ? null : 'document.pdf',
    mimeType: storagePath == null ? null : 'application/pdf',
    fileExtension: storagePath == null ? null : 'pdf',
    fileSizeBytes: storagePath == null ? 0 : 2048,
    hashAlgorithm: 'SHA-256',
    versionNumber: versionNumber,
    parentDocumentId: parentDocumentId,
    previousVersionId: previousVersionId,
    supersedingDocumentId: supersedingDocumentId,
    legalHoldActive: legalHoldActive,
    isLocked: isLocked,
    relatedAssetIds: relatedAssetIds,
  );
}

class _FakeDocumentRepository implements IpDocumentRepositoryPort {
  _FakeDocumentRepository({Map<String, IpDocumentModel>? documents})
    : documents = documents ?? <String, IpDocumentModel>{};

  final Map<String, IpDocumentModel> documents;

  IpDocumentModel? createdDocument;
  IpDocumentModel? updatedDocument;
  IpDocumentModel? atomicPreviousDocument;
  IpDocumentModel? atomicallyCreatedVersion;
  String? atomicUpdatedBy;

  final List<_StatusUpdate> statusUpdates = <_StatusUpdate>[];
  final List<_IntegrityUpdate> integrityUpdates = <_IntegrityUpdate>[];
  final List<String> activatedLegalHoldIds = <String>[];
  final List<String> releasedLegalHoldIds = <String>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<String> create(IpDocumentModel documentModel) async {
    createdDocument = documentModel;
    documents[documentModel.id] = documentModel;

    return documentModel.id;
  }

  @override
  Future<void> update(IpDocumentModel documentModel) async {
    updatedDocument = documentModel;
    documents[documentModel.id] = documentModel;
  }

  @override
  Future<IpDocumentModel?> getById(String documentId) async {
    return documents[documentId];
  }

  @override
  Future<IpDocumentModel?> findByDocumentCode({
    required String brandId,
    required String documentCode,
  }) async {
    for (final document in documents.values) {
      if (document.brandId == brandId &&
          document.documentCode == documentCode) {
        return document;
      }
    }

    return null;
  }

  @override
  Future<IpDocumentModel?> findBySha256Hash({
    required String sha256Hash,
  }) async {
    for (final document in documents.values) {
      if (document.sha256Hash == sha256Hash) {
        return document;
      }
    }

    return null;
  }

  @override
  Future<List<IpDocumentModel>> listAll({
    String? brandId,
    String? assetId,
    String? rightId,
    IpDocumentType? documentType,
    IpDocumentStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpEvidenceIntegrityStatus? integrityStatus,
    IpRiskLevel? riskLevel,
    bool? legalHoldActive,
    int limit = 200,
  }) async {
    return documents.values.take(limit).toList(growable: false);
  }

  @override
  Stream<List<IpDocumentModel>> watchAll({
    String? brandId,
    String? assetId,
    String? rightId,
    IpDocumentType? documentType,
    IpDocumentStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpEvidenceIntegrityStatus? integrityStatus,
    IpRiskLevel? riskLevel,
    bool? legalHoldActive,
    int limit = 200,
  }) {
    return Stream<List<IpDocumentModel>>.value(
      documents.values.take(limit).toList(growable: false),
    );
  }

  @override
  Future<List<IpDocumentModel>> listEvidenceReady({
    String? brandId,
    int limit = 200,
  }) async {
    return documents.values
        .where((document) => document.isEvidenceReady)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpDocumentModel>> listIntegrityConcerns({
    String? brandId,
    int limit = 200,
  }) async {
    return documents.values
        .where((document) => document.hasIntegrityConcern)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpDocumentModel>> listExpiring({
    String? brandId,
    int days = 90,
    int limit = 200,
  }) async {
    return <IpDocumentModel>[];
  }

  @override
  Future<void> updateStatus({
    required String documentId,
    required IpDocumentStatus status,
    required String updatedBy,
  }) async {
    statusUpdates.add(
      _StatusUpdate(
        documentId: documentId,
        status: status,
        updatedBy: updatedBy,
      ),
    );
  }

  @override
  Future<void> updateIntegrityStatus({
    required String documentId,
    required IpEvidenceIntegrityStatus integrityStatus,
    required String updatedBy,
  }) async {
    integrityUpdates.add(
      _IntegrityUpdate(
        documentId: documentId,
        status: integrityStatus,
        updatedBy: updatedBy,
      ),
    );
  }

  @override
  Future<void> activateLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    activatedLegalHoldIds.add(documentId);
  }

  @override
  Future<void> releaseLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    releasedLegalHoldIds.add(documentId);
  }

  @override
  Future<String> createVersionAtomically({
    required IpDocumentModel previousDocument,
    required IpDocumentModel newVersion,
    required String updatedBy,
  }) async {
    if (!documents.containsKey(previousDocument.id)) {
      throw StateError(
        'Önceki belge sürümü bulunamadı: ${previousDocument.id}',
      );
    }

    if (documents.containsKey(newVersion.id)) {
      throw StateError(
        'Yeni sürüm kimliği zaten kullanılıyor: ${newVersion.id}',
      );
    }

    atomicPreviousDocument = previousDocument;
    atomicallyCreatedVersion = newVersion;
    atomicUpdatedBy = updatedBy;
    documents[newVersion.id] = newVersion;

    return newVersion.id;
  }

  @override
  Future<void> delete(String documentId) async {
    deletedIds.add(documentId);
    documents.remove(documentId);
  }
}

class _StatusUpdate {
  const _StatusUpdate({
    required this.documentId,
    required this.status,
    required this.updatedBy,
  });

  final String documentId;
  final IpDocumentStatus status;
  final String updatedBy;
}

class _IntegrityUpdate {
  const _IntegrityUpdate({
    required this.documentId,
    required this.status,
    required this.updatedBy,
  });

  final String documentId;
  final IpEvidenceIntegrityStatus status;
  final String updatedBy;
}
