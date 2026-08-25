import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/detective/presentation/brand_detective_hub_page.dart';

void main() {
  Future<void> pumpHub(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BrandDetectiveHubPage()));
    await tester.pumpAndSettle();
  }

  void expectApprovedContent() {
    expect(find.text('Marka Dedektifi'), findsOneWidget);
    expect(find.text('Dijital Dedektif'), findsAtLeastNWidgets(2));
    expect(find.text('Mevcut durumu görün'), findsOneWidget);
    expect(find.text('12 Yapay Zekâ Ajanı'), findsOneWidget);
    expect(find.text('Marka kapsamınızı yönetin'), findsOneWidget);
    expect(find.text('Yeni 12-Ajan operasyonu'), findsOneWidget);
    expect(
      find.text('Markanızı yalnız doğrulamayın, izini de sürün.'),
      findsOneWidget,
    );
    expect(find.text('Dedektif Hizmetleri'), findsOneWidget);
    expect(find.text('Tüketici Dedektifi'), findsOneWidget);
    expect(find.text('Marka İstihbarat Raporu'), findsOneWidget);
    expect(find.text('Yapay Zekâ Saha Dedektifleri'), findsOneWidget);
  }

  testWidgets('approved Marka Dedektifi hub renders on desktop', (
    tester,
  ) async {
    await pumpHub(tester, size: const Size(1440, 1200));
    expectApprovedContent();
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved Marka Dedektifi hub renders on mobile', (tester) async {
    await pumpHub(tester, size: const Size(390, 844));
    expectApprovedContent();
    expect(tester.takeException(), isNull);
  });
}
