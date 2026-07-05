import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_shield_page.dart';

void main() {
  testWidgets('ticari sır kalkanı temel panelleri gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IpTradeSecretShieldPage()));

    expect(find.text('Formül ve Ticari Sır Kalkanı'), findsOneWidget);
    expect(find.text('Dayanıklılık\nEndeksi'), findsOneWidget);
    expect(find.text('Risk Skoru'), findsOneWidget);
    expect(find.text('Koruma Skoru'), findsOneWidget);
    expect(find.text('Savunulabilirlik'), findsOneWidget);
    expect(find.text('Kritik Açıklar'), findsOneWidget);
    expect(find.text('Öncelikli Müdahaleler'), findsOneWidget);
    expect(find.text('Formül ve Bileşen Envanteri'), findsOneWidget);
    expect(find.text('Yönetim Kararları'), findsOneWidget);
  });
}
