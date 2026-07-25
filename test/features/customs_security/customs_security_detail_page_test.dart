import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_detail_page.dart';

import 'customs_security_test_fakes.dart';

void main() {
  testWidgets('profile detail renders rights authentication and audit data', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.profile(
          profileId: 'profile-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('customs-profile-detail')),
      findsOneWidget,
    );
    expect(find.text('Hak ve ürün kapsamı'), findsOneWidget);
    expect(find.text('Orijinal ürün doğrulama kiti'), findsOneWidget);
    expect(find.text('TR-MARKA-123'), findsOneWidget);
    expect(find.text('Hologram ve parti kodu'), findsOneWidget);
  });

  testWidgets('profile transition requires a reason and updates status', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository(
      profiles: [sampleProfile(status: 'draft')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.profile(
          profileId: 'profile-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('transition-customs-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customs-transition-reason')),
      'Hak ve ürün kayıtları insan incelemesine hazırlandı.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-customs-transition')));
    await tester.pumpAndSettle();

    expect(repository.transitionProfileCalls, 1);
    expect(repository.lastNextStatus, 'under_review');
    expect(find.text('İncelemede'), findsWidgets);
  });

  testWidgets('intervention detail keeps integrity signal legally neutral', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository(
      interventions: [sampleIntervention(integritySignal: true)],
    );
    await tester.binding.setSurfaceSize(const Size(1100, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.intervention(
          interventionId: 'intervention-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('customs-intervention-detail')),
      findsOneWidget,
    );
    expect(find.text('İşlem bütünlüğü'), findsOneWidget);
    expect(find.text('İşlem bütünlüğü sinyali'), findsOneWidget);
    expect(
      find.textContaining('otomatik rüşvet veya suç sonucu üretmez'),
      findsOneWidget,
    );
    expect(find.text('Değiştirilemez olay zinciri'), findsOneWidget);
    expect(find.text('Dosya ön incelemeye alındı.'), findsOneWidget);
  });

  testWidgets('released transition requires decision reference', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository(
      interventions: [sampleIntervention(status: 'temporarily_detained')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.intervention(
          interventionId: 'intervention-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('transition-customs-intervention')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('customs-next-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serbest bırakıldı').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customs-transition-reason')),
      'Yetkili karar ve doğrulama sonucu serbest bırakmayı destekliyor.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-customs-transition')));
    await tester.pumpAndSettle();
    expect(find.text('Bu dayanak zorunludur.'), findsOneWidget);
    expect(repository.transitionInterventionCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('customs-decision-reference')),
      'GUMRUK-KARAR-2026-44',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-customs-transition')));
    await tester.pumpAndSettle();

    expect(repository.transitionInterventionCalls, 1);
    expect(repository.lastNextStatus, 'released');
    expect(repository.lastDecisionReference, 'GUMRUK-KARAR-2026-44');
  });
}
