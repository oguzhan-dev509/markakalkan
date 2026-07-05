import 'dart:typed_data';

/// Belge Kasası dosyalarının fiziksel saklama katmanı sözleşmesi.
///
/// Domain ve uygulama servisleri Firebase Storage sınıflarına doğrudan bağımlı
/// değildir. Gerçek Firebase adaptörü ve test sahteleri bu portu uygular.
abstract interface class IpDocumentStoragePort {
  Future<IpDocumentStorageUploadResult> upload({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required String originalFileName,
    required String sha256Hash,
    required String tenantId,
    required String documentId,
    required String uploadedBy,
  });

  Future<void> delete({required String storagePath});

  Future<IpDocumentStoredObjectMetadata?> readMetadata({
    required String storagePath,
  });
}

class IpDocumentStorageUploadResult {
  const IpDocumentStorageUploadResult({
    required this.storagePath,
    required this.downloadUrl,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.sha256Hash,
    required this.uploadedAt,
  });

  final String storagePath;
  final String downloadUrl;
  final String mimeType;
  final int fileSizeBytes;
  final String sha256Hash;
  final DateTime uploadedAt;
}

class IpDocumentStoredObjectMetadata {
  const IpDocumentStoredObjectMetadata({
    required this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.sha256Hash,
    required this.tenantId,
    required this.documentId,
    required this.uploadedBy,
    required this.updatedAt,
  });

  final String storagePath;
  final String? mimeType;
  final int fileSizeBytes;
  final String? sha256Hash;
  final String? tenantId;
  final String? documentId;
  final String? uploadedBy;
  final DateTime? updatedAt;
}
