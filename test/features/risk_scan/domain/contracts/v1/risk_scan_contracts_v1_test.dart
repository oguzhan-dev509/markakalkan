import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/domain/contracts/v1/risk_scan_contracts_v1.dart';

const _requestId = '123e4567-e89b-42d3-a456-426614174501';
const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _hashC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Map<String, dynamic> _targetJson() => {
  'contractVersion': riskScanTargetContractVersionV1,
  'brandNameNormalized': 'Bosch',
  'officialWebsiteCanonicalUrl': 'https://www.bosch.com/',
  'officialHost': 'www.bosch.com',
  'targetFingerprintSha256': _hashA,
};

Map<String, dynamic> _anonymousRunJson() => {
  'contractVersion': riskScanRunContractVersionV1,
  'scanRunId': 'scan-run-1',
  'scanMode': 'quick',
  'accessTier': 'public_lite',
  'identityMode': 'anonymous',
  'target': _targetJson(),
  'status': 'created',
  'coverageStatus': 'insufficient',
  'requestId': _requestId,
  'requestFingerprintSha256': _hashB,
  'deduplicationFingerprintSha256': _hashC,
  'createdAt': '2026-07-29T10:00:00.000Z',
  'updatedAt': '2026-07-29T10:00:00.000Z',
  'expiresAt': '2026-07-30T10:00:00.000Z',
};

Map<String, dynamic> _registeredRunJson() => {
  ..._anonymousRunJson(),
  'scanRunId': 'scan-run-2',
  'accessTier': 'registered',
  'identityMode': 'resolved',
  'tenantId': 'tenant-1',
  'canonicalBrandId': 'brand-1',
  'createdByUid': 'user-1',
};

Map<String, dynamic> _channelJson() => {
  'contractVersion': riskScanChannelContractVersionV1,
  'scanRunId': 'scan-run-1',
  'channelCode': 'similar_domains',
  'status': 'completed_with_limits',
  'coverageStatus': 'limited',
  'attemptCount': 2,
  'observationCount': 5,
  'findingCount': 2,
  'limitReasonCodes': ['source_rate_limited'],
  'startedAt': '2026-07-29T10:01:00.000Z',
  'completedAt': '2026-07-29T10:05:00.000Z',
  'updatedAt': '2026-07-29T10:05:00.000Z',
};

Map<String, dynamic> _jsonRoundTrip(Map<String, Object?> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  test('anonymous Public Lite run round-trips', () {
    final model = RiskScanRunContractV1.fromJson(_anonymousRunJson());
    final restored = RiskScanRunContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.contractVersion, riskScanRunContractVersionV1);
    expect(restored.accessTier, RiskScanAccessTier.publicLite);
    expect(restored.identityMode, RiskScanIdentityMode.anonymous);
    expect(restored.tenantId, isNull);
    expect(restored.target.officialHost, 'www.bosch.com');
  });

  test('registered resolved run round-trips', () {
    final restored = RiskScanRunContractV1.fromJson(_registeredRunJson());
    expect(restored.accessTier, RiskScanAccessTier.registered);
    expect(restored.identityMode, RiskScanIdentityMode.resolved);
    expect(restored.tenantId, 'tenant-1');
    expect(restored.canonicalBrandId, 'brand-1');
    expect(restored.createdByUid, 'user-1');
  });

  test('request UUID is normalized to lowercase', () {
    final json = _anonymousRunJson();
    json['requestId'] = _requestId.toUpperCase();
    expect(RiskScanRunContractV1.fromJson(json).requestId, _requestId);
  });

  test('Public Lite cannot use resolved identity', () {
    final json = _anonymousRunJson();
    json['identityMode'] = 'resolved';
    json['tenantId'] = 'tenant-1';
    json['canonicalBrandId'] = 'brand-1';
    json['createdByUid'] = 'user-1';
    expect(() => RiskScanRunContractV1.fromJson(json), throwsFormatException);
  });

  test('registered run cannot use anonymous identity', () {
    final json = _anonymousRunJson();
    json['accessTier'] = 'registered';
    expect(() => RiskScanRunContractV1.fromJson(json), throwsFormatException);
  });

  test('anonymous run rejects resolved identity fields', () {
    final json = _anonymousRunJson();
    json['tenantId'] = 'tenant-1';
    expect(() => RiskScanRunContractV1.fromJson(json), throwsFormatException);
  });

  test('resolved run requires all identity fields', () {
    final json = _registeredRunJson()..remove('canonicalBrandId');
    expect(() => RiskScanRunContractV1.fromJson(json), throwsFormatException);
  });

  test('SHA-256 fields reject uppercase and malformed values', () {
    final uppercase = _anonymousRunJson();
    uppercase['requestFingerprintSha256'] = _hashB.toUpperCase();
    final malformed = _anonymousRunJson();
    malformed['deduplicationFingerprintSha256'] = 'abc';
    expect(
      () => RiskScanRunContractV1.fromJson(uppercase),
      throwsFormatException,
    );
    expect(
      () => RiskScanRunContractV1.fromJson(malformed),
      throwsFormatException,
    );
  });

  test('run temporal invariants reject invalid dates', () {
    final staleUpdate = _anonymousRunJson();
    staleUpdate['updatedAt'] = '2026-07-29T09:59:59.000Z';
    final expiredAtCreation = _anonymousRunJson();
    expiredAtCreation['expiresAt'] = '2026-07-29T10:00:00.000Z';
    expect(
      () => RiskScanRunContractV1.fromJson(staleUpdate),
      throwsFormatException,
    );
    expect(
      () => RiskScanRunContractV1.fromJson(expiredAtCreation),
      throwsFormatException,
    );
  });

  test('unknown run enum values fail closed', () {
    final unknownStatus = _anonymousRunJson();
    unknownStatus['status'] = 'mystery';
    final unknownTier = _anonymousRunJson();
    unknownTier['accessTier'] = 'paid';
    expect(
      () => RiskScanRunContractV1.fromJson(unknownStatus),
      throwsFormatException,
    );
    expect(
      () => RiskScanRunContractV1.fromJson(unknownTier),
      throwsFormatException,
    );
  });

  test('target round-trips and binds canonical host', () {
    final model = RiskScanTargetContractV1.fromJson(_targetJson());
    final restored = RiskScanTargetContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.contractVersion, riskScanTargetContractVersionV1);
    expect(restored.officialHost, 'www.bosch.com');
  });

  test('target rejects host mismatch and unsafe URL shape', () {
    final mismatch = _targetJson();
    mismatch['officialHost'] = 'example.com';
    final unsafe = _targetJson();
    unsafe['officialWebsiteCanonicalUrl'] = 'ftp://www.bosch.com/file';
    expect(
      () => RiskScanTargetContractV1.fromJson(mismatch),
      throwsFormatException,
    );
    expect(
      () => RiskScanTargetContractV1.fromJson(unsafe),
      throwsFormatException,
    );
  });

  test('channel round-trips exact wire values', () {
    final model = RiskScanChannelContractV1.fromJson(_channelJson());
    final restored = RiskScanChannelContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.contractVersion, riskScanChannelContractVersionV1);
    expect(restored.channelCode, RiskScanChannelCode.similarDomains);
    expect(restored.status, RiskScanChannelStatus.completedWithLimits);
    expect(restored.coverageStatus, RiskScanCoverageStatus.limited);
    expect(restored.limitReasonCodes, ['source_rate_limited']);
  });

  test('channel list is an immutable snapshot', () {
    final source = <String>['source_rate_limited'];
    final channel = RiskScanChannelContractV1(
      scanRunId: 'scan-run-1',
      channelCode: RiskScanChannelCode.openWeb,
      status: RiskScanChannelStatus.queued,
      coverageStatus: RiskScanCoverageStatus.insufficient,
      attemptCount: 0,
      observationCount: 0,
      findingCount: 0,
      updatedAt: DateTime.parse('2026-07-29T10:00:00.000Z'),
      limitReasonCodes: source,
    );
    source.add('later_change');
    expect(channel.limitReasonCodes, ['source_rate_limited']);
    expect(
      () => channel.limitReasonCodes.add('forbidden'),
      throwsUnsupportedError,
    );
  });

  test('channel counters cannot be negative', () {
    final json = _channelJson();
    json['findingCount'] = -1;
    expect(
      () => RiskScanChannelContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('channel counters must be integers', () {
    final json = _channelJson();
    json['attemptCount'] = 1.5;
    expect(
      () => RiskScanChannelContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('channel temporal invariants reject invalid dates', () {
    final completedEarly = _channelJson();
    completedEarly['completedAt'] = '2026-07-29T10:00:00.000Z';
    final updatedEarly = _channelJson();
    updatedEarly['updatedAt'] = '2026-07-29T10:00:00.000Z';
    expect(
      () => RiskScanChannelContractV1.fromJson(completedEarly),
      throwsFormatException,
    );
    expect(
      () => RiskScanChannelContractV1.fromJson(updatedEarly),
      throwsFormatException,
    );
  });

  test('unknown channel enum values fail closed', () {
    final unknownCode = _channelJson();
    unknownCode['channelCode'] = 'social_media';
    final unknownStatus = _channelJson();
    unknownStatus['status'] = 'running';
    expect(
      () => RiskScanChannelContractV1.fromJson(unknownCode),
      throwsFormatException,
    );
    expect(
      () => RiskScanChannelContractV1.fromJson(unknownStatus),
      throwsFormatException,
    );
  });

  test('unsupported contract versions are rejected', () {
    final target = _targetJson();
    target['contractVersion'] = 'risk-scan-target-v2';
    final run = _anonymousRunJson();
    run['contractVersion'] = 'risk-scan-run-v2';
    final channel = _channelJson();
    channel['contractVersion'] = 'risk-scan-channel-v2';
    expect(
      () => RiskScanTargetContractV1.fromJson(target),
      throwsFormatException,
    );
    expect(() => RiskScanRunContractV1.fromJson(run), throwsFormatException);
    expect(
      () => RiskScanChannelContractV1.fromJson(channel),
      throwsFormatException,
    );
  });
}
