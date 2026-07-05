import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_alert_rule_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretAlertRuleRepository
    implements IpTradeSecretDetailRepositoryPort<IpTradeSecretAlertRuleModel> {
  IpTradeSecretAlertRuleRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretAlertRuleModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretAlertRules,
        codeField: 'ruleCode',
        entityLabel: 'Ticari sır alarm kuralı',
        fromDocument: IpTradeSecretAlertRuleModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.ruleCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError(
              'Ticari sır alarm kuralı zorunlu kimlik alanları eksik.',
            );
          }

          model.toMap();
        },
      );

  factory IpTradeSecretAlertRuleRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretAlertRuleRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretAlertRuleModel> _delegate;

  @override
  Future<String> create(IpTradeSecretAlertRuleModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretAlertRuleModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretAlertRuleModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretAlertRuleModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretAlertRuleModel>> list({
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
  Stream<List<IpTradeSecretAlertRuleModel>> watch({
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
