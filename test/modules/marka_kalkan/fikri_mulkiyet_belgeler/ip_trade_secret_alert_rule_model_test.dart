import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_alert_rule_model.dart';

void main() {
  group('IpTradeSecretAlertRuleModel', () {
    IpTradeSecretAlertRuleModel buildModel({
      IpTradeSecretAlertStatus status = IpTradeSecretAlertStatus.active,
      IpTradeSecretAlertSeverity severity = IpTradeSecretAlertSeverity.high,
      IpTradeSecretAlertSourceType sourceType =
          IpTradeSecretAlertSourceType.remediationAction,
      IpTradeSecretAlertTriggerType triggerType =
          IpTradeSecretAlertTriggerType.overdue,
      String? sourceRecordId = 'action-1',
      List<String> recipientUserIds = const <String>['user-1'],
      List<String> recipientRoleIds = const <String>[],
      List<String> recipientTeamIds = const <String>[],
      List<String> escalationUserIds = const <String>[],
      bool active = true,
      bool repeatEnabled = false,
      bool autoEscalationEnabled = false,
      bool managementEscalationRequired = false,
      bool legalEscalationRequired = false,
      bool securityEscalationRequired = false,
      bool falsePositive = false,
      num? thresholdValue,
      String? thresholdUnit,
      int? repeatIntervalMinutes,
      int? maxRepeatCount,
      int? snoozeMinutes,
      String? muteReason,
      String? acknowledgedBy,
      String? resolvedBy,
      String? reopenedBy,
      String? falsePositiveReason,
      DateTime? triggeredAt,
      DateTime? snoozedUntil,
      DateTime? mutedAt,
      DateTime? acknowledgedAt,
      DateTime? escalatedAt,
      DateTime? resolvedAt,
      DateTime? reopenedAt,
      DateTime? disabledAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretAlertRuleModel(
        id: 'alert-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        sourceRecordId: sourceRecordId,
        recipientUserIds: recipientUserIds,
        recipientRoleIds: recipientRoleIds,
        recipientTeamIds: recipientTeamIds,
        escalationUserIds: escalationUserIds,
        notificationChannelIds: const <String>['in_app'],
        ruleCode: 'ALERT-001',
        title: 'Gecikmiş iyileştirme eylemi',
        status: status,
        severity: severity,
        sourceType: sourceType,
        triggerType: triggerType,
        ownerUserId: 'owner-1',
        description: 'Eylem son tarihi geçtiğinde alarm üret.',
        thresholdValue: thresholdValue,
        thresholdUnit: thresholdUnit,
        repeatIntervalMinutes: repeatIntervalMinutes,
        maxRepeatCount: maxRepeatCount,
        snoozeMinutes: snoozeMinutes,
        muteReason: muteReason,
        acknowledgedBy: acknowledgedBy,
        resolvedBy: resolvedBy,
        reopenedBy: reopenedBy,
        falsePositiveReason: falsePositiveReason,
        active: active,
        repeatEnabled: repeatEnabled,
        autoEscalationEnabled: autoEscalationEnabled,
        managementEscalationRequired: managementEscalationRequired,
        legalEscalationRequired: legalEscalationRequired,
        securityEscalationRequired: securityEscalationRequired,
        falsePositive: falsePositive,
        triggeredAt: triggeredAt,
        snoozedUntil: snoozedUntil,
        mutedAt: mutedAt,
        acknowledgedAt: acknowledgedAt,
        escalatedAt: escalatedAt,
        resolvedAt: resolvedAt,
        reopenedAt: reopenedAt,
        disabledAt: disabledAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel alarm kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'active');
      expect(map['severity'], 'high');
      expect(map['sourceType'], 'remediation_action');
      expect(map['triggerType'], 'overdue');
    });

    test('aktif kuralda alıcı ister', () {
      final model = buildModel(recipientUserIds: const <String>[]);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kaynak türünde kaynak kayıt kimliği ister', () {
      final model = buildModel(sourceRecordId: null);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('eşik tabanlı alarmda değer ve birim ister', () {
      final model = buildModel(
        triggerType: IpTradeSecretAlertTriggerType.scoreBelowThreshold,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli eşik tabanlı alarmı serileştirir', () {
      final model = buildModel(
        triggerType: IpTradeSecretAlertTriggerType.scoreBelowThreshold,
        thresholdValue: 60,
        thresholdUnit: 'score',
      );

      expect(model.toMap()['thresholdValue'], 60);
    });

    test('tekrarlayan alarmda aralık ve sayı ister', () {
      final model = buildModel(repeatEnabled: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('tetiklenen alarmda tarih ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.triggered);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kabul edilen alarmda kişi ve tarih ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.acknowledged);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('ertelenen alarmda süre ve bitiş ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.snoozed);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('susturulan alarmda tarih ve gerekçe ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.muted);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yükseltilen alarmda tarih ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.escalated);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('çözülen alarmda kişi ve tarih ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.resolved);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yeniden açılan alarmda kişi ve tarih ister', () {
      final model = buildModel(status: IpTradeSecretAlertStatus.reopened);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('devre dışı alarmda active false ve tarih ister', () {
      final model = buildModel(
        status: IpTradeSecretAlertStatus.disabled,
        active: true,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yanlış pozitifte gerekçe ister', () {
      final model = buildModel(falsePositive: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('otomatik yükseltmede hedef ister', () {
      final model = buildModel(autoEscalationEnabled: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kritik alarmı acil yükseltir', () {
      final model = buildModel(severity: IpTradeSecretAlertSeverity.critical);

      expect(model.requiresImmediateEscalation, isTrue);
    });

    test('tetiklenen alarmı panele taşır', () {
      final model = buildModel(
        status: IpTradeSecretAlertStatus.triggered,
        triggeredAt: DateTime.utc(2026, 7, 5),
      );

      expect(model.shouldAppearOnAlertDashboard, isTrue);
    });

    test('geçerli çözülen alarmı serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretAlertStatus.resolved,
        resolvedBy: 'resolver-1',
        resolvedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap()['status'], 'resolved');
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'secretContent': 'gizli formül'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
