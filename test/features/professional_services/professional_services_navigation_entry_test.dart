import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';

void main() {
  testWidgets(
    'corporate hub exposes the Professional Services entry and injected route',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateHubPage(
            userEmailProvider: () => 'test@example.com',
            professionalServicesRouteOpener: (context) async {
              opened = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byKey(const ValueKey('professional-services-action'));
      expect(action, findsOneWidget);
      expect(find.text('Profesyonel Hizmetler Merkezi'), findsOneWidget);

      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();

      expect(opened, isTrue);
    },
  );
}
