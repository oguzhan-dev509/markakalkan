import '../constants/ip_enums.dart';
import '../models/ip_document_model.dart';
import '../repositories/ip_repository_ports.dart';

/// Belge Kasası domain kurallarını Firestore repository katmanından ayırır.
///
/// Bu servis dosya yükleme işlemini gerçekleştirmez. Dosyanın fiziksel olarak
/// Firebase Storage'a yüklenmesi, SHA-256 hesaplanması ve indirme yetkileri
/// ayrı Storage katmanında ele alınır.
class IpDocumentVaultService {
  const IpDocumentVaultService({
    required IpDocumentRepositoryPort repository,
    required String tenantId,
  }) : _repository = repository,
       _tenantId = tenantId;

  final IpDocumentRepositoryPort _repository;
  final String _tenantId;

  /// Yeni belge kaydını temel Belge Kasası kurallarıyla oluşturur.
  Future<String> createDocument(IpDocumentModel document) async {
    _validateTenant(document.tenantId);
    _validateActor(document.createdBy, fieldName: 'createdBy');
    _validateDocumentIdentity(document);
    _validateFileAndIntegrityConsistency(document);
    _validateVersionIdentity(document);

    return _repository.create(document);
  }

  /// Genel belge bilgilerini günceller.
  ///
  /// Legal hold altındaki veya kilitli belgeler genel güncelleme akışından
  /// değiştirilemez. Bu kayıtlar yalnız özel domain işlemleriyle yönetilir.
  Future<void> updateDocument(IpDocumentModel document) async {
    _validateTenant(document.tenantId);
    _validateActor(document.updatedBy ?? '', fieldName: 'updatedBy');
    _validateDocumentIdentity(document);
    _validateFileAndIntegrityConsistency(document);
    _validateVersionIdentity(document);

    final existing = await _requireDocument(document.id);

    if (existing.legalHoldActive) {
      throw StateError(
        'Hukuki muhafaza altındaki belge genel güncelleme akışından '
        'değiştirilemez.',
      );
    }

    if (existing.isLocked) {
      throw StateError(
        'Kilitli belge genel güncelleme akışından değiştirilemez.',
      );
    }

    if (existing.brandId != document.brandId.trim()) {
      throw StateError('Belgenin marka kimliği değiştirilemez.');
    }

    if (existing.documentCode != document.documentCode.trim()) {
      throw StateError('Belge kodu değiştirilemez.');
    }

    await _repository.update(document);
  }

  /// Belgenin iş akışı durumunu kontrollü biçimde günceller.
  Future<void> updateStatus({
    required String documentId,
    required IpDocumentStatus status,
    required String updatedBy,
  }) async {
    final actorId = _validateActor(updatedBy, fieldName: 'updatedBy');
    final document = await _requireDocument(documentId);

    if (document.legalHoldActive &&
        status != IpDocumentStatus.archived &&
        status != IpDocumentStatus.quarantined) {
      throw StateError(
        'Hukuki muhafaza altındaki belgenin durumu yalnız arşiv veya '
        'karantina durumuna geçirilebilir.',
      );
    }

    if (status == IpDocumentStatus.verified && !document.isEvidenceReady) {
      throw StateError(
        'Dosya referansı, SHA-256 parmak izi ve uygun bütünlük durumu '
        'bulunmayan belge doğrulandı durumuna geçirilemez.',
      );
    }

    await _repository.updateStatus(
      documentId: document.id,
      status: status,
      updatedBy: actorId,
    );
  }

  /// Dışarıda hesaplanan SHA-256 değeriyle kasadaki parmak izini karşılaştırır.
  ///
  /// Eşleşme halinde bütünlük durumu verified yapılır.
  /// Eşleşmeme halinde belge compromised ve quarantined durumuna geçirilir.
  Future<bool> verifySha256({
    required String documentId,
    required String calculatedSha256,
    required String verifiedBy,
  }) async {
    final actorId = _validateActor(verifiedBy, fieldName: 'verifiedBy');
    final calculatedHash = _normalizeSha256(calculatedSha256);
    final document = await _requireDocument(documentId);

    final storedHash = document.sha256Hash;

    if (storedHash == null || storedHash.trim().isEmpty) {
      throw StateError(
        'Belgede karşılaştırılabilir SHA-256 parmak izi bulunmuyor.',
      );
    }

    final normalizedStoredHash = _normalizeSha256(storedHash);
    final matches = normalizedStoredHash == calculatedHash;

    if (matches) {
      await _repository.updateIntegrityStatus(
        documentId: document.id,
        integrityStatus: IpEvidenceIntegrityStatus.verified,
        updatedBy: actorId,
      );

      return true;
    }

    await _repository.updateIntegrityStatus(
      documentId: document.id,
      integrityStatus: IpEvidenceIntegrityStatus.compromised,
      updatedBy: actorId,
    );

    await _repository.updateStatus(
      documentId: document.id,
      status: IpDocumentStatus.quarantined,
      updatedBy: actorId,
    );

    return false;
  }

  /// Belgeyi hukuki muhafaza altına alır.
  ///
  /// Repository bu işlem sırasında belgeyi aynı zamanda kilitler.
  Future<void> activateLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    final actorId = _validateActor(updatedBy, fieldName: 'updatedBy');
    final document = await _requireDocument(documentId);

    if (document.legalHoldActive) {
      return;
    }

    await _repository.activateLegalHold(
      documentId: document.id,
      updatedBy: actorId,
    );
  }

  /// Belgenin hukuki muhafaza durumunu kaldırır.
  ///
  /// Legal hold kaldırılması belgenin kilidini otomatik açmaz. Kilit durumu
  /// ayrı ve denetlenebilir bir güvenlik kararı olarak korunur.
  Future<void> releaseLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    final actorId = _validateActor(updatedBy, fieldName: 'updatedBy');
    final document = await _requireDocument(documentId);

    if (!document.legalHoldActive) {
      throw StateError('Belge hukuki muhafaza altında değil.');
    }

    await _repository.releaseLegalHold(
      documentId: document.id,
      updatedBy: actorId,
    );
  }

  /// Silme güvenliğini hem servis hem repository katmanında uygular.
  Future<void> deleteDocument(String documentId) async {
    final document = await _repository.getById(_validateDocumentId(documentId));

    if (document == null) {
      return;
    }

    _validateTenant(document.tenantId);

    if (document.legalHoldActive) {
      throw StateError('Hukuki muhafaza altındaki belge silinemez.');
    }

    if (document.isLocked) {
      throw StateError('Kilitli belge silinemez.');
    }

    if (document.parentDocumentId != null ||
        document.previousVersionId != null ||
        document.supersedingDocumentId != null) {
      throw StateError('Sürüm zincirindeki belge silinemez; arşivlenmelidir.');
    }

    if (document.caseIds.isNotEmpty ||
        document.relatedAssetIds.isNotEmpty ||
        document.relatedRightIds.isNotEmpty ||
        document.relationshipIds.isNotEmpty) {
      throw StateError(
        'Başka kayıtlarla bağlantılı belge silinemez; arşivlenmelidir.',
      );
    }

    await _repository.delete(document.id);
  }

  Future<IpDocumentModel> _requireDocument(String documentId) async {
    final cleanedId = _validateDocumentId(documentId);
    final document = await _repository.getById(cleanedId);

    if (document == null) {
      throw StateError('Belge bulunamadı: $cleanedId');
    }

    _validateTenant(document.tenantId);

    return document;
  }

  void _validateTenant(String tenantId) {
    final cleanedTenantId = tenantId.trim();
    final expectedTenantId = _tenantId.trim();

    if (expectedTenantId.isEmpty) {
      throw StateError('Belge Kasası servis tenantId değeri boş olamaz.');
    }

    if (cleanedTenantId != expectedTenantId) {
      throw StateError(
        'Belge tenantId değeri Belge Kasası tenantId değeriyle eşleşmiyor.',
      );
    }
  }

  static void _validateDocumentIdentity(IpDocumentModel document) {
    if (!document.hasCompleteIdentity) {
      throw ArgumentError(
        'tenantId, brandId, documentCode ve title alanları zorunludur.',
      );
    }

    if (document.documentCode.trim().length > 100) {
      throw ArgumentError.value(
        document.documentCode,
        'documentCode',
        'Belge kodu 100 karakterden uzun olamaz.',
      );
    }

    if (document.title.trim().length > 300) {
      throw ArgumentError.value(
        document.title,
        'title',
        'Belge başlığı 300 karakterden uzun olamaz.',
      );
    }
  }

  static void _validateFileAndIntegrityConsistency(IpDocumentModel document) {
    if (document.fileSizeBytes < 0) {
      throw ArgumentError.value(
        document.fileSizeBytes,
        'fileSizeBytes',
        'Dosya boyutu negatif olamaz.',
      );
    }

    final hash = document.sha256Hash?.trim();

    if (hash != null && hash.isNotEmpty) {
      _normalizeSha256(hash);

      if (!document.hasFileReference) {
        throw StateError(
          'SHA-256 parmak izi bulunan belgede Storage yolu veya indirme '
          'referansı bulunmalıdır.',
        );
      }

      if (document.hashAlgorithm.trim().toUpperCase() != 'SHA-256') {
        throw StateError(
          'Belge Kasası çekirdeğinde yalnız SHA-256 algoritması kabul edilir.',
        );
      }
    }

    if (document.isTimestamped && document.timestampedAt == null) {
      throw StateError('Zaman damgalı belgede timestampedAt zorunludur.');
    }

    if (document.isElectronicallySigned && document.signedAt == null) {
      throw StateError('Elektronik imzalı belgede signedAt zorunludur.');
    }

    if (document.isNotarized && document.notarizedAt == null) {
      throw StateError('Noter onaylı belgede notarizedAt zorunludur.');
    }
  }

  static void _validateVersionIdentity(IpDocumentModel document) {
    if (document.versionNumber < 1) {
      throw ArgumentError.value(
        document.versionNumber,
        'versionNumber',
        'Sürüm numarası en az 1 olmalıdır.',
      );
    }

    if (document.versionNumber == 1 &&
        (document.parentDocumentId != null ||
            document.previousVersionId != null)) {
      throw StateError(
        'İlk sürüm parentDocumentId veya previousVersionId içeremez.',
      );
    }

    if (document.versionNumber > 1 && document.previousVersionId == null) {
      throw StateError(
        'İkinci ve sonraki belge sürümlerinde previousVersionId zorunludur.',
      );
    }

    final id = document.id.trim();

    for (final linkedId in <String?>[
      document.parentDocumentId,
      document.previousVersionId,
      document.supersedingDocumentId,
    ]) {
      if (id.isNotEmpty && linkedId?.trim() == id) {
        throw StateError('Belge kendi sürüm zincirine bağlanamaz.');
      }
    }
  }

  static String _validateActor(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }

  static String _validateDocumentId(String value) {
    return _validateActor(value, fieldName: 'documentId');
  }

  static String _normalizeSha256(String value) {
    final cleaned = value.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(cleaned)) {
      throw ArgumentError.value(
        value,
        'sha256',
        'SHA-256 değeri 64 karakterlik hexadecimal biçimde olmalıdır.',
      );
    }

    return cleaned;
  }
}
