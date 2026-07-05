import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_incident_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_detail_repository.dart';
import 'ip_trade_secret_detail_repository_ports.dart';

class IpTradeSecretIncidentRepository
    implements IpTradeSecretDetailRepositoryPort<IpTradeSecretIncidentModel> {
  IpTradeSecretIncidentRepository({required IpFirestoreRefs refs})
    : _delegate = IpTradeSecretDetailRepository<IpTradeSecretIncidentModel>(
        firestore: refs.firestore,
        tenantId: refs.tenantId,
        collectionName: IpCollections.tradeSecretIncidents,
        codeField: 'incidentCode',
        entityLabel: 'Ticari sır olayı',
        fromDocument: IpTradeSecretIncidentModel.fromDocument,
        toCreateMap: (model) => model.toCreateMap(),
        toUpdateMap: (model, actorId) => model.toUpdateMap(actorId: actorId),
        idOf: (model) => model.id,
        tenantIdOf: (model) => model.tenantId,
        brandIdOf: (model) => model.brandId,
        tradeSecretIdOf: (model) => model.tradeSecretId,
        codeOf: (model) => model.incidentCode,
        createdByOf: (model) => model.createdBy,
        updatedByOf: (model) => model.updatedBy,
        validateModel: (model) {
          if (!model.hasCompleteIdentity) {
            throw StateError('Ticari sır olayı zorunlu kimlik alanları eksik.');
          }

          model.toMap();
        },
      );

  factory IpTradeSecretIncidentRepository.instance({required String tenantId}) {
    return IpTradeSecretIncidentRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpTradeSecretDetailRepository<IpTradeSecretIncidentModel> _delegate;

  @override
  Future<String> create(IpTradeSecretIncidentModel model) =>
      _delegate.create(model);

  @override
  Future<void> update(IpTradeSecretIncidentModel model) =>
      _delegate.update(model);

  @override
  Future<IpTradeSecretIncidentModel?> getById(String id) =>
      _delegate.getById(id);

  @override
  Future<IpTradeSecretIncidentModel?> findByCode({
    required String brandId,
    required String code,
  }) {
    return _delegate.findByCode(brandId: brandId, code: code);
  }

  @override
  Future<List<IpTradeSecretIncidentModel>> list({
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
  Stream<List<IpTradeSecretIncidentModel>> watch({
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
