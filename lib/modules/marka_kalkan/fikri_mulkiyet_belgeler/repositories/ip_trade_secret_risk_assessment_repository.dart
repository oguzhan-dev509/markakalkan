import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_risk_assessment_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretRiskAssessmentRepository
    implements
        IpTradeSecretDetailRepositoryPort<IpTradeSecretRiskAssessmentModel> {
  IpTradeSecretRiskAssessmentRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretRiskAssessmentModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretRiskAssessments,
        codeField: 'assessmentCode',
        entityLabel: 'Ticari sır risk değerlendirmesi',
        fromDocument: IpTradeSecretRiskAssessmentModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.assessmentCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError(
              'Ticari sır risk değerlendirmesi zorunlu kimlik alanları eksik.',
            );
          }

          model.toMap();
        },
      );

  factory IpTradeSecretRiskAssessmentRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretRiskAssessmentRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretRiskAssessmentModel>
  _delegate;

  @override
  Future<String> create(IpTradeSecretRiskAssessmentModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretRiskAssessmentModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretRiskAssessmentModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretRiskAssessmentModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretRiskAssessmentModel>> list({
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
  Stream<List<IpTradeSecretRiskAssessmentModel>> watch({
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
