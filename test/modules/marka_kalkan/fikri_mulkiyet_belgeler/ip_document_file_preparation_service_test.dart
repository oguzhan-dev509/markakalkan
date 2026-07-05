import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_document_file_preparation_service.dart';

void main() {
  group('IpDocumentFilePreparationService', () {
    test('PDF dosyasını SHA-256 ve güvenli Storage yoluyla hazırlar', () {
      final result = IpDocumentFilePreparationService.prepare(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        originalFileName: 'Marka Tescil Belgesi.pdf',
        mimeType: 'application/pdf',
        tenantId: 'tenant-a',
        documentId: 'document-1',
      );

      expect(
        result.sha256Hash,
        '9f64a747e1b97f131fabb6b447296c9b'
        '6f0201e79fb3c5356e6c77e89b6a806a',
      );
      expect(result.hashAlgorithm, 'SHA-256');
      expect(result.mimeType, 'application/pdf');
      expect(result.fileExtension, 'pdf');
      expect(result.fileSizeBytes, 4);
      expect(result.originalFileName, 'Marka Tescil Belgesi.pdf');
      expect(result.storedFileName, '${result.sha256Hash}.pdf');
      expect(
        result.storagePath,
        'tenants/tenant-a/ip_documents/document-1/'
        '${result.sha256Hash}.pdf',
      );
    });

    test('aynı baytlar her zaman aynı SHA-256 değerini üretir', () {
      final bytes = Uint8List.fromList(<int>[10, 20, 30, 40, 50]);

      final first = IpDocumentFilePreparationService.prepare(
        bytes: bytes,
        originalFileName: 'first.pdf',
        mimeType: 'application/pdf',
        tenantId: 'tenant-a',
        documentId: 'document-1',
      );

      final second = IpDocumentFilePreparationService.prepare(
        bytes: bytes,
        originalFileName: 'second.pdf',
        mimeType: 'application/pdf',
        tenantId: 'tenant-a',
        documentId: 'document-2',
      );

      expect(first.sha256Hash, second.sha256Hash);
      expect(first.storedFileName, second.storedFileName);
      expect(first.storagePath, isNot(second.storagePath));
    });

    test('MIME türünü küçük harfe normalize eder', () {
      final result = IpDocumentFilePreparationService.prepare(
        bytes: Uint8List.fromList(<int>[1]),
        originalFileName: 'BELGE.PDF',
        mimeType: ' APPLICATION/PDF ',
        tenantId: 'tenant-a',
        documentId: 'document-1',
      );

      expect(result.mimeType, 'application/pdf');
      expect(result.fileExtension, 'pdf');
    });

    test('dosya adındaki yol ve tehlikeli karakterleri temizler', () {
      final result = IpDocumentFilePreparationService.prepare(
        bytes: Uint8List.fromList(<int>[1]),
        originalFileName: r'..\özel/marka:belgesi?.pdf',
        mimeType: 'application/pdf',
        tenantId: 'tenant-a',
        documentId: 'document-1',
      );

      expect(result.originalFileName, contains('özel_marka_belgesi_.pdf'));
      expect(result.originalFileName, isNot(contains('/')));
      expect(result.originalFileName, isNot(contains(r'\')));
      expect(result.originalFileName, isNot(startsWith('.')));
    });

    test('boş dosyayı reddeder', () {
      expect(
        () => IpDocumentFilePreparationService.prepare(
          bytes: Uint8List(0),
          originalFileName: 'empty.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('izin verilmeyen MIME türünü reddeder', () {
      expect(
        () => IpDocumentFilePreparationService.prepare(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'script.exe',
          mimeType: 'application/x-msdownload',
          tenantId: 'tenant-a',
          documentId: 'document-1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('azami boyutu aşan dosyayı reddeder', () {
      expect(
        () => IpDocumentFilePreparationService.prepare(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          originalFileName: 'large.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document-1',
          maximumFileSizeBytes: 2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('geçersiz tenant veya belge kimliğini reddeder', () {
      expect(
        () => IpDocumentFilePreparationService.prepare(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: '../tenant-a',
          documentId: 'document-1',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => IpDocumentFilePreparationService.prepare(
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'document.pdf',
          mimeType: 'application/pdf',
          tenantId: 'tenant-a',
          documentId: 'document/1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
