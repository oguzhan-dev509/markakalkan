import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

import 'risk_operations_models.dart';

typedef SharedRiskDryRunTransport =
    Future<Map<Object?, Object?>> Function(Map<String, Object> request);

enum SharedRiskDryRunOutcome { dryRunReady, blocked, conflict, failed }

class SharedRiskDryRunResult {
  const SharedRiskDryRunResult(this.outcome);

  final SharedRiskDryRunOutcome outcome;

  bool get succeeded => outcome == SharedRiskDryRunOutcome.dryRunReady;

  String get turkishMessage => switch (outcome) {
    SharedRiskDryRunOutcome.dryRunReady =>
      'Yazısız doğrulama başarılı. Ortak risk kaydı oluşturulmadı.',
    SharedRiskDryRunOutcome.blocked =>
      'Yazısız doğrulama şu anda güvenli biçimde kapalı.',
    SharedRiskDryRunOutcome.conflict =>
      'Kaynak kayıt değişti. Listeyi yenileyip yeniden inceleyin.',
    SharedRiskDryRunOutcome.failed =>
      'Yazısız doğrulama güvenli biçimde tamamlanamadı.',
  };
}

abstract interface class SharedRiskDryRunService {
  Future<SharedRiskDryRunResult> validate(RiskOperationItem item);
}

class CallableSharedRiskDryRunService implements SharedRiskDryRunService {
  CallableSharedRiskDryRunService({
    FirebaseFunctions? functions,
    SharedRiskDryRunTransport? transport,
    Random? random,
  }) : _transport = transport ?? _firebaseTransport(functions),
       _random = random ?? Random.secure();

  final SharedRiskDryRunTransport _transport;
  final Random _random;
  bool _inFlight = false;
  final Set<String> _attempted = <String>{};

  @override
  Future<SharedRiskDryRunResult> validate(RiskOperationItem item) async {
    if (_inFlight || _attempted.contains(item.signalId)) {
      return const SharedRiskDryRunResult(SharedRiskDryRunOutcome.blocked);
    }
    _inFlight = true;
    _attempted.add(item.signalId);
    try {
      final response = await _transport(<String, Object>{
        'sourceSystem': item.sourceSystem,
        'sourceRecordId': item.sourceRecordId,
        'expectedSourceRecordVersion': item.sourceRecordVersion,
        'expectedProjectionFingerprint': item.projectionFingerprint,
        'dryRun': true,
        'correlationId': _correlationId(),
      });
      final outcome = response['outcome'];
      final safeNoWrite =
          response['dryRun'] == true &&
          response['transactionCommitted'] == false &&
          response['writeAttempted'] == false;
      if (outcome == 'dry_run_ready' && safeNoWrite) {
        return const SharedRiskDryRunResult(
          SharedRiskDryRunOutcome.dryRunReady,
        );
      }
      if (outcome == 'blocked' && safeNoWrite) {
        return const SharedRiskDryRunResult(SharedRiskDryRunOutcome.blocked);
      }
      if (outcome == 'conflict' && safeNoWrite) {
        return const SharedRiskDryRunResult(SharedRiskDryRunOutcome.conflict);
      }
      return const SharedRiskDryRunResult(SharedRiskDryRunOutcome.failed);
    } catch (_) {
      return const SharedRiskDryRunResult(SharedRiskDryRunOutcome.failed);
    } finally {
      _inFlight = false;
    }
  }

  String _correlationId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return 'web-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static SharedRiskDryRunTransport _firebaseTransport(
    FirebaseFunctions? value,
  ) {
    final functions =
        value ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
    return (request) async {
      final response = await functions
          .httpsCallable('promoteRiskOperationToSharedRisk')
          .call<Object?>(request);
      if (response.data is! Map) {
        throw const FormatException('Invalid shared-risk dry-run response');
      }
      return Map<Object?, Object?>.from(response.data as Map);
    };
  }
}
