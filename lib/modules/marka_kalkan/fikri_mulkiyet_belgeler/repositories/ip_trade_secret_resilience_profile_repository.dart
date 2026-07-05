import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_resilience_profile_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretResilienceProfileRepository
    implements
        IpTradeSecretDetailRepositoryPort<IpTradeSecretResilienceProfileModel> {
  IpTradeSecretResilienceProfileRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretResilienceProfileModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretResilienceProfiles,
            codeField: 'profileCode',
            entityLabel: 'Ticari sır dayanıklılık profili',
            fromDocument: IpTradeSecretResilienceProfileModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.profileCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır dayanıklılık profili zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretResilienceProfileRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretResilienceProfileRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretResilienceProfileModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretResilienceProfileModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretResilienceProfileModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretResilienceProfileModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretResilienceProfileModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretResilienceProfileModel>> list({
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
  Stream<List<IpTradeSecretResilienceProfileModel>> watch({
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
