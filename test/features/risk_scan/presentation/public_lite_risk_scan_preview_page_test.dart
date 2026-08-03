import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_controller.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_preview_page.dart';

void main() {
  testWidgets('public page explains purpose, privacy, and starts on mobile', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final controller = await _pumpPreview(
      tester,
      repository: repository,
      size: const Size(390, 844),
    );

    expect(find.text('Hızlı Risk Taraması'), findsOneWidget);
    expect(find.textContaining('Önizleme'), findsNothing);
    expect(find.textContaining('Firebase Rules UpdateRelease'), findsNothing);
    expect(find.text('Bu bölüm ne işe yarar?'), findsOneWidget);
    expect(find.text('Ne zaman kullanmalısınız?'), findsOneWidget);
    expect(find.text('Bu işlem için ne gerekir?'), findsOneWidget);
    expect(find.text('İşlem sonunda ne elde edersiniz?'), findsOneWidget);
    expect(
      find.textContaining('kapsamı sınırlı bir özet rapor'),
      findsOneWidget,
    );
    expect(find.byKey(publicLiteRiskScanTrustNoticeKey), findsOneWidget);
    expect(find.text('Veri kullanımı ve gizlilik'), findsOneWidget);
    expect(
      find.textContaining('kişisel profil bilgisi istemez'),
      findsOneWidget,
    );
    expect(
      find.textContaining('kendiliğinden kamuya yayımlamaz'),
      findsOneWidget,
    );

    await _submitValidScan(tester);

    expect(repository.startCalls, 1);
    expect(repository.lastStartRequest?.brandName, 'MarkaKalkan');
    expect(find.text('Tarama oluşturuldu'), findsOneWidget);
    expect(find.textContaining('Tarama no:'), findsOneWidget);
    expect(
      find.textContaining('bu oturum boyunca güvenli biçimde'),
      findsOneWidget,
    );
    expect(find.text(_accessKey), findsNothing);
    expect(find.byKey(publicLiteRiskScanTimelineKey), findsOneWidget);
    expect(find.text('Tarama ilerlemesi'), findsOneWidget);

    final semantics = tester.getSemantics(
      find.byKey(publicLiteRiskScanStatusRegionKey),
    );
    expect(semantics.label, contains('Tarama durumu'));

    await _disposePreview(tester, controller);
  });

  testWidgets('form validation blocks empty and invalid input', (tester) async {
    final repository = _FakeRepository();
    final controller = await _pumpPreview(tester, repository: repository);

    await tester.ensureVisible(find.byKey(publicLiteRiskScanStartButtonKey));
    await tester.tap(find.byKey(publicLiteRiskScanStartButtonKey));
    await tester.pump();

    expect(find.text('Marka adı gereklidir.'), findsOneWidget);
    expect(find.text('Geçerli bir HTTP(S) adresi girin.'), findsOneWidget);
    expect(repository.startCalls, 0);

    await tester.enterText(
      find.byKey(publicLiteRiskScanBrandFieldKey),
      'MarkaKalkan',
    );
    await tester.enterText(
      find.byKey(publicLiteRiskScanWebsiteFieldKey),
      'ftp://markakalkan.com',
    );
    await tester.tap(find.byKey(publicLiteRiskScanStartButtonKey));
    await tester.pump();

    expect(find.text('Geçerli bir HTTP(S) adresi girin.'), findsOneWidget);
    expect(repository.startCalls, 0);

    await _disposePreview(tester, controller);
  });

  testWidgets('desktop layout exposes lifecycle controls', (tester) async {
    final controller = await _pumpPreview(
      tester,
      repository: _FakeRepository(),
      size: const Size(1440, 1000),
    );

    await _submitValidScan(tester);

    expect(find.text('Otomatik izleme etkin'), findsOneWidget);
    expect(find.textContaining('Erişim süresi:'), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanRefreshButtonKey), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanReportButtonKey), findsOneWidget);
    expect(find.text('Hazırlık'), findsOneWidget);
    expect(find.text('Kaynak tarama'), findsOneWidget);
    expect(find.text('Risk değerlendirme'), findsOneWidget);
    expect(find.text('Raporlama'), findsOneWidget);
    expect(find.text('Sonuç'), findsOneWidget);

    final reportButton = tester.widget<FilledButton>(
      find.byKey(publicLiteRiskScanReportButtonKey),
    );
    expect(reportButton.onPressed, isNull);

    await _disposePreview(tester, controller);
  });

  testWidgets('final report renders complete product metadata and focus', (
    tester,
  ) async {
    final controller = await _pumpPreview(
      tester,
      repository: _FakeRepository(startProjection: _finalProjection()),
      size: const Size(1440, 1200),
    );

    await _submitValidScan(tester);

    expect(find.text('Hızlı risk taraması raporu'), findsOneWidget);
    expect(
      find.text('Rapor üretim zamanı: 30.07.2026 12:02 UTC'),
      findsOneWidget,
    );
    expect(
      find.text('Önerilen sonraki adım: Öne çıkan bulguları inceleyin'),
      findsOneWidget,
    );
    expect(find.text('Rapor kanal dağılımı'), findsOneWidget);
    expect(find.textContaining('Pazaryeri erişimi sınırlı'), findsWidgets);
    expect(
      find.textContaining('Yeterli kamuya açık veri bulunamadı'),
      findsWidgets,
    );
    expect(find.text('Genel risk: Yüksek'), findsOneWidget);
    expect(find.text('Güven: Orta'), findsOneWidget);

    final focus = tester.widget<Focus>(
      find.byKey(publicLiteRiskScanResultFocusKey),
    );
    expect(focus.focusNode?.hasFocus, isTrue);

    await _disposePreview(tester, controller);
  });

  testWidgets('terminal status is visible and offers a new scan', (
    tester,
  ) async {
    final controller = await _pumpPreview(
      tester,
      repository: _FakeRepository(startProjection: _terminalProjection()),
    );

    await _submitValidScan(tester);

    expect(find.text('Durum: Tamamlanamayan hata'), findsOneWidget);
    expect(find.text('Sonlandırıldı'), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanRestartButtonKey), findsOneWidget);

    final focus = tester.widget<Focus>(
      find.byKey(publicLiteRiskScanResultFocusKey),
    );
    expect(focus.focusNode?.hasFocus, isTrue);

    await _disposePreview(tester, controller);
  });

  testWidgets('expired status is visible and offers safe restart', (
    tester,
  ) async {
    final controller = await _pumpPreview(
      tester,
      repository: _FakeRepository(startProjection: _expiredProjection()),
    );

    await _submitValidScan(tester);

    expect(find.text('Durum: Süresi doldu'), findsOneWidget);
    expect(find.textContaining('Erişim süresi: Süre doldu'), findsOneWidget);
    expect(find.text('Tarama erişim süresi doldu.'), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanRetryButtonKey), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanRestartButtonKey), findsOneWidget);

    final focus = tester.widget<Focus>(
      find.byKey(publicLiteRiskScanResultFocusKey),
    );
    expect(focus.focusNode?.hasFocus, isTrue);

    await _disposePreview(tester, controller);
  });

  testWidgets('application lifecycle pauses and resumes the controller', (
    tester,
  ) async {
    final controller = await _pumpPreview(
      tester,
      repository: _FakeRepository(),
    );

    await _submitValidScan(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(controller.state, PublicLiteRiskScanOperationState.paused);
    expect(controller.isForeground, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(controller.state, PublicLiteRiskScanOperationState.paused);
    expect(controller.isForeground, isFalse);
    expect(find.text('Otomatik izleme duraklatıldı'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(controller.isForeground, isTrue);

    await _disposePreview(tester, controller);
  });
}

final DateTime _now = DateTime.utc(2026, 7, 30, 12);

Future<PublicLiteRiskScanController> _pumpPreview(
  WidgetTester tester, {
  required PublicLiteRiskScanRepository repository,
  Size? size,
}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  final controller = PublicLiteRiskScanController(
    repository: repository,
    schedule: _noOpSchedule,
    now: () => _now,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: PublicLiteRiskScanPreviewPage(
        controller: controller,
        requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        clientNonceFactory: () => 'nonce-1',
      ),
    ),
  );

  return controller;
}

Future<void> _submitValidScan(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(publicLiteRiskScanBrandFieldKey),
    'MarkaKalkan',
  );
  await tester.enterText(
    find.byKey(publicLiteRiskScanWebsiteFieldKey),
    'https://markakalkan.com',
  );
  await tester.ensureVisible(find.byKey(publicLiteRiskScanStartButtonKey));
  await tester.tap(find.byKey(publicLiteRiskScanStartButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _disposePreview(
  WidgetTester tester,
  PublicLiteRiskScanController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

PublicLiteRiskScanCancel _noOpSchedule(Duration delay, VoidCallback callback) =>
    () {};

final class _FakeRepository implements PublicLiteRiskScanRepository {
  _FakeRepository({
    PublicLiteRiskScanProjection? startProjection,
    PublicLiteRiskScanProjection? statusProjection,
    PublicLiteRiskScanProjection? reportProjection,
  }) : _startProjection = startProjection ?? _projection(),
       _statusProjection = statusProjection ?? _projection(status: 'assessing'),
       _reportProjection = reportProjection ?? _finalProjection();

  final PublicLiteRiskScanProjection _startProjection;
  final PublicLiteRiskScanProjection _statusProjection;
  final PublicLiteRiskScanProjection _reportProjection;
  int startCalls = 0;
  PublicLiteRiskScanStartRequest? lastStartRequest;

  @override
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  ) async {
    startCalls += 1;
    lastStartRequest = request;
    return PublicLiteRiskScanStartResult(
      outcome: 'created',
      accessKey: _accessKey,
      projection: _startProjection,
    );
  }

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) async =>
      _statusProjection;

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) async =>
      _reportProjection;
}

const String _accessKey =
    'hrt1.'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.'
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

PublicLiteRiskScanProjection _projection({
  String status = 'created',
  String coverageStatus = 'insufficient',
  DateTime? expiresAt,
  List<Map<String, dynamic>>? channels,
  Map<String, dynamic>? report,
}) => PublicLiteRiskScanProjection.fromMap({
  'contractVersion': publicLiteRiskScanProjectionContractVersionV1,
  'scanRunId': 'a' * 64,
  'scanMode': 'quick',
  'accessTier': 'publicLite',
  'identityMode': 'anonymous',
  'status': status,
  'coverageStatus': coverageStatus,
  'createdAt': _now.toIso8601String(),
  'updatedAt': _now.toIso8601String(),
  'expiresAt': (expiresAt ?? _now.add(const Duration(hours: 24)))
      .toIso8601String(),
  'target': {
    'brandNameNormalized': 'markakalkan',
    'officialHost': 'markakalkan.com',
  },
  'channels':
      channels ??
      [
        _channel('similarDomains'),
        _channel('openWeb'),
        _channel('marketplaceLimited'),
      ],
  'report': report,
});

PublicLiteRiskScanProjection _finalProjection() => _projection(
  status: 'completedWithLimits',
  coverageStatus: 'limited',
  channels: [
    _channel(
      'similarDomains',
      status: 'completed',
      coverageStatus: 'complete',
      observationCount: 4,
      findingCount: 1,
    ),
    _channel(
      'openWeb',
      status: 'completedWithLimits',
      coverageStatus: 'limited',
      observationCount: 7,
      findingCount: 2,
      limitReasonCodes: ['insufficient_public_data'],
    ),
    _channel(
      'marketplaceLimited',
      status: 'completedWithLimits',
      coverageStatus: 'limited',
      observationCount: 3,
      findingCount: 1,
      limitReasonCodes: ['marketplace_limited'],
    ),
  ],
  report: {
    'reportId': 'report-1',
    'reportVersion': 1,
    'generatedAt': _now.add(const Duration(minutes: 2)).toIso8601String(),
    'status': 'completedWithLimits',
    'coverageStatus': 'limited',
    'overallRiskLevel': 'high',
    'overallConfidenceLevel': 'medium',
    'recommendedAction': 'review_top_findings',
    'summary': 'Dört öncelikli bulgu tespit edildi.',
    'findingCount': 4,
    'observationCount': 14,
    'topFindingSnapshots': [
      {
        'findingId': 'finding-1',
        'findingType': 'similar_domain',
        'channelCode': 'similarDomains',
        'riskLevel': 'high',
        'confidenceLevel': 'high',
        'impactLevel': 'high',
        'interventionDifficulty': 'medium',
        'reviewStatus': 'pending',
        'recommendationCode': 'review_top_findings',
        'title': 'Benzer alan adı',
        'summary': 'Marka adına yakın bir alan adı bulundu.',
      },
    ],
    'channelDistribution': [
      _channel(
        'similarDomains',
        status: 'completed',
        coverageStatus: 'complete',
        observationCount: 4,
        findingCount: 1,
      ),
      _channel(
        'openWeb',
        status: 'completedWithLimits',
        coverageStatus: 'limited',
        observationCount: 7,
        findingCount: 2,
        limitReasonCodes: ['insufficient_public_data'],
      ),
      _channel(
        'marketplaceLimited',
        status: 'completedWithLimits',
        coverageStatus: 'limited',
        observationCount: 3,
        findingCount: 1,
        limitReasonCodes: ['marketplace_limited'],
      ),
    ],
  },
);

PublicLiteRiskScanProjection _terminalProjection() =>
    _projection(status: 'failedTerminal', coverageStatus: 'insufficient');

PublicLiteRiskScanProjection _expiredProjection() => _projection(
  status: 'expired',
  coverageStatus: 'insufficient',
  expiresAt: _now.subtract(const Duration(seconds: 1)),
);

Map<String, dynamic> _channel(
  String code, {
  String status = 'queued',
  String coverageStatus = 'insufficient',
  int observationCount = 0,
  int findingCount = 0,
  List<String> limitReasonCodes = const [],
}) => {
  'channelCode': code,
  'status': status,
  'coverageStatus': coverageStatus,
  'observationCount': observationCount,
  'findingCount': findingCount,
  'limitReasonCodes': limitReasonCodes,
  'startedAt': null,
  'completedAt': null,
};
