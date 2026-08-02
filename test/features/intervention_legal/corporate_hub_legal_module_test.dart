import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';

void main() {
  testWidgets('corporate hub exposes active Intervention and Legal route', (
    tester,
  ) async {
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateHubPage(
          userEmailProvider: () => 'test@example.com',
          interventionLegalRouteOpener: (_) async {
            openCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final legalCard = find.byKey(
      const ValueKey<String>('corporate-module-legal'),
    );
    expect(legalCard, findsOneWidget);

    final directAction = find.byKey(
      const ValueKey<String>('intervention-legal-action'),
    );
    expect(directAction, findsOneWidget);

    await tester.scrollUntilVisible(directAction, 500);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: legalCard, matching: find.text('Aktif')),
      findsOneWidget,
    );

    await tester.tap(directAction);
    await tester.pumpAndSettle();

    expect(openCalls, 1);
  });
}
