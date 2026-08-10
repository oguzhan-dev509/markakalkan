import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_sponsor_footer_section.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

SponsorContentEntry sponsor(
  String id,
  String name,
  int order, {
  String category = 'Teknoloji',
}) {
  return SponsorContentEntry(
    id: id,
    displayName: name,
    categoryCode: 'technology',
    categoryLabel: category,
    websiteUrl: '',
    logoUrl: '',
    logoAlt: '',
    displayOrder: order,
    status: 'active',
    startsAt: null,
    endsAt: null,
    createdAt: null,
    updatedAt: null,
  );
}

Future<void> pumpAt(
  WidgetTester tester, {
  required Size size,
  required Future<List<SponsorContentEntry>> Function() loader,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: reducedMotion,
          accessibleNavigation: reducedMotion,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PublicLiteSponsorFooterSection(loadSponsors: loader),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'empty data animates the approved six fallback slots on desktop',
    (tester) async {
      await pumpAt(
        tester,
        size: const Size(1440, 1200),
        loader: () async => const <SponsorContentEntry>[],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(publicLiteSponsorFooterSectionKey), findsOneWidget);
      expect(find.byKey(publicLiteSponsorStripKey), findsOneWidget);
      expect(
        find.byKey(const Key('publicLiteFallbackSponsorRail')),
        findsOneWidget,
      );
      expect(find.text('İş Ortaklarımız / Sponsorlarımız'), findsOneWidget);
      expect(
        find.text('Markanızı korumak için güç birliği yapıyoruz'),
        findsOneWidget,
      );
      expect(find.text('Sponsor alanı'), findsNWidgets(12));
      expect(find.text('Tüm iş ortaklarımızı görüntüle'), findsOneWidget);
      expect(
        find.text('Siz de burada yer almak ister misiniz?'),
        findsOneWidget,
      );

      final target = find.byKey(const Key('publicLiteFallbackSponsor-0-0'));
      expect(target, findsOneWidget);
      final before = tester.getTopLeft(target).dx;
      await tester.pump(const Duration(seconds: 1));
      final after = tester.getTopLeft(target).dx;

      expect(after, lessThan(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty data animated fallback remains overflow-free on mobile', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(390, 1200),
      loader: () async => const <SponsorContentEntry>[],
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('publicLiteFallbackSponsorRail')),
      findsOneWidget,
    );
    expect(find.text('Sponsor alanı'), findsNWidgets(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps fallback slots static', (tester) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      reducedMotion: true,
      loader: () async => const <SponsorContentEntry>[],
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('publicLiteFallbackSponsorRail')),
      findsNothing,
    );
    expect(find.text('Sponsor alanı'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback rail pauses on hover and resumes after pointer exit', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      loader: () async => const <SponsorContentEntry>[],
    );
    await tester.pump();
    await tester.pump();

    final rail = find.byKey(const Key('publicLiteFallbackSponsorRail'));
    final target = find.byKey(const Key('publicLiteFallbackSponsor-0-0'));
    expect(rail, findsOneWidget);
    expect(target, findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(rail));
    await tester.pump();

    final pausedBefore = tester.getTopLeft(target).dx;
    await tester.pump(const Duration(seconds: 1));
    final pausedAfter = tester.getTopLeft(target).dx;
    expect(pausedAfter, closeTo(pausedBefore, 0.01));

    await mouse.moveTo(Offset.zero);
    await tester.pump();

    final resumeBefore = tester.getTopLeft(target).dx;
    await tester.pump(const Duration(seconds: 1));
    final resumeAfter = tester.getTopLeft(target).dx;

    expect(resumeAfter, lessThan(resumeBefore));
    expect(tester.takeException(), isNull);
  });

  testWidgets('active dynamic sponsor names replace fallback slots', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      reducedMotion: true,
      loader: () async => <SponsorContentEntry>[
        sponsor('a', 'Atlas Teknoloji', 20),
        sponsor('b', 'Bosphorus Hukuk', 10, category: 'Hukuk ve IP'),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bosphorus Hukuk'), findsOneWidget);
    expect(find.text('Atlas Teknoloji'), findsOneWidget);
    expect(find.text('Sponsor alanı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three or more sponsors move slowly from right to left', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      loader: () async => <SponsorContentEntry>[
        sponsor('a', 'Atlas Teknoloji', 10),
        sponsor('b', 'Bosphorus Hukuk', 20),
        sponsor('c', 'Caspian Lojistik', 30, category: 'Lojistik'),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('publicLiteSponsorRail')), findsOneWidget);
    final target = find.byKey(const Key('publicLiteDynamicSponsor-a-0'));
    expect(target, findsOneWidget);

    final before = tester.getTopLeft(target).dx;
    await tester.pump(const Duration(seconds: 1));
    final after = tester.getTopLeft(target).dx;

    expect(after, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps three sponsors static', (tester) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      reducedMotion: true,
      loader: () async => <SponsorContentEntry>[
        sponsor('a', 'Atlas Teknoloji', 10),
        sponsor('b', 'Bosphorus Hukuk', 20),
        sponsor('c', 'Caspian Lojistik', 30),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('publicLiteSponsorRail')), findsNothing);
    expect(find.text('Atlas Teknoloji'), findsOneWidget);
    expect(find.text('Bosphorus Hukuk'), findsOneWidget);
    expect(find.text('Caspian Lojistik'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('callable failure keeps the approved placeholder fallback', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(900, 900),
      loader: () async => throw StateError('offline'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sponsor alanı'), findsNWidgets(12));
    expect(
      find.byKey(const Key('publicLiteFallbackSponsorRail')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('publicLiteSponsorRail')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sponsor calls to action remain honest placeholders', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(900, 900),
      loader: () async => const <SponsorContentEntry>[],
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(publicLitePartnersButtonKey));
    await tester.pump();
    expect(
      find.text('Onaylı iş ortakları dizini hazırlanıyor.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(publicLiteSponsorInquiryButtonKey));
    await tester.pump();
    expect(
      find.text('Sponsorluk ve iş ortaklığı başvuru kanalı hazırlanıyor.'),
      findsOneWidget,
    );
  });

  test('motion contract includes hover focus and accessibility stops', () {
    final source = File(
      'lib/features/risk_scan/presentation/'
      'public_lite_sponsor_footer_section.dart',
    ).readAsStringSync();

    expect(source, contains('MouseRegion('));
    expect(source, contains('onEnter: (_) => _pause()'));
    expect(source, contains('onExit: (_) => _resume()'));
    expect(source, contains('onFocusChange:'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('accessibleNavigation'));
    expect(source, contains('entries.length >= 3'));
    expect(source, contains('fallbackSlots.length >= 3'));
    expect(source, contains('class _FallbackSponsorRail'));
    expect(source, contains("Key('publicLiteFallbackSponsorRail')"));
  });

  test(
    'fallback motion uses layout-safe one-row rail with calibrated height',
    () {
      final source = File(
        'lib/features/risk_scan/presentation/'
        'public_lite_sponsor_footer_section.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'final cardWidth = constraints.maxWidth >= 900 ? 220.0 : 190.0;',
        ),
      );
      expect(source, contains('const railHeight = 132.0;'));
      expect(source, isNot(contains('const cardHeight = 118.0;')));
    },
  );

  test('color polish contract uses distinct sponsor accents', () {
    final source = File(
      'lib/features/risk_scan/presentation/'
      'public_lite_sponsor_footer_section.dart',
    ).readAsStringSync();

    expect(source, contains('_sponsorAccentFor'));
    expect(source, contains("'technology'"));
    expect(source, contains("'ecommerce'"));
    expect(source, contains("'telecom'"));
    expect(source, contains("'logistics'"));
    expect(source, contains("'corporate'"));
    expect(source, contains('LinearGradient('));
    expect(source, contains('accent.border.withValues(alpha: 0.82)'));
  });

  testWidgets('unverified example brands and certifications are not claimed', (
    tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(1200, 900),
      loader: () async => const <SponsorContentEntry>[],
    );
    await tester.pump();
    await tester.pump();

    for (final text in <String>[
      'Turkcell',
      'Türk Telekom',
      'Hepsiburada',
      'Trendyol',
      'ideasoft',
      'ISO 27001',
      'GDPR Uyumlu',
      'Güvenli ve sertifikalı altyapı',
    ]) {
      expect(find.text(text), findsNothing);
    }

    expect(tester.takeException(), isNull);
  });
}
