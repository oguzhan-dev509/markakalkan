import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_enums.dart';
import '../models/ip_trade_secret_model.dart';
import '../repositories/ip_trade_secret_repository_port.dart';

class IpTradeSecretShieldService {
  const IpTradeSecretShieldService({
    required IpTradeSecretRepositoryPort repository,
  }) : _repository = repository;

  final IpTradeSecretRepositoryPort _repository;

  Future<String> createProtectionFile(IpTradeSecretModel tradeSecret) async {
    _validateForCreation(tradeSecret);

    return _repository.create(tradeSecret);
  }

  Future<void> updateProtectionFile(IpTradeSecretModel tradeSecret) async {
    _validateForUpdate(tradeSecret);

    await _repository.update(tradeSecret);
  }

  Future<void> reportLeakageSuspicion({
    required String tradeSecretId,
    required String reportedBy,
  }) async {
    _validateRequiredId(tradeSecretId, fieldName: 'tradeSecretId');

    _validateRequiredId(reportedBy, fieldName: 'reportedBy');

    await _repository.markLeakageSuspected(
      tradeSecretId: tradeSecretId,
      updatedBy: reportedBy,
    );
  }

  Future<void> clearLeakageSuspicion({
    required String tradeSecretId,
    required String reviewedBy,
  }) async {
    _validateRequiredId(tradeSecretId, fieldName: 'tradeSecretId');

    _validateRequiredId(reviewedBy, fieldName: 'reviewedBy');

    await _repository.clearLeakageSuspicion(
      tradeSecretId: tradeSecretId,
      updatedBy: reviewedBy,
    );
  }

  Future<void> activateLegalHold({
    required String tradeSecretId,
    required String actorId,
  }) async {
    _validateRequiredId(tradeSecretId, fieldName: 'tradeSecretId');

    _validateRequiredId(actorId, fieldName: 'actorId');

    await _repository.activateLegalHold(
      tradeSecretId: tradeSecretId,
      updatedBy: actorId,
    );
  }

  Future<void> releaseLegalHold({
    required String tradeSecretId,
    required String actorId,
  }) async {
    _validateRequiredId(tradeSecretId, fieldName: 'tradeSecretId');

    _validateRequiredId(actorId, fieldName: 'actorId');

    await _repository.releaseLegalHold(
      tradeSecretId: tradeSecretId,
      updatedBy: actorId,
    );
  }

  Stream<List<IpTradeSecretModel>> watchProtectionFiles({
    String? brandId,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    bool? leakageSuspected,
    int limit = 200,
  }) {
    return _repository.watchAll(
      brandId: brandId,
      status: status,
      riskLevel: riskLevel,
      leakageSuspected: leakageSuspected,
      limit: limit,
    );
  }

  void _validateForCreation(IpTradeSecretModel tradeSecret) {
    if (!tradeSecret.hasCompleteIdentity) {
      throw StateError(
        'Ticari sır koruma dosyasının zorunlu kimlik alanları eksik.',
      );
    }

    if (tradeSecret.confidentialityLevel !=
            IpConfidentialityLevel.tradeSecret &&
        tradeSecret.confidentialityLevel !=
            IpConfidentialityLevel.highlyConfidential &&
        tradeSecret.confidentialityLevel != IpConfidentialityLevel.restricted) {
      throw StateError(
        'Ticari sır koruma dosyası yüksek gizlilik seviyesinde olmalıdır.',
      );
    }

    if (tradeSecret.secretSecurityScore < 0 ||
        tradeSecret.secretSecurityScore > 100) {
      throw RangeError.range(
        tradeSecret.secretSecurityScore,
        0,
        100,
        'secretSecurityScore',
      );
    }

    tradeSecret.toMap();
  }

  void _validateForUpdate(IpTradeSecretModel tradeSecret) {
    _validateForCreation(tradeSecret);

    _validateRequiredId(tradeSecret.id, fieldName: 'tradeSecretId');

    _validateRequiredId(
      tradeSecret.updatedBy ?? tradeSecret.createdBy,
      fieldName: 'updatedBy',
    );
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }
}
