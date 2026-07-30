import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_preview_page.dart';

void main() {
  testWidgets('preview explains purpose and starts a scan', (tester) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PublicLiteRiskScanPreviewPage(
          repository: repository,
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
    expect(find.textContaining('Erişim anahtarı yalnız'), findsOneWidget);
    expect(find.text(_accessKey), findsNothing);
  });

  testWidgets('report remains disabled before completion', (tester) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PublicLiteRiskScanPreviewPage(
          repository: repository,
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
    await tester.ensureVisible(find.byKey(publicLiteRiskScanReportButtonKey));

    final button = tester.widget<FilledButton>(
      find.byKey(publicLiteRiskScanReportButtonKey),
    );
    expect(button.onPressed, isNull);
  });
}

final class _FakeRepository implements PublicLiteRiskScanRepository {
  int startCalls = 0;
  PublicLiteRiskScanStartRequest? lastStartRequest;

  @override
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  ) async {
    startCalls += 1;
    lastStartRequest = request;
    return PublicLiteRiskScanStartResult.fromMap({
      'contractVersion': publicLiteRiskScanCallableContractVersionV1,
      'outcome': 'created',
      'accessKey': _accessKey,
      'projection': _projection(),
    });
  }

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) async =>
      PublicLiteRiskScanProjection.fromMap(_projection());

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) async =>
      PublicLiteRiskScanProjection.fromMap(_projection());
}

const String _accessKey =
    'hrt1.'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.'
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

Map<String, dynamic> _projection() => {
  'contractVersion': publicLiteRiskScanProjectionContractVersionV1,
  'scanRunId': 'a' * 64,
  'scanMode': 'quick',
  'accessTier': 'publicLite',
  'identityMode': 'anonymous',
  'status': 'created',
  'coverageStatus': 'insufficient',
  'createdAt': '2026-07-30T12:00:00Z',
  'updatedAt': '2026-07-30T12:00:00Z',
  'expiresAt': '2026-07-31T12:00:00Z',
  'target': {
    'brandNameNormalized': 'markakalkan',
    'officialHost': 'markakalkan.com',
  },
  'channels': [
    _channel('similarDomains'),
    _channel('openWeb'),
    _channel('marketplaceLimited'),
  ],
  'report': null,
};

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
