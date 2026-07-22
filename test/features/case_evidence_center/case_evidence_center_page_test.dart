import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_center_page.dart';

class FakeRepository implements CaseEvidenceCenterRepository {
  FakeRepository(this.result);

  final CaseEvidenceCenterResult result;
  int createCalls = 0;

  @override
  Future<CaseEvidenceCenterResult> load() async => result;

  @override
  Future<CaseCreationResult> createCase(
    CaseEvidenceCandidate candidate, {
    required bool dryRun,
  }) async {
    createCalls++;
    return CaseCreationResult(
      outcome: dryRun ? 'dry_run_ready' : 'created',
      transactionCommitted: !dryRun,
      caseNumber: dryRun ? null : 'VK-2026-ABC12345',
    );
  }
}

Map<String, dynamic> responseMap() => {
  'contractVersion': 'case-evidence-center-read-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'summary': {
    'openCases': 1,
    'evidenceAwaitingReview': 1,
    'expertReview': 0,
    'legalHold': 0,
    'reviewCandidates': 1,
  },
  'sourceAvailability': [
    {'sourceSystem': 'monitoring', 'status': 'available'},
  ],
  'caseCandidates': [
    {
      'signalId': 'signal-1',
      'sourceSystem': 'monitoring',
      'sourceRecordId': 'source-1',
      'sourceRecordVersion': '2026-07-22T10:00:00.000Z',
      'projectionFingerprint':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'title': 'Şüpheli pazar yeri ilanı',
      'summary': 'İnsan incelemesi gereken güvenli özet.',
      'severity': 'high',
      'evidenceQuality': {'level': 'corroborated'},
      'existingCaseNumber': null,
    },
  ],
  'cases': [
    {
      'caseId': 'case-1',
      'caseNumber': 'VK-2026-ABC12345',
      'title': 'Şüpheli pazar yeri ilanı',
      'summary': 'Vaka özeti.',
      'status': 'open',
      'priority': 'high',
      'sourceBinding': {'sourceSystem': 'monitoring'},
      'events': [
        {
          'summary': 'Risk sinyalinden kontrollü vaka dosyası açıldı.',
          'occurredAt': '2026-07-22T11:00:00.000Z',
        },
      ],
      'evidenceRefs': [
        {
          'title': 'Kaynak risk kaydı',
          'sourceSystem': 'monitoring',
          'reviewStatus': 'pending',
        },
      ],
    },
  ],
};

Map<String, dynamic> navigationResponseMap() {
  final map = responseMap();
  final candidates = map['caseCandidates']! as List<dynamic>;
  (candidates.first as Map<String, dynamic>)['title'] = 'repeat_scan_observed';
  candidates.add({
    ...(candidates.first as Map<String, dynamic>),
    'signalId': 'signal-2',
    'existingCaseId': 'case-1',
    'existingCaseNumber': 'VK-2026-ABC12345',
    'title': 'rapid_repeat_scan',
  });
  return map;
}

void main() {
  testWidgets('renders approved navy identity and five workspaces', (
    tester,
  ) async {
    final repository = FakeRepository(
      CaseEvidenceCenterResult.fromMap(responseMap()),
    );
    await tester.pumpWidget(
      MaterialApp(home: CaseEvidenceCenterPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('case-evidence-center-hero')),
      findsOneWidget,
    );
    expect(
      find.text('Sinyali vakaya, delili savunmaya dönüştür.'),
      findsOneWidget,
    );
    expect(find.text('Delil Kasası ve Delil Zinciri'), findsOneWidget);
    expect(find.text('Görevler, Uzmanlar ve İncelemeler'), findsOneWidget);
    expect(
      find.text('Taraflar, İlişkiler ve Olay Zaman Çizelgesi'),
      findsOneWidget,
    );
    expect(
      find.text('Hukuki Muhafaza, Saklama ve Dışa Aktarım'),
      findsOneWidget,
    );
  });

  testWidgets('dry-run action is zero-write and user-facing', (tester) async {
    final repository = FakeRepository(
      CaseEvidenceCenterResult.fromMap(responseMap()),
    );
    await tester.pumpWidget(
      MaterialApp(home: CaseEvidenceCenterPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final action = find.text('Yazmadan doğrula');
    await tester.scrollUntilVisible(
      action,
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(
      find.text('Yazısız doğrulama başarılı. Vaka dosyası oluşturulmadı.'),
      findsOneWidget,
    );
  });

  testWidgets('case code and existing case action open detail', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceCenterPage(
          repository: FakeRepository(
            CaseEvidenceCenterResult.fromMap(navigationResponseMap()),
          ),
          detailOpener: (_, caseId) async => opened.add(caseId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('case-code-case-1')),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const ValueKey('case-code-case-1')));
    await tester.pump();
    expect(opened, ['case-1']);

    await tester.scrollUntilVisible(
      find.text('Vaka dosyası mevcut'),
      -500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Vaka dosyası mevcut'));
    await tester.pump();
    expect(opened, ['case-1', 'case-1']);
  });

  testWidgets('workspace scrolls and active and converted risks are separate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceCenterPage(
          repository: FakeRepository(
            CaseEvidenceCenterResult.fromMap(navigationResponseMap()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('case-files-workspace')));
    await tester.pumpAndSettle();
    expect(find.text('Vaka Dosyaları'), findsWidgets);
    expect(find.text('İnceleme Gerektiren Riskler'), findsOneWidget);
    expect(find.text('Vakaya Dönüştürülen Riskler'), findsOneWidget);
    expect(find.text('repeat_scan_observed'), findsNothing);
    expect(find.text('Tekrarlanan tarama gözlendi'), findsOneWidget);
  });
}
