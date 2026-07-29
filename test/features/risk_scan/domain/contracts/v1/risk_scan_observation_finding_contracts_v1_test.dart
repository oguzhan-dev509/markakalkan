import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/domain/contracts/v1/risk_scan_contracts_v1.dart';

const _requestId = '123e4567-e89b-42d3-a456-426614174601';
const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _observationJson({String status = 'acquired'}) => {
  'contractVersion': riskScanObservationContractVersionV1,
  'observationId': 'observation-1',
  'scanRunId': 'scan-run-1',
  'channelCode': 'open_web',
  'sourceType': 'web_page',
  'sourceUrlCanonical': 'https://example.com/product',
  'sourceHost': 'example.com',
  'sourceTitleSnapshot': 'Örnek ürün sayfası',
  'acquisitionStatus': status,
  if (status == 'acquired' || status == 'acquired_with_limits')
    'acquiredAt': '2026-07-29T10:01:00.000Z',
  if (status == 'acquired') 'contentFingerprintSha256': _hashA,
  'observedAt': '2026-07-29T10:00:00.000Z',
  'createdAt': '2026-07-29T10:02:00.000Z',
  'immutable': true,
};

Map<String, dynamic> _findingJson({
  String reviewStatus = 'review_required',
  String promotionStatus = 'not_requested',
}) => {
  'contractVersion': riskScanFindingContractVersionV1,
  'findingId': 'finding-1',
  'scanRunId': 'scan-run-1',
  'channelCode': 'open_web',
  'findingType': 'content_similarity',
  'observationRefs': ['observation-1'],
  'title': 'Benzer marka içeriği',
  'summary': 'Resmî marka içeriğine benzeyen bir sayfa sinyali bulundu.',
  'riskLevel': 'high',
  'confidenceLevel': 'medium',
  'impactLevel': 'high',
  'interventionDifficulty': 'moderate',
  'reviewStatus': reviewStatus,
  'recommendationCode': 'review_finding',
  if (reviewStatus == 'suspicious' ||
      reviewStatus == 'confirmed' ||
      reviewStatus == 'false_positive') ...{
    'reviewedAt': '2026-07-29T10:05:00.000Z',
    'reviewedByUid': 'reviewer-1',
  },
  'promotionStatus': promotionStatus,
  if (promotionStatus == 'promoted') ...{
    'promotedSignalId': 'signal-1',
    'promotedAt': '2026-07-29T10:06:00.000Z',
    'promotionRequestId': _requestId,
  },
  'createdAt': '2026-07-29T10:02:00.000Z',
  'updatedAt': '2026-07-29T10:07:00.000Z',
};

Map<String, dynamic> _jsonRoundTrip(Map<String, Object?> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  test('acquired observation round-trips exact wire values', () {
    final model = RiskScanObservationContractV1.fromJson(_observationJson());
    final restored = RiskScanObservationContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.contractVersion, riskScanObservationContractVersionV1);
    expect(restored.channelCode, RiskScanChannelCode.openWeb);
    expect(restored.sourceType, RiskScanObservationSourceType.webPage);
    expect(restored.acquisitionStatus, RiskScanAcquisitionStatus.acquired);
    expect(restored.contentFingerprintSha256, _hashA);
    expect(restored.immutable, isTrue);
  });

  test('observation binds source host to canonical URL', () {
    final json = _observationJson();
    json['sourceHost'] = 'other.example';
    expect(
      () => RiskScanObservationContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('observation rejects unsafe URL shapes', () {
    final userInfo = _observationJson();
    userInfo['sourceUrlCanonical'] = 'https://user@example.com/product';
    final fragment = _observationJson();
    fragment['sourceUrlCanonical'] = 'https://example.com/product#detail';
    expect(
      () => RiskScanObservationContractV1.fromJson(userInfo),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(fragment),
      throwsFormatException,
    );
  });

  test('acquired observation requires time and fingerprint', () {
    final missingTime = _observationJson()..remove('acquiredAt');
    final missingFingerprint = _observationJson()
      ..remove('contentFingerprintSha256');
    expect(
      () => RiskScanObservationContractV1.fromJson(missingTime),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(missingFingerprint),
      throwsFormatException,
    );
  });

  test('acquired with limits requires time but permits no fingerprint', () {
    final model = RiskScanObservationContractV1.fromJson(
      _observationJson(status: 'acquired_with_limits'),
    );
    expect(
      model.acquisitionStatus,
      RiskScanAcquisitionStatus.acquiredWithLimits,
    );
    expect(model.acquiredAt, isNotNull);
    expect(model.contentFingerprintSha256, isNull);
  });

  test('non-acquired observation rejects acquisition output', () {
    final discovered = _observationJson(status: 'discovered');
    discovered['acquiredAt'] = '2026-07-29T10:01:00.000Z';
    final failed = _observationJson(status: 'failed_terminal');
    failed['contentFingerprintSha256'] = _hashA;
    expect(
      () => RiskScanObservationContractV1.fromJson(discovered),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(failed),
      throwsFormatException,
    );
  });

  test('observation temporal invariants are enforced', () {
    final observedLate = _observationJson();
    observedLate['observedAt'] = '2026-07-29T10:03:00.000Z';
    final acquiredEarly = _observationJson();
    acquiredEarly['acquiredAt'] = '2026-07-29T09:59:00.000Z';
    final acquiredLate = _observationJson();
    acquiredLate['acquiredAt'] = '2026-07-29T10:03:00.000Z';
    expect(
      () => RiskScanObservationContractV1.fromJson(observedLate),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(acquiredEarly),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(acquiredLate),
      throwsFormatException,
    );
  });

  test('observation immutable flag must be boolean true', () {
    final falseValue = _observationJson();
    falseValue['immutable'] = false;
    final textValue = _observationJson();
    textValue['immutable'] = 'true';
    expect(
      () => RiskScanObservationContractV1.fromJson(falseValue),
      throwsFormatException,
    );
    expect(
      () => RiskScanObservationContractV1.fromJson(textValue),
      throwsFormatException,
    );
  });

  test('unknown observation values fail closed', () {
    final unknownType = _observationJson();
    unknownType['sourceType'] = 'social_account';
    final unknownStatus = _observationJson();
    unknownStatus['acquisitionStatus'] = 'running';
    final unknownVersion = _observationJson();
    unknownVersion['contractVersion'] = 'risk-scan-observation-v2';
    for (final json in [unknownType, unknownStatus, unknownVersion]) {
      expect(
        () => RiskScanObservationContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('automated finding round-trips four explainable dimensions', () {
    final model = RiskScanFindingContractV1.fromJson(_findingJson());
    final restored = RiskScanFindingContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.contractVersion, riskScanFindingContractVersionV1);
    expect(restored.riskLevel, RiskScanRiskLevel.high);
    expect(restored.confidenceLevel, RiskScanConfidenceLevel.medium);
    expect(restored.impactLevel, RiskScanImpactLevel.high);
    expect(
      restored.interventionDifficulty,
      RiskScanInterventionDifficulty.moderate,
    );
    expect(restored.reviewStatus, RiskScanReviewStatus.reviewRequired);
    expect(restored.promotionStatus, RiskScanPromotionStatus.notRequested);
  });

  test('observation references are non-empty and unique', () {
    final empty = _findingJson();
    empty['observationRefs'] = <String>[];
    final duplicate = _findingJson();
    duplicate['observationRefs'] = ['observation-1', 'observation-1'];
    expect(
      () => RiskScanFindingContractV1.fromJson(empty),
      throwsFormatException,
    );
    expect(
      () => RiskScanFindingContractV1.fromJson(duplicate),
      throwsFormatException,
    );
  });

  test('observation references are an immutable snapshot', () {
    final source = <String>['observation-1'];
    final finding = RiskScanFindingContractV1(
      findingId: 'finding-1',
      scanRunId: 'scan-run-1',
      channelCode: RiskScanChannelCode.openWeb,
      findingType: RiskScanFindingType.contentSimilarity,
      observationRefs: source,
      title: 'Benzer içerik',
      summary: 'Kontrollü açıklanabilir risk bulgusu.',
      riskLevel: RiskScanRiskLevel.high,
      confidenceLevel: RiskScanConfidenceLevel.medium,
      impactLevel: RiskScanImpactLevel.high,
      interventionDifficulty: RiskScanInterventionDifficulty.moderate,
      reviewStatus: RiskScanReviewStatus.reviewRequired,
      recommendationCode: RiskScanRecommendationCode.reviewFinding,
      promotionStatus: RiskScanPromotionStatus.notRequested,
      createdAt: DateTime.parse('2026-07-29T10:02:00.000Z'),
      updatedAt: DateTime.parse('2026-07-29T10:02:00.000Z'),
    );
    source.add('later-change');
    expect(finding.observationRefs, ['observation-1']);
    expect(
      () => finding.observationRefs.add('forbidden'),
      throwsUnsupportedError,
    );
  });

  test('automated status rejects human review fields', () {
    final json = _findingJson();
    json['reviewedAt'] = '2026-07-29T10:05:00.000Z';
    json['reviewedByUid'] = 'reviewer-1';
    expect(
      () => RiskScanFindingContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('human status requires complete review fields', () {
    final missingTime = _findingJson(reviewStatus: 'suspicious')
      ..remove('reviewedAt');
    final missingReviewer = _findingJson(reviewStatus: 'confirmed')
      ..remove('reviewedByUid');
    expect(
      () => RiskScanFindingContractV1.fromJson(missingTime),
      throwsFormatException,
    );
    expect(
      () => RiskScanFindingContractV1.fromJson(missingReviewer),
      throwsFormatException,
    );
  });

  test('human review temporal invariants are enforced', () {
    final early = _findingJson(reviewStatus: 'suspicious');
    early['reviewedAt'] = '2026-07-29T10:01:00.000Z';
    final late = _findingJson(reviewStatus: 'suspicious');
    late['reviewedAt'] = '2026-07-29T10:08:00.000Z';
    expect(
      () => RiskScanFindingContractV1.fromJson(early),
      throwsFormatException,
    );
    expect(
      () => RiskScanFindingContractV1.fromJson(late),
      throwsFormatException,
    );
  });

  test('not requested promotion rejects promotion fields', () {
    final json = _findingJson();
    json['promotedSignalId'] = 'signal-1';
    expect(
      () => RiskScanFindingContractV1.fromJson(json),
      throwsFormatException,
    );
  });

  test('promoted finding requires all promotion fields', () {
    final base = _findingJson(
      reviewStatus: 'suspicious',
      promotionStatus: 'promoted',
    );
    for (final field in [
      'promotedSignalId',
      'promotedAt',
      'promotionRequestId',
    ]) {
      final json = Map<String, dynamic>.from(base)..remove(field);
      expect(
        () => RiskScanFindingContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('only suspicious or confirmed finding can be promoted', () {
    for (final status in ['signal', 'review_required', 'false_positive']) {
      final json = _findingJson(
        reviewStatus: status,
        promotionStatus: 'promoted',
      );
      expect(
        () => RiskScanFindingContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test('valid promoted suspicious finding round-trips', () {
    final model = RiskScanFindingContractV1.fromJson(
      _findingJson(reviewStatus: 'suspicious', promotionStatus: 'promoted'),
    );
    final restored = RiskScanFindingContractV1.fromJson(
      _jsonRoundTrip(model.toJson()),
    );
    expect(restored.reviewStatus, RiskScanReviewStatus.suspicious);
    expect(restored.promotionStatus, RiskScanPromotionStatus.promoted);
    expect(restored.promotedSignalId, 'signal-1');
    expect(restored.promotionRequestId, _requestId);
  });

  test('promotion request UUID and temporal rules are enforced', () {
    final badUuid = _findingJson(
      reviewStatus: 'confirmed',
      promotionStatus: 'promoted',
    );
    badUuid['promotionRequestId'] = 'bad';
    final beforeReview = _findingJson(
      reviewStatus: 'confirmed',
      promotionStatus: 'promoted',
    );
    beforeReview['promotedAt'] = '2026-07-29T10:04:00.000Z';
    final afterUpdate = _findingJson(
      reviewStatus: 'confirmed',
      promotionStatus: 'promoted',
    );
    afterUpdate['promotedAt'] = '2026-07-29T10:08:00.000Z';
    expect(
      () => RiskScanFindingContractV1.fromJson(badUuid),
      throwsFormatException,
    );
    expect(
      () => RiskScanFindingContractV1.fromJson(beforeReview),
      throwsFormatException,
    );
    expect(
      () => RiskScanFindingContractV1.fromJson(afterUpdate),
      throwsFormatException,
    );
  });

  test('finding time and unknown values fail closed', () {
    final stale = _findingJson();
    stale['updatedAt'] = '2026-07-29T10:01:00.000Z';
    final unknownRisk = _findingJson();
    unknownRisk['riskLevel'] = 'extreme';
    final unknownReview = _findingJson();
    unknownReview['reviewStatus'] = 'approved';
    final unknownRecommendation = _findingJson();
    unknownRecommendation['recommendationCode'] = 'takedown_now';
    final unknownVersion = _findingJson();
    unknownVersion['contractVersion'] = 'risk-scan-finding-v2';
    for (final json in [
      stale,
      unknownRisk,
      unknownReview,
      unknownRecommendation,
      unknownVersion,
    ]) {
      expect(
        () => RiskScanFindingContractV1.fromJson(json),
        throwsFormatException,
      );
    }
  });
}
