import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/subscriptions/data/subscription_request_repository.dart';
import 'package:markakalkan/features/subscriptions/domain/subscription_request_models.dart';
import 'package:markakalkan/features/subscriptions/presentation/broad_digital_scan_subscription_page.dart';

void main() {
  testWidgets('page presents one clear subscription request action', (
    tester,
  ) async {
    final repository = _FakeSubscriptionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: BroadDigitalScanSubscriptionPage(
          source: _source(),
          repository: repository,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );

    expect(find.text('Abonelik ve Hizmetler'), findsOneWidget);
    expect(find.text('Geniş Kapsamlı Tarama Aboneliği'), findsOneWidget);
    expect(
      find.textContaining('abonelik talebinizi oluşturun'),
      findsOneWidget,
    );
    expect(find.text('MarkaKalkan'), findsOneWidget);
    expect(find.text('https://markakalkan.com'), findsOneWidget);
    expect(
      find.byKey(broadDigitalScanSubscriptionSubmitButtonKey),
      findsOneWidget,
    );
    expect(find.textContaining('₺'), findsNothing);
    expect(find.textContaining('Ödeme'), findsNothing);

    await tester.tap(find.byKey(broadDigitalScanSubscriptionSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.lastCommand?.source.scanRunId, 'scan-001');
    expect(find.byKey(broadDigitalScanSubscriptionSuccessKey), findsOneWidget);
    expect(find.text('Talebiniz alındı'), findsOneWidget);
    expect(find.text('Talep no: subreq_123'), findsOneWidget);
  });

  testWidgets('page displays a safe repository failure', (tester) async {
    final repository = _FakeSubscriptionRepository(
      failure: const SubscriptionServiceRequestFailure(
        code: 'unavailable',
        message: 'Abonelik hizmeti geçici olarak kullanılamıyor.',
        retryable: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BroadDigitalScanSubscriptionPage(
          source: _source(),
          repository: repository,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );

    await tester.tap(find.byKey(broadDigitalScanSubscriptionSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(broadDigitalScanSubscriptionErrorKey), findsOneWidget);
    expect(
      find.text('Abonelik hizmeti geçici olarak kullanılamıyor.'),
      findsOneWidget,
    );
  });
}

BroadDigitalScanSubscriptionSource _source() =>
    BroadDigitalScanSubscriptionSource(
      scanRunId: 'scan-001',
      reportId: 'report-001',
      brandName: 'MarkaKalkan',
      officialWebsiteUrl: 'https://markakalkan.com',
    );

final class _FakeSubscriptionRepository
    implements SubscriptionServiceRequestRepository {
  _FakeSubscriptionRepository({this.failure});

  final SubscriptionServiceRequestFailure? failure;
  int calls = 0;
  CreateSubscriptionServiceRequestCommand? lastCommand;

  @override
  Future<SubscriptionServiceRequestResult> create(
    CreateSubscriptionServiceRequestCommand command,
  ) async {
    calls += 1;
    lastCommand = command;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return const SubscriptionServiceRequestResult(
      resultId: 'subreq_123',
      status: 'requested',
      idempotentReplay: false,
    );
  }
}
