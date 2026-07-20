import 'package:flutter/foundation.dart';
import 'package:markakalkan/features/admin/data/internal_real_provisioning_service.dart';
import 'package:markakalkan/features/admin/models/internal_provisioning_dry_run_result.dart';

enum InternalRealProvisioningSubmissionState {
  idle,
  submitting,
  completed,
  failed,
}

class InternalRealProvisioningSessionLock {
  InternalRealProvisioningSessionLock();

  static final InternalRealProvisioningSessionLock shared =
      InternalRealProvisioningSessionLock();
  bool _locked = false;

  bool get isLocked => _locked;

  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }
}

class InternalRealProvisioningController extends ChangeNotifier {
  InternalRealProvisioningController({
    InternalRealProvisioningService? service,
    InternalRealProvisioningSessionLock? sessionLock,
  }) : _service = service ?? InternalRealProvisioningService(),
       _sessionLock = sessionLock ?? InternalRealProvisioningSessionLock.shared;

  final InternalRealProvisioningService _service;
  final InternalRealProvisioningSessionLock _sessionLock;
  InternalRealProvisioningSubmissionState _state =
      InternalRealProvisioningSubmissionState.idle;
  InternalProvisioningResult? _result;

  InternalRealProvisioningSubmissionState get state => _state;
  InternalProvisioningResult? get result => _result;
  bool get canSubmit =>
      _state == InternalRealProvisioningSubmissionState.idle &&
      !_sessionLock.isLocked;

  Future<InternalProvisioningResult?> submitConfirmed({
    required bool confirmed,
  }) async {
    if (!confirmed || !canSubmit || !_sessionLock.tryLock()) return null;
    _state = InternalRealProvisioningSubmissionState.submitting;
    notifyListeners();
    try {
      _result = await _service.create();
      _state = InternalRealProvisioningSubmissionState.completed;
      return _result;
    } catch (_) {
      _state = InternalRealProvisioningSubmissionState.failed;
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
