import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/professional_services/data/professional_services_callable_client.dart';
import 'package:markakalkan/features/professional_services/domain/professional_service_models.dart';
import 'package:markakalkan/features/professional_services/presentation/professional_services_controller.dart';

class FakeProfessionalServicesGateway implements ProfessionalServicesGateway {
  FakeProfessionalServicesGateway({this.result, this.failure, this.pending});

  final ProfessionalServiceResult? result;
  final ProfessionalServicesClientFailure? failure;
  final Completer<ProfessionalServiceResult>? pending;
  final commands = <ProfessionalServiceCommand>[];

  @override
  Future<ProfessionalServiceResult> execute(
    ProfessionalServiceCommand command,
  ) async {
    commands.add(command);
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return result ??
        ProfessionalServiceResult.fromValue(<String, Object?>{
          'resultType': 'professional_service_request',
          'resultId': 'psr-1',
          'idempotentReplay': false,
        });
  }
}

void main() {
  test('controller selects operation without calling production boundary', () {
    final gateway = FakeProfessionalServicesGateway();
    final controller = ProfessionalServicesController(gateway: gateway);

    controller.selectOperation(ProfessionalServiceOperation.recordAgentReview);

    expect(
      controller.selectedOperation,
      ProfessionalServiceOperation.recordAgentReview,
    );
    expect(controller.status, ProfessionalServicesControllerStatus.idle);
    expect(gateway.commands, isEmpty);
  });

  test('controller exposes success result', () async {
    final gateway = FakeProfessionalServicesGateway();
    final controller = ProfessionalServicesController(gateway: gateway);
    final command = ProfessionalServiceCommand(
      operation: ProfessionalServiceOperation.createServiceRequest,
      payload: <String, Object?>{
        'contractVersion': 'command-v1',
        'requestId': 'request-1',
        'idempotencyKey': 'idem-1',
        'serviceRequest': <String, Object?>{'title': 'Test'},
      },
    );

    await controller.execute(command);

    expect(controller.status, ProfessionalServicesControllerStatus.succeeded);
    expect(controller.result?.resultId, 'psr-1');
    expect(gateway.commands, <ProfessionalServiceCommand>[command]);
  });

  test('controller prevents a concurrent duplicate execution', () async {
    final completer = Completer<ProfessionalServiceResult>();
    final gateway = FakeProfessionalServicesGateway(pending: completer);
    final controller = ProfessionalServicesController(gateway: gateway);
    final command = ProfessionalServiceCommand(
      operation: ProfessionalServiceOperation.startAgentRun,
      payload: <String, Object?>{
        'contractVersion': 'command-v1',
        'requestId': 'request-1',
        'idempotencyKey': 'idem-1',
      },
    );

    final first = controller.execute(command);
    final second = controller.execute(command);
    expect(gateway.commands, hasLength(1));

    completer.complete(
      ProfessionalServiceResult.fromValue(<String, Object?>{
        'resultType': 'professional_agent_run',
        'resultId': 'par-1',
        'idempotentReplay': false,
      }),
    );
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.commands, hasLength(1));
    expect(controller.status, ProfessionalServicesControllerStatus.succeeded);
  });

  test('controller exposes controlled client failure', () async {
    final gateway = FakeProfessionalServicesGateway(
      failure: const ProfessionalServicesClientFailure(
        code: 'permission-denied',
        message: 'Yetki yok.',
      ),
    );
    final controller = ProfessionalServicesController(gateway: gateway);
    final command = ProfessionalServiceCommand(
      operation: ProfessionalServiceOperation.publishAgentOutput,
      payload: <String, Object?>{
        'contractVersion': 'command-v1',
        'requestId': 'request-1',
        'idempotencyKey': 'idem-1',
      },
    );

    await controller.execute(command);

    expect(controller.status, ProfessionalServicesControllerStatus.failed);
    expect(controller.failure?.code, 'permission-denied');
    expect(controller.failure?.message, 'Yetki yok.');
  });
}
