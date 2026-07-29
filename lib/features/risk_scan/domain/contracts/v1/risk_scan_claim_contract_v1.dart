// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanClaimContractV1 {
  RiskScanClaimContractV1({
    required String claimId,
    required String scanRunId,
    required RiskScanClaimStatus status,
    required String claimTokenDigestSha256,
    required String requestId,
    required String requestFingerprintSha256,
    required DateTime issuedAt,
    required DateTime expiresAt,
    DateTime? claimedAt,
    String? claimedByUid,
    String? tenantId,
    String? canonicalBrandId,
  }) : claimId = _requiredString(claimId, 'claimId'),
       scanRunId = _requiredString(scanRunId, 'scanRunId'),
       status = status,
       claimTokenDigestSha256 = _requiredSha256(
         claimTokenDigestSha256,
         'claimTokenDigestSha256',
       ),
       requestId = _requiredUuid(requestId, 'requestId'),
       requestFingerprintSha256 = _requiredSha256(
         requestFingerprintSha256,
         'requestFingerprintSha256',
       ),
       issuedAt = issuedAt,
       expiresAt = expiresAt,
       claimedAt = claimedAt,
       claimedByUid = _optionalString(claimedByUid, 'claimedByUid'),
       tenantId = _optionalString(tenantId, 'tenantId'),
       canonicalBrandId = _optionalString(
         canonicalBrandId,
         'canonicalBrandId',
       ) {
    if (!this.expiresAt.isAfter(this.issuedAt)) {
      throw const FormatException('expiresAt must follow issuedAt');
    }

    final hasAnyClaimedIdentity =
        this.claimedAt != null ||
        this.claimedByUid != null ||
        this.tenantId != null ||
        this.canonicalBrandId != null;
    final hasAllClaimedIdentity =
        this.claimedAt != null &&
        this.claimedByUid != null &&
        this.tenantId != null &&
        this.canonicalBrandId != null;

    if (this.status == RiskScanClaimStatus.claimed) {
      if (!hasAllClaimedIdentity) {
        throw const FormatException(
          'claimed status requires all ownership fields',
        );
      }
      if (this.claimedAt!.isBefore(this.issuedAt)) {
        throw const FormatException('claimedAt cannot precede issuedAt');
      }
      if (!this.claimedAt!.isBefore(this.expiresAt)) {
        throw const FormatException('claimedAt must precede expiresAt');
      }
    } else if (hasAnyClaimedIdentity) {
      throw const FormatException(
        'unclaimed status cannot contain ownership fields',
      );
    }
  }

  final String contractVersion = riskScanClaimContractVersionV1;
  final String claimId;
  final String scanRunId;
  final RiskScanClaimStatus status;
  final String claimTokenDigestSha256;
  final String requestId;
  final String requestFingerprintSha256;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? claimedAt;
  final String? claimedByUid;
  final String? tenantId;
  final String? canonicalBrandId;

  factory RiskScanClaimContractV1.fromJson(Map<String, dynamic> json) {
    for (final forbiddenKey in ['claimToken', 'rawClaimToken', 'token']) {
      if (json.containsKey(forbiddenKey)) {
        throw FormatException('$forbiddenKey is forbidden');
      }
    }
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanClaimContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskScanClaimContractV1(
      claimId: _requiredString(json['claimId'], 'claimId'),
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      status: _claimStatusFrom(json['status']),
      claimTokenDigestSha256: _requiredSha256(
        json['claimTokenDigestSha256'],
        'claimTokenDigestSha256',
      ),
      requestId: _requiredUuid(json['requestId'], 'requestId'),
      requestFingerprintSha256: _requiredSha256(
        json['requestFingerprintSha256'],
        'requestFingerprintSha256',
      ),
      issuedAt: _requiredDate(json['issuedAt'], 'issuedAt'),
      expiresAt: _requiredDate(json['expiresAt'], 'expiresAt'),
      claimedAt: _optionalDate(json['claimedAt'], 'claimedAt'),
      claimedByUid: _optionalString(json['claimedByUid'], 'claimedByUid'),
      tenantId: _optionalString(json['tenantId'], 'tenantId'),
      canonicalBrandId: _optionalString(
        json['canonicalBrandId'],
        'canonicalBrandId',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'claimId': claimId,
    'scanRunId': scanRunId,
    'status': _claimStatusValue(status),
    'claimTokenDigestSha256': claimTokenDigestSha256,
    'requestId': requestId,
    'requestFingerprintSha256': requestFingerprintSha256,
    'issuedAt': issuedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (claimedAt != null) 'claimedAt': claimedAt!.toIso8601String(),
    if (claimedByUid != null) 'claimedByUid': claimedByUid,
    if (tenantId != null) 'tenantId': tenantId,
    if (canonicalBrandId != null) 'canonicalBrandId': canonicalBrandId,
  };
}
