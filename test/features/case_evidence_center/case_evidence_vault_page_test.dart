import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_chain_presentation_labels.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_vault_page.dart';

class _Repository implements CaseEvidenceVaultRepository {
  _Repository(this.loader);
  final Future<EvidenceVaultResult> Function() loader;

  @override
  Future<EvidenceVaultResult> loadVault() => loader();

  @override
  Future<EvidenceItemDetail> loadDetail(String evidenceRefId) =>
      throw UnimplementedError();

  @override
  Future<EvidenceAppendResult> append(
    String evidenceRefId,
    String eventType,
    String note,
    String requestId,
  ) => throw UnimplementedError();
}

EvidenceVaultResult _result({bool empty = false, Object? lastChainEventAt}) =>
    EvidenceVaultResult.fromMap({
      'contractVersion': 'case-evidence-vault-list-v1',
      'readOnly': true,
      'writesPerformed': 0,
      'stats': {
        'totalEvidence': empty ? 0 : 1,
        'awaitingReview': empty ? 0 : 1,
        'underReview': 0,
        'verified': 0,
        'sealed': 0,
        'chainNotStarted': empty ? 0 : 1,
      },
      'items': empty
          ? []
          : [
              {
                'evidenceRefId': 'internal-evidence-id',
                'caseId': 'internal-case-id',
                'caseNumber': 'VK-2026-EA953C48',
                'caseTitle': 'Şüpheli tarama vakası',
                'evidenceLabel': 'Kaynak risk kaydı',
                'evidenceType': 'source_record',
                'sourceLabel': 'İzleme sistemi',
                'reviewStatus': 'awaiting_review',
                'custodyStatus': 'not_started',
                'integrityStatus': 'not_started',
                'chainEventCount': 0,
                'createdAt': '2026-07-22T10:00:00.000Z',
                'lastChainEventAt': lastChainEventAt,
              },
            ],
    });

void main() {
  test('date formatter preserves day, month, hour and minute zero padding', () {
    expect(
      caseEvidenceDateTimeLabel('2026-08-03T06:05:00.000Z'),
      '03.08.2026 09:05',
    );
  });

  testWidgets(
    'vault shows loading then safe Turkish content and opens detail',
    (tester) async {
      final completer = Completer<EvidenceVaultResult>();
      String? openedId;
      await tester.pumpWidget(
        MaterialApp(
          home: CaseEvidenceVaultPage(
            repository: _Repository(() => completer.future),
            detailOpener: (_, id) async => openedId = id,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('evidence-vault-loading')),
        findsOneWidget,
      );
      completer.complete(_result());
      await tester.pumpAndSettle();

      expect(find.text('Toplam Delil: 1'), findsOneWidget);
      expect(find.text('İnceleme Bekliyor: 1'), findsOneWidget);
      expect(find.text('Kaynak risk kaydı'), findsOneWidget);
      expect(find.textContaining('İnceleme bekliyor'), findsOneWidget);
      expect(find.textContaining('Zincir başlatılmadı'), findsOneWidget);
      expect(find.textContaining('internal-evidence-id'), findsNothing);
      expect(find.textContaining('internal-case-id'), findsNothing);
      expect(find.textContaining('awaiting_review'), findsNothing);
      expect(find.textContaining('chainHash'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('evidence-internal-evidence-id')),
      );
      await tester.pump();
      expect(openedId, 'internal-evidence-id');
    },
  );

  testWidgets('vault has empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceVaultPage(
          repository: _Repository(() async => _result(empty: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz delil kaydı bulunmuyor.'), findsOneWidget);
  });

  testWidgets('vault formats the last chain event in local date and time', (
    tester,
  ) async {
    const raw = '2026-07-23T04:58:04.271Z';
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceVaultPage(
          repository: _Repository(() async => _result(lastChainEventAt: raw)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Son zincir işlemi: 23.07.2026 07:58'),
      findsOneWidget,
    );
    expect(find.textContaining(raw), findsNothing);
    expect(find.textContaining('T04:58'), findsNothing);
  });

  testWidgets('vault preserves the no chain event message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceVaultPage(
          repository: _Repository(() async => _result()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Son zincir işlemi: Henüz yok'), findsOneWidget);
  });

  testWidgets('vault has safe error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseEvidenceVaultPage(
          repository: _Repository(() async => throw StateError('secret')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delil kasası yüklenemedi.'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });
}
