import 'package:flutter_test/flutter_test.dart';

import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_event_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/signal_rule_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/signal_rule_engine.dart';

void main() {
  group('SignalRuleEngine', () {
    test('aktif ve eşleşen kural için sinyal üretir', () {
      final event = _event();

      final rule = _rule(
        id: 'rule_1',
        name: 'Yüksek fiyat düşüşü',
        eventTypes: const <MonitoringEventType>[
          MonitoringEventType.priceDecreased,
        ],
        conditions: const <SignalRuleConditionModel>[
          SignalRuleConditionModel(
            field: 'changeRate',
            operator: MonitoringSignalRuleOperator.lessThanOrEqual,
            value: -0.30,
          ),
        ],
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, hasLength(1));

      final signal = signals.single;

      expect(signal.ruleId, 'rule_1');
      expect(signal.eventId, 'event_1');
      expect(signal.signalLevel, MonitoringSignalLevel.high);
      expect(signal.status, MonitoringSignalStatus.newSignal);
      expect(
        signal.forwardingStatus,
        MonitoringSignalForwardingStatus.notForwarded,
      );
      expect(signal.title, 'Yüksek fiyat düşüşü');
    });

    test('pasif kural için sinyal üretmez', () {
      final event = _event();

      final rule = _rule(
        id: 'rule_paused',
        name: 'Duraklatılmış kural',
        status: MonitoringSignalRuleStatus.paused,
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, isEmpty);
    });

    test('koşul eşleşmezse sinyal üretmez', () {
      final event = _event(changeRate: -0.10);

      final rule = _rule(
        id: 'rule_threshold',
        name: 'Yüzde otuz düşüş',
        conditions: const <SignalRuleConditionModel>[
          SignalRuleConditionModel(
            field: 'changeRate',
            operator: MonitoringSignalRuleOperator.lessThanOrEqual,
            value: -0.30,
          ),
        ],
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, isEmpty);
    });

    test('yüksek öncelikli kuralı önce değerlendirir', () {
      final event = _event();

      final lowRule = _rule(
        id: 'rule_low',
        name: 'Düşük öncelik',
        priority: MonitoringPriority.low,
      );

      final highRule = _rule(
        id: 'rule_high',
        name: 'Yüksek öncelik',
        priority: MonitoringPriority.high,
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[lowRule, highRule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, hasLength(2));
      expect(signals.first.ruleId, 'rule_high');
      expect(signals.last.ruleId, 'rule_low');
    });

    test('stopOnMatch sonraki kuralları durdurur', () {
      final event = _event();

      final stoppingRule = _rule(
        id: 'rule_stop',
        name: 'Durduran kural',
        priority: MonitoringPriority.high,
        stopOnMatch: true,
      );

      final secondRule = _rule(
        id: 'rule_second',
        name: 'İkinci kural',
        priority: MonitoringPriority.low,
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[secondRule, stoppingRule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, hasLength(1));
      expect(signals.single.ruleId, 'rule_stop');
    });

    test('farklı tenant kuralını yok sayar', () {
      final event = _event();

      final rule = _rule(
        id: 'rule_other_tenant',
        name: 'Başka tenant',
        tenantId: 'tenant_2',
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, isEmpty);
    });

    test('kaynak kapsamı dışındaki kuralı yok sayar', () {
      final event = _event();

      final rule = _rule(
        id: 'rule_other_source',
        name: 'Başka kaynak',
        sourceIds: const <String>['source_2'],
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, isEmpty);
    });

    test('başlık ve özet şablonlarını doldurur', () {
      final event = _event();

      final rule = _rule(
        id: 'rule_template',
        name: 'Şablon kuralı',
        signalTitleTemplate: '{{eventType}} - {{sourceId}}',
        signalSummaryTemplate:
            '{{oldValue}} değerinden {{newValue}} değerine değişti.',
      );

      final signals = SignalRuleEngine.evaluate(
        event: event,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10),
      );

      expect(signals, hasLength(1));
      expect(signals.single.title, 'price_decreased - source_1');
      expect(signals.single.summary, '100.0 değerinden 60.0 değerine değişti.');
    });
  });
}

MonitoringEventModel _event({double changeRate = -0.40}) {
  final detectedAt = DateTime.utc(2026, 7, 4, 9);

  return MonitoringEventModel(
    id: 'event_1',
    tenantId: 'tenant_1',
    brandId: 'brand_1',
    sourceId: 'source_1',
    pageId: 'page_1',
    listingId: 'listing_1',
    sellerId: 'seller_1',
    storeId: 'store_1',
    eventType: MonitoringEventType.priceDecreased,
    eventCategory: MonitoringEventCategory.price,
    previousSnapshotId: 'snapshot_previous',
    currentSnapshotId: 'snapshot_current',
    oldValue: 100.0,
    newValue: 60.0,
    changeRate: changeRate,
    severity: MonitoringEventSeverity.high,
    status: MonitoringEventStatus.newEvent,
    summary: 'Fiyat önemli ölçüde düştü.',
    detectedAt: detectedAt,
    createdBySystem: true,
    createdAt: detectedAt,
  );
}

SignalRuleModel _rule({
  required String id,
  required String name,
  String tenantId = 'tenant_1',
  MonitoringSignalRuleStatus status = MonitoringSignalRuleStatus.active,
  MonitoringPriority priority = MonitoringPriority.normal,
  List<MonitoringEventType> eventTypes = const <MonitoringEventType>[
    MonitoringEventType.priceDecreased,
  ],
  List<String> sourceIds = const <String>[],
  List<SignalRuleConditionModel> conditions =
      const <SignalRuleConditionModel>[],
  MonitoringSignalLevel signalLevel = MonitoringSignalLevel.high,
  bool stopOnMatch = false,
  String? signalTitleTemplate,
  String? signalSummaryTemplate,
}) {
  return SignalRuleModel(
    id: id,
    tenantId: tenantId,
    brandId: 'brand_1',
    name: name,
    eventTypes: eventTypes,
    sourceIds: sourceIds,
    conditions: conditions,
    signalLevel: signalLevel,
    status: status,
    priority: priority,
    signalTitleTemplate: signalTitleTemplate,
    signalSummaryTemplate: signalSummaryTemplate,
    stopOnMatch: stopOnMatch,
    createdAt: DateTime.utc(2026, 7, 4, 8),
    createdBy: 'system',
  );
}
