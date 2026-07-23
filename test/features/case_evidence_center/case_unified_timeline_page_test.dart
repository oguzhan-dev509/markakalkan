import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_unified_timeline_page.dart';

class _Repository implements CasePartyRepository {
  @override
  Future<Map<String, dynamic>> timeline(String caseId) async => {
    'contractVersion': 'case-unified-timeline-v1',
    'case': {
      'caseId': caseId,
      'caseNumber': 'VK-2026-EA953C48',
      'caseTitle': 'Dejure Spor Ayakkabı',
      'status': 'open',
    },
    'stats': {
      'totalEvents': 2,
      'caseEvents': 0,
      'evidenceEvents': 0,
      'taskEvents': 1,
      'partyEvents': 1,
      'relationshipEvents': 0,
    },
    'events': [
      {
        'eventType': 'party_created',
        'eventLabel': 'Taraf kaydı oluşturuldu',
        'category': 'party',
        'categoryLabel': 'Taraf',
        'summary': 'TRF-2026-7A91C4D2 taraf kaydı oluşturuldu.',
        'occurredAt': '2026-07-23T14:47:00.000Z',
      },
      {
        'eventType': 'review_task_created',
        'eventLabel': 'Görev oluşturuldu',
        'category': 'task',
        'categoryLabel': 'Görev',
        'summary': 'GV-2026-43A9D932 inceleme görevi oluşturuldu.',
        'occurredAt': '2026-07-23T13:00:00.000Z',
      },
    ],
    'readOnly': true,
    'writesPerformed': 0,
  };
  @override
  Future<Map<String, dynamic>> workspace() async => {};
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) async => {};
  @override
  Future<Map<String, dynamic>> createParty(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> createRelationship(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) async => {};
}

void main() {
  testWidgets('unified timeline presents local date and category filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaseUnifiedTimelinePage(
          caseId: 'case-internal',
          repository: _Repository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('VK-2026-EA953C48'), findsOneWidget);
    expect(find.textContaining('23.07.2026 17:47'), findsOneWidget);
    expect(find.textContaining('2026-07-23T14:47'), findsNothing);
    expect(find.textContaining('party_created'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Taraf'));
    await tester.pumpAndSettle();
    expect(find.text('Görev oluşturuldu'), findsNothing);
    expect(find.text('Taraf kaydı oluşturuldu'), findsOneWidget);
  });
}
