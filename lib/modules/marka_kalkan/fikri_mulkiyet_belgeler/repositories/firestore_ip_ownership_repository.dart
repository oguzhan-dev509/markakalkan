import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ip_ownership_record_model.dart';
import 'ip_ownership_repository_port.dart';

class FirestoreIpOwnershipRepository implements IpOwnershipRepositoryPort {
  FirestoreIpOwnershipRepository({
    required String tenantId,
    FirebaseFirestore? firestore,
    String collectionPath = 'ip_ownership_records',
  }) : _tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId'),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _collectionPath = _validateRequiredId(
         collectionPath,
         fieldName: 'collectionPath',
       );

  final String _tenantId;
  final FirebaseFirestore _firestore;
  final String _collectionPath;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(_collectionPath);
  }

  Query<Map<String, dynamic>> get _tenantQuery {
    return _collection.where('tenantId', isEqualTo: _tenantId);
  }

  DocumentReference<Map<String, dynamic>> _document(String ownershipRecordId) {
    final normalizedId = _validateRequiredId(
      ownershipRecordId,
      fieldName: 'ownershipRecordId',
    );

    return _collection.doc(normalizedId);
  }

  @override
  Future<String> create(IpOwnershipRecordModel record) async {
    _validateTenant(record.tenantId);
    _validateRecord(record);

    final existing = await findByRecordCode(
      brandId: record.brandId,
      recordCode: record.recordCode,
    );

    if (existing != null && existing.id != record.id.trim()) {
      throw StateError(
        'Bu hak sahipliği kayıt kodu seçilen marka '
        'için zaten kullanılıyor: ${record.recordCode}',
      );
    }

    final requestedId = record.id.trim();

    final document = requestedId.isEmpty
        ? _collection.doc()
        : _document(requestedId);

    if (requestedId.isNotEmpty) {
      final snapshot = await document.get();

      if (snapshot.exists) {
        final existingRecord = _fromSnapshot(snapshot);
        _validateTenant(existingRecord.tenantId);

        throw StateError(
          'Aynı kimlikle bir hak sahipliği kaydı '
          'zaten mevcut: $requestedId',
        );
      }
    }

    final data = _createMap(record);

    await document.set(data);

    return document.id;
  }

  @override
  Future<void> update(IpOwnershipRecordModel record) async {
    _validateTenant(record.tenantId);
    _validateRecord(record);

    final recordId = _validateRequiredId(
      record.id,
      fieldName: 'ownershipRecordId',
    );

    final document = _document(recordId);
    final existing = await _requireOwnedRecord(document);

    final duplicate = await findByRecordCode(
      brandId: record.brandId,
      recordCode: record.recordCode,
    );

    if (duplicate != null && duplicate.id != recordId) {
      throw StateError(
        'Bu hak sahipliği kayıt kodu seçilen marka '
        'için zaten kullanılıyor: ${record.recordCode}',
      );
    }

    final updatedBy = _validateRequiredId(
      record.updatedBy ?? '',
      fieldName: 'updatedBy',
    );

    final data = _updateMap(
      record: record,
      existing: existing,
      updatedBy: updatedBy,
    );

    await document.update(data);
  }

  @override
  Future<IpOwnershipRecordModel?> getById(String ownershipRecordId) async {
    final snapshot = await _document(ownershipRecordId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final record = _fromSnapshot(snapshot);

    _validateTenant(record.tenantId);

    return record;
  }

  @override
  Future<IpOwnershipRecordModel?> findByRecordCode({
    required String brandId,
    required String recordCode,
  }) async {
    final normalizedBrandId = _validateRequiredId(
      brandId,
      fieldName: 'brandId',
    );
    final normalizedRecordCode = _validateRequiredId(
      recordCode,
      fieldName: 'recordCode',
    );

    final snapshot = await _tenantQuery
        .where('brandId', isEqualTo: normalizedBrandId)
        .where('recordCode', isEqualTo: normalizedRecordCode)
        .limit(2)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final records = snapshot.docs.map(_fromSnapshot).toList(growable: false);

    _validateTenantRecords(records);

    if (records.length > 1) {
      throw StateError(
        'Aynı tenant, marka ve kayıt kodu için birden '
        'fazla hak sahipliği kaydı bulundu: '
        '$normalizedRecordCode',
      );
    }

    return records.single;
  }

  @override
  Future<List<IpOwnershipRecordModel>> listAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  }) async {
    final normalizedLimit = _validateLimit(limit);

    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      partyId: partyId,
      rightId: rightId,
      ownershipKind: ownershipKind,
      partyType: partyType,
      acquisitionType: acquisitionType,
      status: status,
      isPrimaryOwner: isPrimaryOwner,
      isOwnershipVerified: isOwnershipVerified,
    ).limit(normalizedLimit);

    final snapshot = await query.get();

    final records = snapshot.docs.map(_fromSnapshot).toList(growable: false);

    _validateTenantRecords(records);

    records.sort(_compareNewestFirst);

    return List<IpOwnershipRecordModel>.unmodifiable(records);
  }

  @override
  Stream<List<IpOwnershipRecordModel>> watchAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  }) {
    final normalizedLimit = _validateLimit(limit);

    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      partyId: partyId,
      rightId: rightId,
      ownershipKind: ownershipKind,
      partyType: partyType,
      acquisitionType: acquisitionType,
      status: status,
      isPrimaryOwner: isPrimaryOwner,
      isOwnershipVerified: isOwnershipVerified,
    ).limit(normalizedLimit);

    return query.snapshots().map((snapshot) {
      final records = snapshot.docs.map(_fromSnapshot).toList(growable: false);

      _validateTenantRecords(records);

      records.sort(_compareNewestFirst);

      return List<IpOwnershipRecordModel>.unmodifiable(records);
    });
  }

  @override
  Future<List<IpOwnershipRecordModel>> listActiveForAsset({
    required String assetId,
    DateTime? effectiveAt,
    int limit = 200,
  }) async {
    final normalizedAssetId = _validateRequiredId(
      assetId,
      fieldName: 'assetId',
    );
    final normalizedLimit = _validateLimit(limit);
    final targetDate = effectiveAt ?? DateTime.now();

    final snapshot = await _tenantQuery
        .where('assetId', isEqualTo: normalizedAssetId)
        .where('status', isEqualTo: IpOwnershipStatus.active.value)
        .limit(normalizedLimit)
        .get();

    final records = snapshot.docs
        .map(_fromSnapshot)
        .where((record) => record.isEffectiveAt(targetDate))
        .toList(growable: false);

    _validateTenantRecords(records);

    records.sort(_compareOwnershipPriority);

    return List<IpOwnershipRecordModel>.unmodifiable(records);
  }

  @override
  Future<List<IpOwnershipRecordModel>> listOwnershipChain({
    required String assetId,
    int limit = 500,
  }) async {
    final normalizedAssetId = _validateRequiredId(
      assetId,
      fieldName: 'assetId',
    );
    final normalizedLimit = _validateLimit(limit);

    final snapshot = await _tenantQuery
        .where('assetId', isEqualTo: normalizedAssetId)
        .limit(normalizedLimit)
        .get();

    final records = snapshot.docs.map(_fromSnapshot).toList(growable: false);

    _validateTenantRecords(records);

    records.sort(_compareChainOrder);

    return List<IpOwnershipRecordModel>.unmodifiable(records);
  }

  @override
  Future<List<IpOwnershipRecordModel>> listByParty({
    required String partyId,
    bool activeOnly = false,
    int limit = 200,
  }) async {
    final normalizedPartyId = _validateRequiredId(
      partyId,
      fieldName: 'partyId',
    );
    final normalizedLimit = _validateLimit(limit);

    Query<Map<String, dynamic>> query = _tenantQuery.where(
      'partyId',
      isEqualTo: normalizedPartyId,
    );

    if (activeOnly) {
      query = query.where('status', isEqualTo: IpOwnershipStatus.active.value);
    }

    final snapshot = await query.limit(normalizedLimit).get();

    final records = snapshot.docs.map(_fromSnapshot).toList(growable: false);

    _validateTenantRecords(records);

    records.sort(_compareNewestFirst);

    return List<IpOwnershipRecordModel>.unmodifiable(records);
  }

  @override
  Future<void> updateStatus({
    required String ownershipRecordId,
    required IpOwnershipStatus status,
    required String updatedBy,
  }) async {
    final document = _document(ownershipRecordId);

    await _requireOwnedRecord(document);

    final normalizedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': normalizedUpdatedBy,
    });
  }

  @override
  Future<void> markVerified({
    required String ownershipRecordId,
    required DateTime verificationDate,
    required String verifiedBy,
  }) async {
    final document = _document(ownershipRecordId);

    await _requireOwnedRecord(document);

    final normalizedVerifiedBy = _validateRequiredId(
      verifiedBy,
      fieldName: 'verifiedBy',
    );

    await document.update(<String, dynamic>{
      'isOwnershipVerified': true,
      'verificationDate': Timestamp.fromDate(verificationDate),
      'verifiedBy': normalizedVerifiedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': normalizedVerifiedBy,
    });
  }

  @override
  Future<void> delete(String ownershipRecordId) async {
    final document = _document(ownershipRecordId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final record = _fromSnapshot(snapshot);

    _validateTenant(record.tenantId);

    if (record.status != IpOwnershipStatus.draft) {
      throw StateError(
        'Yalnız taslak hak sahipliği kayıtları '
        'kalıcı olarak silinebilir.',
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
        'silinemez.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
  }) {
    Query<Map<String, dynamic>> query = _tenantQuery;

    final normalizedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');
    final normalizedAssetId = _cleanOptionalId(assetId, fieldName: 'assetId');
    final normalizedPartyId = _cleanOptionalId(partyId, fieldName: 'partyId');
    final normalizedRightId = _cleanOptionalId(rightId, fieldName: 'rightId');

    if (normalizedBrandId != null) {
      query = query.where('brandId', isEqualTo: normalizedBrandId);
    }

    if (normalizedAssetId != null) {
      query = query.where('assetId', isEqualTo: normalizedAssetId);
    }

    if (normalizedPartyId != null) {
      query = query.where('partyId', isEqualTo: normalizedPartyId);
    }

    if (normalizedRightId != null) {
      query = query.where('rightId', isEqualTo: normalizedRightId);
    }

    if (ownershipKind != null) {
      query = query.where('ownershipKind', isEqualTo: ownershipKind.value);
    }

    if (partyType != null) {
      query = query.where('partyType', isEqualTo: partyType.value);
    }

    if (acquisitionType != null) {
      query = query.where('acquisitionType', isEqualTo: acquisitionType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (isPrimaryOwner != null) {
      query = query.where('isPrimaryOwner', isEqualTo: isPrimaryOwner);
    }

    if (isOwnershipVerified != null) {
      query = query.where(
        'isOwnershipVerified',
        isEqualTo: isOwnershipVerified,
      );
    }

    return query;
  }

  Future<IpOwnershipRecordModel> _requireOwnedRecord(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak hak sahipliği kaydı '
        'bulunamadı: ${document.id}',
      );
    }

    final record = _fromSnapshot(snapshot);

    _validateTenant(record.tenantId);

    return record;
  }

  IpOwnershipRecordModel _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Hak sahipliği kaydı verisi okunamadı: '
        '${snapshot.id}',
      );
    }

    return IpOwnershipRecordModel.fromMap(id: snapshot.id, data: data);
  }

  Map<String, dynamic> _createMap(IpOwnershipRecordModel record) {
    final data = Map<String, dynamic>.from(record.toMap());

    data.remove('updatedAt');
    data.remove('updatedBy');

    data['tenantId'] = _tenantId;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = null;
    data['updatedBy'] = null;

    _convertDateFields(data);

    return data;
  }

  Map<String, dynamic> _updateMap({
    required IpOwnershipRecordModel record,
    required IpOwnershipRecordModel existing,
    required String updatedBy,
  }) {
    final data = Map<String, dynamic>.from(record.toMap());

    data.remove('tenantId');
    data.remove('createdAt');
    data.remove('createdBy');

    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = updatedBy;

    _convertDateFields(data);

    if (existing.tenantId != _tenantId) {
      throw StateError(
        'Güncellenen hak sahipliği kaydı farklı '
        'tenant kaydına aittir.',
      );
    }

    return data;
  }

  static void _convertDateFields(Map<String, dynamic> data) {
    const dateFields = <String>[
      'agreementDate',
      'effectiveFrom',
      'effectiveUntil',
      'verificationDate',
    ];

    for (final field in dateFields) {
      final value = data[field];

      if (value is DateTime) {
        data[field] = Timestamp.fromDate(value);
      }
    }
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _tenantId) {
      throw StateError(
        'Hak sahipliği kaydı tenantId ile repository '
        'tenantId eşleşmiyor.',
      );
    }
  }

  void _validateTenantRecords(Iterable<IpOwnershipRecordModel> records) {
    for (final record in records) {
      _validateTenant(record.tenantId);
    }
  }

  static void _validateRecord(IpOwnershipRecordModel record) {
    _validateRequiredId(record.tenantId, fieldName: 'tenantId');
    _validateRequiredId(record.brandId, fieldName: 'brandId');
    _validateRequiredId(record.assetId, fieldName: 'assetId');
    _validateRequiredId(record.recordCode, fieldName: 'recordCode');
    _validateRequiredId(record.partyName, fieldName: 'partyName');
    _validateRequiredId(record.createdBy, fieldName: 'createdBy');

    if (record.ownershipPercentage < 0 || record.ownershipPercentage > 100) {
      throw ArgumentError.value(
        record.ownershipPercentage,
        'ownershipPercentage',
        'Sahiplik yüzdesi 0 ile 100 arasında olmalıdır.',
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
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return normalized;
  }

  static String? _cleanOptionalId(String? value, {required String fieldName}) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return _validateRequiredId(normalized, fieldName: fieldName);
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(
        value,
        'limit',
        'Limit 1 ile 500 arasında olmalıdır.',
      );
    }

    return value;
  }

  static int _compareNewestFirst(
    IpOwnershipRecordModel left,
    IpOwnershipRecordModel right,
  ) {
    final leftDate = left.updatedAt ?? left.createdAt;
    final rightDate = right.updatedAt ?? right.createdAt;

    return rightDate.compareTo(leftDate);
  }

  static int _compareChainOrder(
    IpOwnershipRecordModel left,
    IpOwnershipRecordModel right,
  ) {
    final leftDate = left.effectiveFrom ?? left.createdAt;
    final rightDate = right.effectiveFrom ?? right.createdAt;

    final dateComparison = leftDate.compareTo(rightDate);

    if (dateComparison != 0) {
      return dateComparison;
    }

    return left.recordCode.compareTo(right.recordCode);
  }

  static int _compareOwnershipPriority(
    IpOwnershipRecordModel left,
    IpOwnershipRecordModel right,
  ) {
    if (left.isPrimaryOwner != right.isPrimaryOwner) {
      return left.isPrimaryOwner ? -1 : 1;
    }

    final percentageComparison = right.ownershipPercentage.compareTo(
      left.ownershipPercentage,
    );

    if (percentageComparison != 0) {
      return percentageComparison;
    }

    return left.partyName.compareTo(right.partyName);
  }
}
