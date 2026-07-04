import '../constants/monitoring_enums.dart';
import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/signal_rule_model.dart';

abstract final class SignalRuleEngine {
  static List<MonitoringSignalModel> evaluate({
    required MonitoringEventModel event,
    required List<SignalRuleModel> rules,
    required DateTime evaluatedAt,
  }) {
    final orderedRules = List<SignalRuleModel>.from(rules)
      ..sort(
        (first, second) => _priorityRank(
          first.priority,
        ).compareTo(_priorityRank(second.priority)),
      );

    final signals = <MonitoringSignalModel>[];

    for (final rule in orderedRules) {
      if (!_ruleApplies(event: event, rule: rule)) {
        continue;
      }

      signals.add(
        _buildSignal(event: event, rule: rule, evaluatedAt: evaluatedAt),
      );

      if (rule.stopOnMatch) {
        break;
      }
    }

    return List<MonitoringSignalModel>.unmodifiable(signals);
  }

  static bool _ruleApplies({
    required MonitoringEventModel event,
    required SignalRuleModel rule,
  }) {
    if (!rule.isActive) {
      return false;
    }

    if (rule.tenantId != event.tenantId) {
      return false;
    }

    if (rule.brandId != null &&
        rule.brandId!.trim().isNotEmpty &&
        rule.brandId != event.brandId) {
      return false;
    }

    if (!rule.appliesToSource(event.sourceId)) {
      return false;
    }

    if (!rule.appliesToEventType(event.eventType)) {
      return false;
    }

    for (final condition in rule.conditions) {
      if (!_conditionMatches(event: event, condition: condition)) {
        return false;
      }
    }

    return true;
  }

  static bool _conditionMatches({
    required MonitoringEventModel event,
    required SignalRuleConditionModel condition,
  }) {
    final actualValue = _eventFieldValue(event: event, field: condition.field);

    switch (condition.operator) {
      case MonitoringSignalRuleOperator.equals:
        return _equals(actualValue, condition.value);

      case MonitoringSignalRuleOperator.notEquals:
        return !_equals(actualValue, condition.value);

      case MonitoringSignalRuleOperator.greaterThan:
        return _compareNumbers(
          actualValue,
          condition.value,
          (actual, expected) => actual > expected,
        );

      case MonitoringSignalRuleOperator.greaterThanOrEqual:
        return _compareNumbers(
          actualValue,
          condition.value,
          (actual, expected) => actual >= expected,
        );

      case MonitoringSignalRuleOperator.lessThan:
        return _compareNumbers(
          actualValue,
          condition.value,
          (actual, expected) => actual < expected,
        );

      case MonitoringSignalRuleOperator.lessThanOrEqual:
        return _compareNumbers(
          actualValue,
          condition.value,
          (actual, expected) => actual <= expected,
        );

      case MonitoringSignalRuleOperator.contains:
        return _contains(actualValue, condition.value);

      case MonitoringSignalRuleOperator.inList:
        return _inList(actualValue, condition.value);

      case MonitoringSignalRuleOperator.exists:
        return _existsMatches(actualValue, condition.value);
    }
  }

  static dynamic _eventFieldValue({
    required MonitoringEventModel event,
    required String field,
  }) {
    switch (field.trim()) {
      case 'tenantId':
        return event.tenantId;
      case 'brandId':
        return event.brandId;
      case 'sourceId':
        return event.sourceId;
      case 'pageId':
        return event.pageId;
      case 'listingId':
        return event.listingId;
      case 'sellerId':
        return event.sellerId;
      case 'storeId':
        return event.storeId;
      case 'eventType':
        return event.eventType.value;
      case 'eventCategory':
        return event.eventCategory.value;
      case 'severity':
        return event.severity.value;
      case 'status':
        return event.status.value;
      case 'oldValue':
        return event.oldValue;
      case 'newValue':
        return event.newValue;
      case 'changeRate':
        return event.changeRate;
      case 'summary':
        return event.summary;
      case 'createdBySystem':
        return event.createdBySystem;
      default:
        return null;
    }
  }

  static MonitoringSignalModel _buildSignal({
    required MonitoringEventModel event,
    required SignalRuleModel rule,
    required DateTime evaluatedAt,
  }) {
    final title = _renderTemplate(
      template: rule.signalTitleTemplate,
      fallback: _defaultTitle(event: event, rule: rule),
      event: event,
      rule: rule,
    );

    final summary = _renderTemplate(
      template: rule.signalSummaryTemplate,
      fallback: event.summary ?? 'İzleme olayı sinyal kuralıyla eşleşti.',
      event: event,
      rule: rule,
    );

    return MonitoringSignalModel(
      id: '',
      tenantId: event.tenantId,
      brandId: event.brandId,
      sourceId: event.sourceId,
      pageId: event.pageId,
      listingId: event.listingId,
      sellerId: event.sellerId,
      storeId: event.storeId,
      eventId: event.id,
      ruleId: rule.id,
      ruleName: rule.name,
      eventType: event.eventType,
      eventCategory: event.eventCategory,
      signalLevel: rule.signalLevel,
      status: MonitoringSignalStatus.newSignal,
      forwardingStatus: MonitoringSignalForwardingStatus.notForwarded,
      title: title,
      summary: summary,
      detectedAt: event.detectedAt,
      createdAt: evaluatedAt,
    );
  }

  static String _defaultTitle({
    required MonitoringEventModel event,
    required SignalRuleModel rule,
  }) {
    final ruleName = rule.name.trim();

    if (ruleName.isNotEmpty) {
      return ruleName;
    }

    return 'Yeni ${event.eventType.value} sinyali';
  }

  static String _renderTemplate({
    required String? template,
    required String fallback,
    required MonitoringEventModel event,
    required SignalRuleModel rule,
  }) {
    var rendered = template?.trim();

    if (rendered == null || rendered.isEmpty) {
      rendered = fallback.trim();
    }

    final replacements = <String, String>{
      '{{ruleName}}': rule.name,
      '{{eventType}}': event.eventType.value,
      '{{eventCategory}}': event.eventCategory.value,
      '{{severity}}': event.severity.value,
      '{{sourceId}}': event.sourceId,
      '{{pageId}}': event.pageId,
      '{{listingId}}': event.listingId ?? '',
      '{{sellerId}}': event.sellerId ?? '',
      '{{storeId}}': event.storeId ?? '',
      '{{oldValue}}': _displayValue(event.oldValue),
      '{{newValue}}': _displayValue(event.newValue),
      '{{changeRate}}': event.changeRate?.toString() ?? '',
      '{{eventSummary}}': event.summary ?? '',
    };

    for (final entry in replacements.entries) {
      rendered = rendered!.replaceAll(entry.key, entry.value);
    }

    return rendered!.trim();
  }

  static bool _equals(dynamic actualValue, dynamic expectedValue) {
    if (actualValue == null || expectedValue == null) {
      return actualValue == expectedValue;
    }

    final actualNumber = _numberFromValue(actualValue);
    final expectedNumber = _numberFromValue(expectedValue);

    if (actualNumber != null && expectedNumber != null) {
      return actualNumber == expectedNumber;
    }

    if (actualValue is bool || expectedValue is bool) {
      return _boolFromValue(actualValue) == _boolFromValue(expectedValue);
    }

    return _normalize(actualValue) == _normalize(expectedValue);
  }

  static bool _compareNumbers(
    dynamic actualValue,
    dynamic expectedValue,
    bool Function(double actual, double expected) comparator,
  ) {
    final actualNumber = _numberFromValue(actualValue);
    final expectedNumber = _numberFromValue(expectedValue);

    if (actualNumber == null || expectedNumber == null) {
      return false;
    }

    return comparator(actualNumber, expectedNumber);
  }

  static bool _contains(dynamic actualValue, dynamic expectedValue) {
    if (actualValue == null || expectedValue == null) {
      return false;
    }

    if (actualValue is Iterable) {
      return actualValue.any((item) => _equals(item, expectedValue));
    }

    return _normalize(actualValue).contains(_normalize(expectedValue));
  }

  static bool _inList(dynamic actualValue, dynamic expectedValue) {
    if (expectedValue is! Iterable) {
      return false;
    }

    return expectedValue.any((item) => _equals(actualValue, item));
  }

  static bool _existsMatches(dynamic actualValue, dynamic expectedValue) {
    final shouldExist = expectedValue == null
        ? true
        : _boolFromValue(expectedValue);

    final exists =
        actualValue != null &&
        (actualValue is! String || actualValue.trim().isNotEmpty) &&
        (actualValue is! Iterable || actualValue.isNotEmpty) &&
        (actualValue is! Map || actualValue.isNotEmpty);

    return shouldExist ? exists : !exists;
  }

  static double? _numberFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '');
  }

  static bool _boolFromValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();

    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'evet';
  }

  static String _normalize(dynamic value) {
    return value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  static String _displayValue(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is Iterable) {
      return value.join(', ');
    }

    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }

    return value.toString();
  }

  static int _priorityRank(MonitoringPriority priority) {
    switch (priority.value) {
      case 'critical':
        return 0;
      case 'high':
        return 1;
      case 'normal':
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 2;
    }
  }
}
