import 'package:cloud_functions/cloud_functions.dart';

import '../domain/professional_service_models.dart';

typedef ProfessionalServicesCallableTransport =
    Future<Object?> Function(String callableName, Map<String, Object?> payload);

abstract interface class ProfessionalServicesGateway {
  Future<ProfessionalServiceResult> execute(ProfessionalServiceCommand command);
}

class FirebaseProfessionalServicesCallableClient
    implements ProfessionalServicesGateway {
  FirebaseProfessionalServicesCallableClient({
    FirebaseFunctions? functions,
    ProfessionalServicesCallableTransport? transport,
  }) : _transport = transport ?? _firebaseTransport(functions);

  final ProfessionalServicesCallableTransport _transport;

  @override
  Future<ProfessionalServiceResult> execute(
    ProfessionalServiceCommand command,
  ) async {
    try {
      final value = await _transport(
        command.operation.callableName,
        command.toMap(),
      );
      return ProfessionalServiceResult.fromValue(value);
    } on FirebaseFunctionsException catch (error) {
      throw ProfessionalServicesClientFailure(
        code: error.code,
        message: error.message ?? _defaultMessage(error.code),
        details: error.details,
        retryable: _retryableCodes.contains(error.code),
      );
    } on ProfessionalServicesClientFailure {
      rethrow;
    } on FormatException catch (error) {
      throw ProfessionalServicesClientFailure(
        code: 'invalid-response',
        message: error.message,
      );
    } catch (_) {
      throw const ProfessionalServicesClientFailure(
        code: 'client-internal',
        message: 'Profesyonel Hizmetler işlemi tamamlanamadı.',
      );
    }
  }

  Future<ProfessionalServiceResult> createServiceRequest(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.createServiceRequest,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> transitionServiceRequest(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.transitionServiceRequest,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> createServiceEngagement(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.createServiceEngagement,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> createServiceAssignment(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.createServiceAssignment,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> startAgentRun(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.startAgentRun,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> recordAgentOutput(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.recordAgentOutput,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> recordAgentReview(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.recordAgentReview,
        payload: payload,
      ),
    );
  }

  Future<ProfessionalServiceResult> publishAgentOutput(
    Map<String, Object?> payload,
  ) {
    return execute(
      ProfessionalServiceCommand(
        operation: ProfessionalServiceOperation.publishAgentOutput,
        payload: payload,
      ),
    );
  }

  static ProfessionalServicesCallableTransport _firebaseTransport(
    FirebaseFunctions? value,
  ) {
    final functions =
        value ??
        FirebaseFunctions.instanceFor(
          region: ProfessionalServicesCallableContract.region,
        );

    return (callableName, payload) async {
      final response = await functions
          .httpsCallable(callableName)
          .call<Object?>(payload);
      return response.data;
    };
  }

  static String _defaultMessage(String code) {
    return switch (code) {
      'unauthenticated' => 'Oturum açmanız gerekir.',
      'failed-precondition' => 'İşlem ön koşulları sağlanmadı.',
      'permission-denied' => 'Bu işlem için yetkiniz bulunmuyor.',
      'invalid-argument' => 'Gönderilen işlem verileri geçersiz.',
      'not-found' => 'İstenen kayıt bulunamadı.',
      'already-exists' => 'Kayıt zaten mevcut.',
      'aborted' => 'Kayıt başka bir işlem nedeniyle değişti.',
      'resource-exhausted' => 'İşlem kotası geçici olarak doldu.',
      'unavailable' => 'Hizmet geçici olarak kullanılamıyor.',
      'deadline-exceeded' => 'İşlem zaman aşımına uğradı.',
      _ => 'Profesyonel Hizmetler işlemi tamamlanamadı.',
    };
  }

  static const Set<String> _retryableCodes = <String>{
    'aborted',
    'deadline-exceeded',
    'resource-exhausted',
    'unavailable',
  };
}
