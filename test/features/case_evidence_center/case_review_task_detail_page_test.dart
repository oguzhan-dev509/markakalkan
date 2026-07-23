import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_task_detail_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_tasks_page.dart';

class _Repository implements CaseReviewTaskRepository {
  _Repository(this.loader, {this.duplicate = false});
  final Future<CaseReviewTaskDetail> Function() loader;
  final bool duplicate;
  int loads = 0;
  int appends = 0;
  Map<String, dynamic>? lastRequest;
  @override
  Future<CaseReviewTaskListResult> list() => throw UnimplementedError();
  @override
  Future<CaseReviewTaskDetail> detail(String taskId) async {
    loads++;
    return loader();
  }

  @override
  Future<CaseReviewTaskMutation> create(Map<String, dynamic> request) =>
      throw UnimplementedError();
  @override
  Future<CaseReviewTaskMutation> append(Map<String, dynamic> request) async {
    appends++;
    lastRequest = request;
    return CaseReviewTaskMutation(
      taskId: 'internal-task-id',
      duplicate: duplicate,
    );
  }
}

CaseReviewTaskDetail _detail({
  String status = 'assigned',
  List<String> actions = const [
    'change_assignment',
    'start_review',
    'add_note',
    'change_due_date',
    'cancel_task',
  ],
}) => CaseReviewTaskDetail.fromMap({
  'contractVersion': 'case-review-task-detail-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'task': {
    'taskId': 'internal-task-id',
    'taskNumber': 'GV-2026-ABCDEF12',
    'caseId': 'internal-case-id',
    'caseNumber': 'VK-2026-EA953C48',
    'caseTitle': 'Dejure Spor Ayakkabı',
    'evidenceRefId': 'internal-evidence-id',
    'evidenceLabel': 'Kaynak risk kaydı',
    'title': 'Kaynak risk kaydı incelemesi',
    'description': 'Uzman incelemesi için güvenli açıklama.',
    'taskType': 'evidence_review',
    'priority': 'high',
    'status': status,
    'assigneeType': 'external_expert',
    'assigneeLabel': 'Ayşe Uzman',
    'assigneeOrganization': 'Uzmanlık AŞ',
    'expertiseArea': 'Ayakkabı analizi',
    'dueAt': '2026-07-24T04:58:04.271Z',
    'isOverdue': false,
    'resultOutcome': status == 'completed' ? 'confirmed' : null,
    'resultSummary': status == 'completed'
        ? 'Bulgular güvenli biçimde doğrulandı.'
        : null,
    'createdAt': '2026-07-23T04:58:04.271Z',
    'updatedAt': '2026-07-23T04:58:04.271Z',
    'startedAt': status == 'in_review' || status == 'completed'
        ? '2026-07-23T04:58:04.271Z'
        : null,
    'completedAt': status == 'completed' ? '2026-07-23T05:58:04.271Z' : null,
    'cancelledAt': null,
    'lastEventAt': '2026-07-23T04:58:04.271Z',
    'eventCount': 2,
  },
  'timelineEvents': [
    {
      'sequence': 2,
      'eventType': 'assignment_set',
      'eventLabel': 'Görev atandı',
      'note': 'Uzman atandı.',
      'actorLabel': 'Yetkili kullanıcı',
      'recordedAt': '2026-07-23T04:58:04.271Z',
    },
    {
      'sequence': 1,
      'eventType': 'task_created',
      'eventLabel': 'Görev oluşturuldu',
      'note': 'Görev oluşturuldu.',
      'actorLabel': 'Yetkili kullanıcı',
      'recordedAt': '2026-07-23T03:58:04.271Z',
    },
  ],
  'allowedActions': actions,
});

void main() {
  testWidgets('task detail shows loading, safe Turkish content and routes', (
    tester,
  ) async {
    final completer = Completer<CaseReviewTaskDetail>();
    String? caseId;
    String? evidenceId;
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTaskDetailPage(
          taskId: 'internal-task-id',
          repository: _Repository(() => completer.future),
          caseOpener: (_, id) async => caseId = id,
          evidenceOpener: (_, id) async => evidenceId = id,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('review-task-detail-loading')),
      findsOneWidget,
    );
    completer.complete(_detail());
    await tester.pumpAndSettle();
    expect(find.text('GV-2026-ABCDEF12'), findsOneWidget);
    expect(find.text('Delil incelemesi'), findsOneWidget);
    expect(find.text('Atandı'), findsOneWidget);
    expect(find.textContaining('23.07.2026 07:58'), findsWidgets);
    expect(find.textContaining('evidence_review'), findsNothing);
    expect(find.textContaining('internal-task-id'), findsNothing);
    expect(find.textContaining('2026-07-23T'), findsNothing);
    await tester.tap(find.textContaining('VK-2026-EA953C48'));
    await tester.tap(find.text('Kaynak risk kaydı'));
    expect(caseId, 'internal-case-id');
    expect(evidenceId, 'internal-evidence-id');
  });

  testWidgets('detail renders only server allowed actions and terminal state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTaskDetailPage(
          taskId: 'internal-task-id',
          repository: _Repository(
            () async => _detail(status: 'completed', actions: const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tamamlandı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Sonuç:'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.textContaining('Bulgular doğrulandı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bu görev için kullanılabilir işlem bulunmuyor.'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.text('Bu görev için kullanılabilir işlem bulunmuyor.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('start review validates note, appends and reloads safely', (
    tester,
  ) async {
    final repository = _Repository(() async => _detail(), duplicate: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTaskDetailPage(
          taskId: 'internal-task-id',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('task-action-start_review'));
    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-event-note')), 'x');
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    expect(repository.appends, 0);
    await tester.enterText(
      find.byKey(const ValueKey('task-event-note')),
      'İnceleme başlatıldı.',
    );
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(repository.lastRequest?['eventType'], 'review_started');
    expect(repository.loads, 2);
    expect(find.text('Bu işlem daha önce kaydedildi.'), findsOneWidget);
  });

  for (final scenario in [
    ('not-found', 'İnceleme görevi bulunamadı.'),
    ('permission-denied', 'Bu görevi görüntüleme yetkiniz bulunmuyor.'),
    ('internal', 'Görev ayrıntısı yüklenemedi.'),
  ]) {
    testWidgets('task detail ${scenario.$1} error is safe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CaseReviewTaskDetailPage(
            taskId: 'internal-task-id',
            repository: _ErrorRepository(scenario.$1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.textContaining('technical'), findsNothing);
    });
  }
}

class _ErrorRepository implements CaseReviewTaskRepository {
  _ErrorRepository(this.code);
  final String code;
  @override
  Future<CaseReviewTaskListResult> list() => throw UnimplementedError();
  @override
  Future<CaseReviewTaskDetail> detail(String taskId) async =>
      throw FirebaseFunctionsException(code: code, message: 'technical');
  @override
  Future<CaseReviewTaskMutation> create(Map<String, dynamic> request) =>
      throw UnimplementedError();
  @override
  Future<CaseReviewTaskMutation> append(Map<String, dynamic> request) =>
      throw UnimplementedError();
}
