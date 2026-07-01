import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/app/app.dart';

void main() {
  testWidgets('MarkaKalkan ana sayfası açılır', (tester) async {
    await tester.pumpWidget(const MarkaKalkanApp());
    await tester.pumpAndSettle();

    expect(find.text('MarkaKalkan'), findsOneWidget);
    expect(
      find.textContaining('Müşteriniz orijinalini bilsin'),
      findsOneWidget,
    );
  });
}
