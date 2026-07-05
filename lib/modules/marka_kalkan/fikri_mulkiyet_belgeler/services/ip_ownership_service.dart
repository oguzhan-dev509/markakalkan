import '../models/ip_asset_model.dart';
import '../models/ip_ownership_record_model.dart';
import '../repositories/ip_ownership_repository_port.dart';
import '../repositories/ip_repository_ports.dart';

class IpOwnershipService {
  IpOwnershipService({
    required String tenantId,
    required IpOwnershipRepositoryPort ownershipRepository,
    required IpAssetRepositoryPort assetRepository,
    DateTime Function()? clock,
  }) : _tenantId = _requiredValue(tenantId, 'tenantId'),
       _ownershipRepository = ownershipRepository,
       _assetRepository = assetRepository,
       _clock = clock ?? DateTime.now;

  static const double _percentageTolerance = 0.000001;

  final String _tenantId;
  final IpOwnershipRepositoryPort _ownershipRepository;
  final IpAssetRepositoryPort _assetRepository;
  final DateTime Function() _clock;

  Future<String> createRecord(IpOwnershipRecordModel record) async {
    final normalized = _normalizeForCreate(record);

    final asset = await _requireAsset(normalized.assetId);

    _ensureSameBrand(ownershipBrandId: normalized.brandId, asset: asset);

    await _ensureRecordCodeAvailable(
      recordCode: normalized.recordCode,
      brandId: normalized.brandId,
    );

    final activeRecords = await _ownershipRepository.listActiveForAsset(
      assetId: normalized.assetId,
      effectiveAt: normalized.effectiveFrom ?? _clock(),
      limit: 500,
    );

    _ensureTenantRecords(activeRecords);
    _validateNoConflictingPrimaryOwner(
      candidate: normalized,
      existingRecords: activeRecords,
    );
    _validateOwnershipPercentageTotal(
      candidate: normalized,
      existingRecords: activeRecords,
    );

    return _ownershipRepository.create(normalized);
  }

  Future<void> updateRecord(
    IpOwnershipRecordModel record, {
    required String actorId,
  }) async {
    final normalizedId = _requiredValue(record.id, 'record.id');
    final normalizedActorId = _requiredValue(actorId, 'actorId');

    final existing = await _requireRecord(normalizedId);

    if (record.tenantId.trim() != _tenantId) {
      throw StateError(
        'Hak sahipliği kaydı farklı tenant adına güncellenemez.',
      );
    }

    final normalized = _normalizeRecord(
      record.copyWith(
        id: normalizedId,
        tenantId: _tenantId,
        createdAt: existing.createdAt,
        createdBy: existing.createdBy,
        updatedAt: _clock(),
        updatedBy: normalizedActorId,
      ),
    );

    final asset = await _requireAsset(normalized.assetId);

    _ensureSameBrand(ownershipBrandId: normalized.brandId, asset: asset);

    final sameCode = await _ownershipRepository.findByRecordCode(
      brandId: normalized.brandId,
      recordCode: normalized.recordCode,
    );

    if (sameCode != null && sameCode.id != normalized.id) {
      _ensureTenantRecord(sameCode);

      throw StateError(
        'Bu hak sahipliği kayıt kodu zaten kullanılıyor: '
        '${normalized.recordCode}',
      );
    }

    final activeRecords = await _ownershipRepository.listActiveForAsset(
      assetId: normalized.assetId,
      effectiveAt: normalized.effectiveFrom ?? _clock(),
      limit: 500,
    );

    _ensureTenantRecords(activeRecords);

    final otherRecords = activeRecords
        .where((item) => item.id != normalized.id)
        .toList(growable: false);

    _validateNoConflictingPrimaryOwner(
      candidate: normalized,
      existingRecords: otherRecords,
    );
    _validateOwnershipPercentageTotal(
      candidate: normalized,
      existingRecords: otherRecords,
    );

    await _ownershipRepository.update(normalized);
  }

  Future<IpOwnershipRecordModel?> getById(String ownershipRecordId) async {
    final normalizedId = _requiredValue(ownershipRecordId, 'ownershipRecordId');

    final record = await _ownershipRepository.getById(normalizedId);

    if (record == null) {
      return null;
    }

    _ensureTenantRecord(record);

    return record;
  }

  Future<List<IpOwnershipRecordModel>> listForAsset({
    required String assetId,
    bool activeOnly = false,
    DateTime? effectiveAt,
    int limit = 200,
  }) async {
    final normalizedAssetId = _requiredValue(assetId, 'assetId');
    final normalizedLimit = limit.clamp(1, 500);

    await _requireAsset(normalizedAssetId);

    final records = activeOnly
        ? await _ownershipRepository.listActiveForAsset(
            assetId: normalizedAssetId,
            effectiveAt: effectiveAt ?? _clock(),
            limit: normalizedLimit,
          )
        : await _ownershipRepository.listAll(
            assetId: normalizedAssetId,
            limit: normalizedLimit,
          );

    _ensureTenantRecords(records);

    return List<IpOwnershipRecordModel>.unmodifiable(records);
  }

  Stream<List<IpOwnershipRecordModel>> watchForAsset({
    required String assetId,
    IpOwnershipStatus? status,
    int limit = 200,
  }) async* {
    final normalizedAssetId = _requiredValue(assetId, 'assetId');
    final normalizedLimit = limit.clamp(1, 500);

    await _requireAsset(normalizedAssetId);

    yield* _ownershipRepository
        .watchAll(
          assetId: normalizedAssetId,
          status: status,
          limit: normalizedLimit,
        )
        .map((records) {
          _ensureTenantRecords(records);

          return List<IpOwnershipRecordModel>.unmodifiable(records);
        });
  }

  Future<List<IpOwnershipRecordModel>> loadOwnershipChain({
    required String assetId,
    int limit = 500,
  }) async {
    final normalizedAssetId = _requiredValue(assetId, 'assetId');
    final normalizedLimit = limit.clamp(1, 1000);

    await _requireAsset(normalizedAssetId);

    final records = await _ownershipRepository.listOwnershipChain(
      assetId: normalizedAssetId,
      limit: normalizedLimit,
    );

    _ensureTenantRecords(records);

    final sorted = List<IpOwnershipRecordModel>.from(records)
      ..sort((left, right) {
        final leftDate = left.effectiveFrom ?? left.createdAt;
        final rightDate = right.effectiveFrom ?? right.createdAt;

        return leftDate.compareTo(rightDate);
      });

    return List<IpOwnershipRecordModel>.unmodifiable(sorted);
  }

  Future<double> calculateActiveOwnershipPercentage({
    required String assetId,
    DateTime? effectiveAt,
  }) async {
    final records = await listForAsset(
      assetId: assetId,
      activeOnly: true,
      effectiveAt: effectiveAt,
      limit: 500,
    );

    return records
        .where((record) => record.isOwnershipRole)
        .fold<double>(0, (total, record) => total + record.ownershipPercentage);
  }

  Future<void> updateStatus({
    required String ownershipRecordId,
    required IpOwnershipStatus status,
    required String actorId,
  }) async {
    final normalizedId = _requiredValue(ownershipRecordId, 'ownershipRecordId');
    final normalizedActorId = _requiredValue(actorId, 'actorId');

    await _requireRecord(normalizedId);

    await _ownershipRepository.updateStatus(
      ownershipRecordId: normalizedId,
      status: status,
      updatedBy: normalizedActorId,
    );
  }

  Future<void> verifyOwnership({
    required String ownershipRecordId,
    required String actorId,
    DateTime? verificationDate,
  }) async {
    final normalizedId = _requiredValue(ownershipRecordId, 'ownershipRecordId');
    final normalizedActorId = _requiredValue(actorId, 'actorId');

    final record = await _requireRecord(normalizedId);

    if (!record.hasSupportingDocuments) {
      throw StateError(
        'Dayanak belgesi olmayan hak sahipliği kaydı '
        'doğrulanamaz.',
      );
    }

    await _ownershipRepository.markVerified(
      ownershipRecordId: normalizedId,
      verificationDate: verificationDate ?? _clock(),
      verifiedBy: normalizedActorId,
    );
  }

  Future<void> deleteRecord(String ownershipRecordId) async {
    final normalizedId = _requiredValue(ownershipRecordId, 'ownershipRecordId');

    final record = await _requireRecord(normalizedId);

    if (record.status != IpOwnershipStatus.draft) {
      throw StateError(
        'Yalnız taslak hak sahipliği kayıtları kalıcı '
        'olarak silinebilir.',
      );
    }

    if (record.documentIds.isNotEmpty ||
        record.relationshipIds.isNotEmpty ||
        record.transferChainRecordIds.isNotEmpty ||
        record.sourceOwnershipRecordId != null ||
        record.previousOwnershipRecordId != null ||
        record.nextOwnershipRecordId != null ||
        record.rightId != null) {
      throw StateError(
        'Bağlantılı hak sahipliği kaydı kalıcı olarak '
        'silinemez. Kayıt arşivlenmelidir.',
      );
    }

    await _ownershipRepository.delete(normalizedId);
  }

  IpOwnershipRecordModel _normalizeForCreate(IpOwnershipRecordModel record) {
    if (record.tenantId.trim() != _tenantId) {
      throw StateError(
        'Hak sahipliği kaydı farklı tenant adına '
        'oluşturulamaz.',
      );
    }

    return _normalizeRecord(
      record.copyWith(tenantId: _tenantId, createdAt: record.createdAt),
    );
  }

  IpOwnershipRecordModel _normalizeRecord(IpOwnershipRecordModel record) {
    final normalized = record.copyWith(
      id: record.id.trim(),
      tenantId: _requiredValue(record.tenantId, 'tenantId'),
      brandId: _requiredValue(record.brandId, 'brandId'),
      assetId: _requiredValue(record.assetId, 'assetId'),
      recordCode: _requiredValue(record.recordCode, 'recordCode'),
      partyName: _requiredValue(record.partyName, 'partyName'),
      partyId: _nullableValue(record.partyId),
      partyExternalId: _nullableValue(record.partyExternalId),
      partyCountryCode: _upperNullableValue(record.partyCountryCode),
      partyRegistrationNumber: _nullableValue(record.partyRegistrationNumber),
      partyTaxNumber: _nullableValue(record.partyTaxNumber),
      partyContactEmail: _lowerNullableValue(record.partyContactEmail),
      countryCodes: _normalizeCountryCodes(record.countryCodes),
      regionCode: _upperNullableValue(record.regionCode),
      rightId: _nullableValue(record.rightId),
      sourceOwnershipRecordId: _nullableValue(record.sourceOwnershipRecordId),
      previousOwnershipRecordId: _nullableValue(
        record.previousOwnershipRecordId,
      ),
      nextOwnershipRecordId: _nullableValue(record.nextOwnershipRecordId),
      agreementNumber: _nullableValue(record.agreementNumber),
      verifiedBy: _nullableValue(record.verifiedBy),
      documentIds: _normalizeIds(record.documentIds),
      relationshipIds: _normalizeIds(record.relationshipIds),
      transferChainRecordIds: _normalizeIds(record.transferChainRecordIds),
      notes: _nullableValue(record.notes),
      createdBy: _requiredValue(record.createdBy, 'createdBy'),
      updatedBy: _nullableValue(record.updatedBy),
    );

    _validateRecord(normalized);

    return normalized;
  }

  void _validateRecord(IpOwnershipRecordModel record) {
    if (record.ownershipPercentage < 0 || record.ownershipPercentage > 100) {
      throw ArgumentError.value(
        record.ownershipPercentage,
        'ownershipPercentage',
        'Sahiplik yüzdesi 0 ile 100 arasında olmalıdır.',
      );
    }

    if (record.isOwnershipRole && record.ownershipPercentage <= 0) {
      throw ArgumentError.value(
        record.ownershipPercentage,
        'ownershipPercentage',
        'Hak sahipliği rolünün yüzdesi sıfırdan büyük '
            'olmalıdır.',
      );
    }

    if (record.effectiveFrom != null &&
        record.effectiveUntil != null &&
        record.effectiveUntil!.isBefore(record.effectiveFrom!)) {
      throw ArgumentError(
        'Hak sahipliği bitiş tarihi başlangıç '
        'tarihinden önce olamaz.',
      );
    }

    if (record.isOwnershipVerified &&
        (record.verificationDate == null || record.verifiedBy == null)) {
      throw ArgumentError(
        'Doğrulanmış hak sahipliği kaydında doğrulama '
        'tarihi ve doğrulayan kişi zorunludur.',
      );
    }

    if (record.isPrimaryOwner && !record.isOwnershipRole) {
      throw ArgumentError(
        'Birincil hak sahibi işareti yalnız sahiplik '
        'rollerinde kullanılabilir.',
      );
    }

    if (record.acquisitionType == IpOwnershipAcquisitionType.assignment &&
        record.documentIds.isEmpty &&
        record.agreementNumber == null) {
      throw ArgumentError(
        'Devir kaydında devir sözleşmesi belgesi veya '
        'sözleşme numarası bulunmalıdır.',
      );
    }

    if (record.acquisitionType == IpOwnershipAcquisitionType.license &&
        record.documentIds.isEmpty &&
        record.agreementNumber == null) {
      throw ArgumentError(
        'Lisans kaydında lisans sözleşmesi belgesi veya '
        'sözleşme numarası bulunmalıdır.',
      );
    }
  }

  void _validateNoConflictingPrimaryOwner({
    required IpOwnershipRecordModel candidate,
    required List<IpOwnershipRecordModel> existingRecords,
  }) {
    if (!candidate.isActive || !candidate.isPrimaryOwner) {
      return;
    }

    for (final existing in existingRecords) {
      if (!existing.isActive ||
          !existing.isPrimaryOwner ||
          !existing.isOwnershipRole) {
        continue;
      }

      if (candidate.overlapsPeriod(existing)) {
        throw StateError(
          'Aynı varlık ve dönem için birden fazla aktif '
          'birincil hak sahibi tanımlanamaz.',
        );
      }
    }
  }

  void _validateOwnershipPercentageTotal({
    required IpOwnershipRecordModel candidate,
    required List<IpOwnershipRecordModel> existingRecords,
  }) {
    if (!candidate.isActive || !candidate.isOwnershipRole) {
      return;
    }

    var total = candidate.ownershipPercentage;

    for (final existing in existingRecords) {
      if (!existing.isActive ||
          !existing.isOwnershipRole ||
          !candidate.overlapsPeriod(existing)) {
        continue;
      }

      total += existing.ownershipPercentage;
    }

    if (total > 100 + _percentageTolerance) {
      throw StateError(
        'Çakışan aktif hak sahipliği kayıtlarının toplam '
        'sahiplik yüzdesi 100 değerini aşamaz. '
        'Hesaplanan toplam: ${total.toStringAsFixed(2)}',
      );
    }
  }

  Future<void> _ensureRecordCodeAvailable({
    required String recordCode,
    required String brandId,
  }) async {
    final existing = await _ownershipRepository.findByRecordCode(
      brandId: brandId,
      recordCode: recordCode,
    );

    if (existing == null) {
      return;
    }

    _ensureTenantRecord(existing);

    throw StateError(
      'Bu hak sahipliği kayıt kodu zaten kullanılıyor: '
      '$recordCode',
    );
  }

  Future<IpAssetModel> _requireAsset(String assetId) async {
    final asset = await _assetRepository.getById(assetId);

    if (asset == null) {
      throw StateError(
        'Hak sahipliği kaydı için fikri varlık '
        'bulunamadı: $assetId',
      );
    }

    if (asset.tenantId.trim() != _tenantId) {
      throw StateError('Fikri varlık farklı tenant kaydına aittir.');
    }

    return asset;
  }

  Future<IpOwnershipRecordModel> _requireRecord(
    String ownershipRecordId,
  ) async {
    final record = await _ownershipRepository.getById(ownershipRecordId);

    if (record == null) {
      throw StateError(
        'Hak sahipliği kaydı bulunamadı: '
        '$ownershipRecordId',
      );
    }

    _ensureTenantRecord(record);

    return record;
  }

  void _ensureTenantRecord(IpOwnershipRecordModel record) {
    if (record.tenantId.trim() != _tenantId) {
      throw StateError('Hak sahipliği kaydı farklı tenant kaydına aittir.');
    }
  }

  void _ensureTenantRecords(Iterable<IpOwnershipRecordModel> records) {
    for (final record in records) {
      _ensureTenantRecord(record);
    }
  }

  void _ensureSameBrand({
    required String ownershipBrandId,
    required IpAssetModel asset,
  }) {
    if (ownershipBrandId != asset.brandId.trim()) {
      throw StateError(
        'Hak sahipliği kaydının marka kimliği, fikri '
        'varlığın marka kimliğiyle eşleşmiyor.',
      );
    }
  }

  static String _requiredValue(String value, String fieldName) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName boş bırakılamaz.',
      );
    }

    return normalized;
  }

  static String? _nullableValue(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  static String? _upperNullableValue(String? value) {
    return _nullableValue(value)?.toUpperCase();
  }

  static String? _lowerNullableValue(String? value) {
    return _nullableValue(value)?.toLowerCase();
  }

  static List<String> _normalizeIds(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<String> _normalizeCountryCodes(Iterable<String> values) {
    return values
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
