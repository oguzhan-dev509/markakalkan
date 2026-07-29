// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanRunContractV1 {
  RiskScanRunContractV1({
    required String scanRunId,
    required RiskScanMode scanMode,
    required RiskScanAccessTier accessTier,
    required RiskScanIdentityMode identityMode,
    required RiskScanTargetContractV1 target,
    required RiskScanRunStatus status,
    required RiskScanCoverageStatus coverageStatus,
    required String requestId,
    required String requestFingerprintSha256,
    required String deduplicationFingerprintSha256,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime expiresAt,
    String? tenantId,
    String? canonicalBrandId,
    String? createdByUid,
  }) : scanRunId = _requiredString(scanRunId, 'scanRunId'),
       scanMode = scanMode,
       accessTier = accessTier,
       identityMode = identityMode,
       target = target,
       status = status,
       coverageStatus = coverageStatus,
       requestId = _requiredUuid(requestId, 'requestId'),
       requestFingerprintSha256 = _requiredSha256(
         requestFingerprintSha256,
         'requestFingerprintSha256',
       ),
       deduplicationFingerprintSha256 = _requiredSha256(
         deduplicationFingerprintSha256,
         'deduplicationFingerprintSha256',
       ),
       createdAt = createdAt,
       updatedAt = updatedAt,
       expiresAt = expiresAt,
       tenantId = _optionalString(tenantId, 'tenantId'),
       canonicalBrandId = _optionalString(canonicalBrandId, 'canonicalBrandId'),
       createdByUid = _optionalString(createdByUid, 'createdByUid') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw const FormatException('updatedAt cannot precede createdAt');
    }
    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw const FormatException('expiresAt must follow createdAt');
    }
    final publicAnonymous =
        this.accessTier == RiskScanAccessTier.publicLite &&
        this.identityMode == RiskScanIdentityMode.anonymous;
    final registeredResolved =
        this.accessTier == RiskScanAccessTier.registered &&
        this.identityMode == RiskScanIdentityMode.resolved;
    if (!publicAnonymous && !registeredResolved) {
      throw const FormatException(
        'accessTier and identityMode combination is invalid',
      );
    }
    final hasAnyResolvedField =
        this.tenantId != null ||
        this.canonicalBrandId != null ||
        this.createdByUid != null;
    final hasAllResolvedFields =
        this.tenantId != null &&
        this.canonicalBrandId != null &&
        this.createdByUid != null;
    if (this.identityMode == RiskScanIdentityMode.anonymous &&
        hasAnyResolvedField) {
      throw const FormatException(
        'anonymous run cannot contain resolved identity fields',
      );
    }
    if (this.identityMode == RiskScanIdentityMode.resolved &&
        !hasAllResolvedFields) {
      throw const FormatException(
        'resolved run requires tenantId, canonicalBrandId and createdByUid',
      );
    }
  }

  final String contractVersion = riskScanRunContractVersionV1;
  final String scanRunId;
  final RiskScanMode scanMode;
  final RiskScanAccessTier accessTier;
  final RiskScanIdentityMode identityMode;
  final RiskScanTargetContractV1 target;
  final RiskScanRunStatus status;
  final RiskScanCoverageStatus coverageStatus;
  final String requestId;
  final String requestFingerprintSha256;
  final String deduplicationFingerprintSha256;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String? tenantId;
  final String? canonicalBrandId;
  final String? createdByUid;

  factory RiskScanRunContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanRunContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskScanRunContractV1(
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      scanMode: _scanModeFrom(json['scanMode']),
      accessTier: _accessTierFrom(json['accessTier']),
      identityMode: _identityModeFrom(json['identityMode']),
      target: RiskScanTargetContractV1.fromJson(
        _requiredMap(json['target'], 'target'),
      ),
      status: _runStatusFrom(json['status']),
      coverageStatus: _coverageStatusFrom(json['coverageStatus']),
      requestId: _requiredUuid(json['requestId'], 'requestId'),
      requestFingerprintSha256: _requiredSha256(
        json['requestFingerprintSha256'],
        'requestFingerprintSha256',
      ),
      deduplicationFingerprintSha256: _requiredSha256(
        json['deduplicationFingerprintSha256'],
        'deduplicationFingerprintSha256',
      ),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      updatedAt: _requiredDate(json['updatedAt'], 'updatedAt'),
      expiresAt: _requiredDate(json['expiresAt'], 'expiresAt'),
      tenantId: _optionalString(json['tenantId'], 'tenantId'),
      canonicalBrandId: _optionalString(
        json['canonicalBrandId'],
        'canonicalBrandId',
      ),
      createdByUid: _optionalString(json['createdByUid'], 'createdByUid'),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'scanRunId': scanRunId,
    'scanMode': _scanModeValue(scanMode),
    'accessTier': _accessTierValue(accessTier),
    'identityMode': _identityModeValue(identityMode),
    'target': target.toJson(),
    'status': _runStatusValue(status),
    'coverageStatus': _coverageStatusValue(coverageStatus),
    'requestId': requestId,
    'requestFingerprintSha256': requestFingerprintSha256,
    'deduplicationFingerprintSha256': deduplicationFingerprintSha256,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (tenantId != null) 'tenantId': tenantId,
    if (canonicalBrandId != null) 'canonicalBrandId': canonicalBrandId,
    if (createdByUid != null) 'createdByUid': createdByUid,
  };
}
