import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_protection_control_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretProtectionControlRepository
    implements
        IpTradeSecretDetailRepositoryPort<IpTradeSecretProtectionControlModel> {
  IpTradeSecretProtectionControlRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretProtectionControlModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretProtectionControls,
            codeField: 'controlCode',
            entityLabel: 'Ticari sır koruma kontrolü',
            fromDocument: IpTradeSecretProtectionControlModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.controlCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır koruma kontrolü zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretProtectionControlRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretProtectionControlRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretProtectionControlModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretProtectionControlModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretProtectionControlModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretProtectionControlModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretProtectionControlModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretProtectionControlModel>> list({
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
  Stream<List<IpTradeSecretProtectionControlModel>> watch({
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
