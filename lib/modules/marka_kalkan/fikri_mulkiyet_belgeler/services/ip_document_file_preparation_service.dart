import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Belge Kasası'na yüklenmeden önce dosyanın değişmez teknik özelliklerini
/// hazırlar.
///
/// Bu servis Firebase Storage'a doğrudan erişmez. Dosya baytlarından SHA-256
/// üretir, dosya adını ve MIME türünü doğrular ve güvenli Storage yolunu
/// belirler.
abstract final class IpDocumentFilePreparationService {
  static const int defaultMaximumFileSizeBytes = 25 * 1024 * 1024;

  static const Set<String> allowedMimeTypes = <String>{
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/plain',
    'text/csv',
    'application/zip',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/vnd.oasis.opendocument.presentation',
  };

  static const Map<String, String> _mimeTypeExtensions = <String, String>{
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'text/plain': 'txt',
    'text/csv': 'csv',
    'application/zip': 'zip',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'pptx',
    'application/vnd.oasis.opendocument.text': 'odt',
    'application/vnd.oasis.opendocument.spreadsheet': 'ods',
    'application/vnd.oasis.opendocument.presentation': 'odp',
  };

  static IpPreparedDocumentFile prepare({
    required Uint8List bytes,
    required String originalFileName,
    required String mimeType,
    required String tenantId,
    required String documentId,
    int maximumFileSizeBytes = defaultMaximumFileSizeBytes,
  }) {
    final normalizedTenantId = _validatePathSegment(
      tenantId,
      fieldName: 'tenantId',
    );

    final normalizedDocumentId = _validatePathSegment(
      documentId,
      fieldName: 'documentId',
    );

    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'Belge dosyası boş olamaz.',
      );
    }

    if (maximumFileSizeBytes < 1) {
      throw ArgumentError.value(
        maximumFileSizeBytes,
        'maximumFileSizeBytes',
        'Azami dosya boyutu pozitif olmalıdır.',
      );
    }

    if (bytes.lengthInBytes > maximumFileSizeBytes) {
      throw StateError(
        'Belge dosyası izin verilen azami boyutu aşıyor. '
        'Dosya: ${bytes.lengthInBytes} bayt, '
        'sınır: $maximumFileSizeBytes bayt.',
      );
    }

    final normalizedMimeType = mimeType.trim().toLowerCase();

    if (!allowedMimeTypes.contains(normalizedMimeType)) {
      throw StateError(
        'Belge Kasası bu MIME türünü kabul etmiyor: $normalizedMimeType',
      );
    }

    final extension = _mimeTypeExtensions[normalizedMimeType];

    if (extension == null || extension.isEmpty) {
      throw StateError('MIME türü için güvenli dosya uzantısı belirlenemedi.');
    }

    final sanitizedOriginalFileName = _sanitizeOriginalFileName(
      originalFileName,
      fallbackExtension: extension,
    );

    final sha256Hash = sha256.convert(bytes).toString();

    final storedFileName = '$sha256Hash.$extension';

    final storagePath = [
      'tenants',
      normalizedTenantId,
      'ip_documents',
      normalizedDocumentId,
      storedFileName,
    ].join('/');

    return IpPreparedDocumentFile(
      bytes: bytes,
      originalFileName: sanitizedOriginalFileName,
      storedFileName: storedFileName,
      mimeType: normalizedMimeType,
      fileExtension: extension,
      fileSizeBytes: bytes.lengthInBytes,
      sha256Hash: sha256Hash,
      hashAlgorithm: 'SHA-256',
      storagePath: storagePath,
    );
  }

  static String _validatePathSegment(
    String value, {
    required String fieldName,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (normalized.length > 128) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName 128 karakteri aşamaz.',
      );
    }

    final validPattern = RegExp(r'^[A-Za-z0-9_-]+$');

    if (!validPattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName yalnız harf, rakam, alt çizgi ve tire içerebilir.',
      );
    }

    return normalized;
  }

  static String _sanitizeOriginalFileName(
    String value, {
    required String fallbackExtension,
  }) {
    var normalized = value.trim();

    if (normalized.isEmpty) {
      normalized = 'document.$fallbackExtension';
    }

    normalized = normalized
        .replaceAll(RegExp(r'[\\/]+'), '_')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    normalized = normalized.replaceAll(
      RegExp(r'[^A-Za-z0-9ğüşöçıİĞÜŞÖÇ._ ()-]', unicode: true),
      '_',
    );

    normalized = normalized.replaceAll(RegExp(r'^\.+'), '');

    if (normalized.isEmpty) {
      normalized = 'document.$fallbackExtension';
    }

    if (normalized.length > 160) {
      final suffix = '.$fallbackExtension';
      final maximumBaseLength = 160 - suffix.length;

      normalized =
          '${normalized.substring(0, maximumBaseLength).trim()}$suffix';
    }

    return normalized;
  }
}

class IpPreparedDocumentFile {
  const IpPreparedDocumentFile({
    required this.bytes,
    required this.originalFileName,
    required this.storedFileName,
    required this.mimeType,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.sha256Hash,
    required this.hashAlgorithm,
    required this.storagePath,
  });

  final Uint8List bytes;
  final String originalFileName;
  final String storedFileName;
  final String mimeType;
  final String fileExtension;
  final int fileSizeBytes;
  final String sha256Hash;
  final String hashAlgorithm;
  final String storagePath;
}
