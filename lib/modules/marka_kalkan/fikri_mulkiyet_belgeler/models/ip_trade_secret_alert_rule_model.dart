import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretAlertRuleModel {
  const IpTradeSecretAlertRuleModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.ruleCode,
    required this.title,
    required this.status,
    required this.severity,
    required this.sourceType,
    required this.triggerType,
    required this.ownerUserId,
    required this.createdAt,
    required this.createdBy,
    this.tradeSecretId,
    this.sourceRecordId,
    this.recipientUserIds = const <String>[],
    this.recipientRoleIds = const <String>[],
    this.recipientTeamIds = const <String>[],
    this.escalationUserIds = const <String>[],
    this.notificationChannelIds = const <String>[],
    this.description,
    this.conditionField,
    this.conditionOperator,
    this.conditionValue,
    this.thresholdValue,
    this.thresholdUnit,
    this.repeatIntervalMinutes,
    this.maxRepeatCount,
    this.snoozeMinutes,
    this.muteReason,
    this.acknowledgedBy,
    this.resolvedBy,
    this.reopenedBy,
    this.falsePositiveReason,
    this.active = true,
    this.repeatEnabled = false,
    this.autoEscalationEnabled = false,
    this.managementEscalationRequired = false,
    this.legalEscalationRequired = false,
    this.securityEscalationRequired = false,
    this.falsePositive = false,
    this.triggeredAt,
    this.lastNotifiedAt,
    this.nextNotificationAt,
    this.snoozedUntil,
    this.mutedAt,
    this.acknowledgedAt,
    this.escalatedAt,
    this.resolvedAt,
    this.reopenedAt,
    this.disabledAt,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String? tradeSecretId;
  final String? sourceRecordId;

  final List<String> recipientUserIds;
  final List<String> recipientRoleIds;
  final List<String> recipientTeamIds;
  final List<String> escalationUserIds;
  final List<String> notificationChannelIds;

  final String ruleCode;
  final String title;
  final IpTradeSecretAlertStatus status;
  final IpTradeSecretAlertSeverity severity;
  final IpTradeSecretAlertSourceType sourceType;
  final IpTradeSecretAlertTriggerType triggerType;
  final String ownerUserId;

  final String? description;
  final String? conditionField;
  final String? conditionOperator;
  final String? conditionValue;
  final num? thresholdValue;
  final String? thresholdUnit;

  final int? repeatIntervalMinutes;
  final int? maxRepeatCount;
  final int? snoozeMinutes;

  final String? muteReason;
  final String? acknowledgedBy;
  final String? resolvedBy;
  final String? reopenedBy;
  final String? falsePositiveReason;

  final bool active;
  final bool repeatEnabled;
  final bool autoEscalationEnabled;
  final bool managementEscalationRequired;
  final bool legalEscalationRequired;
  final bool securityEscalationRequired;
  final bool falsePositive;

  final DateTime? triggeredAt;
  final DateTime? lastNotifiedAt;
  final DateTime? nextNotificationAt;
  final DateTime? snoozedUntil;
  final DateTime? mutedAt;
  final DateTime? acknowledgedAt;
  final DateTime? escalatedAt;
  final DateTime? resolvedAt;
  final DateTime? reopenedAt;
  final DateTime? disabledAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretAlertRuleModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır alarm kuralı veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretAlertRuleModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretAlertRuleModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Alarm kuralı oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretAlertRuleModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.nullableString(data['tradeSecretId']),
      sourceRecordId: IpModelUtils.nullableString(data['sourceRecordId']),
      recipientUserIds: _stringList(data['recipientUserIds']),
      recipientRoleIds: _stringList(data['recipientRoleIds']),
      recipientTeamIds: _stringList(data['recipientTeamIds']),
      escalationUserIds: _stringList(data['escalationUserIds']),
      notificationChannelIds: _stringList(data['notificationChannelIds']),
      ruleCode: IpModelUtils.requiredString(data['ruleCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretAlertStatus.fromValue(data['status']?.toString()),
      severity: IpTradeSecretAlertSeverity.fromValue(
        data['severity']?.toString(),
      ),
      sourceType: IpTradeSecretAlertSourceType.fromValue(
        data['sourceType']?.toString(),
      ),
      triggerType: IpTradeSecretAlertTriggerType.fromValue(
        data['triggerType']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      description: IpModelUtils.nullableString(data['description']),
      conditionField: IpModelUtils.nullableString(data['conditionField']),
      conditionOperator: IpModelUtils.nullableString(data['conditionOperator']),
      conditionValue: IpModelUtils.nullableString(data['conditionValue']),
      thresholdValue: data['thresholdValue'] is num
          ? data['thresholdValue'] as num
          : null,
      thresholdUnit: IpModelUtils.nullableString(data['thresholdUnit']),
      repeatIntervalMinutes: _nullableNonNegativeInt(
        data['repeatIntervalMinutes'],
      ),
      maxRepeatCount: _nullableNonNegativeInt(data['maxRepeatCount']),
      snoozeMinutes: _nullableNonNegativeInt(data['snoozeMinutes']),
      muteReason: IpModelUtils.nullableString(data['muteReason']),
      acknowledgedBy: IpModelUtils.nullableString(data['acknowledgedBy']),
      resolvedBy: IpModelUtils.nullableString(data['resolvedBy']),
      reopenedBy: IpModelUtils.nullableString(data['reopenedBy']),
      falsePositiveReason: IpModelUtils.nullableString(
        data['falsePositiveReason'],
      ),
      active: data['active'] != false,
      repeatEnabled: data['repeatEnabled'] == true,
      autoEscalationEnabled: data['autoEscalationEnabled'] == true,
      managementEscalationRequired:
          data['managementEscalationRequired'] == true,
      legalEscalationRequired: data['legalEscalationRequired'] == true,
      securityEscalationRequired: data['securityEscalationRequired'] == true,
      falsePositive: data['falsePositive'] == true,
      triggeredAt: IpModelUtils.dateTimeFromValue(data['triggeredAt']),
      lastNotifiedAt: IpModelUtils.dateTimeFromValue(data['lastNotifiedAt']),
      nextNotificationAt: IpModelUtils.dateTimeFromValue(
        data['nextNotificationAt'],
      ),
      snoozedUntil: IpModelUtils.dateTimeFromValue(data['snoozedUntil']),
      mutedAt: IpModelUtils.dateTimeFromValue(data['mutedAt']),
      acknowledgedAt: IpModelUtils.dateTimeFromValue(data['acknowledgedAt']),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
      resolvedAt: IpModelUtils.dateTimeFromValue(data['resolvedAt']),
      reopenedAt: IpModelUtils.dateTimeFromValue(data['reopenedAt']),
      disabledAt: IpModelUtils.dateTimeFromValue(data['disabledAt']),
      notes: IpModelUtils.nullableString(data['notes']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    _validate();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'tradeSecretId': IpModelUtils.cleanNullable(tradeSecretId),
      'sourceRecordId': IpModelUtils.cleanNullable(sourceRecordId),
      'recipientUserIds': _cleanList(recipientUserIds),
      'recipientRoleIds': _cleanList(recipientRoleIds),
      'recipientTeamIds': _cleanList(recipientTeamIds),
      'escalationUserIds': _cleanList(escalationUserIds),
      'notificationChannelIds': _cleanList(notificationChannelIds),
      'ruleCode': ruleCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'severity': severity.value,
      'sourceType': sourceType.value,
      'triggerType': triggerType.value,
      'ownerUserId': ownerUserId.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'conditionField': IpModelUtils.cleanNullable(conditionField),
      'conditionOperator': IpModelUtils.cleanNullable(conditionOperator),
      'conditionValue': IpModelUtils.cleanNullable(conditionValue),
      'thresholdValue': thresholdValue,
      'thresholdUnit': IpModelUtils.cleanNullable(thresholdUnit),
      'repeatIntervalMinutes': repeatIntervalMinutes,
      'maxRepeatCount': maxRepeatCount,
      'snoozeMinutes': snoozeMinutes,
      'muteReason': IpModelUtils.cleanNullable(muteReason),
      'acknowledgedBy': IpModelUtils.cleanNullable(acknowledgedBy),
      'resolvedBy': IpModelUtils.cleanNullable(resolvedBy),
      'reopenedBy': IpModelUtils.cleanNullable(reopenedBy),
      'falsePositiveReason': IpModelUtils.cleanNullable(falsePositiveReason),
      'active': active,
      'repeatEnabled': repeatEnabled,
      'autoEscalationEnabled': autoEscalationEnabled,
      'managementEscalationRequired': managementEscalationRequired,
      'legalEscalationRequired': legalEscalationRequired,
      'securityEscalationRequired': securityEscalationRequired,
      'falsePositive': falsePositive,
      'triggeredAt': IpModelUtils.timestampOrNull(triggeredAt),
      'lastNotifiedAt': IpModelUtils.timestampOrNull(lastNotifiedAt),
      'nextNotificationAt': IpModelUtils.timestampOrNull(nextNotificationAt),
      'snoozedUntil': IpModelUtils.timestampOrNull(snoozedUntil),
      'mutedAt': IpModelUtils.timestampOrNull(mutedAt),
      'acknowledgedAt': IpModelUtils.timestampOrNull(acknowledgedAt),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'resolvedAt': IpModelUtils.timestampOrNull(resolvedAt),
      'reopenedAt': IpModelUtils.timestampOrNull(reopenedAt),
      'disabledAt': IpModelUtils.timestampOrNull(disabledAt),
      'notes': IpModelUtils.cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': IpModelUtils.timestampOrNull(updatedAt),
      'updatedBy': IpModelUtils.cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Map<String, dynamic> toUpdateMap({required String actorId}) {
    final cleanedActorId = actorId.trim();

    if (cleanedActorId.isEmpty) {
      throw ArgumentError.value(
        actorId,
        'actorId',
        'Güncelleme aktörü boş olamaz.',
      );
    }

    final map = toMap();
    map.remove('tenantId');
    map.remove('brandId');
    map.remove('tradeSecretId');
    map.remove('sourceRecordId');
    map.remove('ruleCode');
    map.remove('createdAt');
    map.remove('createdBy');
    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = cleanedActorId;
    return map;
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        ruleCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get hasRecipients {
    return recipientUserIds.isNotEmpty ||
        recipientRoleIds.isNotEmpty ||
        recipientTeamIds.isNotEmpty;
  }

  bool get isCurrentlySnoozed {
    final until = snoozedUntil;
    return status == IpTradeSecretAlertStatus.snoozed &&
        until != null &&
        until.isAfter(DateTime.now().toUtc());
  }

  bool get requiresImmediateEscalation {
    return severity == IpTradeSecretAlertSeverity.critical ||
        managementEscalationRequired ||
        legalEscalationRequired ||
        securityEscalationRequired;
  }

  bool get shouldAppearOnAlertDashboard {
    return status == IpTradeSecretAlertStatus.triggered ||
        status == IpTradeSecretAlertStatus.acknowledged ||
        status == IpTradeSecretAlertStatus.escalated ||
        status == IpTradeSecretAlertStatus.reopened ||
        requiresImmediateEscalation;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır alarm kuralının zorunlu kimlik alanları eksik.',
      );
    }

    if (active && !hasRecipients) {
      throw StateError(
        'Aktif alarm kuralında en az bir bildirim alıcısı zorunludur.',
      );
    }

    if (sourceType != IpTradeSecretAlertSourceType.other &&
        (sourceRecordId == null || sourceRecordId!.trim().isEmpty)) {
      throw StateError(
        'Kaynak türü diğer değilse kaynak kayıt kimliği zorunludur.',
      );
    }

    if ((triggerType == IpTradeSecretAlertTriggerType.scoreBelowThreshold ||
            triggerType == IpTradeSecretAlertTriggerType.countAboveThreshold) &&
        (thresholdValue == null ||
            thresholdUnit == null ||
            thresholdUnit!.trim().isEmpty)) {
      throw StateError(
        'Eşik tabanlı alarmda eşik değeri ve birimi zorunludur.',
      );
    }

    if (repeatEnabled &&
        (repeatIntervalMinutes == null ||
            repeatIntervalMinutes! <= 0 ||
            maxRepeatCount == null ||
            maxRepeatCount! <= 0)) {
      throw StateError(
        'Tekrarlayan alarmda tekrar aralığı ve azami tekrar sayısı zorunludur.',
      );
    }

    if (status == IpTradeSecretAlertStatus.triggered && triggeredAt == null) {
      throw StateError('Tetiklenen alarmda tetiklenme tarihi zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.acknowledged &&
        (acknowledgedAt == null ||
            acknowledgedBy == null ||
            acknowledgedBy!.trim().isEmpty)) {
      throw StateError('Kabul edilen alarmda kabul eden ve tarih zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.snoozed &&
        (snoozedUntil == null ||
            snoozeMinutes == null ||
            snoozeMinutes! <= 0)) {
      throw StateError(
        'Ertelenen alarmda erteleme süresi ve bitiş tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretAlertStatus.muted &&
        (mutedAt == null || muteReason == null || muteReason!.trim().isEmpty)) {
      throw StateError('Susturulan alarmda tarih ve gerekçe zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.escalated && escalatedAt == null) {
      throw StateError('Yükseltilen alarmda yükseltme tarihi zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.resolved &&
        (resolvedAt == null ||
            resolvedBy == null ||
            resolvedBy!.trim().isEmpty)) {
      throw StateError('Çözülen alarmda çözen kişi ve tarih zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.reopened &&
        (reopenedAt == null ||
            reopenedBy == null ||
            reopenedBy!.trim().isEmpty)) {
      throw StateError('Yeniden açılan alarmda açan kişi ve tarih zorunludur.');
    }

    if (status == IpTradeSecretAlertStatus.disabled &&
        (active || disabledAt == null)) {
      throw StateError(
        'Devre dışı alarmda active false ve devre dışı bırakma tarihi zorunludur.',
      );
    }

    if (falsePositive &&
        (falsePositiveReason == null || falsePositiveReason!.trim().isEmpty)) {
      throw StateError('Yanlış pozitif alarmda gerekçe zorunludur.');
    }

    if (autoEscalationEnabled &&
        escalationUserIds.isEmpty &&
        !managementEscalationRequired &&
        !legalEscalationRequired &&
        !securityEscalationRequired) {
      throw StateError(
        'Otomatik yükseltmede en az bir yükseltme hedefi zorunludur.',
      );
    }

    const prohibitedKeys = <String>{
      'formulaContent',
      'recipeContent',
      'secretContent',
      'plaintextSecret',
      'rawFormula',
      'rawRecipe',
      'sourceCodeContent',
      'algorithmContent',
      'datasetContent',
      'componentContent',
      'documentContent',
      'attachmentContent',
      'decryptionKey',
      'encryptionKey',
      'password',
      'credential',
      'accessToken',
      'privateKey',
    };

    final leakedKeys = metadata.keys
        .where(prohibitedKeys.contains)
        .toList(growable: false);

    if (leakedKeys.isNotEmpty) {
      throw StateError(
        'Ticari sır içeriği veya güvenlik anahtarı metadata alanında '
        'tutulamaz: ${leakedKeys.join(', ')}',
      );
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<String> _cleanList(List<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static int? _nullableNonNegativeInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }

    return null;
  }
}
