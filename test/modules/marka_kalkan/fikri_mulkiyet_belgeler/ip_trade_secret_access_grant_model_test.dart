import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_access_grant_model.dart';

void main() {
  group('IpTradeSecretAccessGrantModel', () {
    IpTradeSecretAccessGrantModel buildModel({
      IpTradeSecretAccessGrantStatus status =
          IpTradeSecretAccessGrantStatus.active,
      DateTime? validFrom,
      DateTime? validUntil,
      bool requiresDualApproval = false,
      bool dualApprovalCompleted = false,
      bool deviceRestricted = false,
      List<String> allowedDeviceIds = const <String>[],
      bool downloadAllowed = false,
      int? sessionTimeLimitMinutes,
      int accessRiskScore = 30,
      Map<String, dynamic> metadata = const <String, dynamic>{},
      DateTime? revokedAt,
      String? revokedBy,
    }) {
      return IpTradeSecretAccessGrantModel(
        id: 'grant-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        grantCode: 'ACCESS-001',
        subjectType: IpTradeSecretAccessSubjectType.employee,
        subjectId: 'user-1',
        subjectName: 'Ar-Ge Uzmanı',
        accessLevel: IpAccessLevel.controlledView,
        status: status,
        grantBasis: IpTradeSecretAccessGrantBasis.confidentialityAgreement,
        ndaDocumentIds: const <String>['nda-1'],
        validFrom: validFrom ?? DateTime.utc(2026, 1, 1),
        validUntil: validUntil ?? DateTime.utc(2030, 1, 1),
        requiresDualApproval: requiresDualApproval,
        dualApprovalCompleted: dualApprovalCompleted,
        deviceRestricted: deviceRestricted,
        allowedDeviceIds: allowedDeviceIds,
        downloadAllowed: downloadAllowed,
        sessionTimeLimitMinutes: sessionTimeLimitMinutes,
        accessRiskScore: accessRiskScore,
        legalProtectionScore: 80,
        metadata: metadata,
        revokedAt: revokedAt,
        revokedBy: revokedBy,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel erişim kimliğini ve hukuki dayanağı üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.hasLegalFoundation, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('mevcut IpAccessLevel enumunu kullanır', () {
      final model = buildModel();

      expect(model.accessLevel, IpAccessLevel.controlledView);
      expect(model.toMap()['accessLevel'], 'controlled_view');
    });

    test('hassas operasyon yetkilerini tespit eder', () {
      final model = buildModel(downloadAllowed: true);

      expect(model.grantsSensitiveOperations, isTrue);
    });

    test('çift onay tamamlanmadan aktif erişimi reddeder', () {
      final model = buildModel(
        requiresDualApproval: true,
        dualApprovalCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('çift onay tamamlandığında aktif erişim serileşir', () {
      final model = buildModel(
        requiresDualApproval: true,
        dualApprovalCompleted: true,
      );

      expect(model.toMap()['dualApprovalCompleted'], isTrue);
    });

    test('cihaz kısıtında izinli cihaz zorunludur', () {
      final model = buildModel(deviceRestricted: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('bitiş tarihi başlangıçtan önce olamaz', () {
      final model = buildModel(
        validFrom: DateTime.utc(2026, 7, 5),
        validUntil: DateTime.utc(2026, 7, 4),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('oturum süresi sıfır olamaz', () {
      final model = buildModel(sessionTimeLimitMinutes: 0);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('pozitif oturum süresi serileşir', () {
      final model = buildModel(sessionTimeLimitMinutes: 30);

      expect(model.toMap()['sessionTimeLimitMinutes'], 30);
    });

    test('metadata içinde sır veya erişim anahtarı tutulmasını reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'decryptionKey': 'secret-key'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('iptal edilen erişimde iptal bilgilerini zorunlu tutar', () {
      final model = buildModel(status: IpTradeSecretAccessGrantStatus.revoked);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli iptal kaydı serileşir', () {
      final model = buildModel(
        status: IpTradeSecretAccessGrantStatus.revoked,
        revokedAt: DateTime.utc(2026, 7, 5),
        revokedBy: 'admin-1',
      );

      expect(model.toMap()['status'], 'revoked');
      expect(model.isRevoked, isTrue);
    });

    test('0–100 dışındaki risk skorunu reddeder', () {
      final model = buildModel(accessRiskScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });
  });
}
