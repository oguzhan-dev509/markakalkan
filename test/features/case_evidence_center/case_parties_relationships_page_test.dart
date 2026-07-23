import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';

class _Repository implements CasePartyRepository {
  _Repository(this.value);
  final Map<String, dynamic> value;
  final List<Map<String, dynamic>> createRequests = [];
  Completer<Map<String, dynamic>>? pendingCreate;
  bool failNextCreate = false;
  bool duplicate = false;
  @override
  Future<Map<String, dynamic>> workspace() async => value;
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) async => {};
  @override
  Future<Map<String, dynamic>> timeline(String caseId) async => {};
  @override
  Future<Map<String, dynamic>> createParty(Map<String, dynamic> request) async {
    createRequests.add(request);
    if (failNextCreate) {
      failNextCreate = false;
      throw TimeoutException('uncertain transport result');
    }
    if (pendingCreate != null) return pendingCreate!.future;
    return {'partyId': 'party-internal', 'duplicate': duplicate};
  }

  @override
  Future<Map<String, dynamic>> createRelationship(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) async => {};
}

Map<String, dynamic> _fixture() => {
  'contractVersion': 'case-party-workspace-list-v1',
  'stats': {
    'totalParties': 1,
    'observedParties': 1,
    'underReviewParties': 0,
    'verifiedParties': 0,
    'disputedParties': 0,
    'activeRelationships': 1,
  },
  'cases': [
    {
      'caseId': 'case-internal',
      'caseNumber': 'VK-2026-EA953C48',
      'caseTitle': 'Dejure Spor Ayakkabı',
      'status': 'open',
    },
  ],
  'parties': [
    {
      'partyId': 'party-internal',
      'partyNumber': 'TRF-2026-7A91C4D2',
      'caseId': 'case-internal',
      'caseNumber': 'VK-2026-EA953C48',
      'caseTitle': 'Dejure Spor Ayakkabı',
      'displayName': 'Örnek Satıcı',
      'partyType': 'seller_account',
      'caseRoles': ['suspected_seller'],
      'status': 'observed',
      'relationshipCount': 1,
      'lastEventAt': '2026-07-23T14:47:00.000Z',
    },
  ],
  'relationships': [
    {
      'relationshipId': 'relationship-internal',
      'relationshipNumber': 'IL-2026-51D2A884',
      'caseId': 'case-internal',
      'sourceLabel': 'Örnek Satıcı',
      'targetLabel': 'Kaynak risk kaydı incelemesi',
      'relationshipType': 'assigned_to_task',
      'status': 'observed',
      'confidence': 'high',
      'summary': 'Taraf inceleme görevine bağlandı.',
      'lastEventAt': '2026-07-23T14:47:00.000Z',
    },
  ],
  'readOnly': true,
  'writesPerformed': 0,
};

Future<void> _openAndFillPartyForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('create-party')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('party-name')),
    'Örnek Satıcı',
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('party-role-related_party')),
  );
  await tester.tap(find.byKey(const ValueKey('party-role-related_party')));
  await tester.ensureVisible(find.byKey(const ValueKey('party-description')));
  await tester.enterText(
    find.byKey(const ValueKey('party-description')),
    'Kontrollü taraf inceleme açıklaması.',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('submit-party')));
}

void main() {
  testWidgets('workspace renders Turkish safe party and relationship content', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartiesRelationshipsPage(
          repository: _Repository(_fixture()),
          partyDetailOpener: (_, id) async => opened = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Toplam Taraf: 1'), findsOneWidget);
    expect(find.textContaining('Satıcı hesabı'), findsOneWidget);
    expect(find.textContaining('Şüpheli satıcı'), findsOneWidget);
    expect(find.textContaining('party-internal'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('party-party-internal')));
    expect(opened, 'party-internal');
    await tester.tap(find.text('İlişkiler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Göreve bağlı'), findsOneWidget);
    expect(find.textContaining('Yüksek güven'), findsOneWidget);
    expect(find.textContaining('assigned_to_task'), findsNothing);
  });

  testWidgets('workspace empty response is user friendly', (tester) async {
    final value = _fixture()
      ..['parties'] = <Object>[]
      ..['relationships'] = <Object>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartiesRelationshipsPage(repository: _Repository(value)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz taraf kaydı bulunmuyor.'), findsOneWidget);
  });

  testWidgets('party form validates and sends the complete canonical payload', (
    tester,
  ) async {
    final repository = _Repository(_fixture());
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartiesRelationshipsPage(
          repository: repository,
          partyDetailOpener: (_, id) async => opened = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-party')));
    await tester.pumpAndSettle();
    for (final label in [
      'Bağlı vaka',
      'Taraf türü',
      'Vaka rolleri (1–5)',
      'Kamuya açık ad veya kullanıcı adı',
      'Kuruluş',
      'Ülke kodu',
      'Şehir',
      'Açıklama',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
    expect(find.text('case-internal'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('party-name')),
      'Örnek Satıcı',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('party-description')));
    await tester.enterText(
      find.byKey(const ValueKey('party-description')),
      'Kontrollü taraf inceleme açıklaması.',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('submit-party')));
    await tester.tap(find.byKey(const ValueKey('submit-party')));
    await tester.pump();
    expect(repository.createRequests, isEmpty);
    expect(find.textContaining('en az bir vaka rolü'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('party-role-suspected_seller')),
    );
    await tester.tap(find.byKey(const ValueKey('party-role-suspected_seller')));
    await tester.ensureVisible(find.byKey(const ValueKey('party-type')));
    await tester.tap(find.byKey(const ValueKey('party-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satıcı hesabı').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('party-public-alias')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('party-public-alias')),
      'dejure_store',
    );
    await tester.enterText(
      find.byKey(const ValueKey('party-organization')),
      'Dejure',
    );
    await tester.enterText(
      find.byKey(const ValueKey('party-country-code')),
      'tr',
    );
    await tester.enterText(
      find.byKey(const ValueKey('party-city')),
      'İstanbul',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('submit-party')));
    await tester.tap(find.byKey(const ValueKey('submit-party')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, hasLength(1));
    final request = repository.createRequests.single;
    expect(request['caseId'], 'case-internal');
    expect(request['displayName'], 'Örnek Satıcı');
    expect(request['partyType'], 'seller_account');
    expect(request['caseRoles'], ['suspected_seller']);
    expect(request['publicAlias'], 'dejure_store');
    expect(request['organizationName'], 'Dejure');
    expect(request['countryCode'], 'TR');
    expect(request['city'], 'İstanbul');
    expect(request['description'], 'Kontrollü taraf inceleme açıklaması.');
    expect(opened, 'party-internal');
  });

  testWidgets(
    'rapid party double submit invokes callable and navigation once',
    (tester) async {
      final repository = _Repository(_fixture())
        ..pendingCreate = Completer<Map<String, dynamic>>();
      var navigationCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CasePartiesRelationshipsPage(
            repository: repository,
            partyDetailOpener: (_, _) async => navigationCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openAndFillPartyForm(tester);
      final submit = find.byKey(const ValueKey('submit-party'));
      await tester.tap(submit);
      await tester.tap(submit);
      expect(repository.createRequests, hasLength(1));
      final stableRequestId = repository.createRequests.single['requestId'];
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      repository.pendingCreate!.complete({
        'partyId': 'party-internal',
        'duplicate': false,
      });
      await tester.pumpAndSettle();
      expect(repository.createRequests.single['requestId'], stableRequestId);
      expect(navigationCount, 1);
    },
  );

  testWidgets(
    'uncertain party retry reuses requestId and duplicate opens detail',
    (tester) async {
      final repository = _Repository(_fixture())
        ..failNextCreate = true
        ..duplicate = true;
      var navigationCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CasePartiesRelationshipsPage(
            repository: repository,
            partyDetailOpener: (_, _) async => navigationCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openAndFillPartyForm(tester);
      final submit = find.byKey(const ValueKey('submit-party'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aynı istekle yeniden deneyin'),
        findsOneWidget,
      );
      final firstId = repository.createRequests.single['requestId'];
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.createRequests, hasLength(2));
      expect(repository.createRequests.last['requestId'], firstId);
      expect(navigationCount, 1);
      expect(find.text('Bu işlem daha önce kaydedildi.'), findsOneWidget);
      expect(find.text('party-internal'), findsNothing);
    },
  );
}
