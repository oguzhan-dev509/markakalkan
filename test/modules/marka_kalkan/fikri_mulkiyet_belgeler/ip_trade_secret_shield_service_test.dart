import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_trade_secret_repository_port.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_trade_secret_shield_service.dart';

void main() {
  group('IpTradeSecretShieldService', () {
    late _FakeTradeSecretRepository repository;
    late IpTradeSecretShieldService service;

    setUp(() {
      repository = _FakeTradeSecretRepository();
      service = IpTradeSecretShieldService(repository: repository);
    });

    IpTradeSecretModel buildModel({
      String id = 'secret-1',
      IpConfidentialityLevel confidentialityLevel =
          IpConfidentialityLevel.tradeSecret,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretModel(
        id: id,
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        secretCode: 'TS-001',
        title: 'Özel Üretim Formülü',
        secretType: IpTradeSecretType.formula,
        status: IpTradeSecretStatus.active,
        confidentialityLevel: confidentialityLevel,
        riskLevel: IpRiskLevel.high,
        protectionMode: IpSecretProtectionMode.metadataOnly,
        disclosureScope: IpSecretDisclosureScope.needToKnow,
        legalBasisStatus: IpSecretLegalBasisStatus.documented,
        compartmentalizationLevel: IpSecretCompartmentalizationLevel.segmented,
        economicValueLevel: IpSecretEconomicValueLevel.critical,
        secretSecurityScore: 70,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'user-1',
        updatedBy: 'user-1',
      );
    }

    test('geçerli koruma dosyasını repository üzerinden oluşturur', () async {
      final id = await service.createProtectionFile(buildModel());

      expect(id, 'secret-1');
      expect(repository.created.length, 1);
    });

    test('düşük gizlilik seviyesini reddeder', () async {
      final model = buildModel(
        confidentialityLevel: IpConfidentialityLevel.internal,
      );

      await expectLater(
        service.createProtectionFile(model),
        throwsA(isA<StateError>()),
      );

      expect(repository.created, isEmpty);
    });

    test('açık metin sır sızıntısını repository öncesinde reddeder', () async {
      final model = buildModel(
        metadata: const <String, dynamic>{'formulaContent': 'gizli formül'},
      );

      await expectLater(
        service.createProtectionFile(model),
        throwsA(isA<StateError>()),
      );

      expect(repository.created, isEmpty);
    });

    test('sızıntı şüphesini repository katmanına iletir', () async {
      await service.reportLeakageSuspicion(
        tradeSecretId: 'secret-1',
        reportedBy: 'user-1',
      );

      expect(repository.leakageMarkedIds, <String>['secret-1']);
    });

    test('hukuki muhafaza komutlarını repository katmanına iletir', () async {
      await service.activateLegalHold(
        tradeSecretId: 'secret-1',
        actorId: 'user-1',
      );

      await service.releaseLegalHold(
        tradeSecretId: 'secret-1',
        actorId: 'user-1',
      );

      expect(repository.legalHoldActivatedIds, <String>['secret-1']);
      expect(repository.legalHoldReleasedIds, <String>['secret-1']);
    });

    test('boş olay aktörü kimliğini reddeder', () async {
      await expectLater(
        service.reportLeakageSuspicion(
          tradeSecretId: 'secret-1',
          reportedBy: ' ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

class _FakeTradeSecretRepository implements IpTradeSecretRepositoryPort {
  final List<IpTradeSecretModel> created = <IpTradeSecretModel>[];
  final List<String> leakageMarkedIds = <String>[];
  final List<String> legalHoldActivatedIds = <String>[];
  final List<String> legalHoldReleasedIds = <String>[];

  @override
  Future<String> create(IpTradeSecretModel tradeSecret) async {
    created.add(tradeSecret);
    return tradeSecret.id;
  }

  @override
  Future<void> update(IpTradeSecretModel tradeSecret) async {}

  @override
  Future<IpTradeSecretModel?> getById(String tradeSecretId) async {
    return null;
  }

  @override
  Future<IpTradeSecretModel?> findBySecretCode({
    required String brandId,
    required String secretCode,
  }) async {
    return null;
  }

  @override
  Future<List<IpTradeSecretModel>> listAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  }) async {
    return List<IpTradeSecretModel>.unmodifiable(created);
  }

  @override
  Stream<List<IpTradeSecretModel>> watchAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  }) {
    return Stream<List<IpTradeSecretModel>>.value(
      List<IpTradeSecretModel>.unmodifiable(created),
    );
  }

  @override
  Future<void> updateStatus({
    required String tradeSecretId,
    required IpTradeSecretStatus status,
    required String updatedBy,
  }) async {}

  @override
  Future<void> markLeakageSuspected({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    leakageMarkedIds.add(tradeSecretId);
  }

  @override
  Future<void> clearLeakageSuspicion({
    required String tradeSecretId,
    required String updatedBy,
  }) async {}

  @override
  Future<void> activateLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    legalHoldActivatedIds.add(tradeSecretId);
  }

  @override
  Future<void> releaseLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    legalHoldReleasedIds.add(tradeSecretId);
  }

  @override
  Future<void> delete(String tradeSecretId) async {}
}
