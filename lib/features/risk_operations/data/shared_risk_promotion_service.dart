import 'package:cloud_functions/cloud_functions.dart';

import 'risk_operations_models.dart';

typedef SharedRiskPromotionTransport =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

enum SharedRiskPromotionOutcome {
  created,
  idempotentSuccess,
  dryRunReady,
  conflict,
  blocked,
  unknown,
}

class SharedRiskPromotionResult {
  const SharedRiskPromotionResult(this.outcome);
  final SharedRiskPromotionOutcome outcome;

  String get turkishMessage => switch (outcome) {
    SharedRiskPromotionOutcome.created => 'Ortak risk kaydı oluşturuldu.',
    SharedRiskPromotionOutcome.idempotentSuccess =>
      'Bu sinyal daha önce güvenli biçimde kaydedilmiş.',
    SharedRiskPromotionOutcome.dryRunReady =>
      'Doğrulama başarılı; kayıt oluşturmaya hazır.',
    SharedRiskPromotionOutcome.conflict =>
      'Kayıt güncellendi. Lütfen listeyi yenileyip tekrar inceleyin.',
    SharedRiskPromotionOutcome.blocked =>
      'İşlem şu anda güvenli biçimde kapalı.',
    SharedRiskPromotionOutcome.unknown =>
      'İşlem güvenli biçimde tamamlanamadı.',
  };
}

abstract interface class SharedRiskPromotionService {
  Future<SharedRiskPromotionResult> promote(RiskOperationItem item);
}

class CallableSharedRiskPromotionService implements SharedRiskPromotionService {
  CallableSharedRiskPromotionService({
    FirebaseFunctions? functions,
    SharedRiskPromotionTransport? transport,
  }) : _functions =
           functions ??
           (transport == null
               ? FirebaseFunctions.instanceFor(region: 'europe-west3')
               : null),
       _transport = transport;
  final FirebaseFunctions? _functions;
  final SharedRiskPromotionTransport? _transport;
  bool _inFlight = false;
  final Set<String> _submitted = <String>{};

  @override
  Future<SharedRiskPromotionResult> promote(RiskOperationItem item) async {
    if (_inFlight || _submitted.contains(item.signalId)) {
      return const SharedRiskPromotionResult(
        SharedRiskPromotionOutcome.blocked,
      );
    }
    _inFlight = true;
    _submitted.add(item.signalId);
    try {
      final request = <String, dynamic>{
        'sourceSystem': item.sourceSystem,
        'sourceRecordId': item.sourceRecordId,
        'expectedSourceRecordVersion': item.sourceRecordVersion,
        'expectedProjectionFingerprint': item.projectionFingerprint,
        'dryRun': false,
        'correlationId':
            '${item.signalId}-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      };
      final data = _transport != null
          ? await _transport(request)
          : (await _functions!
                    .httpsCallable('promoteRiskOperationToSharedRisk')
                    .call<Map<String, dynamic>>(request))
                .data;
      final value = data['outcome'];
      return SharedRiskPromotionResult(switch (value) {
        'created' => SharedRiskPromotionOutcome.created,
        'idempotent_success' => SharedRiskPromotionOutcome.idempotentSuccess,
        'dry_run_ready' => SharedRiskPromotionOutcome.dryRunReady,
        'conflict' => SharedRiskPromotionOutcome.conflict,
        'blocked' => SharedRiskPromotionOutcome.blocked,
        _ => SharedRiskPromotionOutcome.unknown,
      });
    } catch (_) {
      return const SharedRiskPromotionResult(
        SharedRiskPromotionOutcome.unknown,
      );
    } finally {
      _inFlight = false;
    }
  }
}
