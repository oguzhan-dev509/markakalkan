import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_center_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_detail_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_presentation_labels.dart';

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

Map<String, dynamic> labelsResponseMap() {
  final map = navigationResponseMap();
  final candidates = map['caseCandidates']! as List<dynamic>;
  candidates.add({
    ...(candidates.first as Map<String, dynamic>),
    'signalId': 'signal-3',
    'title': 'unknown_signal_code',
  });
  return map;
}

void main() {
  test('signal labels normalize lists, duplicates and safe fallbacks', () {
    expect(
      caseEvidenceSignalLabel(
        ' repeat_scan_observed, rapid_repeat_scan, repeat_scan_observed ',
      ),
      'Tekrarlanan tarama gözlendi, Kısa sürede tekrar tarandı',
    );
    expect(
      caseEvidenceSignalLabel('repeat_scan_observed, unknown_signal_code'),
      'Tekrarlanan tarama gözlendi, İnceleme sinyali',
    );
    expect(caseEvidenceSignalLabel('unknown_signal_code'), 'İnceleme sinyali');
    expect(caseEvidenceSignalLabel(null), 'İnceleme sinyali');
    expect(
      caseEvidenceSignalLabel('Şüpheli tekrar tarama davranışı gözlendi'),
      'Şüpheli tekrar tarama davranışı gözlendi',
    );
  });

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

  testWidgets('center presents known and unknown signal codes safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceCenterPage(
          repository: FakeRepository(
            CaseEvidenceCenterResult.fromMap(labelsResponseMap()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tekrarlanan tarama gözlendi'), findsOneWidget);
    expect(find.text('Kısa sürede tekrar tarandı'), findsOneWidget);
    expect(find.text('İnceleme sinyali'), findsOneWidget);
    expect(find.textContaining('repeat_scan_observed'), findsNothing);
    expect(find.textContaining('rapid_repeat_scan'), findsNothing);
    expect(find.textContaining('unknown_signal_code'), findsNothing);
  });

  testWidgets('all case controls push the real detail route with internal id', (
    tester,
  ) async {
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

    final convertedCode = find.byKey(
      const ValueKey('converted-case-code-signal-2'),
    );
    await tester.scrollUntilVisible(
      convertedCode,
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(convertedCode);
    await tester.pumpAndSettle();
    final convertedButton = find
        .descendant(of: convertedCode, matching: find.byType(TextButton))
        .hitTestable();
    expect(convertedButton, findsOneWidget);
    await tester.tap(convertedButton);
    await tester.pumpAndSettle();
    expect(find.byType(CaseEvidenceDetailPage), findsOneWidget);
    var detail = tester.widget<CaseEvidenceDetailPage>(
      find.byType(CaseEvidenceDetailPage),
    );
    expect(detail.caseId, 'case-1');
    expect(detail.caseId, isNot('VK-2026-ABC12345'));
    expect(detail.caseId, isNot('source-1'));
    expect(
      ModalRoute.of(
        tester.element(find.byType(CaseEvidenceDetailPage)),
      )!.settings.name,
      '/case-evidence-center/case-detail',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Vaka dosyası mevcut'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.text('Vaka dosyası mevcut'));
    await tester.pumpAndSettle();
    final existingCaseButton = find
        .widgetWithText(FilledButton, 'Vaka dosyası mevcut')
        .hitTestable();
    expect(existingCaseButton, findsOneWidget);
    await tester.tap(existingCaseButton);
    await tester.pumpAndSettle();
    detail = tester.widget<CaseEvidenceDetailPage>(
      find.byType(CaseEvidenceDetailPage),
    );
    expect(detail.caseId, 'case-1');
    await tester.pageBack();
    await tester.pumpAndSettle();

    final listedCode = find.byKey(const ValueKey('case-code-case-1'));
    await tester.scrollUntilVisible(
      listedCode,
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(listedCode);
    await tester.pumpAndSettle();
    final listedButton = listedCode.hitTestable();
    expect(listedButton, findsOneWidget);
    await tester.tap(listedButton);
    await tester.pumpAndSettle();
    detail = tester.widget<CaseEvidenceDetailPage>(
      find.byType(CaseEvidenceDetailPage),
    );
    expect(detail.caseId, 'case-1');
  });

  testWidgets('missing existing case id shows a safe message', (tester) async {
    final response = navigationResponseMap();
    final candidates = response['caseCandidates']! as List<dynamic>;
    (candidates.last as Map<String, dynamic>)['existingCaseId'] = null;
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceCenterPage(
          repository: FakeRepository(
            CaseEvidenceCenterResult.fromMap(response),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final code = find.byKey(const ValueKey('converted-case-code-signal-2'));
    await tester.scrollUntilVisible(
      code,
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(code);
    await tester.pumpAndSettle();
    await tester.tap(code);
    await tester.pump();
    expect(find.text('Vaka ayrıntısı şu anda açılamıyor.'), findsOneWidget);
    expect(find.byType(CaseEvidenceDetailPage), findsNothing);
  });

  testWidgets('workspace reaches a lazy case section and gives feedback', (
    tester,
  ) async {
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
    final scrollable = find.byType(Scrollable);
    final workspace = find.byKey(const ValueKey('case-files-workspace'));
    await tester.scrollUntilVisible(workspace, 200, scrollable: scrollable);
    await tester.ensureVisible(workspace);
    await tester.pumpAndSettle();
    final workspaceTap = tester.widget<InkWell>(workspace).onTap!;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(find.text('Vakaya Dönüştürülen Riskler'), findsNothing);
    await tester.tap(workspace);
    await tester.pumpAndSettle();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, greaterThan(before));
    expect(find.text('Vaka Dosyaları'), findsWidgets);
    expect(find.text('Vaka dosyaları bölümüne ulaşıldı.'), findsOneWidget);

    workspaceTap();
    await tester.pumpAndSettle();
    expect(find.text('Vaka dosyaları bölümüne ulaşıldı.'), findsOneWidget);
  });
}
