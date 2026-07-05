import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_component_model.dart';

void main() {
  group('IpTradeSecretComponentModel', () {
    IpTradeSecretComponentModel buildModel({
      IpTradeSecretComponentStorageMode storageMode =
          IpTradeSecretComponentStorageMode.metadataOnly,
      String? encryptedComponentReference,
      String? externalSecureSystemReference,
      Map<String, dynamic> metadata = const <String, dynamic>{},
      int accessControlScore = 80,
    }) {
      return IpTradeSecretComponentModel(
        id: 'component-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentCode: 'COMP-001',
        title: 'Kritik Proses Aşaması',
        componentType: IpTradeSecretComponentType.processStep,
        status: IpTradeSecretComponentStatus.active,
        criticality: IpTradeSecretComponentCriticality.critical,
        confidentialityLevel: IpConfidentialityLevel.tradeSecret,
        riskLevel: IpRiskLevel.high,
        storageMode: storageMode,
        authorizedUserIds: const <String>['user-1'],
        componentFingerprint: 'abc123',
        hashAlgorithm: 'SHA-256',
        encryptedComponentReference: encryptedComponentReference,
        externalSecureSystemReference: externalSecureSystemReference,
        accessControlScore: accessControlScore,
        technicalProtectionScore: 75,
        operationalProtectionScore: 70,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'user-1',
      );
    }

    test('temel kimlik ve kritik bileşen göstergelerini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.isCriticalComponent, isTrue);
      expect(model.hasControlledAccess, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini kararlı biçimde çözer', () {
      expect(
        IpTradeSecretComponentType.fromValue('process_step'),
        IpTradeSecretComponentType.processStep,
      );

      expect(
        IpTradeSecretComponentStorageMode.fromValue('split_knowledge'),
        IpTradeSecretComponentStorageMode.splitKnowledge,
      );
    });

    test('toMap gerçek bileşen içeriği yerine metaveri üretir', () {
      final map = buildModel().toMap();

      expect(map['tradeSecretId'], 'secret-1');
      expect(map['componentCode'], 'COMP-001');
      expect(map['componentType'], 'process_step');
      expect(map.containsKey('formulaContent'), isFalse);
      expect(map.containsKey('processParameterValue'), isFalse);
    });

    test('metadata içinde açık metin bileşen içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'exactProportion': '37.25%'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('şifreli kasa modunda güvenli referans zorunludur', () {
      final model = buildModel(
        storageMode: IpTradeSecretComponentStorageMode.encryptedVault,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('şifreli kasa referansı bulunan model serileşir', () {
      final model = buildModel(
        storageMode: IpTradeSecretComponentStorageMode.encryptedVault,
        encryptedComponentReference: 'vault://trade-secrets/component-1',
      );

      expect(
        model.toMap()['encryptedComponentReference'],
        'vault://trade-secrets/component-1',
      );
    });

    test('harici güvenli sistem referansı zorunludur', () {
      final model = buildModel(
        storageMode: IpTradeSecretComponentStorageMode.externalSecureSystem,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('0–100 dışındaki skorları reddeder', () {
      final model = buildModel(accessControlScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });
  });
}
