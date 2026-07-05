import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_model.dart';

void main() {
  group('IpTradeSecretModel', () {
    final createdAt = DateTime.utc(2026, 7, 5, 10);

    IpTradeSecretModel buildModel({
      IpSecretProtectionMode protectionMode =
          IpSecretProtectionMode.metadataOnly,
      String? encryptedSecretReference,
      String? externalSecureSystemReference,
      Map<String, dynamic> metadata = const <String, dynamic>{},
      int secretSecurityScore = 75,
    }) {
      return IpTradeSecretModel(
        id: 'secret-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        secretCode: 'TS-001',
        title: 'Özel Üretim Formülü',
        description: 'Gizli formül koruma dosyası',
        secretType: IpTradeSecretType.formula,
        status: IpTradeSecretStatus.active,
        confidentialityLevel: IpConfidentialityLevel.tradeSecret,
        riskLevel: IpRiskLevel.high,
        protectionMode: protectionMode,
        disclosureScope: IpSecretDisclosureScope.needToKnow,
        legalBasisStatus: IpSecretLegalBasisStatus.verified,
        compartmentalizationLevel: IpSecretCompartmentalizationLevel.strict,
        economicValueLevel: IpSecretEconomicValueLevel.critical,
        relatedAssetIds: const <String>['asset-1'],
        ndaDocumentIds: const <String>['nda-1'],
        authorizedUserIds: const <String>['user-1'],
        encryptedSecretReference: encryptedSecretReference,
        externalSecureSystemReference: externalSecureSystemReference,
        accessControlScore: 80,
        legalProtectionScore: 90,
        technicalProtectionScore: 70,
        operationalProtectionScore: 65,
        secretSecurityScore: secretSecurityScore,
        metadata: metadata,
        createdAt: createdAt,
        createdBy: 'user-1',
      );
    }

    test('temel kimliği ve güvenlik göstergelerini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.hasVerifiedLegalFoundation, isTrue);
      expect(model.hasControlledAccess, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini kararlı biçimde çözer', () {
      expect(
        IpTradeSecretType.fromValue('manufacturing_process'),
        IpTradeSecretType.manufacturingProcess,
      );
      expect(
        IpTradeSecretStatus.fromValue('compromised'),
        IpTradeSecretStatus.compromised,
      );
      expect(
        IpSecretEconomicValueLevel.fromValue('critical'),
        IpSecretEconomicValueLevel.critical,
      );
    });

    test('toMap gerçek sır içeriği yerine koruma metaverisi üretir', () {
      final map = buildModel().toMap();

      expect(map['secretCode'], 'TS-001');
      expect(map['secretType'], 'formula');
      expect(map['protectionMode'], 'metadata_only');
      expect(map.containsKey('formulaContent'), isFalse);
      expect(map.containsKey('secretContent'), isFalse);
    });

    test('metadata içinde açık metin formül tutulmasını reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'formulaContent': 'gizli bileşim'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('şifreli kasa modunda güvenli referans zorunludur', () {
      final model = buildModel(
        protectionMode: IpSecretProtectionMode.encryptedVault,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('şifreli kasa referansı bulunan model serileşir', () {
      final model = buildModel(
        protectionMode: IpSecretProtectionMode.encryptedVault,
        encryptedSecretReference: 'vault://secret-1',
      );

      expect(model.toMap()['encryptedSecretReference'], 'vault://secret-1');
    });

    test('harici güvenli sistem modunda sistem referansı zorunludur', () {
      final model = buildModel(
        protectionMode: IpSecretProtectionMode.externalSecureSystem,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('0–100 dışındaki skorları reddeder', () {
      final model = buildModel(secretSecurityScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });
  });
}
