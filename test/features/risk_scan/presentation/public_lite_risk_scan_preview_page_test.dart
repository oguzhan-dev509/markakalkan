import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_controller.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_preview_page.dart';

void main() {
  testWidgets('preview explains purpose and starts a scan on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakeRepository();
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

    expect(find.text('Bu bölüm ne işe yarar?'), findsOneWidget);
    expect(find.text('Ne zaman kullanmalısınız?'), findsOneWidget);
    expect(find.text('Bu işlem için ne gerekir?'), findsOneWidget);
    expect(find.text('İşlem sonunda ne elde edersiniz?'), findsOneWidget);
    expect(find.textContaining('İzole frontend önizlemesi'), findsOneWidget);

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

    expect(repository.startCalls, 1);
    expect(repository.lastStartRequest?.brandName, 'MarkaKalkan');
    expect(find.text('Tarama oluşturuldu'), findsOneWidget);
    expect(find.textContaining('Tarama no:'), findsOneWidget);
    expect(find.textContaining('controller belleğinde'), findsOneWidget);
    expect(find.text(_accessKey), findsNothing);

    final semantics = tester.getSemantics(
      find.byKey(publicLiteRiskScanStatusRegionKey),
    );
    expect(semantics.label, contains('Tarama durumu'));

    controller.dispose();
  });

  testWidgets('desktop layout exposes lifecycle controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PublicLiteRiskScanController(
      repository: _FakeRepository(),
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

    await tester.enterText(
      find.byKey(publicLiteRiskScanBrandFieldKey),
      'MarkaKalkan',
    );
    await tester.enterText(
      find.byKey(publicLiteRiskScanWebsiteFieldKey),
      'https://markakalkan.com',
    );
    await tester.tap(find.byKey(publicLiteRiskScanStartButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Otomatik izleme etkin'), findsOneWidget);
    expect(find.textContaining('Erişim süresi:'), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanRefreshButtonKey), findsOneWidget);
    expect(find.byKey(publicLiteRiskScanReportButtonKey), findsOneWidget);

    final reportButton = tester.widget<FilledButton>(
      find.byKey(publicLiteRiskScanReportButtonKey),
    );
    expect(reportButton.onPressed, isNull);

    controller.dispose();
  });

  testWidgets('application lifecycle pauses and resumes the controller', (
    tester,
  ) async {
    final controller = PublicLiteRiskScanController(
      repository: _FakeRepository(),
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

    controller.dispose();
  });
}

final DateTime _now = DateTime.utc(2026, 7, 30, 12);

PublicLiteRiskScanCancel _noOpSchedule(Duration delay, VoidCallback callback) =>
    () {};

final class _FakeRepository implements PublicLiteRiskScanRepository {
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
      projection: _projection(),
    );
  }

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) async =>
      _projection(status: 'assessing');

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) async =>
      _projection(status: 'completed', report: _report());
}

const String _accessKey =
    'hrt1.'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.'
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

PublicLiteRiskScanProjection _projection({
  String status = 'created',
  PublicLiteRiskScanReport? report,
}) => PublicLiteRiskScanProjection.fromMap({
  'contractVersion': publicLiteRiskScanProjectionContractVersionV1,
  'scanRunId': 'a' * 64,
  'scanMode': 'quick',
  'accessTier': 'publicLite',
  'identityMode': 'anonymous',
  'status': status,
  'coverageStatus': 'insufficient',
  'createdAt': _now.toIso8601String(),
  'updatedAt': _now.toIso8601String(),
  'expiresAt': _now.add(const Duration(hours: 24)).toIso8601String(),
  'target': {
    'brandNameNormalized': 'markakalkan',
    'officialHost': 'markakalkan.com',
  },
  'channels': [
    _channel('similarDomains'),
    _channel('openWeb'),
    _channel('marketplaceLimited'),
  ],
  'report': report == null
      ? null
      : {
          'reportId': report.reportId,
          'reportVersion': report.reportVersion,
          'generatedAt': report.generatedAt?.toIso8601String(),
          'status': report.status,
          'coverageStatus': report.coverageStatus,
          'overallRiskLevel': report.overallRiskLevel,
          'overallConfidenceLevel': report.overallConfidenceLevel,
          'recommendedAction': report.recommendedAction,
          'summary': report.summary,
          'findingCount': report.findingCount,
          'observationCount': report.observationCount,
          'topFindingSnapshots': <Object?>[],
          'channelDistribution': <Object?>[],
        },
});

PublicLiteRiskScanReport _report() => PublicLiteRiskScanReport.fromMap({
  'reportId': 'report-1',
  'reportVersion': 1,
  'generatedAt': _now.add(const Duration(minutes: 2)).toIso8601String(),
  'status': 'completed',
  'coverageStatus': 'limited',
  'overallRiskLevel': 'medium',
  'overallConfidenceLevel': 'medium',
  'recommendedAction': 'review_top_findings',
  'summary': 'Rapor hazır.',
  'findingCount': 0,
  'observationCount': 3,
  'topFindingSnapshots': <Object?>[],
  'channelDistribution': <Object?>[],
});

Map<String, dynamic> _channel(String code) => {
  'channelCode': code,
  'status': 'queued',
  'coverageStatus': 'insufficient',
  'observationCount': 0,
  'findingCount': 0,
  'limitReasonCodes': <Object?>[],
  'startedAt': null,
  'completedAt': null,
};
