import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Markalarim ve izlenebilirlik ayridir', () {
    final hub = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();
    expect(hub, contains("AppRouter.openBrandPortfolio(context)"));
    expect(hub, contains("AppRouter.openTraceabilityHub(context)"));
  });
  test('Izlenebilirlikte dijital pazar karti yoktur', () {
    final d = File(
      'lib/features/dashboard/presentation/brand_dashboard_page.dart',
    ).readAsStringSync();
    expect(d, isNot(contains("title: 'Dijital Pazar İzleme'")));
    expect(d, isNot(contains('openDijitalPazarIzleme(context)')));
  });
  test('Bagimsiz dijital pazar karti korunur', () {
    final hub = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();
    expect(hub, contains("id: 'digital_market'"));
    expect(hub, contains("title: 'Dijital Pazar İzleme'"));
  });
}
