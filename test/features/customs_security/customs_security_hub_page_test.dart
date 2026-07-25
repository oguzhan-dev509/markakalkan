import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_hub_page.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';

import 'customs_security_test_fakes.dart';

void main() {
  testWidgets('hub renders legally neutral hero and both workspaces', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customs-security-hero')), findsOneWidget);
    expect(
      find.text('Sınırda sinyali yakala, delili koru, müdahaleyi yönet.'),
      findsOneWidget,
    );
    expect(find.textContaining('otomatik suç isnadı üretmez'), findsOneWidget);
    expect(find.text('GKP-2026-ABC12345'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customs-intervention-tab')));
    await tester.pumpAndSettle();
    expect(find.text('SGM-2026-ABC12345'), findsOneWidget);
    expect(find.text('Ön incelemede'), findsOneWidget);
  });

  testWidgets('profile card delegates internal id to detail opener', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityHubPage(
          repository: repository,
          profileDetailOpener: (context, profileId) async {
            openedId = profileId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('customs-profile-profile-1')));
    await tester.pumpAndSettle();
    expect(openedId, 'profile-1');
  });

  testWidgets('creates a draft protection profile through the callable model', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository(profiles: const []);
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-customs-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customs-profile-name')),
      'Bosch Gümrük Profili',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-right-holder-name')),
      'Robert Bosch GmbH',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-right-holder-references')),
      'TR-MARKA-123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-protected-products')),
      'product-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-authentication-instructions')),
      'Seri numarası ve ambalaj güvenlik işaretleri birlikte doğrulanır.',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-customs-profile')),
    );
    await tester.pumpAndSettle();

    expect(repository.createProfileCalls, 1);
    expect(repository.lastProfileDraft?.protectedProductIds, ['product-1']);
    expect(find.textContaining('taslak profili oluşturuldu'), findsOneWidget);
  });

  testWidgets('creates a draft border intervention from an active profile', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository(interventions: const []);
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('customs-intervention-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-customs-intervention')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('customs-intervention-country')),
      'TR',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-intervention-authority')),
      'İstanbul Gümrük Müdürlüğü',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-border-point-name')),
      'Ambarlı Limanı',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-declared-product')),
      'Binek araç fren balatası',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-suspicion-reasons')),
      'Ambalaj işareti uyuşmuyor',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-customs-intervention')),
    );
    await tester.pumpAndSettle();

    expect(repository.createInterventionCalls, 1);
    expect(repository.lastInterventionDraft?.protectionProfileId, 'profile-1');
    expect(repository.lastInterventionDraft?.countryCode, 'TR');
    expect(
      find.textContaining('taslak müdahale dosyası oluşturuldu'),
      findsOneWidget,
    );
  });

  testWidgets('corporate hub opens KTG through injectable route opener', (
    tester,
  ) async {
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(1200, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CorporateHubPage(
          userEmailProvider: () => 'owner@example.com',
          customsSecurityRouteOpener: (context) async {
            calls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('corporate-module-customs_security'),
    );
    await tester.scrollUntilVisible(
      card,
      600,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Kaçakçılık, Taklit ve Gümrük Güvenliği'), findsOneWidget);
  });
}
