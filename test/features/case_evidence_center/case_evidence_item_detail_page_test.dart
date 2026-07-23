import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_item_detail_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_vault_page.dart';

class _Repository implements CaseEvidenceVaultRepository {
  _Repository(this.detail, {this.duplicate = false});
  EvidenceItemDetail detail;
  final bool duplicate;
  int loads = 0;
  int appends = 0;
  String? eventType;
  String? note;

  @override
  Future<EvidenceVaultResult> loadVault() => throw UnimplementedError();

  @override
  Future<EvidenceItemDetail> loadDetail(String evidenceRefId) async {
    loads++;
    return detail;
  }

  @override
  Future<EvidenceAppendResult> append(
    String evidenceRefId,
    String eventType,
    String note,
    String requestId,
  ) async {
    appends++;
    this.eventType = eventType;
    this.note = note;
    return EvidenceAppendResult(duplicate: duplicate);
  }
}

EvidenceItemDetail _detail({
  List<String> actions = const ['chain_started'],
  bool withEvent = false,
  Object? recordedAt = '2026-07-23T04:58:04.271Z',
}) => EvidenceItemDetail.fromMap({
  'contractVersion': 'case-evidence-item-detail-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'evidence': {
    'evidenceRefId': 'internal-evidence-id',
    'caseId': 'internal-case-id',
    'caseNumber': 'VK-2026-EA953C48',
    'caseTitle': 'Şüpheli tarama vakası',
    'evidenceLabel': 'Kaynak risk kaydı',
    'evidenceType': 'source_record',
    'sourceLabel': 'İzleme sistemi',
    'reviewStatus': withEvent ? 'under_review' : 'awaiting_review',
    'custodyStatus': withEvent ? 'registered' : 'not_started',
    'integrityStatus': withEvent ? 'verified' : 'not_started',
    'chainEventCount': withEvent ? 1 : 0,
    'createdAt': '2026-07-22T10:00:00.000Z',
    'lastChainEventAt': null,
  },
  'chainEvents': withEvent
      ? [
          {
            'sequence': 1,
            'eventType': 'chain_started',
            'eventLabel': 'Delil zinciri başlatıldı',
            'note': 'İlk teslim kaydı',
            'actorLabel': 'Yetkili kullanıcı',
            'recordedAt': recordedAt,
          },
        ]
      : [],
  'allowedActions': actions,
});

void main() {
  testWidgets('detail shows loading, safe fields and only allowed actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceItemDetailPage(
          evidenceRefId: 'internal-evidence-id',
          repository: _Repository(_detail())
            ..detail = _detail(actions: const ['review_started']),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('evidence-detail-loading')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('VK-2026-EA953C48 · Şüpheli tarama vakası'),
      findsOneWidget,
    );
    expect(find.textContaining('İnceleme bekliyor'), findsWidgets);
    expect(find.text('İncelemeyi başlat'), findsOneWidget);
    expect(find.text('Mühürle'), findsNothing);
    expect(find.textContaining('internal-evidence-id'), findsNothing);
    expect(find.textContaining('chainHash'), findsNothing);
    expect(find.textContaining('review_started'), findsNothing);
  });

  testWidgets(
    'starts chain with validated note, reloads and reports duplicate',
    (tester) async {
      final repository = _Repository(_detail(), duplicate: true);
      await tester.pumpWidget(
        MaterialApp(
          home: CaseEvidenceItemDetailPage(
            evidenceRefId: 'internal-evidence-id',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delil zinciri henüz başlatılmadı.'), findsOneWidget);
      await tester.tap(find.text('Delil zincirini başlat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('evidence-note')), 'x');
      await tester.tap(find.text('Onayla'));
      await tester.pump();
      expect(repository.appends, 0);
      await tester.enterText(
        find.byKey(const ValueKey('evidence-note')),
        'İlk teslim kaydı',
      );
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(repository.eventType, 'chain_started');
      expect(repository.note, 'İlk teslim kaydı');
      expect(repository.loads, 2);
      expect(find.text('Bu işlem daha önce kaydedildi.'), findsOneWidget);
    },
  );

  testWidgets('renders Turkish chain timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceItemDetailPage(
          evidenceRefId: 'internal-evidence-id',
          repository: _Repository(
            _detail(actions: const ['sealed'], withEvent: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delil zinciri başlatıldı'), findsOneWidget);
    expect(find.textContaining('İlk teslim kaydı'), findsOneWidget);
    expect(find.textContaining('23.07.2026 07:58'), findsOneWidget);
    expect(find.textContaining('2026-07-23T04:58:04.271Z'), findsNothing);
    expect(find.textContaining('Bütünlük doğrulandı'), findsOneWidget);
    expect(find.text('Mühürle'), findsOneWidget);
    expect(find.textContaining('chain_started'), findsNothing);
  });

  for (final scenario in [(null, 'null'), ('not-a-timestamp', 'invalid')]) {
    testWidgets('timeline uses fallback for ${scenario.$2} timestamp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CaseEvidenceItemDetailPage(
            evidenceRefId: 'internal-evidence-id',
            repository: _Repository(
              _detail(
                actions: const ['sealed'],
                withEvent: true,
                recordedAt: scenario.$1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tarih bilgisi yok'), findsOneWidget);
      expect(find.textContaining('not-a-timestamp'), findsNothing);
      expect(find.text('Delil zinciri başlatıldı'), findsOneWidget);
      expect(find.text('Mühürle'), findsOneWidget);
    });
  }

  for (final scenario in [
    ('not-found', 'Delil kaydı bulunamadı.'),
    ('permission-denied', 'Bu delili görüntüleme yetkiniz bulunmuyor.'),
    ('internal', 'Delil ayrıntısı yüklenemedi.'),
  ]) {
    testWidgets('detail ${scenario.$1} error is safe', (tester) async {
      final repository = _ThrowingRepository(scenario.$1);
      await tester.pumpWidget(
        MaterialApp(
          home: CaseEvidenceItemDetailPage(
            evidenceRefId: 'internal-evidence-id',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.textContaining('technical'), findsNothing);
    });
  }
}

class _ThrowingRepository implements CaseEvidenceVaultRepository {
  _ThrowingRepository(this.code);
  final String code;
  @override
  Future<EvidenceVaultResult> loadVault() => throw UnimplementedError();
  @override
  Future<EvidenceItemDetail> loadDetail(String evidenceRefId) async =>
      throw FirebaseFunctionsException(code: code, message: 'technical');
  @override
  Future<EvidenceAppendResult> append(
    String evidenceRefId,
    String eventType,
    String note,
    String requestId,
  ) => throw UnimplementedError();
}
