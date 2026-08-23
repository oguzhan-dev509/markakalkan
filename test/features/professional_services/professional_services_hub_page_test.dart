import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/professional_services/data/professional_services_callable_client.dart';
import 'package:markakalkan/features/professional_services/domain/professional_service_models.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_controller.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_hub_page.dart';

class RecordingGateway implements ProfessionalServicesGateway {
  final commands = <ProfessionalServiceCommand>[];

  @override
  Future<ProfessionalServiceResult> execute(
    ProfessionalServiceCommand command,
  ) async {
    commands.add(command);
    return ProfessionalServiceResult.fromValue(<String, Object?>{
      'resultType': 'professional_service_request',
      'resultId': 'psr-1',
      'idempotentReplay': false,
    });
  }
}

void main() {
  test('route name is stable', () {
    expect(ProfessionalServicesHubPage.routeName, '/professional-services');
  });

  testWidgets('hub shows intro, workflow and eight callable boundaries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = RecordingGateway();
    final controller = ProfessionalServicesController(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalServicesHubPage(
          controller: controller,
          locale: const Locale('tr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('professional-services-intro-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('professional-services-workflow')),
      findsOneWidget,
    );
    expect(
      find.text('Uzmanlığı kontrollü operasyona dönüştürün.'),
      findsOneWidget,
    );

    for (final operation in ProfessionalServiceOperation.values) {
      expect(
        find.byKey(
          ValueKey('professional-service-capability-${operation.wireValue}'),
        ),
        findsOneWidget,
      );
    }
    expect(gateway.commands, isEmpty);
  });

  testWidgets('selecting a capability never executes a business command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = RecordingGateway();
    final controller = ProfessionalServicesController(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalServicesHubPage(
          controller: controller,
          locale: const Locale('tr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewCard = find.byKey(
      const ValueKey('professional-service-capability-record_agent_review'),
    );
    await tester.ensureVisible(reviewCard);
    await tester.tap(reviewCard);
    await tester.pumpAndSettle();

    expect(
      controller.selectedOperation,
      ProfessionalServiceOperation.recordAgentReview,
    );
    expect(find.text('Yetkili insan incelemesi'), findsWidgets);
    expect(gateway.commands, isEmpty);
  });

  testWidgets('selected transition form submits only after explicit action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = RecordingGateway();
    final controller = ProfessionalServicesController(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalServicesHubPage(
          controller: controller,
          locale: const Locale('tr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final transitionCard = find.byKey(
      const ValueKey(
        'professional-service-capability-transition_service_request',
      ),
    );
    await tester.ensureVisible(transitionCard);
    await tester.tap(transitionCard);
    await tester.pumpAndSettle();

    expect(gateway.commands, isEmpty);
    expect(
      find.byKey(
        const ValueKey(
          'professional-service-command-form-transition_service_request',
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(
        const ValueKey(
          'professional-service-field-transition_service_request-serviceRequestId',
        ),
      ),
      'psr-1',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'professional-service-field-transition_service_request-expectedVersion',
        ),
      ),
      '3',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'professional-service-field-transition_service_request-nextStatus',
        ),
      ),
      'scoping',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'professional-service-field-transition_service_request-reasonCode',
        ),
      ),
      'operator_update',
    );

    final submit = find.byKey(
      const ValueKey('professional-service-submit-transition_service_request'),
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(gateway.commands, hasLength(1));
    final command = gateway.commands.single;
    expect(
      command.operation,
      ProfessionalServiceOperation.transitionServiceRequest,
    );
    expect(
      command.payload['contractVersion'],
      'professional-service-request-transition-command-v1',
    );
    expect(command.payload['serviceRequestId'], 'psr-1');
    expect(command.payload['expectedVersion'], 3);
    expect(command.payload['nextStatus'], 'scoping');
    expect(command.payload['reasonCode'], 'operator_update');
    expect(command.payload.containsKey('actorUid'), isFalse);
    expect(controller.status, ProfessionalServicesControllerStatus.succeeded);
  });
}
