import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/domain/contracts/v1/risk_scan_contracts_v1.dart';

const _requestId = '123e4567-e89b-42d3-a456-426614174602';
const _digestA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _digestB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, dynamic> _findingSnapshotJson({String findingId = 'finding-1'}) => {
  'findingId': findingId,
  'channelCode': 'similar_domains',
  'findingType': 'similar_domain',
  'title': 'Benzer alan adı',
  'summary': 'Marka adına benzeyen bir alan adı sinyali bulundu.',
  'riskLevel': 'high',
  'confidenceLevel': 'medium',
  'impactLevel': 'high',
  'interventionDifficulty': 'moderate',
  'reviewStatus': 'review_required',
  'recommendationCode': 'review_finding',
};

Map<String, dynamic> _channelSnapshotJson(
  String channelCode, {
  String status = 'completed',
  String coverageStatus = 'complete',
  int observationCount = 2,
  int findingCount = 1,
  String? highestRiskLevel = 'high',
}) => {
  'channelCode': channelCode,
  'status': status,
  'coverageStatus': coverageStatus,
  'observationCount': observationCount,
  'findingCount': findingCount,
  'highestRiskLevel': ?highestRiskLevel,
};

List<Map<String, dynamic>> _channelDistributionJson() => [
  _channelSnapshotJson('similar_domains'),
  _channelSnapshotJson(
    'open_web',
    status: 'completed_with_limits',
    coverageStatus: 'limited',
    observationCount: 1,
    highestRiskLevel: 'medium',
  ),
  _channelSnapshotJson(
    'marketplace_limited',
    status: 'skipped',
    coverageStatus: 'insufficient',
    observationCount: 0,
    findingCount: 0,
    highestRiskLevel: null,
  ),
];

Map<String, dynamic> _reportJson() => {
  'contractVersion': riskScanReportContractVersionV1,
  'reportId': 'report-1',
  'scanRunId': 'scan-run-1',
  'reportVersion': 1,
  'overallRiskLevel': 'high',
  'overallConfidenceLevel': 'medium',
  'coverageStatus': 'limited',
  'topFindingSnapshots': [_findingSnapshotJson()],
  'channelDistribution': _channelDistributionJson(),
  'recommendedAction': 'review_top_findings',
  'generatedAt': '2026-07-29T12:00:00.000Z',
  'reportDigestSha256': _digestA,
  'immutable': true,
};

Map<String, dynamic> _claimJson({String status = 'issued'}) => {
  'contractVersion': riskScanClaimContractVersionV1,
  'claimId': 'claim-1',
  'scanRunId': 'scan-run-1',
  'status': status,
  'claimTokenDigestSha256': _digestA,
  'requestId': _requestId,
  'requestFingerprintSha256': _digestB,
  'issuedAt': '2026-07-29T12:00:00.000Z',
  'expiresAt': '2026-07-29T13:00:00.000Z',
  if (status == 'claimed') ...{
    'claimedAt': '2026-07-29T12:30:00.000Z',
    'claimedByUid': 'user-1',
    'tenantId': 'tenant-1',
    'canonicalBrandId': 'brand-1',
  },
};

Map<String, dynamic> _jsonRoundTrip(Map<String, Object?> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  test('report round-trips immutable snapshot wire values', () {
    final report = RiskScanReportContractV1.fromJson(_reportJson());
    final restored = RiskScanReportContractV1.fromJson(
      _jsonRoundTrip(report.toJson()),
    );
    expect(restored.contractVersion, riskScanReportContractVersionV1);
    expect(restored.reportVersion, 1);
    expect(restored.overallRiskLevel, RiskScanRiskLevel.high);
    expect(restored.overallConfidenceLevel, RiskScanConfidenceLevel.medium);
    expect(restored.coverageStatus, RiskScanCoverageStatus.limited);
    expect(
      restored.recommendedAction,
      RiskScanReportRecommendedAction.reviewTopFindings,
    );
    expect(restored.topFindingSnapshots, hasLength(1));
    expect(restored.channelDistribution, hasLength(3));
    expect(restored.immutable, isTrue);
  });

  test('report version must be a positive integer', () {
    final zero = _reportJson();
    zero['reportVersion'] = 0;
    final decimal = _reportJson();
    decimal['reportVersion'] = 1.5;
    expect(
      () => RiskScanReportContractV1.fromJson(zero),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(decimal),
      throwsFormatException,
    );
  });

  test('report permits zero top findings', () {
    final json = _reportJson();
    json['topFindingSnapshots'] = <Map<String, dynamic>>[];
    final report = RiskScanReportContractV1.fromJson(json);
    expect(report.topFindingSnapshots, isEmpty);
  });

  test('report limits top findings to five', () {
    final json = _reportJson();
    json['topFindingSnapshots'] = [
      for (var index = 0; index < 6; index++)
        _findingSnapshotJson(findingId: 'finding-$index'),
    ];
    expect(
      () => RiskScanReportContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('report rejects duplicate top finding identifiers', () {
    final json = _reportJson();
    json['topFindingSnapshots'] = [
      _findingSnapshotJson(),
      _findingSnapshotJson(),
    ];
    expect(
      () => RiskScanReportContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('report finding list is an immutable snapshot', () {
    final source = <RiskScanReportFindingSnapshotV1>[
      RiskScanReportFindingSnapshotV1.fromJson(_findingSnapshotJson()),
    ];
    final report = RiskScanReportContractV1(
      reportId: 'report-1',
      scanRunId: 'scan-run-1',
      reportVersion: 1,
      overallRiskLevel: RiskScanRiskLevel.high,
      overallConfidenceLevel: RiskScanConfidenceLevel.medium,
      coverageStatus: RiskScanCoverageStatus.limited,
      topFindingSnapshots: source,
      channelDistribution: _channelDistributionJson()
          .map(RiskScanReportChannelSnapshotV1.fromJson)
          .toList(),
      recommendedAction: RiskScanReportRecommendedAction.reviewTopFindings,
      generatedAt: DateTime.parse('2026-07-29T12:00:00.000Z'),
      reportDigestSha256: _digestA,
      immutable: true,
    );
    source.add(
      RiskScanReportFindingSnapshotV1.fromJson(
        _findingSnapshotJson(findingId: 'finding-later'),
      ),
    );
    expect(report.topFindingSnapshots, hasLength(1));
    expect(
      () => report.topFindingSnapshots.add(
        RiskScanReportFindingSnapshotV1.fromJson(
          _findingSnapshotJson(findingId: 'forbidden'),
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('report snapshot excludes operational and raw source fields', () {
    final json = RiskScanReportContractV1.fromJson(_reportJson()).toJson();
    final snapshot =
        (json['topFindingSnapshots']! as List).single as Map<String, Object?>;
    expect(snapshot, isNot(contains('promotedSignalId')));
    expect(snapshot, isNot(contains('reviewedByUid')));
    expect(snapshot, isNot(contains('sourceUrlCanonical')));
  });

  test('channel distribution contains every V1 channel exactly once', () {
    final missing = _reportJson();
    missing['channelDistribution'] = _channelDistributionJson()..removeLast();
    final duplicate = _reportJson();
    final channels = _channelDistributionJson();
    channels[2] = _channelSnapshotJson('open_web');
    duplicate['channelDistribution'] = channels;
    expect(
      () => RiskScanReportContractV1.fromJson(missing),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(duplicate),
      throwsFormatException,
    );
  });

  test('report channel accepts only final statuses', () {
    for (final status in [
      'queued',
      'acquiring',
      'assessing',
      'failed_retryable',
    ]) {
      final json = _reportJson();
      final channels = _channelDistributionJson();
      channels[0] = _channelSnapshotJson('similar_domains', status: status);
      json['channelDistribution'] = channels;
      expect(
        () => RiskScanReportContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('channel snapshot counters are non-negative integers', () {
    final negative = _reportJson();
    final negativeChannels = _channelDistributionJson();
    negativeChannels[0]['findingCount'] = -1;
    negative['channelDistribution'] = negativeChannels;
    final decimal = _reportJson();
    final decimalChannels = _channelDistributionJson();
    decimalChannels[0]['observationCount'] = 1.5;
    decimal['channelDistribution'] = decimalChannels;
    expect(
      () => RiskScanReportContractV1.fromJson(negative),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(decimal),
      throwsFormatException,
    );
  });

  test('highest risk presence follows finding count', () {
    final unexpected = _reportJson();
    final unexpectedChannels = _channelDistributionJson();
    unexpectedChannels[2]['highestRiskLevel'] = 'low';
    unexpected['channelDistribution'] = unexpectedChannels;
    final missing = _reportJson();
    final missingChannels = _channelDistributionJson();
    missingChannels[0].remove('highestRiskLevel');
    missing['channelDistribution'] = missingChannels;
    expect(
      () => RiskScanReportContractV1.fromJson(unexpected),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(missing),
      throwsFormatException,
    );
  });

  test('report digest and immutable declaration are enforced', () {
    final badDigest = _reportJson();
    badDigest['reportDigestSha256'] = 'ABC';
    final falseImmutable = _reportJson();
    falseImmutable['immutable'] = false;
    final textImmutable = _reportJson();
    textImmutable['immutable'] = 'true';
    expect(
      () => RiskScanReportContractV1.fromJson(badDigest),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(falseImmutable),
      throwsFormatException,
    );
    expect(
      () => RiskScanReportContractV1.fromJson(textImmutable),
      throwsFormatException,
    );
  });

  test('unknown report values fail closed', () {
    final risk = _reportJson();
    risk['overallRiskLevel'] = 'extreme';
    final confidence = _reportJson();
    confidence['overallConfidenceLevel'] = 'certain';
    final action = _reportJson();
    action['recommendedAction'] = 'takedown_now';
    final version = _reportJson();
    version['contractVersion'] = 'risk-scan-report-v2';
    for (final json in [risk, confidence, action, version]) {
      expect(
        () => RiskScanReportContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('issued claim round-trips without ownership fields', () {
    final claim = RiskScanClaimContractV1.fromJson(_claimJson());
    final restored = RiskScanClaimContractV1.fromJson(
      _jsonRoundTrip(claim.toJson()),
    );
    expect(restored.contractVersion, riskScanClaimContractVersionV1);
    expect(restored.status, RiskScanClaimStatus.issued);
    expect(restored.claimedAt, isNull);
    expect(restored.tenantId, isNull);
  });

  test('claimed claim round-trips complete ownership fields', () {
    final claim = RiskScanClaimContractV1.fromJson(
      _claimJson(status: 'claimed'),
    );
    final restored = RiskScanClaimContractV1.fromJson(
      _jsonRoundTrip(claim.toJson()),
    );
    expect(restored.status, RiskScanClaimStatus.claimed);
    expect(restored.claimedByUid, 'user-1');
    expect(restored.tenantId, 'tenant-1');
    expect(restored.canonicalBrandId, 'brand-1');
  });

  test('claim rejects every raw token key', () {
    for (final key in ['claimToken', 'rawClaimToken', 'token']) {
      final json = _claimJson();
      json[key] = 'raw-secret';
      expect(
        () => RiskScanClaimContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('claim serialization never emits a raw token', () {
    final json = RiskScanClaimContractV1.fromJson(_claimJson()).toJson();
    expect(json, isNot(contains('claimToken')));
    expect(json, isNot(contains('rawClaimToken')));
    expect(json, isNot(contains('token')));
    expect(json['claimTokenDigestSha256'], _digestA);
  });

  test('claim validates token and request digests', () {
    final tokenDigest = _claimJson();
    tokenDigest['claimTokenDigestSha256'] = 'ABC';
    final requestDigest = _claimJson();
    requestDigest['requestFingerprintSha256'] = 'ABC';
    expect(
      () => RiskScanClaimContractV1.fromJson(tokenDigest),
      throwsFormatException,
    );
    expect(
      () => RiskScanClaimContractV1.fromJson(requestDigest),
      throwsFormatException,
    );
  });

  test('claim requestId must be a canonical UUID', () {
    final json = _claimJson();
    json['requestId'] = 'not-a-uuid';
    expect(() => RiskScanClaimContractV1.fromJson(json), throwsFormatException);
  });

  test('claim expiry must follow issue time', () {
    final equal = _claimJson();
    equal['expiresAt'] = equal['issuedAt'];
    final earlier = _claimJson();
    earlier['expiresAt'] = '2026-07-29T11:59:59.000Z';
    expect(
      () => RiskScanClaimContractV1.fromJson(equal),
      throwsFormatException,
    );
    expect(
      () => RiskScanClaimContractV1.fromJson(earlier),
      throwsFormatException,
    );
  });

  test('non-claimed statuses reject ownership fields', () {
    for (final status in ['issued', 'expired', 'revoked']) {
      final json = _claimJson(status: status);
      json['claimedAt'] = '2026-07-29T12:30:00.000Z';
      json['claimedByUid'] = 'user-1';
      json['tenantId'] = 'tenant-1';
      json['canonicalBrandId'] = 'brand-1';
      expect(
        () => RiskScanClaimContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('claimed status requires every ownership field', () {
    final base = _claimJson(status: 'claimed');
    for (final field in [
      'claimedAt',
      'claimedByUid',
      'tenantId',
      'canonicalBrandId',
    ]) {
      final json = Map<String, dynamic>.from(base)..remove(field);
      expect(
        () => RiskScanClaimContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('claimedAt must be within the issue and expiry window', () {
    final beforeIssue = _claimJson(status: 'claimed');
    beforeIssue['claimedAt'] = '2026-07-29T11:59:59.000Z';
    final atExpiry = _claimJson(status: 'claimed');
    atExpiry['claimedAt'] = atExpiry['expiresAt'];
    final afterExpiry = _claimJson(status: 'claimed');
    afterExpiry['claimedAt'] = '2026-07-29T13:00:01.000Z';
    expect(
      () => RiskScanClaimContractV1.fromJson(beforeIssue),
      throwsFormatException,
    );
    expect(
      () => RiskScanClaimContractV1.fromJson(atExpiry),
      throwsFormatException,
    );
    expect(
      () => RiskScanClaimContractV1.fromJson(afterExpiry),
      throwsFormatException,
    );
  });

  test('unknown claim status and version fail closed', () {
    final status = _claimJson();
    status['status'] = 'consumed';
    final version = _claimJson();
    version['contractVersion'] = 'risk-scan-claim-v2';
    expect(
      () => RiskScanClaimContractV1.fromJson(status),
      throwsFormatException,
    );
    expect(
      () => RiskScanClaimContractV1.fromJson(version),
      throwsFormatException,
    );
  });
}
