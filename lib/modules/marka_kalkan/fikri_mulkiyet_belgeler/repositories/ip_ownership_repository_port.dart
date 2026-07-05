import '../models/ip_ownership_record_model.dart';

abstract interface class IpOwnershipRepositoryPort {
  Future<String> create(IpOwnershipRecordModel record);

  Future<void> update(IpOwnershipRecordModel record);

  Future<IpOwnershipRecordModel?> getById(String ownershipRecordId);

  Future<IpOwnershipRecordModel?> findByRecordCode({
    required String brandId,
    required String recordCode,
  });

  Future<List<IpOwnershipRecordModel>> listAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  });

  Stream<List<IpOwnershipRecordModel>> watchAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  });

  Future<List<IpOwnershipRecordModel>> listActiveForAsset({
    required String assetId,
    DateTime? effectiveAt,
    int limit = 200,
  });

  Future<List<IpOwnershipRecordModel>> listOwnershipChain({
    required String assetId,
    int limit = 500,
  });

  Future<List<IpOwnershipRecordModel>> listByParty({
    required String partyId,
    bool activeOnly = false,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String ownershipRecordId,
    required IpOwnershipStatus status,
    required String updatedBy,
  });

  Future<void> markVerified({
    required String ownershipRecordId,
    required DateTime verificationDate,
    required String verifiedBy,
  });

  Future<void> delete(String ownershipRecordId);
}
