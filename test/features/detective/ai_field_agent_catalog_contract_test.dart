import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI field catalog matches the canonical n8n twelve-agent contract', () {
    final models = File(
      'lib/features/detective/data/ai_field_operation_models.dart',
    ).readAsStringSync();
    final backend = File(
      'functions/digital_detective/digital_detective_result.js',
    ).readAsStringSync();
    const codes = <String>[
      'task_planner',
      'digital_field_scanner',
      'page_change_monitor',
      'visual_matcher',
      'text_language_analyzer',
      'seller_entity_linker',
      'domain_technical_trace',
      'price_commercial_pattern',
      'geographic_channel_analyzer',
      'evidence_validator',
      'risk_prioritizer',
      'reporting_intervention_preparer',
    ];

    for (final code in codes) {
      expect(models, contains("id: '$code'"));
      expect(backend, contains('code: "$code"'));
    }
    expect(RegExp(r"id: '").allMatches(models), hasLength(12));
    expect(models, isNot(contains("id: 'human_expert_gate'")));
  });

  test('AI field hub presents truthful non-clickable pipeline semantics', () {
    final hub = File(
      'lib/features/detective/presentation/ai_field_detectives_hub_page.dart',
    ).readAsStringSync();

    expect(hub, contains('Operasyon zincirinde etkin'));
    expect(hub, contains('kartlar bağımsız işlem başlatmaz'));
    expect(hub, contains('Ajan ilerlemesini ve sonuçları gör'));
    expect(hub, contains('AppRouter.openAiFieldOperations(context)'));
    expect(hub, contains('Raporlama ve Müdahale Hazırlama Ajanı'));
    expect(hub, isNot(contains('Ajan altyapısı hazırlanıyor')));
    expect(hub, isNot(contains('Geliştirme önceliğinde')));
    expect(hub, contains('insan uzman onayı olmadan kesinleştirilmez'));
  });

  test('AI field operation results have a dedicated truthful UI route', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    final page = File(
      'lib/features/detective/presentation/ai_field_operations_page.dart',
    ).readAsStringSync();
    final models = File(
      'lib/features/detective/data/ai_field_operation_models.dart',
    ).readAsStringSync();

    expect(router, contains('openAiFieldOperations'));
    expect(page, contains('watchOperations()'));
    expect(page, contains('watchAgentTasks(operation.id)'));
    expect(page, contains('Ajan çıktısı alındı'));
    expect(page, contains('İnsan uzman onayı ayrı bir karar kapısıdır'));
    expect(models, contains('processedAgentCount'));
    expect(models, contains('completedAgentCount'));
    expect(models, contains('failedAgentCount'));
  });
}
