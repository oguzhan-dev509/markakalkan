import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_lifecycle_transition_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretLifecycleTransitionRepository
    implements
        IpTradeSecretDetailRepositoryPort<
          IpTradeSecretLifecycleTransitionModel
        > {
  IpTradeSecretLifecycleTransitionRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretLifecycleTransitionModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretLifecycleTransitions,
            codeField: 'transitionCode',
            entityLabel: 'Ticari sır yaşam döngüsü geçişi',
            fromDocument: IpTradeSecretLifecycleTransitionModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.transitionCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır yaşam döngüsü geçişi zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretLifecycleTransitionRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretLifecycleTransitionRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretLifecycleTransitionModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretLifecycleTransitionModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretLifecycleTransitionModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretLifecycleTransitionModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretLifecycleTransitionModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretLifecycleTransitionModel>> list({
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
  Stream<List<IpTradeSecretLifecycleTransitionModel>> watch({
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
