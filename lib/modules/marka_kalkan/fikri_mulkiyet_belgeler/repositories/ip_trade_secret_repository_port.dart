import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_enums.dart';
import '../models/ip_trade_secret_model.dart';

abstract interface class IpTradeSecretRepositoryPort {
  Future<String> create(IpTradeSecretModel tradeSecret);

  Future<void> update(IpTradeSecretModel tradeSecret);

  Future<IpTradeSecretModel?> getById(String tradeSecretId);

  Future<IpTradeSecretModel?> findBySecretCode({
    required String brandId,
    required String secretCode,
  });

  Future<List<IpTradeSecretModel>> listAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  });

  Stream<List<IpTradeSecretModel>> watchAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String tradeSecretId,
    required IpTradeSecretStatus status,
    required String updatedBy,
  });

  Future<void> markLeakageSuspected({
    required String tradeSecretId,
    required String updatedBy,
  });

  Future<void> clearLeakageSuspicion({
    required String tradeSecretId,
    required String updatedBy,
  });

  Future<void> activateLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  });

  Future<void> releaseLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  });

  Future<void> delete(String tradeSecretId);
}
