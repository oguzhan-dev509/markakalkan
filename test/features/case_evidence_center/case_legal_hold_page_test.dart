import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_legal_hold_page.dart';

class _Repository implements CaseLegalHoldRepository {
  _Repository({required this.casesLoader, required this.detailLoader});

  final Future<List<CaseLegalHoldCaseOption>> Function() casesLoader;
  final Future<CaseLegalHoldDetail> Function(String caseId) detailLoader;

  Map<String, dynamic>? startRequest;
  Map<String, dynamic>? releaseRequest;

  @override
  Future<List<CaseLegalHoldCaseOption>> listCases() => casesLoader();

  @override
  Future<CaseLegalHoldDetail> load(String caseId) => detailLoader(caseId);

  @override
  Future<CaseLegalHoldMutation> start({
    required String caseId,
    required String reason,
    required String? authorityReference,
    required String requestId,
  }) async {
    startRequest = {
      'caseId': caseId,
      'reason': reason,
      'authorityReference': authorityReference,
      'requestId': requestId,
    };
    return const CaseLegalHoldMutation(
      holdId: 'hold-created',
      holdNumber: 'HM-2026-ABCDEF12',
      status: 'active',
      activeCount: 1,
      duplicate: false,
      transactionCommitted: true,
    );
  }

  @override
  Future<CaseLegalHoldMutation> release({
    required String holdId,
    required String reason,
    required String requestId,
  }) async {
    releaseRequest = {
      'holdId': holdId,
      'reason': reason,
      'requestId': requestId,
    };
    return const CaseLegalHoldMutation(
      holdId: 'internal-hold-id',
      holdNumber: 'HM-2026-AAAA1111',
      status: 'released',
      activeCount: 0,
      duplicate: false,
      transactionCommitted: true,
    );
  }
}

List<CaseLegalHoldCaseOption> _cases() => const [
  CaseLegalHoldCaseOption(
    caseId: 'internal-case-id',
    caseNumber: 'VK-2026-ABC12345',
    title: 'Şüpheli pazar yeri ilanı',
    status: 'open',
  ),
];

CaseLegalHoldDetail _detail({bool withHold = true}) =>
    CaseLegalHoldDetail.fromMap({
      'contractVersion': 'case-legal-hold-detail-v1',
      'readOnly': true,
      'writesPerformed': 0,
      'case': {
        'caseId': 'internal-case-id',
        'caseNumber': 'VK-2026-ABC12345',
        'title': 'Şüpheli pazar yeri ilanı',
        'status': 'open',
      },
      'legalHold': {
        'active': withHold,
        'activeCount': withHold ? 1 : 0,
        'latestHoldId': withHold ? 'internal-hold-id' : null,
        'startedAt': withHold ? '2026-07-24T10:00:00.000Z' : null,
        'releasedAt': null,
        'lastChangedAt': withHold ? '2026-07-24T10:00:00.000Z' : null,
      },
      'stats': {
        'totalHolds': withHold ? 1 : 0,
        'activeHolds': withHold ? 1 : 0,
        'releasedHolds': 0,
      },
      'holds': withHold
          ? [
              {
                'holdId': 'internal-hold-id',
                'holdNumber': 'HM-2026-AAAA1111',
                'caseId': 'internal-case-id',
                'scope': 'case_and_descendants',
                'status': 'active',
                'reason': 'Muhtemel hukuki süreç nedeniyle kayıt korunmalıdır.',
                'authorityReference': 'İç hukuk değerlendirmesi 2026/01',
                'startedAt': '2026-07-24T10:00:00.000Z',
                'releasedAt': null,
                'releaseReason': null,
                'eventCount': 1,
                'lastEventType': 'legal_hold_started',
                'lastEventAt': '2026-07-24T10:00:00.000Z',
              },
            ]
          : [],
      'events': withHold
          ? [
              {
                'holdId': 'internal-hold-id',
                'sequence': 1,
                'eventType': 'legal_hold_started',
                'note': 'Muhtemel hukuki süreç nedeniyle kayıt korunmalıdır.',
                'actorLabel': 'Yetkili kullanıcı',
                'recordedAt': '2026-07-24T10:00:00.000Z',
              },
            ]
          : [],
      'integrityStatus': 'verified',
    });

Future<void> _pump(
  WidgetTester tester,
  CaseLegalHoldRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: CaseLegalHoldPage(repository: repository)),
  );
}

void main() {
  testWidgets('workspace loads cases and presents safe legal hold detail', (
    tester,
  ) async {
    final casesCompleter = Completer<List<CaseLegalHoldCaseOption>>();
    final repository = _Repository(
      casesLoader: () => casesCompleter.future,
      detailLoader: (_) async => _detail(),
    );
    await _pump(tester, repository);
    expect(find.byKey(const ValueKey('legal-hold-loading')), findsOneWidget);
    casesCompleter.complete(_cases());
    await tester.pumpAndSettle();

    expect(find.text('VK-2026-ABC12345'), findsWidgets);
    expect(find.text('HM-2026-AAAA1111'), findsOneWidget);
    expect(find.text('Hukuki muhafaza başlatıldı'), findsOneWidget);
    expect(find.text('Aktif'), findsWidgets);
    expect(find.textContaining('internal-case-id'), findsNothing);
    expect(find.textContaining('internal-hold-id'), findsNothing);
  });

  testWidgets('workspace starts a hold with validated owner request', (
    tester,
  ) async {
    final repository = _Repository(
      casesLoader: () async => _cases(),
      detailLoader: (_) async => _detail(withHold: false),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-legal-hold')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-start-legal-hold')));
    await tester.pump();
    expect(find.text('Gerekçe en az 10 karakter olmalıdır.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('legal-hold-start-reason')),
      'Muhtemel hukuki süreç nedeniyle vaka kayıtları korunmalıdır.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('legal-hold-authority-reference')),
      'İç hukuk değerlendirmesi 2026/01',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-start-legal-hold')));
    await tester.pumpAndSettle();

    expect(repository.startRequest?['caseId'], 'internal-case-id');
    expect(
      repository.startRequest?['authorityReference'],
      'İç hukuk değerlendirmesi 2026/01',
    );
    expect(
      repository.startRequest?['requestId'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      find.text('HM-2026-ABCDEF12 hukuki muhafazası başlatıldı.'),
      findsOneWidget,
    );
  });

  testWidgets('workspace releases only the selected active hold', (
    tester,
  ) async {
    final repository = _Repository(
      casesLoader: () async => _cases(),
      detailLoader: (_) async => _detail(),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('release-legal-hold-internal-hold-id')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('legal-hold-release-reason')),
      'Yetkili değerlendirme sonucunda muhafaza ihtiyacı sona erdi.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-release-legal-hold')));
    await tester.pumpAndSettle();

    expect(repository.releaseRequest?['holdId'], 'internal-hold-id');
    expect(
      repository.releaseRequest?['reason'],
      'Yetkili değerlendirme sonucunda muhafaza ihtiyacı sona erdi.',
    );
    expect(
      find.text('HM-2026-AAAA1111 hukuki muhafazası kaldırıldı.'),
      findsOneWidget,
    );
  });

  testWidgets('workspace has safe empty and error states', (tester) async {
    await _pump(
      tester,
      _Repository(
        casesLoader: () async => const [],
        detailLoader: (_) async => _detail(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Hukuki muhafaza uygulanabilecek vaka dosyası bulunmuyor.'),
      findsOneWidget,
    );
  });
}
