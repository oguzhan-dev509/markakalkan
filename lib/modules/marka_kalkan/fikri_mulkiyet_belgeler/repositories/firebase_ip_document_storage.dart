import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'ip_document_storage_port.dart';

/// [IpDocumentStoragePort] sözleşmesinin Firebase Storage uygulaması.
final class FirebaseIpDocumentStorage implements IpDocumentStoragePort {
  FirebaseIpDocumentStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

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
    final normalizedPath = _validateStoragePath(storagePath);
    final normalizedMimeType = _requireValue(
      mimeType,
      fieldName: 'mimeType',
    ).toLowerCase();
    final normalizedOriginalFileName = _requireValue(
      originalFileName,
      fieldName: 'originalFileName',
    );
    final normalizedSha256 = _validateSha256(sha256Hash);
    final normalizedTenantId = _validateIdentifier(
      tenantId,
      fieldName: 'tenantId',
    );
    final normalizedDocumentId = _validateIdentifier(
      documentId,
      fieldName: 'documentId',
    );
    final normalizedUploadedBy = _validateIdentifier(
      uploadedBy,
      fieldName: 'uploadedBy',
    );

    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'Yüklenecek belge dosyası boş olamaz.',
      );
    }

    final expectedPrefix =
        'tenants/$normalizedTenantId/ip_documents/$normalizedDocumentId/';

    if (!normalizedPath.startsWith(expectedPrefix)) {
      throw StateError('Storage yolu tenant ve belge kimliğiyle eşleşmiyor.');
    }

    final reference = _storage.ref(normalizedPath);

    final metadata = SettableMetadata(
      contentType: normalizedMimeType,
      cacheControl: 'private, no-store, max-age=0',
      customMetadata: <String, String>{
        'tenantId': normalizedTenantId,
        'documentId': normalizedDocumentId,
        'uploadedBy': normalizedUploadedBy,
        'originalFileName': normalizedOriginalFileName,
        'sha256': normalizedSha256,
        'hashAlgorithm': 'SHA-256',
      },
    );

    final snapshot = await reference.putData(bytes, metadata);

    if (snapshot.state != TaskState.success) {
      throw StateError(
        'Belge dosyası Firebase Storage yüklemesi tamamlanamadı.',
      );
    }

    final storedMetadata = await snapshot.ref.getMetadata();
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final storedSha256 = storedMetadata.customMetadata?['sha256'];

    if (storedSha256 != normalizedSha256) {
      try {
        await snapshot.ref.delete();
      } catch (_) {
        // Ana hata, metadata bütünlük uyuşmazlığıdır.
      }

      throw StateError(
        'Storage metadata SHA-256 değeri yüklenen dosyayla eşleşmiyor.',
      );
    }

    return IpDocumentStorageUploadResult(
      storagePath: snapshot.ref.fullPath,
      downloadUrl: downloadUrl,
      mimeType: storedMetadata.contentType ?? normalizedMimeType,
      fileSizeBytes: storedMetadata.size ?? bytes.lengthInBytes,
      sha256Hash: normalizedSha256,
      uploadedAt: storedMetadata.timeCreated ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> delete({required String storagePath}) async {
    final normalizedPath = _validateStoragePath(storagePath);

    try {
      await _storage.ref(normalizedPath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }

      rethrow;
    }
  }

  @override
  Future<IpDocumentStoredObjectMetadata?> readMetadata({
    required String storagePath,
  }) async {
    final normalizedPath = _validateStoragePath(storagePath);

    try {
      final metadata = await _storage.ref(normalizedPath).getMetadata();
      final customMetadata = metadata.customMetadata;

      return IpDocumentStoredObjectMetadata(
        storagePath: normalizedPath,
        mimeType: metadata.contentType,
        fileSizeBytes: metadata.size ?? 0,
        sha256Hash: customMetadata?['sha256'],
        tenantId: customMetadata?['tenantId'],
        documentId: customMetadata?['documentId'],
        uploadedBy: customMetadata?['uploadedBy'],
        updatedAt: metadata.updated,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return null;
      }

      rethrow;
    }
  }

  static String _validateStoragePath(String value) {
    final normalized = _requireValue(value, fieldName: 'storagePath');

    if (normalized.startsWith('/') ||
        normalized.endsWith('/') ||
        normalized.contains('//') ||
        normalized.contains(r'\') ||
        normalized.split('/').any((segment) => segment == '..')) {
      throw ArgumentError.value(
        value,
        'storagePath',
        'Storage yolu güvenli ve göreli bir yol olmalıdır.',
      );
    }

    if (!normalized.startsWith('tenants/')) {
      throw ArgumentError.value(
        value,
        'storagePath',
        'Belge Storage yolu tenants/ kökü altında olmalıdır.',
      );
    }

    return normalized;
  }

  static String _validateIdentifier(String value, {required String fieldName}) {
    final normalized = _requireValue(value, fieldName: fieldName);

    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName yalnız harf, rakam, alt çizgi ve tire içerebilir.',
      );
    }

    return normalized;
  }

  static String _validateSha256(String value) {
    final normalized = _requireValue(
      value,
      fieldName: 'sha256Hash',
    ).toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'sha256Hash',
        'SHA-256 değeri 64 karakterlik hexadecimal biçimde olmalıdır.',
      );
    }

    return normalized;
  }

  static String _requireValue(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return normalized;
  }
}
