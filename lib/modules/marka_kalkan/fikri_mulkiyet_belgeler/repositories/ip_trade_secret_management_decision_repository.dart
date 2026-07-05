import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_management_decision_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretManagementDecisionRepository
    implements
        IpTradeSecretDetailRepositoryPort<
          IpTradeSecretManagementDecisionModel
        > {
  IpTradeSecretManagementDecisionRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretManagementDecisionModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretManagementDecisions,
            codeField: 'decisionCode',
            entityLabel: 'Ticari sır yönetim kararı',
            fromDocument: IpTradeSecretManagementDecisionModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.decisionCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır yönetim kararı zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretManagementDecisionRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretManagementDecisionRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretManagementDecisionModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretManagementDecisionModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretManagementDecisionModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretManagementDecisionModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretManagementDecisionModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretManagementDecisionModel>> list({
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
  Stream<List<IpTradeSecretManagementDecisionModel>> watch({
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
