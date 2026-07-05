import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_asset_inventory_filter.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_asset_inventory_summary.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_asset_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_repository_ports.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_asset_inventory_service.dart';

void main() {
  const tenantId = 'tenant-1';
  const brandId = 'brand-1';

  final now = DateTime.utc(2026, 7, 5, 8);

  group('IpAssetInventoryFilter', () {
    test('arama, risk ve eksik hak filtrelerini birlikte uygular', () {
      final assets = <IpAssetModel>[
        _asset(
          id: 'asset-1',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Altın Seri Marka',
          assetCode: 'MK-001',
          assetType: IpAssetType.trademark,
          riskLevel: IpRiskLevel.critical,
          tags: const <String>['kozmetik', 'premium'],
          rightIds: const <String>[],
          createdAt: now,
        ),
        _asset(
          id: 'asset-2',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Gizli Üretim Formülü',
          assetCode: 'FRM-001',
          assetType: IpAssetType.formula,
          riskLevel: IpRiskLevel.high,
          tags: const <String>['reçete'],
          rightIds: const <String>['right-1'],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      const filter = IpAssetInventoryFilter(
        query: 'kozmetik',
        riskLevel: IpRiskLevel.critical,
        missingRightsOnly: true,
      );

      final result = filter.apply(assets);

      expect(result, hasLength(1));
      expect(result.single.id, 'asset-1');
      expect(result.single.title, 'Altın Seri Marka');
    });

    test('risk sıralaması kritik varlığı önce getirir', () {
      final assets = <IpAssetModel>[
        _asset(
          id: 'asset-low',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Düşük Risk',
          assetCode: 'LOW-1',
          riskLevel: IpRiskLevel.low,
          createdAt: now,
        ),
        _asset(
          id: 'asset-critical',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Kritik Risk',
          assetCode: 'CRT-1',
          riskLevel: IpRiskLevel.critical,
          createdAt: now,
        ),
        _asset(
          id: 'asset-high',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Yüksek Risk',
          assetCode: 'HGH-1',
          riskLevel: IpRiskLevel.high,
          createdAt: now,
        ),
      ];

      const filter = IpAssetInventoryFilter(
        sort: IpAssetInventorySort.riskDescending,
      );

      final result = filter.apply(assets);

      expect(result.map((asset) => asset.id).toList(), <String>[
        'asset-critical',
        'asset-high',
        'asset-low',
      ]);
    });

    test('en zayıf koruma skorunu önce getirir', () {
      final assets = <IpAssetModel>[
        _asset(
          id: 'asset-strong',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Güçlü Varlık',
          assetCode: 'STR-1',
          rightStrengthScore: 90,
          secretSecurityScore: 90,
          responseReadinessScore: 90,
          resilienceScore: 90,
          createdAt: now,
        ),
        _asset(
          id: 'asset-weak',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Zayıf Varlık',
          assetCode: 'WEK-1',
          rightStrengthScore: 20,
          secretSecurityScore: 30,
          responseReadinessScore: 40,
          resilienceScore: 50,
          createdAt: now,
        ),
      ];

      const filter = IpAssetInventoryFilter(
        sort: IpAssetInventorySort.weakestProtectionFirst,
      );

      final result = filter.apply(assets);

      expect(result.first.id, 'asset-weak');
      expect(result.last.id, 'asset-strong');
    });

    test('limit değeri 1 ile 500 arasında normalize edilir', () {
      expect(const IpAssetInventoryFilter(limit: 0).normalized().limit, 1);

      expect(const IpAssetInventoryFilter(limit: 900).normalized().limit, 500);
    });
  });

  group('IpAssetInventorySummary', () {
    test('sayaçları, ortalamaları ve kapsam oranlarını hesaplar', () {
      final assets = <IpAssetModel>[
        _asset(
          id: 'asset-1',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Korunan Marka',
          assetCode: 'MK-1',
          status: IpAssetStatus.protected,
          riskLevel: IpRiskLevel.low,
          rightIds: const <String>['right-1'],
          documentIds: const <String>['doc-1'],
          monitoringEnabled: true,
          rightStrengthScore: 80,
          secretSecurityScore: 60,
          responseReadinessScore: 70,
          resilienceScore: 90,
          createdAt: now,
        ),
        _asset(
          id: 'asset-2',
          tenantId: tenantId,
          brandId: brandId,
          title: 'Açık Formül',
          assetCode: 'FRM-1',
          assetType: IpAssetType.formula,
          status: IpAssetStatus.exposed,
          riskLevel: IpRiskLevel.critical,
          confidentialityLevel: IpConfidentialityLevel.tradeSecret,
          containsTradeSecret: true,
          rightIds: const <String>[],
          documentIds: const <String>[],
          rightStrengthScore: 20,
          secretSecurityScore: 30,
          responseReadinessScore: 40,
          resilienceScore: 50,
          createdAt: now,
        ),
      ];

      final summary = IpAssetInventorySummary.fromAssets(assets);

      expect(summary.totalAssetCount, 2);
      expect(summary.activeAssetCount, 1);
      expect(summary.protectedAssetCount, 1);
      expect(summary.tradeSecretAssetCount, 1);
      expect(summary.monitoredAssetCount, 1);
      expect(summary.criticalRiskCount, 1);
      expect(summary.immediateAttentionCount, 1);
      expect(summary.protectionGapCount, 1);
      expect(summary.missingRightsCount, 1);
      expect(summary.missingDocumentsCount, 1);
      expect(summary.missingRightsAndDocumentsCount, 1);

      expect(summary.averageRightStrengthScore, 50);
      expect(summary.averageSecretSecurityScore, 45);
      expect(summary.averageResponseReadinessScore, 55);
      expect(summary.averageResilienceScore, 70);
      expect(summary.averageOverallProtectionScore, 55);

      expect(summary.rightsCoverageRate, 0.5);
      expect(summary.documentCoverageRate, 0.5);
      expect(summary.monitoringCoverageRate, 0.5);
      expect(summary.hasCriticalExposure, isTrue);
    });

    test('boş envanter sıfır değerler döndürür', () {
      final summary = IpAssetInventorySummary.empty();

      expect(summary.totalAssetCount, 0);
      expect(summary.averageOverallProtectionScore, 0);
      expect(summary.rightsCoverageRate, 0);
      expect(summary.documentCoverageRate, 0);
      expect(summary.monitoringCoverageRate, 0);
      expect(summary.isEmpty, isTrue);
    });
  });

  group('IpAssetInventoryService', () {
    test('yükleme sonucunda filtreli liste ve tam özet üretir', () async {
      final repository = _FakeIpAssetRepository(
        assets: <IpAssetModel>[
          _asset(
            id: 'asset-critical',
            tenantId: tenantId,
            brandId: brandId,
            title: 'Kritik Formül',
            assetCode: 'FRM-1',
            assetType: IpAssetType.formula,
            riskLevel: IpRiskLevel.critical,
            createdAt: now,
          ),
          _asset(
            id: 'asset-low',
            tenantId: tenantId,
            brandId: brandId,
            title: 'Düşük Riskli Marka',
            assetCode: 'MK-1',
            riskLevel: IpRiskLevel.low,
            createdAt: now,
          ),
        ],
      );

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
        clock: () => now,
      );

      final snapshot = await service.loadInventory(
        filter: const IpAssetInventoryFilter(riskLevel: IpRiskLevel.critical),
      );

      expect(snapshot.assets, hasLength(1));
      expect(snapshot.assets.single.id, 'asset-critical');
      expect(snapshot.summary.totalAssetCount, 2);
      expect(snapshot.summary.criticalRiskCount, 1);
      expect(snapshot.visibleAssetCount, 1);
      expect(snapshot.isFiltered, isTrue);
      expect(snapshot.generatedAt, now);
    });

    test('canlı akış filtrelenmiş snapshot üretir', () async {
      final repository = _FakeIpAssetRepository(
        assets: <IpAssetModel>[
          _asset(
            id: 'asset-1',
            tenantId: tenantId,
            brandId: brandId,
            title: 'İzlenen Marka',
            assetCode: 'MK-1',
            monitoringEnabled: true,
            createdAt: now,
          ),
          _asset(
            id: 'asset-2',
            tenantId: tenantId,
            brandId: brandId,
            title: 'İzlenmeyen Marka',
            assetCode: 'MK-2',
            monitoringEnabled: false,
            createdAt: now,
          ),
        ],
      );

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
        clock: () => now,
      );

      final snapshot = await service
          .watchInventory(
            filter: const IpAssetInventoryFilter(monitoringEnabled: true),
          )
          .first;

      expect(snapshot.assets, hasLength(1));
      expect(snapshot.assets.single.id, 'asset-1');
      expect(snapshot.summary.totalAssetCount, 2);
    });

    test('farklı tenant kaydı yüklenirse işlemi reddeder', () async {
      final repository = _FakeIpAssetRepository(
        assets: <IpAssetModel>[
          _asset(
            id: 'foreign-asset',
            tenantId: 'tenant-2',
            brandId: brandId,
            title: 'Yabancı Varlık',
            assetCode: 'FOREIGN-1',
            createdAt: now,
          ),
        ],
      );

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
      );

      expect(service.loadInventory(), throwsA(isA<StateError>()));
    });

    test('bağlantılı varlığın kalıcı silinmesini engeller', () async {
      final repository = _FakeIpAssetRepository(
        assets: <IpAssetModel>[
          _asset(
            id: 'linked-asset',
            tenantId: tenantId,
            brandId: brandId,
            title: 'Bağlantılı Varlık',
            assetCode: 'LINK-1',
            rightIds: const <String>['right-1'],
            createdAt: now,
          ),
        ],
      );

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
      );

      expect(service.deleteAsset('linked-asset'), throwsA(isA<StateError>()));

      expect(repository.deletedAssetIds, isEmpty);
    });

    test('bağlantısız varlığı repository üzerinden siler', () async {
      final repository = _FakeIpAssetRepository(
        assets: <IpAssetModel>[
          _asset(
            id: 'orphan-asset',
            tenantId: tenantId,
            brandId: brandId,
            title: 'Bağlantısız Varlık',
            assetCode: 'ORPHAN-1',
            createdAt: now,
          ),
        ],
      );

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
      );

      await service.deleteAsset('orphan-asset');

      expect(repository.deletedAssetIds, <String>['orphan-asset']);
      expect(
        repository.assets.any((asset) => asset.id == 'orphan-asset'),
        isFalse,
      );
    });

    test('durum ve skor güncellemelerini doğru aktarır', () async {
      final repository = _FakeIpAssetRepository();

      final service = IpAssetInventoryService(
        tenantId: tenantId,
        repository: repository,
      );

      await service.updateStatus(
        assetId: 'asset-1',
        status: IpAssetStatus.archived,
        actorId: 'user-1',
      );

      await service.updateScores(
        assetId: 'asset-1',
        rightStrengthScore: 90,
        secretSecurityScore: 80,
        responseReadinessScore: 70,
        resilienceScore: 60,
        actorId: 'user-1',
      );

      expect(repository.lastStatusAssetId, 'asset-1');
      expect(repository.lastStatus, IpAssetStatus.archived);
      expect(repository.lastStatusActorId, 'user-1');

      expect(repository.lastScoreAssetId, 'asset-1');
      expect(repository.lastRightStrengthScore, 90);
      expect(repository.lastSecretSecurityScore, 80);
      expect(repository.lastResponseReadinessScore, 70);
      expect(repository.lastResilienceScore, 60);
      expect(repository.lastScoreActorId, 'user-1');
    });
  });
}

class _FakeIpAssetRepository implements IpAssetRepositoryPort {
  _FakeIpAssetRepository({List<IpAssetModel> assets = const <IpAssetModel>[]})
    : assets = List<IpAssetModel>.from(assets);

  final List<IpAssetModel> assets;
  final List<String> deletedAssetIds = <String>[];

  String? lastStatusAssetId;
  IpAssetStatus? lastStatus;
  String? lastStatusActorId;

  String? lastScoreAssetId;
  int? lastRightStrengthScore;
  int? lastSecretSecurityScore;
  int? lastResponseReadinessScore;
  int? lastResilienceScore;
  String? lastScoreActorId;

  @override
  Future<String> create(IpAssetModel asset) async {
    final id = asset.id.trim().isEmpty
        ? 'asset-${assets.length + 1}'
        : asset.id.trim();

    assets.add(asset.copyWith(id: id));

    return id;
  }

  @override
  Future<void> update(IpAssetModel asset) async {
    final index = assets.indexWhere((item) => item.id == asset.id);

    if (index >= 0) {
      assets[index] = asset;
    }
  }

  @override
  Future<IpAssetModel?> getById(String assetId) async {
    for (final asset in assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<IpAssetModel?> findByAssetCode({
    required String brandId,
    required String assetCode,
  }) async {
    for (final asset in assets) {
      if (asset.brandId == brandId && asset.assetCode == assetCode) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<List<IpAssetModel>> listAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) async {
    return _filter(
      brandId: brandId,
      assetType: assetType,
      status: status,
      riskLevel: riskLevel,
      containsTradeSecret: containsTradeSecret,
      monitoringEnabled: monitoringEnabled,
      limit: limit,
    );
  }

  @override
  Stream<List<IpAssetModel>> watchAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) {
    return Stream<List<IpAssetModel>>.value(
      _filter(
        brandId: brandId,
        assetType: assetType,
        status: status,
        riskLevel: riskLevel,
        containsTradeSecret: containsTradeSecret,
        monitoringEnabled: monitoringEnabled,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<IpAssetModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  }) async {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              asset.hasProtectionGap,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpAssetModel>> listImmediateAttention({
    String? brandId,
    int limit = 200,
  }) async {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              asset.requiresImmediateAttention,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> updateStatus({
    required String assetId,
    required IpAssetStatus status,
    required String updatedBy,
  }) async {
    lastStatusAssetId = assetId;
    lastStatus = status;
    lastStatusActorId = updatedBy;
  }

  @override
  Future<void> updateScores({
    required String assetId,
    required int rightStrengthScore,
    required int secretSecurityScore,
    required int responseReadinessScore,
    required int resilienceScore,
    required String updatedBy,
  }) async {
    lastScoreAssetId = assetId;
    lastRightStrengthScore = rightStrengthScore;
    lastSecretSecurityScore = secretSecurityScore;
    lastResponseReadinessScore = responseReadinessScore;
    lastResilienceScore = resilienceScore;
    lastScoreActorId = updatedBy;
  }

  @override
  Future<void> delete(String assetId) async {
    deletedAssetIds.add(assetId);
    assets.removeWhere((asset) => asset.id == assetId);
  }

  List<IpAssetModel> _filter({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    required int limit,
  }) {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              (assetType == null || asset.assetType == assetType) &&
              (status == null || asset.status == status) &&
              (riskLevel == null || asset.riskLevel == riskLevel) &&
              (containsTradeSecret == null ||
                  asset.containsTradeSecret == containsTradeSecret) &&
              (monitoringEnabled == null ||
                  asset.monitoringEnabled == monitoringEnabled),
        )
        .take(limit)
        .toList(growable: false);
  }
}

IpAssetModel _asset({
  required String id,
  required String tenantId,
  required String brandId,
  required String title,
  required String assetCode,
  required DateTime createdAt,
  IpAssetType assetType = IpAssetType.trademark,
  IpAssetStatus status = IpAssetStatus.active,
  IpConfidentialityLevel confidentialityLevel = IpConfidentialityLevel.internal,
  IpRiskLevel riskLevel = IpRiskLevel.medium,
  List<String> tags = const <String>[],
  List<String> rightIds = const <String>[],
  List<String> documentIds = const <String>[],
  List<String> relationshipIds = const <String>[],
  List<String> monitoringProfileIds = const <String>[],
  int rightStrengthScore = 70,
  int secretSecurityScore = 70,
  int responseReadinessScore = 70,
  int resilienceScore = 70,
  bool containsTradeSecret = false,
  bool monitoringEnabled = false,
}) {
  return IpAssetModel(
    id: id,
    tenantId: tenantId,
    brandId: brandId,
    assetCode: assetCode,
    title: title,
    assetType: assetType,
    status: status,
    confidentialityLevel: confidentialityLevel,
    riskLevel: riskLevel,
    tags: tags,
    rightIds: rightIds,
    documentIds: documentIds,
    relationshipIds: relationshipIds,
    monitoringProfileIds: monitoringProfileIds,
    rightStrengthScore: rightStrengthScore,
    secretSecurityScore: secretSecurityScore,
    responseReadinessScore: responseReadinessScore,
    resilienceScore: resilienceScore,
    containsTradeSecret: containsTradeSecret,
    monitoringEnabled: monitoringEnabled,
    createdAt: createdAt,
    createdBy: 'user-1',
  );
}
