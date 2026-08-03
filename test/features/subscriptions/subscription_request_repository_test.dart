import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/subscriptions/data/subscription_request_repository.dart';
import 'package:markakalkan/features/subscriptions/domain/subscription_request_models.dart';

void main() {
  test('callable repository sends exact protected request contract', () async {
    var appCheckCalls = 0;
    String? callableName;
    Map<String, Object?>? payload;

    final repository = CallableSubscriptionServiceRequestRepository(
      ensureAppCheckReady: () async {
        appCheckCalls += 1;
      },
      callable: (name, request) async {
        callableName = name;
        payload = request;
        return <String, Object?>{
          'contractVersion': subscriptionRequestCallableContractVersionV1,
          'resultType': 'subscription_service_request',
          'resultId': 'subreq_123',
          'status': 'requested',
          'idempotentReplay': false,
        };
      },
    );

    final result = await repository.create(
      CreateSubscriptionServiceRequestCommand(
        requestId: '11111111-1111-4111-8111-111111111111',
        source: BroadDigitalScanSubscriptionSource(
          scanRunId: 'scan-001',
          reportId: 'report-001',
          brandName: 'MarkaKalkan',
          officialWebsiteUrl: 'https://markakalkan.com',
        ),
      ),
    );

    expect(appCheckCalls, 1);
    expect(
      callableName,
      CallableSubscriptionServiceRequestRepository.callableName,
    );
    expect(
      payload?['contractVersion'],
      createSubscriptionRequestCommandVersionV1,
    );
    expect(payload?['productCode'], broadDigitalScanSubscriptionProductCode);
    expect(
      (payload?['source'] as Map<String, Object?>)['sourceType'],
      publicLiteRiskScanSubscriptionSourceType,
    );
    expect(result.resultId, 'subreq_123');
    expect(result.status, 'requested');
    expect(result.idempotentReplay, isFalse);
  });

  test('result rejects unsupported callable contract', () {
    expect(
      () => SubscriptionServiceRequestResult.fromValue(<String, Object?>{
        'contractVersion': 'unsupported',
        'resultType': 'subscription_service_request',
        'resultId': 'subreq_123',
        'status': 'requested',
        'idempotentReplay': false,
      }),
      throwsFormatException,
    );
  });

  test('source rejects non-http official website', () {
    expect(
      () => BroadDigitalScanSubscriptionSource(
        scanRunId: 'scan-001',
        brandName: 'MarkaKalkan',
        officialWebsiteUrl: 'ftp://markakalkan.com',
      ),
      throwsFormatException,
    );
  });
}
