import '../constants/ip_enums.dart';
import '../models/ip_asset_model.dart';
import '../models/ip_document_model.dart';
import '../models/ip_relationship_model.dart';
import '../models/ip_right_model.dart';

abstract interface class IpAssetRepositoryPort {
  Future<String> create(IpAssetModel asset);

  Future<void> update(IpAssetModel asset);

  Future<IpAssetModel?> getById(String assetId);

  Future<IpAssetModel?> findByAssetCode({
    required String brandId,
    required String assetCode,
  });

  Future<List<IpAssetModel>> listAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  });

  Stream<List<IpAssetModel>> watchAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  });

  Future<List<IpAssetModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpAssetModel>> listImmediateAttention({
    String? brandId,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String assetId,
    required IpAssetStatus status,
    required String updatedBy,
  });

  Future<void> updateScores({
    required String assetId,
    required int rightStrengthScore,
    required int secretSecurityScore,
    required int responseReadinessScore,
    required int resilienceScore,
    required String updatedBy,
  });

  Future<void> delete(String assetId);
}

abstract interface class IpRightRepositoryPort {
  Future<String> create(IpRightModel right);

  Future<void> update(IpRightModel right);

  Future<IpRightModel?> getById(String rightId);

  Future<IpRightModel?> findByRightCode({
    required String brandId,
    required String rightCode,
  });

  Future<IpRightModel?> findByRegistrationNumber({
    required String registrationNumber,
    String? primaryCountryCode,
  });

  Future<List<IpRightModel>> listAll({
    String? brandId,
    String? assetId,
    IpRightType? rightType,
    IpRightStatus? status,
    IpRiskLevel? riskLevel,
    String? countryCode,
    int limit = 200,
  });

  Stream<List<IpRightModel>> watchAll({
    String? brandId,
    String? assetId,
    IpRightType? rightType,
    IpRightStatus? status,
    IpRiskLevel? riskLevel,
    String? countryCode,
    int limit = 200,
  });

  Future<List<IpRightModel>> listUpcomingDeadlines({
    String? brandId,
    int days = 90,
    int limit = 200,
  });

  Future<List<IpRightModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String rightId,
    required IpRightStatus status,
    required String updatedBy,
  });

  Future<void> updateRightStrengthScore({
    required String rightId,
    required int score,
    required String updatedBy,
  });

  Future<void> delete(String rightId);
}

abstract interface class IpDocumentRepositoryPort {
  Future<String> create(IpDocumentModel document);

  Future<void> update(IpDocumentModel document);

  Future<IpDocumentModel?> getById(String documentId);

  Future<IpDocumentModel?> findByDocumentCode({
    required String brandId,
    required String documentCode,
  });

  Future<IpDocumentModel?> findBySha256Hash({required String sha256Hash});

  Future<List<IpDocumentModel>> listAll({
    String? brandId,
    String? assetId,
    String? rightId,
    IpDocumentType? documentType,
    IpDocumentStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpEvidenceIntegrityStatus? integrityStatus,
    IpRiskLevel? riskLevel,
    bool? legalHoldActive,
    int limit = 200,
  });

  Stream<List<IpDocumentModel>> watchAll({
    String? brandId,
    String? assetId,
    String? rightId,
    IpDocumentType? documentType,
    IpDocumentStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpEvidenceIntegrityStatus? integrityStatus,
    IpRiskLevel? riskLevel,
    bool? legalHoldActive,
    int limit = 200,
  });

  Future<List<IpDocumentModel>> listEvidenceReady({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpDocumentModel>> listIntegrityConcerns({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpDocumentModel>> listExpiring({
    String? brandId,
    int days = 90,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String documentId,
    required IpDocumentStatus status,
    required String updatedBy,
  });

  Future<void> updateIntegrityStatus({
    required String documentId,
    required IpEvidenceIntegrityStatus integrityStatus,
    required String updatedBy,
  });

  Future<void> activateLegalHold({
    required String documentId,
    required String updatedBy,
  });

  Future<void> releaseLegalHold({
    required String documentId,
    required String updatedBy,
  });

  Future<void> delete(String documentId);
}

abstract interface class IpRelationshipRepositoryPort {
  Future<String> create(IpRelationshipModel relationship);

  Future<void> update(IpRelationshipModel relationship);

  Future<IpRelationshipModel?> getById(String relationshipId);

  Future<IpRelationshipModel?> findByRelationshipCode({
    required String brandId,
    required String relationshipCode,
  });

  Future<List<IpRelationshipModel>> listAll({
    String? brandId,
    String? assetId,
    IpRelationshipType? relationshipType,
    IpRelationshipStatus? status,
    IpAccessLevel? accessLevel,
    IpRiskLevel? riskLevel,
    bool? accessRevoked,
    bool? hasNda,
    int limit = 200,
  });

  Stream<List<IpRelationshipModel>> watchAll({
    String? brandId,
    String? assetId,
    IpRelationshipType? relationshipType,
    IpRelationshipStatus? status,
    IpAccessLevel? accessLevel,
    IpRiskLevel? riskLevel,
    bool? accessRevoked,
    bool? hasNda,
    int limit = 200,
  });

  Future<List<IpRelationshipModel>> listHighRisk({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpRelationshipModel>> listActiveAccess({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpRelationshipModel>> listMissingOrExpiredNda({
    String? brandId,
    int limit = 200,
  });

  Future<List<IpRelationshipModel>> listImmediateReview({
    String? brandId,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String relationshipId,
    required IpRelationshipStatus status,
    required String updatedBy,
  });

  Future<void> updateRisk({
    required String relationshipId,
    required IpRiskLevel riskLevel,
    required int riskScore,
    required int trustScore,
    required String updatedBy,
    String? riskReason,
  });

  Future<void> revokeAccess({
    required String relationshipId,
    required String revokedBy,
  });

  Future<void> delete(String relationshipId);
}
