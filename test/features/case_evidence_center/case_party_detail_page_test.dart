import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_party_detail_page.dart';

class _Repository implements CasePartyRepository {
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) async => {
    'contractVersion': 'case-party-detail-v1',
    'party': {
      'partyId': partyId,
      'partyNumber': 'TRF-2026-7A91C4D2',
      'caseId': 'case-internal',
      'caseNumber': 'VK-2026-EA953C48',
      'caseTitle': 'Dejure Spor Ayakkabı',
      'displayName': 'Örnek Satıcı',
      'partyType': 'seller_account',
      'caseRoles': ['suspected_seller'],
      'status': 'under_review',
      'description': 'Kontrollü taraf açıklaması.',
      'createdAt': '2026-07-23T14:47:00.000Z',
      'updatedAt': '2026-07-23T14:47:00.000Z',
    },
    'relationships': [
      {
        'sourceEntityType': 'party',
        'sourceEntityId': partyId,
        'sourceLabel': 'Örnek Satıcı',
        'targetEntityType': 'task',
        'targetEntityId': 'task-internal',
        'targetLabel': 'Kaynak risk kaydı incelemesi',
        'relationshipType': 'assigned_to_task',
        'status': 'observed',
      },
    ],
    'timelineEvents': [
      {
        'sequence': 1,
        'eventType': 'party_created',
        'note': 'Taraf kaydı oluşturuldu.',
        'recordedAt': '2026-07-23T14:47:00.000Z',
      },
    ],
    'allowedActions': ['verify', 'add_note'],
    'readOnly': true,
    'writesPerformed': 0,
  };
  @override
  Future<Map<String, dynamic>> workspace() async => {};
  @override
  Future<Map<String, dynamic>> timeline(String caseId) async => {};
  @override
  Future<Map<String, dynamic>> createParty(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> createRelationship(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) async => {
    'duplicate': false,
  };
}

void main() {
  testWidgets(
    'party detail shows safe timeline actions and linked task route',
    (tester) async {
      String? openedType;
      String? openedId;
      await tester.pumpWidget(
        MaterialApp(
          home: CasePartyDetailPage(
            partyId: 'party-internal',
            repository: _Repository(),
            linkOpener: (_, type, id) async {
              openedType = type;
              openedId = id;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TRF-2026-7A91C4D2'), findsOneWidget);
      expect(find.textContaining('Satıcı hesabı'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Doğrula'), 300);
      expect(find.text('Doğrula'), findsOneWidget);
      expect(find.text('Pasife al'), findsNothing);
      expect(find.textContaining('party_created'), findsNothing);
      await tester.tap(find.text('Kaynak risk kaydı incelemesi'));
      expect(openedType, 'task');
      expect(openedId, 'task-internal');
    },
  );
}
