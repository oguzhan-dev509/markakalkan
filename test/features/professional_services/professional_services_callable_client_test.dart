import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/professional_services/data/professional_services_callable_client.dart';
import 'package:markakalkan/features/professional_services/domain/professional_service_models.dart';

void main() {
  test('callable contract locks region and eight operation names', () {
    expect(ProfessionalServicesCallableContract.region, 'europe-west3');
    expect(ProfessionalServicesCallableContract.callableNames, <String>[
      'createProfessionalServiceRequest',
      'transitionProfessionalServiceRequest',
      'createProfessionalServiceEngagement',
      'createProfessionalServiceAssignment',
      'startProfessionalAgentRun',
      'recordProfessionalAgentOutput',
      'recordProfessionalAgentReview',
      'publishProfessionalAgentOutput',
    ]);
    expect(ProfessionalServiceOperation.values, hasLength(8));
  });

  test('injected transport receives exact callable name and payload', () async {
    String? receivedName;
    Map<String, Object?>? receivedPayload;

    final client = FirebaseProfessionalServicesCallableClient(
      transport: (callableName, payload) async {
        receivedName = callableName;
        receivedPayload = payload;
        return <String, Object?>{
          'resultType': 'professional_service_request',
          'resultId': 'psr-1',
          'idempotentReplay': false,
        };
      },
    );

    final result = await client.createServiceRequest(<String, Object?>{
      'contractVersion': 'professional-service-request-create-command-v1',
      'requestId': 'request-1',
      'idempotencyKey': 'idem-1',
      'serviceRequest': <String, Object?>{'title': 'Hukuki ön değerlendirme'},
    });

    expect(receivedName, 'createProfessionalServiceRequest');
    expect(receivedPayload?['requestId'], 'request-1');
    expect(result.resultType, 'professional_service_request');
    expect(result.resultId, 'psr-1');
    expect(result.idempotentReplay, isFalse);
  });

  test('client actor fields are rejected recursively before transport', () {
    expect(
      () => ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.createServiceAssignment,
        payload: <String, Object?>{
          'serviceAssignment': <String, Object?>{
            'providerId': 'provider-1',
            'assignedByUid': 'spoofed-user',
          },
        },
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('callable response accepts object-key maps and freezes payload', () {
    final result = ProfessionalServiceResult.fromValue(<Object?, Object?>{
      'resultType': 'professional_agent_run',
      'resultId': 'par-1',
      'idempotentReplay': true,
      'agentRun': <Object?, Object?>{'status': 'running'},
    });

    expect(result.resultType, 'professional_agent_run');
    expect(result.idempotentReplay, isTrue);
    expect(
      () => result.payload['newField'] = 'forbidden',
      throwsUnsupportedError,
    );
  });
}
