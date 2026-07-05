import 'package:cloud_firestore/cloud_firestore.dart';

import 'ip_trade_secret_detail_repository_ports.dart';

typedef IpTradeSecretModelFromDocument<T> =
    T Function(DocumentSnapshot<Map<String, dynamic>> document);
typedef IpTradeSecretModelToCreateMap<T> =
    Map<String, dynamic> Function(T model);
typedef IpTradeSecretModelToUpdateMap<T> =
    Map<String, dynamic> Function(T model, String actorId);
typedef IpTradeSecretStringSelector<T> = String Function(T model);
typedef IpTradeSecretNullableStringSelector<T> = String? Function(T model);
typedef IpTradeSecretModelValidator<T> = void Function(T model);

class IpTradeSecretDetailRepository<T>
    implements IpTradeSecretDetailRepositoryPort<T> {
  const IpTradeSecretDetailRepository({
    required FirebaseFirestore firestore,
    required String tenantId,
    required String collectionName,
    required String codeField,
    required String entityLabel,
    required IpTradeSecretModelFromDocument<T> fromDocument,
    required IpTradeSecretModelToCreateMap<T> toCreateMap,
    required IpTradeSecretModelToUpdateMap<T> toUpdateMap,
    required IpTradeSecretStringSelector<T> idOf,
    required IpTradeSecretStringSelector<T> tenantIdOf,
    required IpTradeSecretStringSelector<T> brandIdOf,
    required IpTradeSecretNullableStringSelector<T> tradeSecretIdOf,
    required IpTradeSecretStringSelector<T> codeOf,
    required IpTradeSecretStringSelector<T> createdByOf,
    required IpTradeSecretNullableStringSelector<T> updatedByOf,
    required IpTradeSecretModelValidator<T> validateModel,
  }) : _firestore = firestore,
       _tenantId = tenantId,
       _collectionName = collectionName,
       _codeField = codeField,
       _entityLabel = entityLabel,
       _fromDocument = fromDocument,
       _toCreateMap = toCreateMap,
       _toUpdateMap = toUpdateMap,
       _idOf = idOf,
       _tenantIdOf = tenantIdOf,
       _brandIdOf = brandIdOf,
       _tradeSecretIdOf = tradeSecretIdOf,
       _codeOf = codeOf,
       _createdByOf = createdByOf,
       _updatedByOf = updatedByOf,
       _validateModel = validateModel;

  final FirebaseFirestore _firestore;
  final String _tenantId;
  final String _collectionName;
  final String _codeField;
  final String _entityLabel;
  final IpTradeSecretModelFromDocument<T> _fromDocument;
  final IpTradeSecretModelToCreateMap<T> _toCreateMap;
  final IpTradeSecretModelToUpdateMap<T> _toUpdateMap;
  final IpTradeSecretStringSelector<T> _idOf;
  final IpTradeSecretStringSelector<T> _tenantIdOf;
  final IpTradeSecretStringSelector<T> _brandIdOf;
  final IpTradeSecretNullableStringSelector<T> _tradeSecretIdOf;
  final IpTradeSecretStringSelector<T> _codeOf;
  final IpTradeSecretStringSelector<T> _createdByOf;
  final IpTradeSecretNullableStringSelector<T> _updatedByOf;
  final IpTradeSecretModelValidator<T> _validateModel;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  Query<Map<String, dynamic>> get _tenantQuery =>
      _collection.where('tenantId', isEqualTo: _tenantId);

  @override
  Future<String> create(T model) async {
    _validateOwnedModel(model);

    final brandId = _requiredId(_brandIdOf(model), fieldName: 'brandId');
    final code = _requiredText(_codeOf(model), fieldName: _codeField);

    final existing = await findByCode(brandId: brandId, code: code);
    final requestedId = _idOf(model).trim();

    if (existing != null && _idOf(existing).trim() != requestedId) {
      throw StateError(
        '$_entityLabel kodu seçilen marka için zaten kullanılıyor: $code',
      );
    }

    final document = requestedId.isEmpty
        ? _collection.doc()
        : _collection.doc(_requiredId(requestedId, fieldName: 'id'));

    if (requestedId.isNotEmpty) {
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir $_entityLabel kaydı zaten mevcut: $requestedId',
        );
      }
    }

    await document.set(_toCreateMap(model));
    return document.id;
  }

  @override
  Future<void> update(T model) async {
    _validateOwnedModel(model);

    final id = _requiredId(_idOf(model), fieldName: 'id');
    final document = _collection.doc(id);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek $_entityLabel kaydı bulunamadı: $id');
    }

    final existing = _fromDocument(snapshot);
    _validateOwnedModel(existing);

    if (_brandIdOf(existing).trim() != _brandIdOf(model).trim()) {
      throw StateError('$_entityLabel marka kimliği değiştirilemez.');
    }

    if ((_tradeSecretIdOf(existing) ?? '').trim() !=
        (_tradeSecretIdOf(model) ?? '').trim()) {
      throw StateError('$_entityLabel ticari sır kimliği değiştirilemez.');
    }

    if (_codeOf(existing).trim() != _codeOf(model).trim()) {
      throw StateError('$_entityLabel kodu değiştirilemez.');
    }

    final actorId = _requiredId(
      _updatedByOf(model) ?? _createdByOf(model),
      fieldName: 'updatedBy',
    );

    await document.update(_toUpdateMap(model, actorId));
  }

  @override
  Future<T?> getById(String id) async {
    final snapshot = await _collection
        .doc(_requiredId(id, fieldName: 'id'))
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final model = _fromDocument(snapshot);
    _validateOwnedModel(model);
    return model;
  }

  @override
  Future<T?> findByCode({required String brandId, required String code}) async {
    final cleanedBrandId = _requiredId(brandId, fieldName: 'brandId');
    final cleanedCode = _requiredText(code, fieldName: _codeField);

    final snapshot = await _tenantQuery
        .where('brandId', isEqualTo: cleanedBrandId)
        .where(_codeField, isEqualTo: cleanedCode)
        .limit(2)
        .get();

    if (snapshot.docs.length > 1) {
      throw StateError(
        '$_entityLabel kodu için birden fazla kayıt bulundu: $cleanedCode',
      );
    }

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final model = _fromDocument(snapshot.docs.single);
    _validateOwnedModel(model);
    return model;
  }

  @override
  Future<List<T>> list({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  }) async {
    final snapshot =
        await _buildListQuery(brandId: brandId, tradeSecretId: tradeSecretId)
            .orderBy('createdAt', descending: true)
            .limit(_validatedLimit(limit))
            .get();

    return snapshot.docs
        .map((document) {
          final model = _fromDocument(document);
          _validateOwnedModel(model);
          return model;
        })
        .toList(growable: false);
  }

  @override
  Stream<List<T>> watch({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  }) {
    return _buildListQuery(brandId: brandId, tradeSecretId: tradeSecretId)
        .orderBy('createdAt', descending: true)
        .limit(_validatedLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final model = _fromDocument(document);
                _validateOwnedModel(model);
                return model;
              })
              .toList(growable: false),
        );
  }

  @override
  Future<void> delete(String id) async {
    final document = _collection.doc(_requiredId(id, fieldName: 'id'));
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final model = _fromDocument(snapshot);
    _validateOwnedModel(model);
    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? tradeSecretId,
  }) {
    Query<Map<String, dynamic>> query = _tenantQuery;

    final cleanedBrandId = _optionalId(brandId, fieldName: 'brandId');
    final cleanedTradeSecretId = _optionalId(
      tradeSecretId,
      fieldName: 'tradeSecretId',
    );

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedTradeSecretId != null) {
      query = query.where('tradeSecretId', isEqualTo: cleanedTradeSecretId);
    }

    return query;
  }

  void _validateOwnedModel(T model) {
    _validateModel(model);

    if (_tenantIdOf(model).trim() != _tenantId) {
      throw StateError(
        '$_entityLabel tenant kimliği repository tenant kimliğiyle eşleşmiyor.',
      );
    }

    _requiredId(_brandIdOf(model), fieldName: 'brandId');
    _requiredText(_codeOf(model), fieldName: _codeField);

    final tradeSecretId = _tradeSecretIdOf(model);
    if (tradeSecretId != null && tradeSecretId.trim().isNotEmpty) {
      _requiredId(tradeSecretId, fieldName: 'tradeSecretId');
    }
  }

  static int _validatedLimit(int value) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(
        value,
        'limit',
        'limit 1 ile 500 arasında olmalıdır.',
      );
    }

    return value;
  }

  static String _requiredId(String value, {required String fieldName}) {
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

  static String _requiredText(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return cleaned;
  }

  static String? _optionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _requiredId(cleaned, fieldName: fieldName);
  }
}
