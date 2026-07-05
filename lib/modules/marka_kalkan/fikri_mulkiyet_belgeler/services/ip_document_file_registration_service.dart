import 'dart:typed_data';

import '../constants/ip_enums.dart';
import '../models/ip_document_model.dart';
import 'ip_document_file_preparation_service.dart';
import 'ip_document_upload_service.dart';
import 'ip_document_vault_service.dart';

abstract interface class IpDocumentRecordWriter {
  Future<String> create(IpDocumentModel document);
}

final class IpDocumentVaultRecordWriter implements IpDocumentRecordWriter {
  const IpDocumentVaultRecordWriter({
    required IpDocumentVaultService vaultService,
  }) : _vaultService = vaultService;

  final IpDocumentVaultService _vaultService;

  @override
  Future<String> create(IpDocumentModel document) {
    return _vaultService.createDocument(document);
  }
}

/// Dosya hazırlama, Storage yükleme ve belge kaydını tek güvenli akışta
/// birleştirir.
///
/// Belge kaydı başarısız olursa yüklenen Storage nesnesi telafi edici işlemle
/// silinir.
final class IpDocumentFileRegistrationService {
  const IpDocumentFileRegistrationService({
    required IpDocumentUploadService uploadService,
    required IpDocumentRecordWriter recordWriter,
  }) : _uploadService = uploadService,
       _recordWriter = recordWriter;

  final IpDocumentUploadService _uploadService;
  final IpDocumentRecordWriter _recordWriter;

  Future<String> uploadAndCreate({
    required IpDocumentModel draft,
    required Uint8List bytes,
    required String originalFileName,
    required String mimeType,
    required String uploadedBy,
    int maximumFileSizeBytes =
        IpDocumentFilePreparationService.defaultMaximumFileSizeBytes,
  }) async {
    final actorId = _validateIdentifier(uploadedBy, fieldName: 'uploadedBy');

    final documentId = _validateIdentifier(draft.id, fieldName: 'documentId');

    final tenantId = _validateIdentifier(draft.tenantId, fieldName: 'tenantId');

    if (draft.createdBy.trim() != actorId) {
      throw StateError(
        'Belgeyi oluşturan kullanıcı ile dosyayı yükleyen kullanıcı eşleşmiyor.',
      );
    }

    if (_containsFileData(draft)) {
      throw StateError(
        'Yükleme taslağı önceden atanmış dosya veya SHA-256 bilgisi içeremez.',
      );
    }

    final prepared = IpDocumentFilePreparationService.prepare(
      bytes: bytes,
      originalFileName: originalFileName,
      mimeType: mimeType,
      tenantId: tenantId,
      documentId: documentId,
      maximumFileSizeBytes: maximumFileSizeBytes,
    );

    final uploadResult = await _uploadService.uploadPrepared(
      prepared: prepared,
      tenantId: tenantId,
      documentId: documentId,
      uploadedBy: actorId,
    );

    final persistedMap = draft.toMap();

    persistedMap
      ..['fileName'] = prepared.storedFileName
      ..['originalFileName'] = prepared.originalFileName
      ..['storagePath'] = uploadResult.storagePath
      ..['downloadUrl'] = uploadResult.downloadUrl
      ..['mimeType'] = prepared.mimeType
      ..['fileExtension'] = prepared.fileExtension
      ..['fileSizeBytes'] = uploadResult.fileSizeBytes
      ..['sha256Hash'] = uploadResult.sha256Hash
      ..['hashAlgorithm'] = prepared.hashAlgorithm
      ..['integrityStatus'] = IpEvidenceIntegrityStatus.fingerprinted.value
      ..['createdBy'] = actorId
      ..['updatedBy'] = actorId;

    final persistedDocument = IpDocumentModel.fromMap(
      id: documentId,
      data: persistedMap,
    );

    try {
      final createdId = await _recordWriter.create(persistedDocument);

      if (createdId.trim() != documentId) {
        throw StateError(
          'Belge kayıt katmanı beklenen kimlikten farklı bir kimlik döndürdü.',
        );
      }

      return createdId;
    } catch (_) {
      await _attemptStorageCleanup(uploadResult.storagePath);
      rethrow;
    }
  }

  Future<void> _attemptStorageCleanup(String storagePath) async {
    try {
      await _uploadService.delete(storagePath: storagePath);
    } catch (_) {
      // Ana kayıt hatasının korunması için temizlik hatası yutulur.
    }
  }

  static bool _containsFileData(IpDocumentModel document) {
    return document.hasFileReference ||
        document.hasCryptographicFingerprint ||
        document.fileName?.trim().isNotEmpty == true ||
        document.originalFileName?.trim().isNotEmpty == true ||
        document.mimeType?.trim().isNotEmpty == true ||
        document.fileExtension?.trim().isNotEmpty == true ||
        document.fileSizeBytes != 0;
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
