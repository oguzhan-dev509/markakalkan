import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/professional_services/data/professional_services_callable_client.dart';
import 'package:markakalkan/features/professional_services/domain/professional_service_models.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_controller.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_hub_page.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_strings.dart';

class _NoopGateway implements ProfessionalServicesGateway {
  final commands = <ProfessionalServiceCommand>[];

  @override
  Future<ProfessionalServiceResult> execute(
    ProfessionalServiceCommand command,
  ) async {
    commands.add(command);
    return ProfessionalServiceResult.fromValue(<String, Object?>{
      'resultType': 'professional_service_request',
      'resultId': 'psr-test',
      'idempotentReplay': false,
    });
  }
}

ProfessionalServicesController _controller(_NoopGateway gateway) {
  return ProfessionalServicesController(gateway: gateway);
}

void main() {
  test('unsupported locales fall back to Turkish', () {
    expect(
      ProfessionalServicesStrings.resolve(const Locale('de')).pageTitle,
      'Profesyonel Hizmetler Merkezi',
    );
  });

  testWidgets('English localization and accessibility semantics are exposed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _NoopGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalServicesHubPage(
          controller: _controller(gateway),
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Professional Services Center'), findsOneWidget);
    expect(
      find.text('Turn expertise into a controlled operation.'),
      findsOneWidget,
    );

    final semanticsWidget = tester.widget<Semantics>(
      find.byKey(
        const ValueKey(
          'professional-service-capability-semantics-create_service_request',
        ),
      ),
    );

    expect(semanticsWidget.properties.button, isTrue);
    expect(semanticsWidget.properties.label, 'Professional service request');
    expect(
      semanticsWidget.properties.hint,
      'Select this boundary. No business command will run.',
    );
    expect(gateway.commands, isEmpty);
  });

  testWidgets('capability grid adapts between narrow and wide layouts', (
    tester,
  ) async {
    final gateway = _NoopGateway();
    final controller = _controller(gateway);

    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalServicesHubPage(
          controller: controller,
          locale: const Locale('tr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byKey(
      const ValueKey('professional-service-capability-create_service_request'),
    );
    final second = find.byKey(
      const ValueKey(
        'professional-service-capability-transition_service_request',
      ),
    );

    final narrowFirst = tester.getTopLeft(first);
    final narrowSecond = tester.getTopLeft(second);
    expect(narrowSecond.dy, greaterThan(narrowFirst.dy));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1400, 2200);
    await tester.pumpAndSettle();

    final widePositions = ProfessionalServiceOperation.values
        .take(4)
        .map(
          (operation) => tester.getTopLeft(
            find.byKey(
              ValueKey(
                'professional-service-capability-${operation.wireValue}',
              ),
            ),
          ),
        )
        .toList();

    expect(widePositions.map((position) => position.dy).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
    expect(gateway.commands, isEmpty);
  });
}
