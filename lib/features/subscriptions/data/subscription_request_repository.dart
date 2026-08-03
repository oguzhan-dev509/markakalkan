import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/features/subscriptions/domain/subscription_request_models.dart';

typedef SubscriptionServiceRequestCallable =
    Future<Object?> Function(String callableName, Map<String, Object?> payload);

abstract interface class SubscriptionServiceRequestRepository {
  Future<SubscriptionServiceRequestResult> create(
    CreateSubscriptionServiceRequestCommand command,
  );
}

final class SubscriptionServiceRequestFailure implements Exception {
  const SubscriptionServiceRequestFailure({
    required this.code,
    required this.message,
    required this.retryable,
    this.details,
  });

  final String code;
  final String message;
  final bool retryable;
  final Object? details;

  @override
  String toString() => 'SubscriptionServiceRequestFailure($code)';
}

final class CallableSubscriptionServiceRequestRepository
    implements SubscriptionServiceRequestRepository {
  CallableSubscriptionServiceRequestRepository({
    FirebaseFunctions? functions,
    Future<void> Function()? ensureAppCheckReady,
    SubscriptionServiceRequestCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable;

  static const String callableName = 'createSubscriptionServiceRequest';

  final FirebaseFunctions? _functions;
  final Future<void> Function() _ensureAppCheckReady;
  final SubscriptionServiceRequestCallable? _callable;

  @override
  Future<SubscriptionServiceRequestResult> create(
    CreateSubscriptionServiceRequestCommand command,
  ) async {
    try {
      await _ensureAppCheckReady();
      final callable = _callable;
      final value = callable == null
          ? (await _functions!
                    .httpsCallable(callableName)
                    .call<Object?>(command.toMap()))
                .data
          : await callable(callableName, command.toMap());

      return SubscriptionServiceRequestResult.fromValue(value);
    } on SubscriptionServiceRequestFailure {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw SubscriptionServiceRequestFailure(
        code: error.code,
        message: _firebaseMessage(error),
        retryable: _retryableCodes.contains(error.code),
        details: error.details,
      );
    } on AppCheckUnavailableException catch (error) {
      throw SubscriptionServiceRequestFailure(
        code: 'app-check-unavailable',
        message:
            'Güvenlik doğrulaması hazırlanamadı. Sayfayı yenileyip tekrar deneyin.',
        retryable: true,
        details: error.runtimeType.toString(),
      );
    } on FormatException catch (error) {
      throw SubscriptionServiceRequestFailure(
        code: 'invalid-response',
        message: error.message,
        retryable: false,
      );
    } catch (_) {
      throw const SubscriptionServiceRequestFailure(
        code: 'client-internal',
        message: 'Abonelik talebi güvenli biçimde oluşturulamadı.',
        retryable: false,
      );
    }
  }

  static String _firebaseMessage(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty && error.code != 'internal') {
      return message;
    }
    return switch (error.code) {
      'unauthenticated' => 'Abonelik talebi için oturum açmanız gerekir.',
      'failed-precondition' => 'Güvenlik doğrulaması tamamlanamadı.',
      'invalid-argument' => 'Abonelik talebi bilgileri geçersiz.',
      'aborted' => 'Bu talep başka bir içerikle daha önce kullanılmış.',
      'resource-exhausted' =>
        'İşlem sınırına ulaşıldı. Bir süre sonra yeniden deneyin.',
      'unavailable' => 'Abonelik hizmeti geçici olarak kullanılamıyor.',
      'deadline-exceeded' => 'Abonelik talebi zaman aşımına uğradı.',
      _ => 'Abonelik talebi güvenli biçimde oluşturulamadı.',
    };
  }

  static const Set<String> _retryableCodes = <String>{
    'aborted',
    'deadline-exceeded',
    'resource-exhausted',
    'unavailable',
  };
}
