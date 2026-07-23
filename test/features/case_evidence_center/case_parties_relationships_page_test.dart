import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';

class _Repository implements CasePartyRepository {
  _Repository(this.value);
  final Map<String, dynamic> value;
  @override
  Future<Map<String, dynamic>> workspace() async => value;
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) async => {};
  @override
  Future<Map<String, dynamic>> timeline(String caseId) async => {};
  @override
  Future<Map<String, dynamic>> createParty(
    Map<String, dynamic> request,
  ) async => {'partyId': 'party-internal', 'duplicate': false};
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
}
