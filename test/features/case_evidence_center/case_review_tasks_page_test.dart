import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_tasks_page.dart';

class _Repository implements CaseReviewTaskRepository {
  _Repository(this.loader, {this.created});
  final Future<CaseReviewTaskListResult> Function() loader;
  final CaseReviewTaskMutation? created;
  Map<String, dynamic>? createRequest;
  @override
  Future<CaseReviewTaskListResult> list() => loader();
  @override
  Future<CaseReviewTaskDetail> detail(String taskId) =>
      throw UnimplementedError();
  @override
  Future<CaseReviewTaskMutation> create(Map<String, dynamic> request) async {
    createRequest = request;
    return created ??
        const CaseReviewTaskMutation(taskId: 'task-created', duplicate: false);
  }

  @override
  Future<CaseReviewTaskMutation> append(Map<String, dynamic> request) =>
      throw UnimplementedError();
}

CaseReviewTaskListResult _result({bool empty = false}) =>
    CaseReviewTaskListResult.fromMap({
      'contractVersion': 'case-review-task-list-v1',
      'readOnly': true,
      'writesPerformed': 0,
      'stats': {
        'totalTasks': empty ? 0 : 2,
        'openTasks': empty ? 0 : 1,
        'assignedTasks': empty ? 0 : 1,
        'inReviewTasks': 0,
        'overdueTasks': empty ? 0 : 1,
        'completedTasks': 0,
      },
      'items': empty
          ? []
          : [
              {
                'taskId': 'internal-task-open',
                'taskNumber': 'GV-2026-ABCDEF12',
                'caseId': 'internal-case-id',
                'caseNumber': 'VK-2026-EA953C48',
                'caseTitle': 'Dejure Spor Ayakkabı',
                'evidenceRefId': 'internal-evidence-id',
                'evidenceLabel': 'Kaynak risk kaydı',
                'title': 'Kaynak risk kaydı incelemesi',
                'taskType': 'evidence_review',
                'priority': 'high',
                'status': 'open',
                'assigneeType': 'unassigned',
                'assigneeLabel': null,
                'expertiseArea': null,
                'dueAt': '2026-07-23T04:58:04.271Z',
                'isOverdue': true,
                'createdAt': '2026-07-22T04:58:04.271Z',
                'updatedAt': '2026-07-22T04:58:04.271Z',
                'lastEventAt': '2026-07-22T04:58:04.271Z',
              },
              {
                'taskId': 'internal-task-assigned',
                'taskNumber': 'GV-2026-1234ABCD',
                'caseId': 'internal-case-id',
                'caseNumber': 'VK-2026-EA953C48',
                'caseTitle': 'Dejure Spor Ayakkabı',
                'evidenceRefId': null,
                'evidenceLabel': null,
                'title': 'Teknik inceleme',
                'taskType': 'technical_analysis',
                'priority': 'medium',
                'status': 'assigned',
                'assigneeType': 'external_expert',
                'assigneeLabel': 'Ayşe Uzman',
                'expertiseArea': 'Ayakkabı analizi',
                'dueAt': null,
                'isOverdue': false,
                'createdAt': '2026-07-22T04:58:04.271Z',
                'updatedAt': '2026-07-23T04:58:04.271Z',
                'lastEventAt': '2026-07-23T04:58:04.271Z',
              },
            ],
    });

void main() {
  testWidgets('task workspace shows loading then safe list, stats and route', (
    tester,
  ) async {
    final completer = Completer<CaseReviewTaskListResult>();
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTasksPage(
          repository: _Repository(() => completer.future),
          detailOpener: (_, id) async => opened = id,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('review-tasks-loading')), findsOneWidget);
    completer.complete(_result());
    await tester.pumpAndSettle();
    expect(find.text('Toplam Görev: 2'), findsOneWidget);
    expect(find.text('Süresi Geçen: 1'), findsOneWidget);
    expect(find.textContaining('Delil incelemesi'), findsOneWidget);
    expect(find.textContaining('23.07.2026 07:58'), findsWidgets);
    expect(find.textContaining('evidence_review'), findsNothing);
    expect(find.textContaining('internal-task-open'), findsNothing);
    expect(find.textContaining('2026-07-23T'), findsNothing);
    expect(find.text('Süresi geçti'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('review-task-internal-task-open')),
    );
    await tester.pump();
    expect(opened, 'internal-task-open');
  });

  testWidgets('task workspace supports status, priority and type filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTasksPage(
          repository: _Repository(() async => _result()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atandı').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Teknik inceleme'), findsOneWidget);
    expect(find.textContaining('Kaynak risk kaydı incelemesi'), findsNothing);
    expect(find.byKey(const ValueKey('task-priority-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-type-filter')), findsOneWidget);
  });

  testWidgets('task workspace has empty and safe error states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTasksPage(
          repository: _Repository(() async => _result(empty: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz inceleme görevi bulunmuyor.'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseReviewTasksPage(
          key: const ValueKey('error-page'),
          repository: _Repository(() async => throw StateError('secret')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İnceleme görevleri yüklenemedi.'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('create form validates and shows dynamic external fields', (
    tester,
  ) async {
    final repository = _Repository(() async => _result(empty: true));
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showCaseReviewTaskForm(
                context,
                caseId: 'internal-case-id',
                evidenceRefId: 'internal-evidence-id',
                initialTitle: 'Kaynak risk kaydı incelemesi',
                repository: repository,
                detailOpener: (_, id) async => opened = id,
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'İç kullanıcı seçimi için güvenli üye dizini henüz bulunmuyor.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('create-review-task')));
    await tester.pump();
    expect(find.text('Görev alanlarını eksiksiz doldurun.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('task-description')),
      'Uzman tarafından güvenli inceleme yapılacak.',
    );
    await tester.tap(find.byKey(const ValueKey('assignee-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dış uzman').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assignee-label')), findsOneWidget);
    expect(find.byKey(const ValueKey('expertise-area')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('assignee-label')),
      'Ayşe Uzman',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expertise-area')),
      'Ayakkabı analizi',
    );
    await tester.tap(find.byKey(const ValueKey('create-review-task')));
    await tester.pumpAndSettle();
    expect(repository.createRequest?['caseId'], 'internal-case-id');
    expect(repository.createRequest?['evidenceRefId'], 'internal-evidence-id');
    expect(opened, 'task-created');
  });
}
