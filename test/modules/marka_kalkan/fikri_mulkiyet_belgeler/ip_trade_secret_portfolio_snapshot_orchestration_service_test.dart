import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_portfolio_summary_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_trade_secret_portfolio_data_source.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_trade_secret_portfolio_aggregation_service.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_trade_secret_portfolio_snapshot_orchestration_service.dart';

class _FakeDataSource implements IpTradeSecretPortfolioDataSourcePort {
  _FakeDataSource({this.error});

  final Object? error;
  int callCount = 0;
  String? lastTenantId;
  String? lastBrandId;

  @override
  Future<IpTradeSecretPortfolioDataSet> loadPortfolioData({
    required String tenantId,
    String? brandId,
  }) async {
    callCount++;
    lastTenantId = tenantId;
    lastBrandId = brandId;

    if (error != null) {
      throw error!;
    }

    return const IpTradeSecretPortfolioDataSet();
  }
}

class _FakeSnapshotStore implements IpTradeSecretPortfolioSnapshotStorePort {
  bool exists = false;
  IpTradeSecretPortfolioSummaryModel? existing;
  IpTradeSecretPortfolioSummaryModel? previous;
  IpTradeSecretPortfolioSummaryModel? saved;
  bool? overwriteValue;
  int saveCallCount = 0;

  @override
  Future<bool> snapshotExists(String snapshotId) async => exists;

  @override
  Future<IpTradeSecretPortfolioSummaryModel?> getSnapshot(
    String snapshotId,
  ) async {
    return existing;
  }

  @override
  Future<IpTradeSecretPortfolioSummaryModel?> findPreviousSnapshot({
    required String tenantId,
    required IpTradeSecretPortfolioScope scope,
    required String scopeId,
    String? brandId,
    required DateTime before,
  }) async {
    return previous;
  }

  @override
  Future<void> saveSnapshot(
    IpTradeSecretPortfolioSummaryModel summary, {
    bool overwrite = false,
  }) async {
    saveCallCount++;
    saved = summary;
    overwriteValue = overwrite;
  }
}

IpTradeSecretPortfolioSummaryModel _summary({
  String id = 'tenant_1_brand_brand_1_2026-07-04',
  int averageRiskScore = 50,
}) {
  return IpTradeSecretPortfolioSummaryModel(
    id: id,
    tenantId: 'tenant-1',
    brandId: 'brand-1',
    scope: IpTradeSecretPortfolioScope.brand,
    scopeId: 'brand-1',
    health: IpTradeSecretPortfolioHealth.watch,
    trend: IpTradeSecretPortfolioTrend.stable,
    totalTradeSecretCount: 0,
    averageRiskScore: averageRiskScore,
    generatedAt: DateTime.utc(2026, 7, 4),
    generatedBy: 'system-1',
  );
}

void main() {
  IpTradeSecretPortfolioSnapshotRequest request({
    bool persist = true,
    bool overwrite = false,
    bool usePreviousSnapshot = true,
    IpTradeSecretPortfolioScope scope = IpTradeSecretPortfolioScope.brand,
    String? brandId = 'brand-1',
    String? businessUnitId,
    String? departmentId,
    String? countryCode,
    String? categoryCode,
    DateTime? snapshotStartAt,
    DateTime? snapshotEndAt,
  }) {
    return IpTradeSecretPortfolioSnapshotRequest(
      tenantId: 'tenant-1',
      scope: scope,
      scopeId: scope == IpTradeSecretPortfolioScope.brand
          ? 'brand-1'
          : 'scope-1',
      generatedBy: 'system-1',
      generatedAt: DateTime.utc(2026, 7, 5, 12),
      brandId: brandId,
      businessUnitId: businessUnitId,
      departmentId: departmentId,
      countryCode: countryCode,
      categoryCode: categoryCode,
      snapshotStartAt: snapshotStartAt,
      snapshotEndAt: snapshotEndAt,
      persist: persist,
      overwrite: overwrite,
      usePreviousSnapshot: usePreviousSnapshot,
    );
  }

  IpTradeSecretPortfolioSnapshotOrchestrationService buildService({
    _FakeDataSource? dataSource,
    _FakeSnapshotStore? store,
  }) {
    return IpTradeSecretPortfolioSnapshotOrchestrationService(
      dataSource: dataSource ?? _FakeDataSource(),
      snapshotStore: store ?? _FakeSnapshotStore(),
      aggregationService: const IpTradeSecretPortfolioAggregationService(),
    );
  }

  test('önizleme modunda snapshot kaydetmez', () async {
    final store = _FakeSnapshotStore();
    final result = await buildService(
      store: store,
    ).run(request(persist: false));

    expect(result.previewOnly, isTrue);
    expect(result.persisted, isFalse);
    expect(store.saveCallCount, 0);
  });

  test('kalıcı modda snapshot kaydeder', () async {
    final store = _FakeSnapshotStore();
    final result = await buildService(store: store).run(request());

    expect(result.persisted, isTrue);
    expect(store.saveCallCount, 1);
    expect(store.saved, isNotNull);
  });

  test('overwrite bayrağını store katmanına taşır', () async {
    final store = _FakeSnapshotStore();
    await buildService(store: store).run(request(overwrite: true));

    expect(store.overwriteValue, isTrue);
  });

  test('mükerrer snapshot varsa veri kaynağını çağırmaz', () async {
    final dataSource = _FakeDataSource();
    final store = _FakeSnapshotStore()
      ..exists = true
      ..existing = _summary(id: 'tenant_1_brand_brand_1_2026-07-05');

    final result = await buildService(
      dataSource: dataSource,
      store: store,
    ).run(request());

    expect(result.duplicateFound, isTrue);
    expect(result.persisted, isFalse);
    expect(dataSource.callCount, 0);
  });

  test('mükerrer işareti var fakat kayıt okunamazsa hata verir', () {
    final store = _FakeSnapshotStore()..exists = true;

    expect(
      () => buildService(store: store).run(request()),
      throwsA(isA<StateError>()),
    );
  });

  test('tenant ve marka filtrelerini veri kaynağına aktarır', () async {
    final dataSource = _FakeDataSource();

    await buildService(dataSource: dataSource).run(request(persist: false));

    expect(dataSource.lastTenantId, 'tenant-1');
    expect(dataSource.lastBrandId, 'brand-1');
  });

  test('önceki snapshot eğilim hesabında kullanılır', () async {
    final store = _FakeSnapshotStore()
      ..previous = _summary(averageRiskScore: 80);

    final result = await buildService(
      store: store,
    ).run(request(persist: false));

    expect(result.summary.trend, IpTradeSecretPortfolioTrend.improving);
  });

  test('önceki snapshot kullanımı kapatılabilir', () async {
    final store = _FakeSnapshotStore()
      ..previous = _summary(averageRiskScore: 80);

    final result = await buildService(
      store: store,
    ).run(request(persist: false, usePreviousSnapshot: false));

    expect(result.summary.trend, IpTradeSecretPortfolioTrend.unknown);
  });

  test('kaynak kayıt sayıları sonuçta taşınır', () async {
    final result = await buildService().run(request(persist: false));

    expect(result.sourceRecordCounts['tradeSecrets'], 0);
    expect(result.sourceRecordCounts['components'], 0);
    expect(result.totalSourceRecordCount, 0);
  });

  test('veri kaynağı hatası snapshot kaydı oluşturmaz', () async {
    final store = _FakeSnapshotStore();
    final dataSource = _FakeDataSource(
      error: StateError('veri kaynağı hatası'),
    );

    expect(
      () => buildService(dataSource: dataSource, store: store).run(request()),
      throwsA(isA<StateError>()),
    );

    expect(store.saveCallCount, 0);
  });

  test('boş tenant kimliği reddedilir', () {
    final invalid = IpTradeSecretPortfolioSnapshotRequest(
      tenantId: ' ',
      scope: IpTradeSecretPortfolioScope.tenant,
      scopeId: 'tenant-1',
      generatedBy: 'system-1',
      generatedAt: DateTime.utc(2026, 7, 5),
    );

    expect(() => buildService().run(invalid), throwsA(isA<ArgumentError>()));
  });

  test('marka kapsamında brandId zorunludur', () {
    expect(
      () => buildService().run(request(brandId: null)),
      throwsA(isA<StateError>()),
    );
  });

  test('iş birimi kapsamında businessUnitId zorunludur', () {
    expect(
      () => buildService().run(
        request(scope: IpTradeSecretPortfolioScope.businessUnit, brandId: null),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('ülke kapsamında iki harfli countryCode zorunludur', () {
    expect(
      () => buildService().run(
        request(
          scope: IpTradeSecretPortfolioScope.country,
          brandId: null,
          countryCode: 'TUR',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('snapshot tarih sırası doğrulanır', () {
    expect(
      () => buildService().run(
        request(
          snapshotStartAt: DateTime.utc(2026, 7, 10),
          snapshotEndAt: DateTime.utc(2026, 7, 5),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('üretilen özet açık ticari sır içeriği taşımaz', () async {
    final result = await buildService().run(request(persist: false));

    expect(result.summary.storesPlaintextSecretContent, isFalse);
    expect(result.summary.metadata.containsKey('secretContent'), isFalse);
  });
}
