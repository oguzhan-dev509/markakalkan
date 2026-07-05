import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_disclosure_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretDisclosureRepository
    implements IpTradeSecretDetailRepositoryPort<IpTradeSecretDisclosureModel> {
  IpTradeSecretDisclosureRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretDisclosureModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretDisclosures,
        codeField: 'disclosureCode',
        entityLabel: 'Ticari sır ifşa kaydı',
        fromDocument: IpTradeSecretDisclosureModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.disclosureCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError(
              'Ticari sır ifşa kaydı zorunlu kimlik alanları eksik.',
            );
          }

          model.toMap();
        },
      );

  factory IpTradeSecretDisclosureRepository.instance({
    required String tenantId,
  }) {
    return IpTradeSecretDisclosureRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretDisclosureModel> _delegate;

  @override
  Future<String> create(IpTradeSecretDisclosureModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretDisclosureModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretDisclosureModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretDisclosureModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretDisclosureModel>> list({
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
  Stream<List<IpTradeSecretDisclosureModel>> watch({
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
