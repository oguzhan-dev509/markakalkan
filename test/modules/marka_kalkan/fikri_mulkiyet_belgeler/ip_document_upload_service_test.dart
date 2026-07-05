import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_document_storage_port.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_document_upload_service.dart';

void main() {
  group('IpDocumentUploadService', () {
    test('hazırlanan dosyayı Storage portuna aktarır', () async {
      final storage = _FakeStorage();
      final service = IpDocumentUploadService(storage: storage);

      final result = await service.upload(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        originalFileName: 'Marka Belgesi.pdf',
        mimeType: 'application/pdf',
        tenantId: 'tenant-a',
        documentId: 'document-1',
        uploadedBy: 'user-1',
      );

      expect(storage.uploadCallCount, 1);
      expect(storage.uploadedBy, 'user-1');
      expect(storage.originalFileName, 'Marka Belgesi.pdf');
      expect(result.storagePath, storage.storagePath);
      expect(result.sha256Hash, storage.sha256Hash);
      expect(result.fileSizeBytes, 4);
    });

    test('Storage yolu uyuşmazlığında yüklenen nesneyi temizler', () async {
      final storage = _FakeStorage(
        overrideStoragePath: 'tenants/tenant-a/ip_documents/wrong/file.pdf',
      );

      final service = IpDocumentUploadService(storage: storage);

      await expectLater(
        () => service.upload(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
          uploadedBy: 'user-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, contains(storage.overrideStoragePath));
    });

    test('SHA-256 uyuşmazlığında yüklenen nesneyi temizler', () async {
      final storage = _FakeStorage(overrideSha256Hash: 'a' * 64);

      final service = IpDocumentUploadService(storage: storage);

      await expectLater(
        () => service.upload(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
          uploadedBy: 'user-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, isNotEmpty);
    });

    test('dosya boyutu uyuşmazlığında yüklenen nesneyi temizler', () async {
      final storage = _FakeStorage(overrideFileSizeBytes: 999);

      final service = IpDocumentUploadService(storage: storage);

      await expectLater(
        () => service.upload(
          bytes: Uint8List.fromList(<int>[1, 2]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
          uploadedBy: 'user-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, isNotEmpty);
    });

    test('boş indirme adresini reddeder ve temizlik yapar', () async {
      final storage = _FakeStorage(overrideDownloadUrl: ' ');

      final service = IpDocumentUploadService(storage: storage);

      await expectLater(
        () => service.upload(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
          uploadedBy: 'user-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(storage.deletedPaths, isNotEmpty);
    });

    test(
      'geçersiz yükleyen kimliğini Storage çağrısından önce reddeder',
      () async {
        final storage = _FakeStorage();
        final service = IpDocumentUploadService(storage: storage);

        await expectLater(
          () => service.upload(
            bytes: Uint8List.fromList(<int>[1]),
            originalFileName: 'document.pdf',
            mimeType: 'application/pdf',
            tenantId: 'tenant-a',
            documentId: 'document-1',
            uploadedBy: '../user',
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(storage.uploadCallCount, 0);
      },
    );
  });
}

final class _FakeStorage implements IpDocumentStoragePort {
  _FakeStorage({
    this.overrideStoragePath,
    this.overrideSha256Hash,
    this.overrideFileSizeBytes,
    this.overrideDownloadUrl,
  });

  final String? overrideStoragePath;
  final String? overrideSha256Hash;
  final int? overrideFileSizeBytes;
  final String? overrideDownloadUrl;

  int uploadCallCount = 0;
  String? storagePath;
  String? sha256Hash;
  String? originalFileName;
  String? uploadedBy;

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

    this.storagePath = storagePath;
    this.sha256Hash = sha256Hash;
    this.originalFileName = originalFileName;
    this.uploadedBy = uploadedBy;

    return IpDocumentStorageUploadResult(
      storagePath: overrideStoragePath ?? storagePath,
      downloadUrl:
          overrideDownloadUrl ?? 'https://example.test/document-download',
      mimeType: mimeType,
      fileSizeBytes: overrideFileSizeBytes ?? bytes.lengthInBytes,
      sha256Hash: overrideSha256Hash ?? sha256Hash,
      uploadedAt: DateTime.utc(2026, 7, 5),
    );
  }

  @override
  Future<void> delete({required String storagePath}) async {
    deletedPaths.add(storagePath);
  }

  @override
  Future<IpDocumentStoredObjectMetadata?> readMetadata({
    required String storagePath,
  }) async {
    return null;
  }
}
