import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_incident_model.dart';

void main() {
  group('IpTradeSecretIncidentModel', () {
    IpTradeSecretIncidentModel buildModel({
      IpTradeSecretIncidentStatus status =
          IpTradeSecretIncidentStatus.investigating,
      IpTradeSecretIncidentSeverity severity =
          IpTradeSecretIncidentSeverity.high,
      DateTime? detectedAt,
      DateTime? reportedAt,
      DateTime? containedAt,
      DateTime? resolvedAt,
      DateTime? closedAt,
      bool containmentCompleted = false,
      bool remediationCompleted = false,
      bool regulatorNotificationRequired = false,
      bool regulatorNotificationCompleted = false,
      bool legalReviewRequired = false,
      bool legalReviewCompleted = false,
      bool evidencePreservationRequired = true,
      bool evidencePreservationCompleted = true,
      bool accessRevocationRequired = false,
      bool accessRevocationCompleted = false,
      double? financialLossAmount,
      String? financialLossCurrency,
      int affectedRecordCount = 0,
      int incidentRiskScore = 75,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretIncidentModel(
        id: 'incident-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        accessGrantIds: const <String>['grant-1'],
        disclosureIds: const <String>['disclosure-1'],
        incidentCode: 'INC-001',
        title: 'Yetkisiz erişim şüphesi',
        type: IpTradeSecretIncidentType.unauthorizedAccess,
        status: status,
        severity: severity,
        source: IpTradeSecretIncidentSource.accessLog,
        affectedUserIds: const <String>['user-1'],
        evidenceDocumentIds: const <String>['evidence-1'],
        detectedAt: detectedAt ?? DateTime.utc(2026, 7, 5, 10),
        reportedAt: reportedAt ?? DateTime.utc(2026, 7, 5, 11),
        reportedBy: 'security-user-1',
        containedAt: containedAt,
        resolvedAt: resolvedAt,
        closedAt: closedAt,
        containmentCompleted: containmentCompleted,
        remediationCompleted: remediationCompleted,
        regulatorNotificationRequired: regulatorNotificationRequired,
        regulatorNotificationCompleted: regulatorNotificationCompleted,
        legalReviewRequired: legalReviewRequired,
        legalReviewCompleted: legalReviewCompleted,
        evidencePreservationRequired: evidencePreservationRequired,
        evidencePreservationCompleted: evidencePreservationCompleted,
        accessRevocationRequired: accessRevocationRequired,
        accessRevocationCompleted: accessRevocationCompleted,
        financialLossAmount: financialLossAmount,
        financialLossCurrency: financialLossCurrency,
        affectedRecordCount: affectedRecordCount,
        incidentRiskScore: incidentRiskScore,
        businessImpactScore: 60,
        legalImpactScore: 70,
        reputationImpactScore: 65,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5, 11),
        createdBy: 'admin-1',
      );
    }

    test('temel olay kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.isOpen, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final model = buildModel();

      final map = model.toMap();

      expect(map['type'], 'unauthorized_access');
      expect(map['status'], 'investigating');
      expect(map['severity'], 'high');
      expect(map['source'], 'access_log');
    });

    test('yüksek şiddetli olayı acil yükseltme olarak işaretler', () {
      final model = buildModel();

      expect(model.requiresImmediateEscalation, isTrue);
      expect(model.requiresImmediateReview, isTrue);
    });

    test('kritik risk skorunu kritik olay kabul eder', () {
      final model = buildModel(
        severity: IpTradeSecretIncidentSeverity.medium,
        incidentRiskScore: 95,
      );

      expect(model.isCritical, isTrue);
    });

    test('bildirim tarihi tespit tarihinden önce olamaz', () {
      final model = buildModel(
        detectedAt: DateTime.utc(2026, 7, 5, 12),
        reportedAt: DateTime.utc(2026, 7, 5, 11),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kontrol altındaki olayda containment bilgilerini ister', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.contained,
        containmentCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli kontrol altına alma kaydı serileşir', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.contained,
        containmentCompleted: true,
        containedAt: DateTime.utc(2026, 7, 5, 12),
      );

      expect(model.toMap()['containmentCompleted'], isTrue);
    });

    test('çözülen olayda giderme ve çözüm tarihini ister', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.resolved,
        remediationCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kapanışta düzenleyici kurum bildirimini zorunlu tutar', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.closed,
        resolvedAt: DateTime.utc(2026, 7, 6),
        closedAt: DateTime.utc(2026, 7, 7),
        remediationCompleted: true,
        regulatorNotificationRequired: true,
        regulatorNotificationCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kapanışta hukuki incelemeyi zorunlu tutar', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.closed,
        resolvedAt: DateTime.utc(2026, 7, 6),
        closedAt: DateTime.utc(2026, 7, 7),
        remediationCompleted: true,
        legalReviewRequired: true,
        legalReviewCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kapanışta erişim iptalini zorunlu tutar', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.closed,
        resolvedAt: DateTime.utc(2026, 7, 6),
        closedAt: DateTime.utc(2026, 7, 7),
        remediationCompleted: true,
        accessRevocationRequired: true,
        accessRevocationCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli kapatılmış olay kaydını serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretIncidentStatus.closed,
        resolvedAt: DateTime.utc(2026, 7, 6),
        closedAt: DateTime.utc(2026, 7, 7),
        remediationCompleted: true,
      );

      expect(model.toMap()['status'], 'closed');
      expect(model.isOpen, isFalse);
    });

    test('negatif finansal kaybı reddeder', () {
      final model = buildModel(
        financialLossAmount: -1,
        financialLossCurrency: 'TRY',
      );

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('finansal kayıp varsa para birimini zorunlu tutar', () {
      final model = buildModel(financialLossAmount: 1000);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('negatif etkilenen kayıt sayısını reddeder', () {
      final model = buildModel(affectedRecordCount: -1);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('0–100 dışındaki risk skorunu reddeder', () {
      final model = buildModel(incidentRiskScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'secretContent': 'gizli içerik'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
