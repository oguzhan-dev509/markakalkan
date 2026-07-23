import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_detail_page.dart';

class FakeDetailRepository implements CaseEvidenceDetailRepository {
  FakeDetailRepository(this.loader);
  final Future<CaseEvidenceDetail> Function() loader;
  @override
  Future<CaseEvidenceDetail> load(String caseId) => loader();
}

CaseEvidenceDetail detail({
  bool emptyEvidence = false,
  String summary = 'Kullanıcı dostu özet.',
}) => CaseEvidenceDetail.fromMap({
  'contractVersion': 'case-evidence-detail-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'case': {
    'id': 'internal-case-id',
    'caseCode': 'VK-2026-ABC12345',
    'title': 'Şüpheli ilan',
    'summary': summary,
    'status': 'open',
    'priority': 'high',
    'sourceType': 'monitoring',
    'sourceReference': 'Kaynak risk kaydı',
    'createdAt': '2026-07-22T10:00:00.000Z',
    'updatedAt': '2026-07-22T11:00:00.000Z',
  },
  'evidenceReferences': emptyEvidence
      ? []
      : [
          {
            'evidenceRefId': 'internal-evidence-ref-id',
            'title': 'Kaynak risk kaydı',
            'sourceType': 'monitoring',
            'reviewStatus': 'pending',
            'integrityStatus': 'reference_only',
            'createdAt': '2026-07-22T10:00:00.000Z',
          },
        ],
  'timelineEvents': [
    {
      'type': 'case_opened_from_risk',
      'summary': 'Vaka kontrollü biçimde açıldı.',
      'occurredAt': '2026-07-22T10:00:00.000Z',
    },
  ],
  'auditSummary': [
    {
      'action': 'case.created_from_risk',
      'occurredAt': '2026-07-22T10:00:00.000Z',
    },
  ],
});

Future<void> pump(
  WidgetTester tester,
  CaseEvidenceDetailRepository repository,
) => tester.pumpWidget(
  MaterialApp(
    home: CaseEvidenceDetailPage(
      caseId: 'internal-case-id',
      repository: repository,
    ),
  ),
);

void main() {
  testWidgets('detail shows loading then safe success content', (tester) async {
    final completer = Completer<CaseEvidenceDetail>();
    await pump(tester, FakeDetailRepository(() => completer.future));
    expect(find.byKey(const ValueKey('case-detail-loading')), findsOneWidget);
    completer.complete(detail());
    await tester.pumpAndSettle();
    expect(find.text('VK-2026-ABC12345'), findsOneWidget);
    expect(find.text('Delil Referansları'), findsOneWidget);
    expect(find.text('Olay Zaman Çizelgesi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Denetim Özeti'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Denetim Özeti'), findsOneWidget);
    expect(find.text('internal-case-id'), findsNothing);
    expect(find.textContaining('fingerprint'), findsNothing);
    expect(find.textContaining('case_opened_from_risk'), findsNothing);
  });

  testWidgets('detail explains empty evidence', (tester) async {
    await pump(
      tester,
      FakeDetailRepository(() async => detail(emptyEvidence: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz delil referansı bulunmuyor.'), findsOneWidget);
  });

  testWidgets('detail presents canonical signal codes in Turkish', (
    tester,
  ) async {
    await pump(
      tester,
      FakeDetailRepository(
        () async => detail(summary: 'repeat_scan_observed, rapid_repeat_scan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tekrarlanan tarama gözlendi, Kısa sürede tekrar tarandı'),
      findsOneWidget,
    );
    expect(find.textContaining('repeat_scan_observed'), findsNothing);
    expect(find.textContaining('rapid_repeat_scan'), findsNothing);
  });

  testWidgets('detail hides unknown technical code behind safe fallback', (
    tester,
  ) async {
    await pump(
      tester,
      FakeDetailRepository(() async => detail(summary: 'unknown_signal_code')),
    );
    await tester.pumpAndSettle();
    expect(find.text('İnceleme sinyali'), findsOneWidget);
    expect(find.textContaining('unknown_signal_code'), findsNothing);
  });

  testWidgets('detail preserves normal user summary', (tester) async {
    const summary = 'Şüpheli tekrar tarama davranışı gözlendi';
    await pump(
      tester,
      FakeDetailRepository(() async => detail(summary: summary)),
    );
    await tester.pumpAndSettle();
    expect(find.text(summary), findsOneWidget);
  });

  testWidgets('evidence row opens item detail with internal evidence id', (
    tester,
  ) async {
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceDetailPage(
          caseId: 'internal-case-id',
          repository: FakeDetailRepository(() async => detail()),
          evidenceDetailOpener: (_, id) async => openedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('case-evidence-internal-evidence-ref-id')),
    );
    await tester.pump();
    expect(openedId, 'internal-evidence-ref-id');
    expect(find.textContaining('internal-evidence-ref-id'), findsNothing);
  });

  testWidgets('case detail opens review task form with internal case id', (
    tester,
  ) async {
    String? openedCaseId;
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceDetailPage(
          caseId: 'internal-case-id',
          repository: FakeDetailRepository(() async => detail()),
          reviewTaskFormOpener: (_, caseId) async => openedCaseId = caseId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-case-review-task')));
    await tester.pump();
    expect(openedCaseId, 'internal-case-id');
  });

  for (final scenario in [
    ('not-found', 'Vaka dosyası bulunamadı.'),
    ('permission-denied', 'Bu vaka dosyasını görüntüleme yetkiniz bulunmuyor.'),
  ]) {
    testWidgets('detail ${scenario.$1} state is user friendly', (tester) async {
      await pump(
        tester,
        FakeDetailRepository(
          () async => throw FirebaseFunctionsException(
            code: scenario.$1,
            message: 'technical',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.text('technical'), findsNothing);
    });
  }
}
