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
      'totalEvents': 6,
      'caseEvents': 2,
      'evidenceEvents': 1,
      'taskEvents': 2,
      'partyEvents': 1,
      'relationshipEvents': 0,
    },
    'events': [
      {
        'eventType': 'review_task_due_date_changed',
        'eventLabel': 'Görev son tarihi değiştirildi',
        'category': 'task',
        'categoryLabel': 'Görev',
        'summary': 'Son tarihi değiştirildi',
        'occurredAt': '2026-07-23T14:47:00.000Z',
      },
      {
        'eventType': 'review_task_created',
        'eventLabel': 'İnceleme görevi oluşturuldu',
        'category': 'task',
        'categoryLabel': 'Görev',
        'summary': 'GV-2026-43A9D932 inceleme görevi oluşturuldu.',
        'occurredAt': '2026-07-23T13:00:00.000Z',
      },
      {
        'eventType': 'party_profile_updated',
        'eventLabel': 'Taraf bilgileri güncellendi',
        'category': 'party',
        'categoryLabel': 'Taraf',
        'summary': 'TRF-2026-7A91C4D2 taraf bilgileri güncellendi.',
        'occurredAt': '2026-07-23T12:30:00.000Z',
      },
      {
        'eventType': 'evidence_chain_started',
        'eventLabel': 'Delil zinciri başlatıldı',
        'category': 'evidence',
        'categoryLabel': 'Delil',
        'summary': 'Delil zinciri başlatıldı',
        'occurredAt': '2026-07-23T12:00:00.000Z',
      },
      {
        'eventType': 'case_opened_from_risk',
        'eventLabel': 'Vaka dosyası açıldı',
        'category': 'case',
        'categoryLabel': 'Vaka',
        'summary': 'Risk sinyalinden kontrollü vaka dosyası açıldı',
        'occurredAt': '2026-07-23T11:00:00.000Z',
      },
      {
        'eventType': 'unknown_internal_event',
        'eventLabel': 'Vaka olayı',
        'category': 'case',
        'categoryLabel': 'Vaka',
        'summary': 'Güvenli özet',
        'occurredAt': '2026-07-23T10:00:00.000Z',
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
  Future<Map<String, dynamic>> updatePartyProfile(
    Map<String, dynamic> request,
  ) async => {};
  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) async => {};
}

void main() {
  testWidgets('unified timeline presents local date and category filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    for (final label in [
      'Görev son tarihi değiştirildi',
      'İnceleme görevi oluşturuldu',
      'Taraf bilgileri güncellendi',
      'Delil zinciri başlatıldı',
      'Vaka dosyası açıldı',
      'Vaka olayı',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
    expect(find.textContaining('review_task_due_date_changed'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Görev'));
    await tester.tap(find.widgetWithText(FilterChip, 'Görev'));
    await tester.pumpAndSettle();
    expect(find.text('Vaka dosyası açıldı'), findsNothing);
    expect(find.text('Görev son tarihi değiştirildi'), findsOneWidget);
  });
}
