import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_party_detail_page.dart';

class _Repository implements CasePartyRepository {
  final List<Map<String, dynamic>> appendRequests = [];
  Completer<Map<String, dynamic>>? pendingAppend;
  bool duplicate = false;
  int detailCount = 0;
  final List<Map<String, dynamic>> updateRequests = [];
  Completer<Map<String, dynamic>>? pendingUpdate;
  Map<String, dynamic> updateResult = {'duplicate': false, 'noChange': false};
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) async {
    detailCount++;
    return {
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
      'allowedActions': ['verify', 'edit_profile', 'add_note'],
      'readOnly': true,
      'writesPerformed': 0,
    };
  }

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
  Future<Map<String, dynamic>> updatePartyProfile(
    Map<String, dynamic> request,
  ) async {
    updateRequests.add(request);
    if (pendingUpdate != null) return pendingUpdate!.future;
    return updateResult;
  }

  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) async {
    appendRequests.add(request);
    if (pendingAppend != null) return pendingAppend!.future;
    return {'duplicate': duplicate};
  }
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

  testWidgets('rapid graph action submit invokes append and reload once', (
    tester,
  ) async {
    final repository = _Repository()
      ..pendingAppend = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartyDetailPage(
          partyId: 'party-internal',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Doğrula'), 300);
    await tester.tap(find.text('Doğrula'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('graph-event-note')),
      'Kontrollü doğrulama notu.',
    );
    final submit = find.byKey(const ValueKey('submit-graph-event'));
    await tester.tap(submit);
    await tester.tap(submit);
    expect(repository.appendRequests, hasLength(1));
    final requestId = repository.appendRequests.single['requestId'];
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    repository.pendingAppend!.complete({'duplicate': true});
    await tester.pumpAndSettle();
    expect(repository.appendRequests.single['requestId'], requestId);
    expect(repository.detailCount, 2);
    expect(find.text('Bu işlem daha önce kaydedildi.'), findsOneWidget);
  });

  testWidgets('profile edit is prefilled, stable and reloads once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()
      ..pendingUpdate = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartyDetailPage(
          partyId: 'party-internal',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Taraf bilgilerini düzenle'),
      300,
    );
    await tester.tap(find.text('Taraf bilgilerini düzenle'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('edit-party-name')))
          .controller!
          .text,
      'Örnek Satıcı',
    );
    expect(find.text('Satıcı hesabı'), findsAtLeastNWidgets(1));
    expect(find.text('Şüpheli satıcı'), findsAtLeastNWidgets(1));
    expect(find.text('Güncelleme gerekçesi'), findsOneWidget);
    expect(find.text('party-internal'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('edit-party-name')),
      'Dejure Marka',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-party-country')),
      'tr',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-party-note')),
      'Kimlik sınıflandırması güncellendi.',
    );
    final submit = find.byKey(const ValueKey('submit-party-profile'));
    await tester.tap(submit);
    await tester.tap(submit);
    expect(repository.updateRequests, hasLength(1));
    final requestId = repository.updateRequests.single['requestId'];
    expect(repository.updateRequests.single['partyId'], 'party-internal');
    expect(repository.updateRequests.single['displayName'], 'Dejure Marka');
    expect(repository.updateRequests.single['partyType'], 'seller_account');
    expect(repository.updateRequests.single['caseRoles'], ['suspected_seller']);
    expect(repository.updateRequests.single['countryCode'], 'TR');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    repository.pendingUpdate!.complete({'duplicate': false, 'noChange': false});
    await tester.pumpAndSettle();
    expect(repository.updateRequests.single['requestId'], requestId);
    expect(repository.detailCount, 2);
    expect(find.text('Taraf bilgileri güncellendi.'), findsOneWidget);
  });

  testWidgets('profile noChange is safe and does not reload', (tester) async {
    final repository = _Repository()
      ..updateResult = {'duplicate': false, 'noChange': true};
    await tester.pumpWidget(
      MaterialApp(
        home: CasePartyDetailPage(
          partyId: 'party-internal',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Taraf bilgilerini düzenle'),
      300,
    );
    await tester.tap(find.text('Taraf bilgilerini düzenle'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('edit-party-note')));
    await tester.enterText(
      find.byKey(const ValueKey('edit-party-note')),
      'Profil yeniden kontrol edildi.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-party-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-party-profile')));
    await tester.pumpAndSettle();
    expect(repository.detailCount, 1);
    expect(
      find.text('Taraf bilgilerinde değişiklik bulunmadı.'),
      findsOneWidget,
    );
  });
}
