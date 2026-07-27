import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_hub_page.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';

import 'customs_security_test_fakes.dart';

Future<void> fillActivationProfile(WidgetTester tester) async {
  for (final entry in {
    'customs-profile-name': 'Bosch Gümrük Profili',
    'customs-right-holder-name': 'Robert Bosch GmbH',
    'customs-right-holder-references': 'TR-MARKA-123',
    'customs-protected-products': 'product-1',
    'customs-authentication-instructions':
        'Seri numarası ve güvenlik işaretleri birlikte doğrulanır.',
  }.entries) {
    final field = find.byKey(ValueKey(entry.key));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
  }
}

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
    expect(
      find.byKey(const ValueKey('customs-operation-information-band')),
      findsOneWidget,
    );
    for (final label in [
      'Operasyon Bilgi Bandı',
      'Başvuru içeriği',
      'Başvuru paketi',
      'İndirilebilir resmî dosya',
      'Kuruma iletim',
      'Teslim, cevap ve sonuç',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('GKP-2026-ABC12345'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customs-intervention-tab')));
    await tester.pumpAndSettle();
    expect(find.text('SGM-2026-ABC12345'), findsOneWidget);
    expect(find.text('Ön incelemede'), findsOneWidget);
  });

  testWidgets(
    'hero and operation band remain independent on a narrow viewport',
    (tester) async {
      final repository = FakeCustomsSecurityRepository();
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      final hero = find.byKey(const ValueKey('customs-security-hero'));
      final band = find.byKey(
        const ValueKey('customs-operation-information-band'),
      );
      expect(hero, findsOneWidget);
      expect(band, findsOneWidget);
      expect(find.descendant(of: hero, matching: band), findsNothing);
      expect(
        find.byKey(
          const ValueKey('customs-operation-information-horizontal-list'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short viewport keeps a full workspace without Flex overflow', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    await tester.binding.setSurfaceSize(const Size(390, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('customs-security-scroll-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customs-security-workspace-viewport')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customs-operation-information-band')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    Future<void> addChip(String field, String value) async {
      final input = find.byKey(ValueKey('$field-input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, value);
      final add = find.byKey(ValueKey('$field-add'));
      tester.widget<OutlinedButton>(add).onPressed!();
      await tester.pumpAndSettle();
    }

    expect(find.text('Ürün kategorileri'), findsOneWidget);
    expect(find.text('Seri doğrulama yöntemleri'), findsOneWidget);
    expect(find.text('Menşe ülkeleri'), findsOneWidget);
    expect(find.text('Yetkili ithalat ülkeleri'), findsOneWidget);
    await addChip('customs-product-categories', 'Otomotiv yedek parçası');
    await addChip('customs-product-categories', 'Fren sistemi');
    final categoryChip = find.byKey(
      const ValueKey('customs-product-categories-chip-Otomotiv yedek parçası'),
    );
    tester.widget<InputChip>(categoryChip).onDeleted!();
    await tester.pumpAndSettle();
    await addChip(
      'customs-serial-verification-methods',
      'Üretici seri numarası ve doğrulama kaydı',
    );
    await addChip('customs-origin-countries', 'tr');
    await addChip('customs-origin-countries', 'TR');
    await addChip('customs-authorized-import-countries', 'de');
    await tester.enterText(
      find.byKey(const ValueKey('customs-authentication-instructions')),
      'Seri numarası ve ambalaj güvenlik işaretleri birlikte doğrulanır.',
    );
    await tester.tap(find.byKey(const ValueKey('save-customs-profile-draft')));
    await tester.pumpAndSettle();

    expect(repository.createProfileCalls, 1);
    expect(repository.lastProfileDraft?.protectedProductIds, ['product-1']);
    expect(repository.lastProfileDraft?.productCategories, ['Fren sistemi']);
    expect(repository.lastProfileDraft?.serialVerificationMethods, [
      'Üretici seri numarası ve doğrulama kaydı',
    ]);
    expect(repository.lastProfileDraft?.originCountries, ['TR']);
    expect(repository.lastProfileDraft?.authorizedImportCountries, ['DE']);
    expect(find.text('Sahte İkiz kayıtları'), findsNothing);
    expect(find.text('Üretim varlıkları'), findsNothing);
    expect(find.textContaining('taslak profili oluşturuldu'), findsOneWidget);
  });

  testWidgets('invalid profile country code prevents repository invocation', (
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
    final input = find.byKey(const ValueKey('customs-origin-countries-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'TUR');
    final submit = find.byKey(const ValueKey('save-customs-profile-draft'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.createProfileCalls, 0);
    expect(
      find.text('Ülke kodu iki harfli ISO biçiminde olmalıdır. Örn. TR'),
      findsOneWidget,
    );
  });

  testWidgets(
    'activation shows confirmation and all missing requirements without a call',
    (tester) async {
      final repository = FakeCustomsSecurityRepository(profiles: const []);
      await tester.binding.setSurfaceSize(const Size(700, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: CustomsSecurityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('create-customs-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Kaydet ve aktifleştir'), findsOneWidget);
      expect(find.text('Taslak olarak sakla'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(
                const ValueKey('customs-profile-activation-confirmation'),
              ),
            )
            .value,
        false,
      );
      final validUntil = find.byKey(const ValueKey('customs-valid-until'));
      await tester.ensureVisible(validUntil);
      await tester.enterText(validUntil, '2020-01-01');

      final activate = find.byKey(
        const ValueKey('create-and-activate-customs-profile'),
      );
      await tester.ensureVisible(activate);
      await tester.tap(activate);
      await tester.pumpAndSettle();

      expect(repository.createAndActivateProfileCalls, 0);
      expect(
        find.text(
          'Profili aktifleştirmek için aşağıdaki bilgileri tamamlayın:',
        ),
        findsOneWidget,
      );
      expect(find.text('• En az bir hak/tescil referansı'), findsOneWidget);
      expect(find.text('• En az bir korunan ürün'), findsOneWidget);
      expect(
        find.text('• Geçerlilik sonu geçmiş tarih olmamalı'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Aktivasyon için bilgilerin doğruluğunu açıkça onaylamalısınız.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed activation invokes once and opens active detail once',
    (tester) async {
      final repository = FakeCustomsSecurityRepository(profiles: const []);
      var opened = 0;
      String? openedId;
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomsSecurityHubPage(
            repository: repository,
            profileDetailOpener: (context, profileId) async {
              opened++;
              openedId = profileId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-customs-profile')));
      await tester.pumpAndSettle();
      await fillActivationProfile(tester);
      final pendingCountry = find.byKey(
        const ValueKey('customs-origin-countries-input'),
      );
      await tester.ensureVisible(pendingCountry);
      await tester.enterText(pendingCountry, ' tr ');
      final confirmation = find.byKey(
        const ValueKey('customs-profile-activation-confirmation'),
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pump();
      final activate = find.byKey(
        const ValueKey('create-and-activate-customs-profile'),
      );
      await tester.ensureVisible(activate);
      final button = tester.widget<FilledButton>(activate);
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();

      expect(repository.createAndActivateProfileCalls, 1);
      expect(repository.createProfileCalls, 0);
      expect(repository.transitionProfileCalls, 0);
      expect(repository.lastProfileDraft?.originCountries, ['TR']);
      expect(opened, 1);
      expect(openedId, 'profile-activated');
      expect(repository.profiles.single.status, 'active');
    },
  );

  testWidgets('transport retry keeps the workflow request id', (tester) async {
    final repository = FakeCustomsSecurityRepository(profiles: const [])
      ..createAndActivateError = Exception('timeout')
      ..createAndActivateFailsOnce = true
      ..createAndActivateDuplicate = true;
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityHubPage(
          repository: repository,
          profileDetailOpener: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-customs-profile')));
    await tester.pumpAndSettle();
    await fillActivationProfile(tester);
    final confirmation = find.byKey(
      const ValueKey('customs-profile-activation-confirmation'),
    );
    await tester.ensureVisible(confirmation);
    await tester.tap(confirmation);
    final activate = find.byKey(
      const ValueKey('create-and-activate-customs-profile'),
    );
    await tester.ensureVisible(activate);
    await tester.tap(activate);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.createAndActivateProfileCalls, 1);
    expect(
      find.text(
        'Profil oluşturulamadı ve hiçbir aktivasyon değişikliği '
        'kaydedilmedi. Bilgilerinizi kontrol edip yeniden deneyin.',
      ),
      findsOneWidget,
    );
    await tester.tap(activate);
    await tester.pumpAndSettle();

    expect(repository.createAndActivateProfileCalls, 2);
    expect(repository.activationRequestIds.toSet().length, 1);
    expect(repository.profiles.single.status, 'active');

    await tester.tap(find.byKey(const ValueKey('create-customs-profile')));
    await tester.pumpAndSettle();
    await fillActivationProfile(tester);
    final nextConfirmation = find.byKey(
      const ValueKey('customs-profile-activation-confirmation'),
    );
    await tester.ensureVisible(nextConfirmation);
    await tester.tap(nextConfirmation);
    final nextActivate = find.byKey(
      const ValueKey('create-and-activate-customs-profile'),
    );
    await tester.ensureVisible(nextActivate);
    await tester.tap(nextActivate);
    await tester.pumpAndSettle();

    expect(repository.createAndActivateProfileCalls, 3);
    expect(
      repository.activationRequestIds[0],
      repository.activationRequestIds[1],
    );
    expect(
      repository.activationRequestIds[2],
      isNot(repository.activationRequestIds[0]),
    );
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
