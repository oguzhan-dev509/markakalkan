import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_access_grant_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretAccessGrantRepository
    implements
        IpTradeSecretDetailRepositoryPort<IpTradeSecretAccessGrantModel> {
  IpTradeSecretAccessGrantRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretAccessGrantModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretAccessGrants,
        codeField: 'grantCode',
        entityLabel: 'Ticari sır erişim yetkisi',
        fromDocument: IpTradeSecretAccessGrantModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.grantCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError(
              'Ticari sır erişim yetkisi zorunlu kimlik alanları eksik.',
            );
          }

          model.toMap();
        },
      );

  factory IpTradeSecretAccessGrantRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretAccessGrantRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretAccessGrantModel> _delegate;

  @override
  Future<String> create(IpTradeSecretAccessGrantModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretAccessGrantModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretAccessGrantModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretAccessGrantModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretAccessGrantModel>> list({
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
  Stream<List<IpTradeSecretAccessGrantModel>> watch({
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
