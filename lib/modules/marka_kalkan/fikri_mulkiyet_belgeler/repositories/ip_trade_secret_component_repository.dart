import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_component_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretComponentRepository
    implements IpTradeSecretDetailRepositoryPort<IpTradeSecretComponentModel> {
  IpTradeSecretComponentRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretComponentModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretComponents,
        codeField: 'componentCode',
        entityLabel: 'Ticari sır bileşeni',
        fromDocument: IpTradeSecretComponentModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.componentCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError(
              'Ticari sır bileşeni zorunlu kimlik alanları eksik.',
            );
          }

          model.toMap();
        },
      );

  factory IpTradeSecretComponentRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretComponentRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretComponentModel> _delegate;

  @override
  Future<String> create(IpTradeSecretComponentModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretComponentModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretComponentModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretComponentModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretComponentModel>> list({
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
  Stream<List<IpTradeSecretComponentModel>> watch({
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
