import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';

void main() {
  group('Public Lite models and repository', () {
    test('start request emits exact four-key contract', () {
      final request = PublicLiteRiskScanStartRequest(
        requestId: '11111111-1111-4111-8111-111111111111',
        brandName: ' MarkaKalkan ',
        officialWebsiteUrl: 'https://markakalkan.com/path',
        anonymousClientNonce: 'nonce-1',
      );

      expect(request.toMap(), {
        'requestId': '11111111-1111-4111-8111-111111111111',
        'brandName': 'MarkaKalkan',
        'officialWebsiteUrl': 'https://markakalkan.com/path',
        'anonymousClientNonce': 'nonce-1',
      });
    });

    test('start result parses exact callable and projection contracts', () {
      final result = PublicLiteRiskScanStartResult.fromMap(_startResponse());

      expect(result.outcome, 'created');
      expect(result.accessKey, startsWith('hrt1.'));
      expect(result.projection.scanRunId, 'a' * 64);
      expect(result.projection.channels, hasLength(3));
      expect(result.projection.isReportReady, isFalse);
    });

    test('malformed access key is rejected', () {
      final response = _startResponse()..['accessKey'] = 'invalid';

      expect(
        () => PublicLiteRiskScanStartResult.fromMap(response),
        throwsFormatException,
      );
    });

    test('start ensures App Check and calls exact callable', () async {
      var appCheckCalls = 0;
      String? calledName;
      Map<String, dynamic>? calledRequest;
      final repository = CallablePublicLiteRiskScanRepository(
        ensureAppCheckReady: () async {
          appCheckCalls += 1;
        },
        callable: (name, request) async {
          calledName = name;
          calledRequest = request;
          return _startResponse();
        },
      );

      final result = await repository.start(
        PublicLiteRiskScanStartRequest(
          requestId: '11111111-1111-4111-8111-111111111111',
          brandName: 'MarkaKalkan',
          officialWebsiteUrl: 'https://markakalkan.com',
          anonymousClientNonce: 'nonce-1',
        ),
      );

      expect(appCheckCalls, 1);
      expect(calledName, 'startPublicLiteRiskScan');
      expect(calledRequest?.keys, {
        'requestId',
        'brandName',
        'officialWebsiteUrl',
        'anonymousClientNonce',
      });
      expect(result.projection.status, 'created');
    });

    test('status sends accessKey as the only request field', () async {
      String? calledName;
      Map<String, dynamic>? calledRequest;
      final repository = CallablePublicLiteRiskScanRepository(
        ensureAppCheckReady: () async {},
        callable: (name, request) async {
          calledName = name;
          calledRequest = request;
          return {
            'contractVersion': publicLiteRiskScanCallableContractVersionV1,
            'projection': _projection(),
          };
        },
      );

      await repository.getStatus(_accessKey);

      expect(calledName, 'getPublicLiteRiskScanStatus');
      expect(calledRequest, {'accessKey': _accessKey});
    });

    test('report calls exact report callable', () async {
      String? calledName;
      final repository = CallablePublicLiteRiskScanRepository(
        ensureAppCheckReady: () async {},
        callable: (name, request) async {
          calledName = name;
          return {
            'contractVersion': publicLiteRiskScanCallableContractVersionV1,
            'projection': _projection(),
          };
        },
      );

      await repository.getReport(_accessKey);

      expect(calledName, 'getPublicLiteRiskScanReport');
    });

    test('invalid response becomes safe repository exception', () async {
      final repository = CallablePublicLiteRiskScanRepository(
        ensureAppCheckReady: () async {},
        callable: (_, _) async => {'unexpected': true},
      );

      await expectLater(
        repository.getStatus(_accessKey),
        throwsA(
          isA<PublicLiteRiskScanRepositoryException>().having(
            (error) => error.code,
            'code',
            'invalid-response',
          ),
        ),
      );
    });
  });
}

const String _accessKey =
    'hrt1.'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.'
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

Map<String, dynamic> _startResponse() => {
  'contractVersion': publicLiteRiskScanCallableContractVersionV1,
  'outcome': 'created',
  'accessKey': _accessKey,
  'projection': _projection(),
};

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
