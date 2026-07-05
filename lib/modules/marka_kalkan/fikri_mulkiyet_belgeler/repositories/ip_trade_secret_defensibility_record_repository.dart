import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_defensibility_record_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretDefensibilityRecordRepository
    implements
        IpTradeSecretDetailRepositoryPort<
          IpTradeSecretDefensibilityRecordModel
        > {
  IpTradeSecretDefensibilityRecordRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretDefensibilityRecordModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretDefensibilityRecords,
            codeField: 'recordCode',
            entityLabel: 'Ticari sır savunulabilirlik kaydı',
            fromDocument: IpTradeSecretDefensibilityRecordModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.recordCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır savunulabilirlik kaydı zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretDefensibilityRecordRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretDefensibilityRecordRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretDefensibilityRecordModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretDefensibilityRecordModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretDefensibilityRecordModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretDefensibilityRecordModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretDefensibilityRecordModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretDefensibilityRecordModel>> list({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  }) {
    return _delegate.list(
      brandId: brandId,
      tradeSecretId: tradeSecretId,
      limit: limit,
    );
  }

  @override
  Stream<List<IpTradeSecretDefensibilityRecordModel>> watch({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  }) {
    return _delegate.watch(
      brandId: brandId,
      tradeSecretId: tradeSecretId,
      limit: limit,
    );
  }

  @override
  Future<void> delete(String id) => _delegate.delete(id);
}
