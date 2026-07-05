import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_remediation_action_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretRemediationActionRepository
    implements
        IpTradeSecretDetailRepositoryPort<IpTradeSecretRemediationActionModel> {
  IpTradeSecretRemediationActionRepository({required IpFirestoreRefs refs})
    : _delegate =
          IpTradeSecretDetailRepository<IpTradeSecretRemediationActionModel>(
            firestore: refs.firestore,
            tenantId: refs.tenantId,
            collectionName: IpCollections.tradeSecretRemediationActions,
            codeField: 'actionCode',
            entityLabel: 'Ticari sır iyileştirme aksiyonu',
            fromDocument: IpTradeSecretRemediationActionModel.fromDocument,
            toCreateMap: (model) => model.toCreateMap(),
            toUpdateMap: (model, actorId) =>
                model.toUpdateMap(actorId: actorId),
            idOf: (model) => model.id,
            tenantIdOf: (model) => model.tenantId,
            brandIdOf: (model) => model.brandId,
            tradeSecretIdOf: (model) => model.tradeSecretId,
            codeOf: (model) => model.actionCode,
            createdByOf: (model) => model.createdBy,
            updatedByOf: (model) => model.updatedBy,
            validateModel: (model) {
              if (!model.hasCompleteIdentity) {
                throw StateError(
                  'Ticari sır iyileştirme aksiyonu zorunlu kimlik alanları eksik.',
                );
              }

              model.toMap();
            },
          );

  factory IpTradeSecretRemediationActionRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretRemediationActionRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretRemediationActionModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretRemediationActionModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretRemediationActionModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretRemediationActionModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretRemediationActionModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretRemediationActionModel>> list({
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
  Stream<List<IpTradeSecretRemediationActionModel>> watch({
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
