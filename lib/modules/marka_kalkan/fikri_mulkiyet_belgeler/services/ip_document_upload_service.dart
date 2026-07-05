import 'dart:typed_data';

import '../repositories/ip_document_storage_port.dart';
import 'ip_document_file_preparation_service.dart';

/// Dosya hazırlama çekirdeği ile fiziksel Storage katmanını birleştirir.
final class IpDocumentUploadService {
  const IpDocumentUploadService({required IpDocumentStoragePort storage})
    : _storage = storage;

  final IpDocumentStoragePort _storage;

  Future<IpDocumentStorageUploadResult> upload({
    required Uint8List bytes,
    required String originalFileName,
    required String mimeType,
    required String tenantId,
    required String documentId,
    required String uploadedBy,
    int maximumFileSizeBytes =
        IpDocumentFilePreparationService.defaultMaximumFileSizeBytes,
  }) {
    final prepared = IpDocumentFilePreparationService.prepare(
      bytes: bytes,
      originalFileName: originalFileName,
      mimeType: mimeType,
      tenantId: tenantId,
      documentId: documentId,
      maximumFileSizeBytes: maximumFileSizeBytes,
    );

    return uploadPrepared(
      prepared: prepared,
      tenantId: tenantId,
      documentId: documentId,
      uploadedBy: uploadedBy,
    );
  }

  Future<IpDocumentStorageUploadResult> uploadPrepared({
    required IpPreparedDocumentFile prepared,
    required String tenantId,
    required String documentId,
    required String uploadedBy,
  }) async {
    final actorId = _validateIdentifier(uploadedBy, fieldName: 'uploadedBy');

    final normalizedTenantId = _validateIdentifier(
      tenantId,
      fieldName: 'tenantId',
    );

    final normalizedDocumentId = _validateIdentifier(
      documentId,
      fieldName: 'documentId',
    );

    final expectedPrefix =
        'tenants/$normalizedTenantId/ip_documents/$normalizedDocumentId/';

    if (!prepared.storagePath.startsWith(expectedPrefix)) {
      throw StateError(
        'Hazırlanan Storage yolu tenant ve belge kimliğiyle eşleşmiyor.',
      );
    }

    final result = await _storage.upload(
      storagePath: prepared.storagePath,
      bytes: prepared.bytes,
      mimeType: prepared.mimeType,
      originalFileName: prepared.originalFileName,
      sha256Hash: prepared.sha256Hash,
      tenantId: normalizedTenantId,
      documentId: normalizedDocumentId,
      uploadedBy: actorId,
    );

    if (result.storagePath != prepared.storagePath) {
      await _attemptCleanup(result.storagePath);

      throw StateError(
        'Storage adaptörü beklenen belge yolundan farklı bir yol döndürdü.',
      );
    }

    if (result.sha256Hash.toLowerCase() != prepared.sha256Hash) {
      await _attemptCleanup(result.storagePath);

      throw StateError(
        'Storage adaptörü beklenen SHA-256 değerinden farklı bir değer döndürdü.',
      );
    }

    if (result.fileSizeBytes != prepared.fileSizeBytes) {
      await _attemptCleanup(result.storagePath);

      throw StateError(
        'Storage adaptörü beklenen dosya boyutundan farklı bir değer döndürdü.',
      );
    }

    if (result.mimeType.trim().toLowerCase() != prepared.mimeType) {
      await _attemptCleanup(result.storagePath);

      throw StateError(
        'Storage adaptörü beklenen MIME türünden farklı bir değer döndürdü.',
      );
    }

    if (result.downloadUrl.trim().isEmpty) {
      await _attemptCleanup(result.storagePath);

      throw StateError(
        'Storage adaptörü geçerli bir indirme adresi döndürmedi.',
      );
    }

    return result;
  }

  Future<void> delete({required String storagePath}) {
    return _storage.delete(storagePath: storagePath);
  }

  Future<void> _attemptCleanup(String storagePath) async {
    try {
      await _storage.delete(storagePath: storagePath);
    } catch (_) {
      // Ana bütünlük hatasının korunması için temizlik hatası yutulur.
    }
  }

  static String _validateIdentifier(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName geçerli bir kimlik olmalıdır.',
      );
    }

    return normalized;
  }
}
