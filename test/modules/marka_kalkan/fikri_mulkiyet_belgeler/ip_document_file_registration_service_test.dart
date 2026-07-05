import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_document_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_document_storage_port.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_document_file_registration_service.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_document_upload_service.dart';

void main() {
  const expectedHash =
      '9f64a747e1b97f131fabb6b447296c9b'
      '6f0201e79fb3c5356e6c77e89b6a806a';

  group('IpDocumentFileRegistrationService', () {
    test('dosyayı yükler ve fingerprinted belge kaydı oluşturur', () async {
      final storage = _FakeStorage();
      final writer = _FakeRecordWriter();

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      final result = await service.uploadAndCreate(
        draft: _draft(),
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        originalFileName: 'Marka Tescil Belgesi.pdf',
        mimeType: 'application/pdf',
        uploadedBy: 'actor-a',
      );

      expect(result, 'document-1');
      expect(storage.uploadCallCount, 1);
      expect(storage.deletedPaths, isEmpty);

      final document = writer.createdDocument;

      expect(document, isNotNull);
      expect(document!.fileName, '$expectedHash.pdf');
      expect(
        document.storagePath,
        'tenants/tenant-a/ip_documents/document-1/$expectedHash.pdf',
      );
      expect(document.downloadUrl, 'https://example.test/document');
      expect(document.mimeType, 'application/pdf');
      expect(document.fileExtension, 'pdf');
      expect(document.fileSizeBytes, 4);
      expect(document.sha256Hash, expectedHash);
      expect(document.hashAlgorithm, 'SHA-256');
      expect(document.integrityStatus, IpEvidenceIntegrityStatus.fingerprinted);
      expect(document.createdBy, 'actor-a');
      expect(document.updatedBy, 'actor-a');
    });

    test('belge kaydı başarısız olursa Storage nesnesini temizler', () async {
      final storage = _FakeStorage();
      final writer = _FakeRecordWriter(
        createError: StateError('Firestore kayıt hatası'),
      );

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      await expectLater(
        () => service.uploadAndCreate(
          draft: _draft(),
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          uploadedBy: 'actor-a',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, <String>[
        'tenants/tenant-a/ip_documents/document-1/$expectedHash.pdf',
      ]);
    });

    test('temizlik hatası asıl kayıt hatasını değiştirmez', () async {
      final storage = _FakeStorage(
        deleteError: StateError('Storage silme hatası'),
      );

      final writer = _FakeRecordWriter(
        createError: StateError('Asıl kayıt hatası'),
      );

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      await expectLater(
        () => service.uploadAndCreate(
          draft: _draft(),
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          uploadedBy: 'actor-a',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Asıl kayıt hatası',
          ),
        ),
      );

      expect(storage.deleteCallCount, 1);
    });

    test('önceden dosya bilgisi taşıyan taslağı yüklemeden reddeder', () async {
      final storage = _FakeStorage();
      final writer = _FakeRecordWriter();

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      await expectLater(
        () => service.uploadAndCreate(
          draft: _draft(
            storagePath: 'tenants/tenant-a/ip_documents/document-1/old.pdf',
          ),
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          uploadedBy: 'actor-a',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.uploadCallCount, 0);
      expect(writer.createCallCount, 0);
    });

    test('oluşturan ve yükleyen kullanıcı uyuşmazlığını reddeder', () async {
      final storage = _FakeStorage();
      final writer = _FakeRecordWriter();

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      await expectLater(
        () => service.uploadAndCreate(
          draft: _draft(),
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          uploadedBy: 'actor-b',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.uploadCallCount, 0);
      expect(writer.createCallCount, 0);
    });

    test('kayıt katmanı farklı kimlik döndürürse dosyayı temizler', () async {
      final storage = _FakeStorage();
      final writer = _FakeRecordWriter(
        returnedDocumentId: 'unexpected-document',
      );

      final service = IpDocumentFileRegistrationService(
        uploadService: IpDocumentUploadService(storage: storage),
        recordWriter: writer,
      );

      await expectLater(
        () => service.uploadAndCreate(
          draft: _draft(),
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          uploadedBy: 'actor-a',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, isNotEmpty);
    });
  });
}

IpDocumentModel _draft({String? storagePath}) {
  return IpDocumentModel(
    id: 'document-1',
    tenantId: 'tenant-a',
    brandId: 'brand-1',
    documentCode: 'DOC-001',
    title: 'Marka Tescil Belgesi',
    documentType: IpDocumentType.registrationCertificate,
    status: IpDocumentStatus.draft,
    confidentialityLevel: IpConfidentialityLevel.confidential,
    accessLevel: IpAccessLevel.none,
    integrityStatus: IpEvidenceIntegrityStatus.notAssessed,
    riskLevel: IpRiskLevel.medium,
    createdAt: DateTime.utc(2026, 7, 5),
    createdBy: 'actor-a',
    storagePath: storagePath,
  );
}

final class _FakeRecordWriter implements IpDocumentRecordWriter {
  _FakeRecordWriter({this.createError, this.returnedDocumentId});

  final Object? createError;
  final String? returnedDocumentId;

  int createCallCount = 0;
  IpDocumentModel? createdDocument;

  @override
  Future<String> create(IpDocumentModel document) async {
    createCallCount += 1;
    createdDocument = document;

    final error = createError;

    if (error != null) {
      throw error;
    }

    return returnedDocumentId ?? document.id;
  }
}

final class _FakeStorage implements IpDocumentStoragePort {
  _FakeStorage({this.deleteError});

  final Object? deleteError;

  int uploadCallCount = 0;
  int deleteCallCount = 0;

  final List<String> deletedPaths = <String>[];

  @override
  Future<IpDocumentStorageUploadResult> upload({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required String originalFileName,
    required String sha256Hash,
    required String tenantId,
    required String documentId,
    required String uploadedBy,
  }) async {
    uploadCallCount += 1;

    return IpDocumentStorageUploadResult(
      storagePath: storagePath,
      downloadUrl: 'https://example.test/document',
      mimeType: mimeType,
      fileSizeBytes: bytes.lengthInBytes,
      sha256Hash: sha256Hash,
      uploadedAt: DateTime.utc(2026, 7, 5),
    );
  }

  @override
  Future<void> delete({required String storagePath}) async {
    deleteCallCount += 1;
    deletedPaths.add(storagePath);

    final error = deleteError;

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<IpDocumentStoredObjectMetadata?> readMetadata({
    required String storagePath,
  }) async {
    return null;
  }
}
