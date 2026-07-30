import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';

typedef PublicLiteRiskScanClock = DateTime Function();
typedef PublicLiteRiskScanCancel = void Function();
typedef PublicLiteRiskScanSchedule =
    PublicLiteRiskScanCancel Function(Duration delay, VoidCallback callback);

enum PublicLiteRiskScanOperationState {
  idle,
  starting,
  monitoring,
  paused,
  loadingReport,
  completed,
  terminal,
  expired,
  failed,
}

final class PublicLiteRiskScanController extends ChangeNotifier {
  PublicLiteRiskScanController({
    required PublicLiteRiskScanRepository repository,
    PublicLiteRiskScanClock? now,
    PublicLiteRiskScanSchedule? schedule,
    List<Duration>? pollIntervals,
  }) : _repository = repository,
       _now = now ?? _systemClock,
       _schedule = schedule ?? _timerSchedule,
       _pollIntervals = List<Duration>.unmodifiable(
         pollIntervals ??
             const <Duration>[
               Duration(seconds: 2),
               Duration(seconds: 4),
               Duration(seconds: 8),
               Duration(seconds: 15),
               Duration(seconds: 30),
             ],
       ) {
    if (_pollIntervals.isEmpty ||
        _pollIntervals.any((duration) => duration <= Duration.zero)) {
      throw ArgumentError.value(
        pollIntervals,
        'pollIntervals',
        'En az bir pozitif polling aralığı gerekir.',
      );
    }
  }

  final PublicLiteRiskScanRepository _repository;
  final PublicLiteRiskScanClock _now;
  final PublicLiteRiskScanSchedule _schedule;
  final List<Duration> _pollIntervals;

  PublicLiteRiskScanCancel? _cancelPoll;
  PublicLiteRiskScanCancel? _cancelExpiryTick;

  PublicLiteRiskScanOperationState _state =
      PublicLiteRiskScanOperationState.idle;
  PublicLiteRiskScanProjection? _projection;
  String? _outcome;
  String? _errorMessage;
  String? _accessKey;

  int _pollAttempt = 0;
  bool _foreground = true;
  bool _pollInFlight = false;
  bool _reportInFlight = false;
  bool _disposed = false;

  PublicLiteRiskScanOperationState get state => _state;
  PublicLiteRiskScanProjection? get projection => _projection;
  String? get outcome => _outcome;
  String? get errorMessage => _errorMessage;
  bool get isForeground => _foreground;

  bool get isBusy =>
      _state == PublicLiteRiskScanOperationState.starting ||
      _pollInFlight ||
      _reportInFlight;

  bool get hasActiveOperation =>
      _accessKey != null &&
      _state != PublicLiteRiskScanOperationState.completed &&
      _state != PublicLiteRiskScanOperationState.terminal &&
      _state != PublicLiteRiskScanOperationState.expired &&
      _state != PublicLiteRiskScanOperationState.failed;

  Duration? get remainingAccess {
    final expiresAt = _projection?.expiresAt;
    if (expiresAt == null) return null;

    final difference = expiresAt.difference(_now().toUtc());
    return difference.isNegative ? Duration.zero : difference;
  }

  String get accessibilityStatus {
    final projection = _projection;
    if (_state == PublicLiteRiskScanOperationState.expired) {
      return 'Tarama erişim süresi doldu.';
    }
    if (_state == PublicLiteRiskScanOperationState.paused) {
      return 'Tarama izleme işlemi uygulama arka planda olduğu için duraklatıldı.';
    }
    if (_state == PublicLiteRiskScanOperationState.loadingReport) {
      return 'Tarama tamamlandı. Risk raporu alınıyor.';
    }
    if (_state == PublicLiteRiskScanOperationState.completed) {
      return 'Tarama ve risk raporu hazır.';
    }
    if (_state == PublicLiteRiskScanOperationState.failed) {
      return _errorMessage ?? 'Tarama izleme işlemi tamamlanamadı.';
    }
    if (projection == null) {
      return 'Henüz başlatılmış bir tarama yok.';
    }
    return 'Tarama durumu ${projection.status}. '
        'Kapsama durumu ${projection.coverageStatus}.';
  }

  Future<void> start(PublicLiteRiskScanStartRequest request) async {
    _ensureNotDisposed();
    _cancelSchedules();
    _accessKey = null;
    _projection = null;
    _outcome = null;
    _errorMessage = null;
    _pollAttempt = 0;
    _state = PublicLiteRiskScanOperationState.starting;
    notifyListeners();

    try {
      final result = await _repository.start(request);
      if (_disposed) return;

      _accessKey = result.accessKey;
      _outcome = result.outcome;
      _projection = result.projection;
      _errorMessage = null;

      await _advanceFromProjection();
    } on PublicLiteRiskScanRepositoryException catch (error) {
      if (_disposed) return;
      _state = PublicLiteRiskScanOperationState.failed;
      _errorMessage = error.message;
      notifyListeners();
    } on FormatException catch (error) {
      if (_disposed) return;
      _state = PublicLiteRiskScanOperationState.failed;
      _errorMessage = error.message.toString();
      notifyListeners();
    }
  }

  Future<void> refreshNow() async {
    _ensureNotDisposed();
    if (_accessKey == null || !_foreground || _pollInFlight) return;

    _cancelPollSchedule();
    await _pollStatus();
  }

  Future<void> loadReportNow() async {
    _ensureNotDisposed();
    if (_accessKey == null || _reportInFlight) return;

    _cancelPollSchedule();
    await _loadReport();
  }

  void setForeground(bool foreground) {
    _ensureNotDisposed();
    if (_foreground == foreground) return;

    _foreground = foreground;
    if (!foreground) {
      _cancelSchedules();
      if (hasActiveOperation) {
        _state = PublicLiteRiskScanOperationState.paused;
        notifyListeners();
      }
      return;
    }

    if (_accessKey == null || _isTerminalState(_state)) {
      return;
    }

    if (_hasExpired()) {
      _markExpired();
      return;
    }

    _state = PublicLiteRiskScanOperationState.monitoring;
    _errorMessage = null;
    notifyListeners();
    _scheduleExpiryTick();
    unawaited(_pollStatus());
  }

  Future<void> _pollStatus() async {
    final accessKey = _accessKey;
    if (_disposed ||
        accessKey == null ||
        !_foreground ||
        _pollInFlight ||
        _reportInFlight ||
        _isTerminalState(_state)) {
      return;
    }

    if (_hasExpired()) {
      _markExpired();
      return;
    }

    _pollInFlight = true;
    _state = PublicLiteRiskScanOperationState.monitoring;
    notifyListeners();

    try {
      final projection = await _repository.getStatus(accessKey);
      if (_disposed) return;

      _projection = projection;
      _errorMessage = null;
      await _advanceFromProjection();
    } on PublicLiteRiskScanRepositoryException catch (error) {
      if (_disposed) return;

      if (_hasExpired()) {
        _markExpired();
      } else if (error.isRetryable) {
        _errorMessage = error.message;
        _state = _foreground
            ? PublicLiteRiskScanOperationState.monitoring
            : PublicLiteRiskScanOperationState.paused;
        notifyListeners();
        _scheduleNextPoll(increaseAttempt: true);
      } else {
        _errorMessage = error.message;
        _state = PublicLiteRiskScanOperationState.failed;
        _cancelSchedules();
        notifyListeners();
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _loadReport() async {
    final accessKey = _accessKey;
    if (_disposed ||
        accessKey == null ||
        !_foreground ||
        _reportInFlight ||
        _isTerminalState(_state)) {
      return;
    }

    if (_hasExpired()) {
      _markExpired();
      return;
    }

    _reportInFlight = true;
    _state = PublicLiteRiskScanOperationState.loadingReport;
    notifyListeners();

    try {
      final projection = await _repository.getReport(accessKey);
      if (_disposed) return;

      _projection = projection;
      _errorMessage = null;
      _state = PublicLiteRiskScanOperationState.completed;
      _cancelSchedules();
      notifyListeners();
    } on PublicLiteRiskScanRepositoryException catch (error) {
      if (_disposed) return;

      if (_hasExpired()) {
        _markExpired();
      } else if (error.code == 'failed-precondition' || error.isRetryable) {
        _errorMessage = error.message;
        _state = PublicLiteRiskScanOperationState.monitoring;
        notifyListeners();
        _scheduleNextPoll(increaseAttempt: true);
      } else {
        _errorMessage = error.message;
        _state = PublicLiteRiskScanOperationState.failed;
        _cancelSchedules();
        notifyListeners();
      }
    } finally {
      _reportInFlight = false;
    }
  }

  Future<void> _advanceFromProjection() async {
    final projection = _projection;
    if (_disposed || projection == null) return;

    _scheduleExpiryTick();

    if (_hasExpired() || projection.status == 'expired') {
      _markExpired();
      return;
    }

    if (projection.isReportReady) {
      if (projection.report != null) {
        _state = PublicLiteRiskScanOperationState.completed;
        _cancelSchedules();
        notifyListeners();
        return;
      }

      await _loadReport();
      return;
    }

    if (projection.status == 'failedTerminal' ||
        projection.status == 'cancelled') {
      _state = PublicLiteRiskScanOperationState.terminal;
      _cancelSchedules();
      notifyListeners();
      return;
    }

    if (!_foreground) {
      _state = PublicLiteRiskScanOperationState.paused;
      _cancelPollSchedule();
      notifyListeners();
      return;
    }

    _state = PublicLiteRiskScanOperationState.monitoring;
    notifyListeners();
    _scheduleNextPoll(increaseAttempt: true);
  }

  void _scheduleNextPoll({required bool increaseAttempt}) {
    _cancelPollSchedule();

    if (_disposed ||
        !_foreground ||
        _accessKey == null ||
        _isTerminalState(_state) ||
        _hasExpired()) {
      return;
    }

    final index = _pollAttempt.clamp(0, _pollIntervals.length - 1);
    final delay = _pollIntervals[index];
    if (increaseAttempt && _pollAttempt < _pollIntervals.length - 1) {
      _pollAttempt += 1;
    }

    _cancelPoll = _schedule(delay, () {
      _cancelPoll = null;
      unawaited(_pollStatus());
    });
  }

  void _scheduleExpiryTick() {
    _cancelExpiryTick?.call();
    _cancelExpiryTick = null;

    if (_disposed ||
        !_foreground ||
        _accessKey == null ||
        _isTerminalState(_state)) {
      return;
    }

    final remaining = remainingAccess;
    if (remaining == null) return;
    if (remaining <= Duration.zero) {
      _markExpired();
      return;
    }

    final delay = remaining < const Duration(seconds: 1)
        ? remaining
        : const Duration(seconds: 1);

    _cancelExpiryTick = _schedule(delay, () {
      _cancelExpiryTick = null;
      if (_disposed) return;
      if (_hasExpired()) {
        _markExpired();
        return;
      }
      notifyListeners();
      _scheduleExpiryTick();
    });
  }

  bool _hasExpired() {
    final remaining = remainingAccess;
    return remaining != null && remaining <= Duration.zero;
  }

  void _markExpired() {
    _cancelSchedules();
    _state = PublicLiteRiskScanOperationState.expired;
    _errorMessage = 'Tarama erişim süresi doldu.';
    notifyListeners();
  }

  bool _isTerminalState(PublicLiteRiskScanOperationState state) =>
      state == PublicLiteRiskScanOperationState.completed ||
      state == PublicLiteRiskScanOperationState.terminal ||
      state == PublicLiteRiskScanOperationState.expired ||
      state == PublicLiteRiskScanOperationState.failed;

  void _cancelPollSchedule() {
    _cancelPoll?.call();
    _cancelPoll = null;
  }

  void _cancelSchedules() {
    _cancelPollSchedule();
    _cancelExpiryTick?.call();
    _cancelExpiryTick = null;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PublicLiteRiskScanController disposed.');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelSchedules();
    _accessKey = null;
    super.dispose();
  }

  static DateTime _systemClock() => DateTime.now().toUtc();

  static PublicLiteRiskScanCancel _timerSchedule(
    Duration delay,
    VoidCallback callback,
  ) {
    final timer = Timer(delay, callback);
    return timer.cancel;
  }
}
