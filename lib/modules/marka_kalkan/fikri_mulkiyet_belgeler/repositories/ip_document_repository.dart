import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../models/ip_document_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_repository_ports.dart';

class IpDocumentRepository implements IpDocumentRepositoryPort {
  const IpDocumentRepository({required IpFirestoreRefs refs}) : _refs = refs;

  factory IpDocumentRepository.instance({required String tenantId}) {
    return IpDocumentRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpFirestoreRefs _refs;

  @override
  Future<String> create(IpDocumentModel documentModel) async {
    _validateTenant(documentModel.tenantId);
    _validateDocument(documentModel);

    final existingCode = await findByDocumentCode(
      brandId: documentModel.brandId,
      documentCode: documentModel.documentCode,
    );

    if (existingCode != null && existingCode.id != documentModel.id.trim()) {
      throw StateError(
        'Bu belge kodu seçilen marka için zaten kullanılıyor: '
        '${documentModel.documentCode}',
      );
    }

    final sha256Hash = documentModel.sha256Hash?.trim();

    if (sha256Hash != null && sha256Hash.isNotEmpty) {
      final existingHash = await findBySha256Hash(sha256Hash: sha256Hash);

      if (existingHash != null && existingHash.id != documentModel.id.trim()) {
        throw StateError(
          'Aynı SHA-256 parmak izine sahip belge zaten kasada kayıtlı: '
          '${existingHash.title}',
        );
      }
    }

    if (documentModel.id.trim().isNotEmpty) {
      final document = _refs.documentDocument(documentModel.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir fikri mülkiyet belgesi zaten mevcut: '
          '${documentModel.id}',
        );
      }

      await document.set(documentModel.toCreateMap());

      return document.id;
    }

    final document = _refs.documents.doc();

    await document.set(documentModel.toCreateMap());

    return document.id;
  }

  @override
  Future<void> update(IpDocumentModel documentModel) async {
    _validateTenant(documentModel.tenantId);
    _validateDocument(documentModel);

    final documentId = _validateRequiredId(
      documentModel.id,
      fieldName: 'documentId',
    );

    final document = _refs.documentDocument(documentId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Güncellenecek fikri mülkiyet belgesi bulunamadı: '
        '$documentId',
      );
    }

    final existingDocument = IpDocumentModel.fromDocument(snapshot);

    _validateTenant(existingDocument.tenantId);

    if (existingDocument.brandId != documentModel.brandId.trim()) {
      throw StateError('Belgenin bağlı olduğu marka değiştirilemez.');
    }

    if (existingDocument.documentCode != documentModel.documentCode.trim()) {
      throw StateError('Belgenin belge kodu değiştirilemez.');
    }

    final sha256Hash = documentModel.sha256Hash?.trim();

    if (sha256Hash != null && sha256Hash.isNotEmpty) {
      final duplicate = await findBySha256Hash(sha256Hash: sha256Hash);

      if (duplicate != null && duplicate.id != documentId) {
        throw StateError('Bu SHA-256 parmak izi başka bir belgeye aittir.');
      }
    }

    final actorId = _validateRequiredId(
      documentModel.updatedBy ?? documentModel.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(documentModel.toUpdateMap(actorId: actorId));
  }

  @override
  Future<IpDocumentModel?> getById(String documentId) async {
    final snapshot = await _refs.documentDocument(documentId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final document = IpDocumentModel.fromDocument(snapshot);

    _validateTenant(document.tenantId);

    return document;
  }

  @override
  Future<IpDocumentModel?> findByDocumentCode({
    required String brandId,
    required String documentCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedDocumentCode = _validateRequiredText(
      documentCode,
      fieldName: 'documentCode',
    );

    final snapshot = await _refs
        .tenantQuery(_refs.documents)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('documentCode', isEqualTo: cleanedDocumentCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpDocumentModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<IpDocumentModel?> findBySha256Hash({
    required String sha256Hash,
  }) async {
    final cleanedHash = _validateSha256Hash(sha256Hash);

    final snapshot = await _refs
        .tenantQuery(_refs.documents)
        .where('sha256Hash', isEqualTo: cleanedHash)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpDocumentModel.fromDocument(snapshot.docs.first);
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
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      rightId: rightId,
      documentType: documentType,
      status: status,
      confidentialityLevel: confidentialityLevel,
      integrityStatus: integrityStatus,
      riskLevel: riskLevel,
      legalHoldActive: legalHoldActive,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(IpDocumentModel.fromDocument)
        .toList(growable: false);
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
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      rightId: rightId,
      documentType: documentType,
      status: status,
      confidentialityLevel: confidentialityLevel,
      integrityStatus: integrityStatus,
      riskLevel: riskLevel,
      legalHoldActive: legalHoldActive,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpDocumentModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<List<IpDocumentModel>> listEvidenceReady({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final documents = await listAll(brandId: brandId, limit: 500);

    final matches =
        documents
            .where((document) => document.isEvidenceReady)
            .toList(growable: false)
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );

    return List<IpDocumentModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpDocumentModel>> listIntegrityConcerns({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final documents = await listAll(brandId: brandId, limit: 500);

    final matches =
        documents
            .where((document) => document.hasIntegrityConcern)
            .toList(growable: false)
          ..sort((first, second) {
            final riskComparison = _riskRank(
              second.riskLevel,
            ).compareTo(_riskRank(first.riskLevel));

            if (riskComparison != 0) {
              return riskComparison;
            }

            return second.createdAt.compareTo(first.createdAt);
          });

    return List<IpDocumentModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpDocumentModel>> listExpiring({
    String? brandId,
    int days = 90,
    int limit = 200,
  }) async {
    final safeDays = _validateDays(days);
    final safeLimit = _validateLimit(limit);

    final documents = await listAll(brandId: brandId, limit: 500);

    final now = DateTime.now();
    final threshold = now.add(Duration(days: safeDays));

    final matches =
        documents
            .where((document) {
              final expiryAt = document.expiryAt;

              return expiryAt != null &&
                  !expiryAt.isBefore(now) &&
                  !expiryAt.isAfter(threshold);
            })
            .toList(growable: false)
          ..sort(
            (first, second) => first.expiryAt!.compareTo(second.expiryAt!),
          );

    return List<IpDocumentModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<void> updateStatus({
    required String documentId,
    required IpDocumentStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.documentDocument(documentId);
    final model = await _requireOwnedDocument(document);

    _validateTenant(model.tenantId);

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> updateIntegrityStatus({
    required String documentId,
    required IpEvidenceIntegrityStatus integrityStatus,
    required String updatedBy,
  }) async {
    final document = _refs.documentDocument(documentId);
    final model = await _requireOwnedDocument(document);

    _validateTenant(model.tenantId);

    await document.update(<String, dynamic>{
      'integrityStatus': integrityStatus.value,
      'verifiedAt': integrityStatus == IpEvidenceIntegrityStatus.verified
          ? FieldValue.serverTimestamp()
          : model.verifiedAt == null
          ? null
          : Timestamp.fromDate(model.verifiedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> activateLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    final document = _refs.documentDocument(documentId);
    final model = await _requireOwnedDocument(document);

    _validateTenant(model.tenantId);

    await document.update(<String, dynamic>{
      'legalHoldActive': true,
      'isLocked': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> releaseLegalHold({
    required String documentId,
    required String updatedBy,
  }) async {
    final document = _refs.documentDocument(documentId);
    final model = await _requireOwnedDocument(document);

    _validateTenant(model.tenantId);

    await document.update(<String, dynamic>{
      'legalHoldActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<String> createVersionAtomically({
    required IpDocumentModel previousDocument,
    required IpDocumentModel newVersion,
    required String updatedBy,
  }) async {
    _validateTenant(previousDocument.tenantId);
    _validateTenant(newVersion.tenantId);
    _validateDocument(previousDocument);
    _validateDocument(newVersion);

    final previousId = _validateRequiredId(
      previousDocument.id,
      fieldName: 'previousDocumentId',
    );

    final newVersionId = _validateRequiredId(
      newVersion.id,
      fieldName: 'newVersionId',
    );

    final actorId = _validateRequiredId(updatedBy, fieldName: 'updatedBy');

    if (previousId == newVersionId) {
      throw StateError(
        'Yeni belge sürümü önceki sürümle aynı kimliği kullanamaz.',
      );
    }

    if (previousDocument.brandId.trim() != newVersion.brandId.trim()) {
      throw StateError('Belge sürümleri aynı marka kimliğine bağlı olmalıdır.');
    }

    if (newVersion.versionNumber != previousDocument.versionNumber + 1) {
      throw StateError(
        'Yeni sürüm numarası önceki sürüm numarasından tam olarak '
        'bir büyük olmalıdır.',
      );
    }

    if (newVersion.previousVersionId?.trim() != previousId) {
      throw StateError(
        'Yeni sürümün previousVersionId değeri önceki belge kimliğiyle '
        'eşleşmelidir.',
      );
    }

    final previousRootId = previousDocument.parentDocumentId?.trim();
    final expectedRootId = previousRootId != null && previousRootId.isNotEmpty
        ? previousRootId
        : previousId;

    if (newVersion.parentDocumentId?.trim() != expectedRootId) {
      throw StateError(
        'Yeni sürümün parentDocumentId değeri sürüm zincirinin kök '
        'belge kimliğiyle eşleşmelidir.',
      );
    }

    if (newVersion.supersedingDocumentId != null) {
      throw StateError(
        'Yeni oluşturulan sürüm supersedingDocumentId içeremez.',
      );
    }

    final newHash = newVersion.sha256Hash?.trim();

    if (newHash != null && newHash.isNotEmpty) {
      final duplicateHash = await findBySha256Hash(sha256Hash: newHash);

      if (duplicateHash != null && duplicateHash.id != newVersionId) {
        throw StateError(
          'Yeni sürümün SHA-256 parmak izi başka bir belge kaydında '
          'kullanılıyor.',
        );
      }
    }

    final previousReference = _refs.documentDocument(previousId);
    final newVersionReference = _refs.documentDocument(newVersionId);

    await _refs.firestore.runTransaction((transaction) async {
      final previousSnapshot = await transaction.get(previousReference);
      final newVersionSnapshot = await transaction.get(newVersionReference);

      if (!previousSnapshot.exists || previousSnapshot.data() == null) {
        throw StateError('Önceki belge sürümü bulunamadı: $previousId');
      }

      if (newVersionSnapshot.exists) {
        throw StateError(
          'Yeni sürüm kimliği zaten kullanılıyor: $newVersionId',
        );
      }

      final storedPrevious = IpDocumentModel.fromDocument(previousSnapshot);

      _validateTenant(storedPrevious.tenantId);

      if (storedPrevious.supersedingDocumentId?.trim().isNotEmpty == true) {
        throw StateError(
          'Önceki belge sürümünün zaten bir ardıl sürümü bulunuyor.',
        );
      }

      if (storedPrevious.legalHoldActive) {
        throw StateError(
          'Hukuki muhafaza altındaki belgeden yeni sürüm oluşturulamaz.',
        );
      }

      if (storedPrevious.isLocked) {
        throw StateError('Kilitli belgeden yeni sürüm oluşturulamaz.');
      }

      if (storedPrevious.versionNumber != previousDocument.versionNumber) {
        throw StateError('Önceki sürüm numarası işlem sırasında değişti.');
      }

      if (storedPrevious.brandId != newVersion.brandId.trim()) {
        throw StateError(
          'Kayıtlı önceki sürüm ile yeni sürümün marka kimliği eşleşmiyor.',
        );
      }

      final createMap = newVersion.toMap();

      createMap['createdAt'] = FieldValue.serverTimestamp();
      createMap['createdBy'] = actorId;
      createMap['updatedAt'] = FieldValue.serverTimestamp();
      createMap['updatedBy'] = actorId;

      transaction.set(newVersionReference, createMap);

      transaction.update(previousReference, <String, dynamic>{
        'supersedingDocumentId': newVersionId,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actorId,
      });
    });

    return newVersionId;
  }

  @override
  Future<void> delete(String documentId) async {
    final document = _refs.documentDocument(documentId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final model = IpDocumentModel.fromDocument(snapshot);

    _validateTenant(model.tenantId);

    if (model.legalHoldActive) {
      throw StateError('Hukuki muhafaza altındaki belge silinemez.');
    }

    if (model.isLocked) {
      throw StateError('Kilitli belge silinemez.');
    }

    if (model.parentDocumentId != null ||
        model.previousVersionId != null ||
        model.supersedingDocumentId != null) {
      throw StateError(
        'Sürüm zincirine bağlı belge silinemez. Kaydı arşivleyin.',
      );
    }

    if (model.caseIds.isNotEmpty ||
        model.relatedAssetIds.isNotEmpty ||
        model.relatedRightIds.isNotEmpty ||
        model.relationshipIds.isNotEmpty) {
      throw StateError(
        'Varlık, hak, ilişki veya vaka bağlantısı bulunan belge '
        'silinemez. Kaydı arşivleyin.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? assetId,
    String? rightId,
    IpDocumentType? documentType,
    IpDocumentStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpEvidenceIntegrityStatus? integrityStatus,
    IpRiskLevel? riskLevel,
    bool? legalHoldActive,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.documents);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedAssetId = _cleanOptionalId(assetId, fieldName: 'assetId');

    final cleanedRightId = _cleanOptionalId(rightId, fieldName: 'rightId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedAssetId != null) {
      query = query.where('primaryAssetId', isEqualTo: cleanedAssetId);
    }

    if (cleanedRightId != null) {
      query = query.where('primaryRightId', isEqualTo: cleanedRightId);
    }

    if (documentType != null) {
      query = query.where('documentType', isEqualTo: documentType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (confidentialityLevel != null) {
      query = query.where(
        'confidentialityLevel',
        isEqualTo: confidentialityLevel.value,
      );
    }

    if (integrityStatus != null) {
      query = query.where('integrityStatus', isEqualTo: integrityStatus.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (legalHoldActive != null) {
      query = query.where('legalHoldActive', isEqualTo: legalHoldActive);
    }

    return query;
  }

  Future<IpDocumentModel> _requireOwnedDocument(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak fikri mülkiyet belgesi bulunamadı: '
        '${document.id}',
      );
    }

    final model = IpDocumentModel.fromDocument(snapshot);

    _validateTenant(model.tenantId);

    return model;
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'IP document tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateDocument(IpDocumentModel document) {
    if (!document.hasCompleteIdentity) {
      throw ArgumentError(
        'Belgenin tenantId, brandId, documentCode ve title '
        'alanları zorunludur.',
      );
    }

    _validateRequiredId(document.tenantId, fieldName: 'tenantId');
    _validateRequiredId(document.brandId, fieldName: 'brandId');
    _validateRequiredText(document.documentCode, fieldName: 'documentCode');
    _validateRequiredText(document.title, fieldName: 'title');

    if (document.documentCode.trim().length > 100) {
      throw ArgumentError.value(
        document.documentCode,
        'documentCode',
        'documentCode 100 karakterden uzun olamaz.',
      );
    }

    if (document.title.trim().length > 300) {
      throw ArgumentError.value(
        document.title,
        'title',
        'Başlık 300 karakterden uzun olamaz.',
      );
    }

    if (document.description != null &&
        document.description!.trim().length > 5000) {
      throw ArgumentError.value(
        document.description,
        'description',
        'Açıklama 5000 karakterden uzun olamaz.',
      );
    }

    if (document.notes != null && document.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        document.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    if (document.fileSizeBytes < 0) {
      throw ArgumentError.value(
        document.fileSizeBytes,
        'fileSizeBytes',
        'Dosya boyutu negatif olamaz.',
      );
    }

    if (document.versionNumber < 1) {
      throw ArgumentError.value(
        document.versionNumber,
        'versionNumber',
        'Sürüm numarası en az 1 olmalıdır.',
      );
    }

    final hash = document.sha256Hash?.trim();

    if (hash != null && hash.isNotEmpty) {
      _validateSha256Hash(hash);
    }

    if (document.validFromAt != null &&
        document.expiryAt != null &&
        document.validFromAt!.isAfter(document.expiryAt!)) {
      throw ArgumentError('validFromAt, expiryAt tarihinden sonra olamaz.');
    }

    if (document.issueAt != null &&
        document.expiryAt != null &&
        document.issueAt!.isAfter(document.expiryAt!)) {
      throw ArgumentError('issueAt, expiryAt tarihinden sonra olamaz.');
    }

    if (document.isTimestamped && document.timestampedAt == null) {
      throw ArgumentError(
        'Zaman damgalı belgede timestampedAt alanı zorunludur.',
      );
    }

    if (document.isElectronicallySigned && document.signedAt == null) {
      throw ArgumentError(
        'Elektronik imzalı belgede signedAt alanı zorunludur.',
      );
    }

    if (document.isNotarized && document.notarizedAt == null) {
      throw ArgumentError('Noter onaylı belgede notarizedAt alanı zorunludur.');
    }
  }

  static String _validateSha256Hash(String value) {
    final cleaned = value.trim().toLowerCase();
    final pattern = RegExp(r'^[a-f0-9]{64}$');

    if (!pattern.hasMatch(cleaned)) {
      throw ArgumentError.value(
        value,
        'sha256Hash',
        'SHA-256 parmak izi 64 karakterlik hexadecimal değer olmalıdır.',
      );
    }

    return cleaned;
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
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

  static String _validateRequiredText(
    String value, {
    required String fieldName,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return cleaned;
  }

  static String? _cleanOptionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _validateRequiredId(cleaned, fieldName: fieldName);
  }

  static int _validateDays(int value) {
    if (value < 1 || value > 3650) {
      throw ArgumentError.value(
        value,
        'days',
        'days 1 ile 3650 arasında olmalıdır.',
      );
    }

    return value;
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(
        value,
        'limit',
        'limit 1 ile 500 arasında olmalıdır.',
      );
    }

    return value;
  }

  static int _riskRank(IpRiskLevel level) {
    return switch (level) {
      IpRiskLevel.informational => 0,
      IpRiskLevel.low => 1,
      IpRiskLevel.medium => 2,
      IpRiskLevel.high => 3,
      IpRiskLevel.critical => 4,
    };
  }
}
