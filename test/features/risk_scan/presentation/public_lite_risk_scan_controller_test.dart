import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_controller.dart';

void main() {
  group('PublicLiteRiskScanController', () {
    test('polls and automatically loads the report when ready', () async {
      final scheduler = _ManualScheduler();
      final repository = _SequenceRepository(
        statuses: [
          _projection(status: 'acquiring'),
          _projection(status: 'completed'),
        ],
        report: _projection(status: 'completed', report: _report()),
      );
      final controller = PublicLiteRiskScanController(
        repository: repository,
        schedule: scheduler.schedule,
        now: () => _now,
      );

      await controller.start(_request());

      expect(controller.state, PublicLiteRiskScanOperationState.monitoring);
      expect(scheduler.nextPollDelay, const Duration(seconds: 2));

      scheduler.runNextPoll();
      await _flushAsync();

      expect(repository.statusCalls, 1);
      expect(controller.projection?.status, 'acquiring');

      scheduler.runNextPoll();
      await _flushAsync();

      expect(repository.statusCalls, 2);
      expect(repository.reportCalls, 1);
      expect(controller.state, PublicLiteRiskScanOperationState.completed);
      expect(controller.projection?.report?.summary, 'Rapor hazır.');
      expect(scheduler.hasActivePoll, isFalse);

      controller.dispose();
    });

    test('uses bounded polling delays', () async {
      final scheduler = _ManualScheduler();
      final repository = _RetryingRepository();
      final controller = PublicLiteRiskScanController(
        repository: repository,
        schedule: scheduler.schedule,
        now: () => _now,
      );

      await controller.start(_request());

      final observed = <Duration>[];
      for (var index = 0; index < 6; index += 1) {
        observed.add(scheduler.nextPollDelay);
        scheduler.runNextPoll();
        await _flushAsync();
      }

      expect(observed, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 15),
        const Duration(seconds: 30),
        const Duration(seconds: 30),
      ]);
      expect(controller.state, PublicLiteRiskScanOperationState.monitoring);

      controller.dispose();
    });

    test('pauses in background and refreshes on resume', () async {
      final scheduler = _ManualScheduler();
      final repository = _SequenceRepository(
        statuses: [_projection(status: 'assessing')],
        report: _projection(status: 'completed', report: _report()),
      );
      final controller = PublicLiteRiskScanController(
        repository: repository,
        schedule: scheduler.schedule,
        now: () => _now,
      );

      await controller.start(_request());
      expect(scheduler.hasActivePoll, isTrue);

      controller.setForeground(false);

      expect(controller.state, PublicLiteRiskScanOperationState.paused);
      expect(scheduler.hasActivePoll, isFalse);

      controller.setForeground(true);
      await _flushAsync();

      expect(repository.statusCalls, 1);
      expect(controller.state, PublicLiteRiskScanOperationState.monitoring);

      controller.dispose();
    });

    test('expires and cancels polling', () async {
      final scheduler = _ManualScheduler();
      var now = _now;
      final controller = PublicLiteRiskScanController(
        repository: _SequenceRepository(
          statuses: [_projection(status: 'acquiring')],
          report: _projection(status: 'completed', report: _report()),
          startProjection: _projection(
            status: 'created',
            expiresAt: _now.add(const Duration(seconds: 2)),
          ),
        ),
        schedule: scheduler.schedule,
        now: () => now,
      );

      await controller.start(_request());
      expect(controller.remainingAccess, const Duration(seconds: 2));

      now = _now.add(const Duration(seconds: 2));
      scheduler.runNextExpiryTick();
      await _flushAsync();

      expect(controller.state, PublicLiteRiskScanOperationState.expired);
      expect(controller.errorMessage, contains('süresi doldu'));
      expect(scheduler.hasActivePoll, isFalse);

      controller.dispose();
    });

    test('dispose cancels all scheduled callbacks', () async {
      final scheduler = _ManualScheduler();
      final controller = PublicLiteRiskScanController(
        repository: _SequenceRepository(
          statuses: [_projection(status: 'acquiring')],
          report: _projection(status: 'completed', report: _report()),
        ),
        schedule: scheduler.schedule,
        now: () => _now,
      );

      await controller.start(_request());
      expect(scheduler.activeCount, greaterThan(0));

      controller.dispose();

      expect(scheduler.activeCount, 0);
    });
  });
}

final DateTime _now = DateTime.utc(2026, 7, 30, 12);

PublicLiteRiskScanStartRequest _request() => PublicLiteRiskScanStartRequest(
  requestId: '11111111-1111-4111-8111-111111111111',
  brandName: 'MarkaKalkan',
  officialWebsiteUrl: 'https://markakalkan.com',
  anonymousClientNonce: 'nonce-1',
);

final class _SequenceRepository implements PublicLiteRiskScanRepository {
  _SequenceRepository({
    required List<PublicLiteRiskScanProjection> statuses,
    required this.report,
    PublicLiteRiskScanProjection? startProjection,
  }) : _statuses = List<PublicLiteRiskScanProjection>.of(statuses),
       _startProjection = startProjection ?? _projection(status: 'created');

  final List<PublicLiteRiskScanProjection> _statuses;
  final PublicLiteRiskScanProjection report;
  final PublicLiteRiskScanProjection _startProjection;

  int statusCalls = 0;
  int reportCalls = 0;

  @override
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  ) async => PublicLiteRiskScanStartResult(
    outcome: 'created',
    accessKey: _accessKey,
    projection: _startProjection,
  );

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) async {
    statusCalls += 1;
    if (_statuses.isEmpty) {
      return _projection(status: 'acquiring');
    }
    return _statuses.removeAt(0);
  }

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) async {
    reportCalls += 1;
    return report;
  }
}

final class _RetryingRepository implements PublicLiteRiskScanRepository {
  @override
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  ) async => PublicLiteRiskScanStartResult(
    outcome: 'created',
    accessKey: _accessKey,
    projection: _projection(status: 'created'),
  );

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) {
    throw const PublicLiteRiskScanRepositoryException(
      code: 'unavailable',
      message: 'Geçici ağ hatası.',
    );
  }

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) {
    throw UnimplementedError();
  }
}

final class _ManualScheduler {
  final List<_ScheduledTask> _tasks = [];

  PublicLiteRiskScanCancel schedule(Duration delay, VoidCallback callback) {
    final task = _ScheduledTask(delay, callback);
    _tasks.add(task);
    return task.cancel;
  }

  int get activeCount => _tasks.where((task) => task.active).length;

  bool get hasActivePoll => _activePollTasks.isNotEmpty;

  Duration get nextPollDelay {
    final tasks = _activePollTasks;
    if (tasks.isEmpty) {
      throw StateError('Aktif polling görevi yok.');
    }
    return tasks.first.delay;
  }

  Iterable<_ScheduledTask> get _activePollTasks => _tasks.where(
    (task) => task.active && task.delay > const Duration(seconds: 1),
  );

  void runNextPoll() {
    final tasks = _activePollTasks.toList();
    if (tasks.isEmpty) {
      throw StateError('Aktif polling görevi yok.');
    }
    tasks.first.run();
  }

  void runNextExpiryTick() {
    final tasks = _tasks
        .where(
          (task) => task.active && task.delay <= const Duration(seconds: 1),
        )
        .toList();
    if (tasks.isEmpty) {
      throw StateError('Aktif expiry görevi yok.');
    }
    tasks.first.run();
  }
}

final class _ScheduledTask {
  _ScheduledTask(this.delay, this.callback);

  final Duration delay;
  final VoidCallback callback;
  bool active = true;

  void cancel() {
    active = false;
  }

  void run() {
    if (!active) return;
    active = false;
    callback();
  }
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const String _accessKey =
    'hrt1.'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.'
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

PublicLiteRiskScanProjection _projection({
  required String status,
  DateTime? expiresAt,
  PublicLiteRiskScanReport? report,
}) => PublicLiteRiskScanProjection.fromMap({
  'contractVersion': publicLiteRiskScanProjectionContractVersionV1,
  'scanRunId': 'a' * 64,
  'scanMode': 'quick',
  'accessTier': 'publicLite',
  'identityMode': 'anonymous',
  'status': status,
  'coverageStatus': 'insufficient',
  'createdAt': _now.toIso8601String(),
  'updatedAt': _now.toIso8601String(),
  'expiresAt': (expiresAt ?? _now.add(const Duration(hours: 24)))
      .toIso8601String(),
  'target': {
    'brandNameNormalized': 'markakalkan',
    'officialHost': 'markakalkan.com',
  },
  'channels': [
    _channel('similarDomains'),
    _channel('openWeb'),
    _channel('marketplaceLimited'),
  ],
  'report': report == null
      ? null
      : {
          'reportId': report.reportId,
          'reportVersion': report.reportVersion,
          'generatedAt': report.generatedAt?.toIso8601String(),
          'status': report.status,
          'coverageStatus': report.coverageStatus,
          'overallRiskLevel': report.overallRiskLevel,
          'overallConfidenceLevel': report.overallConfidenceLevel,
          'recommendedAction': report.recommendedAction,
          'summary': report.summary,
          'findingCount': report.findingCount,
          'observationCount': report.observationCount,
          'topFindingSnapshots': <Object?>[],
          'channelDistribution': <Object?>[],
        },
});

PublicLiteRiskScanReport _report() => PublicLiteRiskScanReport.fromMap({
  'reportId': 'report-1',
  'reportVersion': 1,
  'generatedAt': _now.add(const Duration(minutes: 2)).toIso8601String(),
  'status': 'completed',
  'coverageStatus': 'limited',
  'overallRiskLevel': 'medium',
  'overallConfidenceLevel': 'medium',
  'recommendedAction': 'review_top_findings',
  'summary': 'Rapor hazır.',
  'findingCount': 0,
  'observationCount': 3,
  'topFindingSnapshots': <Object?>[],
  'channelDistribution': <Object?>[],
});

Map<String, dynamic> _channel(String code) => {
  'channelCode': code,
  'status': 'queued',
  'coverageStatus': 'insufficient',
  'observationCount': 0,
  'findingCount': 0,
  'limitReasonCodes': <Object?>[],
  'startedAt': null,
  'completedAt': null,
};
