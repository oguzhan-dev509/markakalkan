// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanFindingContractV1 {
  RiskScanFindingContractV1({
    required String findingId,
    required String scanRunId,
    required RiskScanChannelCode channelCode,
    required RiskScanFindingType findingType,
    required List<String> observationRefs,
    required String title,
    required String summary,
    required RiskScanRiskLevel riskLevel,
    required RiskScanConfidenceLevel confidenceLevel,
    required RiskScanImpactLevel impactLevel,
    required RiskScanInterventionDifficulty interventionDifficulty,
    required RiskScanReviewStatus reviewStatus,
    required RiskScanRecommendationCode recommendationCode,
    required RiskScanPromotionStatus promotionStatus,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? reviewedAt,
    String? reviewedByUid,
    String? promotedSignalId,
    DateTime? promotedAt,
    String? promotionRequestId,
  }) : findingId = _requiredString(findingId, 'findingId'),
       scanRunId = _requiredString(scanRunId, 'scanRunId'),
       channelCode = channelCode,
       findingType = findingType,
       observationRefs = _findingObservationRefs(observationRefs),
       title = _requiredString(title, 'title'),
       summary = _requiredString(summary, 'summary'),
       riskLevel = riskLevel,
       confidenceLevel = confidenceLevel,
       impactLevel = impactLevel,
       interventionDifficulty = interventionDifficulty,
       reviewStatus = reviewStatus,
       recommendationCode = recommendationCode,
       reviewedAt = reviewedAt,
       reviewedByUid = _optionalString(reviewedByUid, 'reviewedByUid'),
       promotionStatus = promotionStatus,
       promotedSignalId = _optionalString(promotedSignalId, 'promotedSignalId'),
       promotedAt = promotedAt,
       promotionRequestId = promotionRequestId == null
           ? null
           : _requiredUuid(promotionRequestId, 'promotionRequestId'),
       createdAt = createdAt,
       updatedAt = updatedAt {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw const FormatException('updatedAt cannot precede createdAt');
    }

    final automated =
        this.reviewStatus == RiskScanReviewStatus.signal ||
        this.reviewStatus == RiskScanReviewStatus.reviewRequired;
    final human =
        this.reviewStatus == RiskScanReviewStatus.suspicious ||
        this.reviewStatus == RiskScanReviewStatus.confirmed ||
        this.reviewStatus == RiskScanReviewStatus.falsePositive;
    final hasAnyReview = this.reviewedAt != null || this.reviewedByUid != null;
    final hasAllReview = this.reviewedAt != null && this.reviewedByUid != null;

    if (automated && hasAnyReview) {
      throw const FormatException(
        'automated review status cannot contain human review fields',
      );
    }
    if (human && !hasAllReview) {
      throw const FormatException(
        'human review status requires reviewedAt and reviewedByUid',
      );
    }
    if (this.reviewedAt != null && this.reviewedAt!.isBefore(this.createdAt)) {
      throw const FormatException('reviewedAt cannot precede createdAt');
    }
    if (this.reviewedAt != null && this.reviewedAt!.isAfter(this.updatedAt)) {
      throw const FormatException('reviewedAt cannot follow updatedAt');
    }

    final hasAnyPromotion =
        this.promotedSignalId != null ||
        this.promotedAt != null ||
        this.promotionRequestId != null;
    final hasAllPromotion =
        this.promotedSignalId != null &&
        this.promotedAt != null &&
        this.promotionRequestId != null;

    if (this.promotionStatus == RiskScanPromotionStatus.notRequested) {
      if (hasAnyPromotion) {
        throw const FormatException(
          'not_requested promotion cannot contain promotion fields',
        );
      }
    } else {
      if (!hasAllPromotion) {
        throw const FormatException(
          'promoted finding requires all promotion fields',
        );
      }
      final promotable =
          this.reviewStatus == RiskScanReviewStatus.suspicious ||
          this.reviewStatus == RiskScanReviewStatus.confirmed;
      if (!promotable) {
        throw const FormatException(
          'only suspicious or confirmed finding can be promoted',
        );
      }
      if (this.reviewedAt == null ||
          this.promotedAt!.isBefore(this.reviewedAt!)) {
        throw const FormatException('promotedAt cannot precede human review');
      }
      if (this.promotedAt!.isAfter(this.updatedAt)) {
        throw const FormatException('promotedAt cannot follow updatedAt');
      }
    }
  }

  final String contractVersion = riskScanFindingContractVersionV1;
  final String findingId;
  final String scanRunId;
  final RiskScanChannelCode channelCode;
  final RiskScanFindingType findingType;
  final List<String> observationRefs;
  final String title;
  final String summary;
  final RiskScanRiskLevel riskLevel;
  final RiskScanConfidenceLevel confidenceLevel;
  final RiskScanImpactLevel impactLevel;
  final RiskScanInterventionDifficulty interventionDifficulty;
  final RiskScanReviewStatus reviewStatus;
  final RiskScanRecommendationCode recommendationCode;
  final DateTime? reviewedAt;
  final String? reviewedByUid;
  final RiskScanPromotionStatus promotionStatus;
  final String? promotedSignalId;
  final DateTime? promotedAt;
  final String? promotionRequestId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RiskScanFindingContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanFindingContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskScanFindingContractV1(
      findingId: _requiredString(json['findingId'], 'findingId'),
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      channelCode: _channelCodeFrom(json['channelCode']),
      findingType: _findingTypeFrom(json['findingType']),
      observationRefs: _findingObservationRefs(json['observationRefs']),
      title: _requiredString(json['title'], 'title'),
      summary: _requiredString(json['summary'], 'summary'),
      riskLevel: _riskLevelFrom(json['riskLevel']),
      confidenceLevel: _confidenceLevelFrom(json['confidenceLevel']),
      impactLevel: _impactLevelFrom(json['impactLevel']),
      interventionDifficulty: _interventionDifficultyFrom(
        json['interventionDifficulty'],
      ),
      reviewStatus: _reviewStatusFrom(json['reviewStatus']),
      recommendationCode: _recommendationCodeFrom(json['recommendationCode']),
      reviewedAt: _optionalDate(json['reviewedAt'], 'reviewedAt'),
      reviewedByUid: _optionalString(json['reviewedByUid'], 'reviewedByUid'),
      promotionStatus: _promotionStatusFrom(json['promotionStatus']),
      promotedSignalId: _optionalString(
        json['promotedSignalId'],
        'promotedSignalId',
      ),
      promotedAt: _optionalDate(json['promotedAt'], 'promotedAt'),
      promotionRequestId: json['promotionRequestId'] == null
          ? null
          : _requiredUuid(json['promotionRequestId'], 'promotionRequestId'),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      updatedAt: _requiredDate(json['updatedAt'], 'updatedAt'),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'findingId': findingId,
    'scanRunId': scanRunId,
    'channelCode': _channelCodeValue(channelCode),
    'findingType': _findingTypeValue(findingType),
    'observationRefs': observationRefs,
    'title': title,
    'summary': summary,
    'riskLevel': _riskLevelValue(riskLevel),
    'confidenceLevel': _confidenceLevelValue(confidenceLevel),
    'impactLevel': _impactLevelValue(impactLevel),
    'interventionDifficulty': _interventionDifficultyValue(
      interventionDifficulty,
    ),
    'reviewStatus': _reviewStatusValue(reviewStatus),
    'recommendationCode': _recommendationCodeValue(recommendationCode),
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    if (reviewedByUid != null) 'reviewedByUid': reviewedByUid,
    'promotionStatus': _promotionStatusValue(promotionStatus),
    if (promotedSignalId != null) 'promotedSignalId': promotedSignalId,
    if (promotedAt != null) 'promotedAt': promotedAt!.toIso8601String(),
    if (promotionRequestId != null) 'promotionRequestId': promotionRequestId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

List<String> _findingObservationRefs(Object? value) {
  if (value is! Iterable) {
    throw const FormatException('observationRefs must be an array');
  }
  final result = List<String>.unmodifiable(
    value.map((item) => _requiredString(item, 'observationRefs')),
  );
  if (result.isEmpty) {
    throw const FormatException('observationRefs cannot be empty');
  }
  if (result.toSet().length != result.length) {
    throw const FormatException('observationRefs cannot contain duplicates');
  }
  return result;
}
