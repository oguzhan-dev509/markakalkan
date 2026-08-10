import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/presentation/sponsor_content_admin_page.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

SponsorContentEntry sample({String status = 'active'}) {
  return SponsorContentEntry(
    id: 's1',
    displayName: 'Örnek Sponsor',
    categoryCode: 'technology',
    categoryLabel: 'Teknoloji',
    websiteUrl: 'https://example.com/',
    logoUrl: 'https://example.com/logo.png',
    logoAlt: 'Örnek Sponsor logosu',
    displayOrder: 10,
    status: status,
    startsAt: null,
    endsAt: null,
    createdAt: null,
    updatedAt: null,
  );
}

void main() {
  testWidgets('admin page lists sponsor records and exposes create/edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SponsorContentAdminPage(
          loadEntries: () async => <SponsorContentEntry>[sample()],
          saveEntry: (entry) async => entry.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sponsor / İş Ortağı Yönetimi'), findsOneWidget);
    expect(find.text('Örnek Sponsor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sponsor-content-create-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('sponsor-content-edit-s1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('sponsor-content-edit-s1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sponsor kaydını düzenle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sponsor-editor-name')),
      findsOneWidget,
    );
  });

  testWidgets('archive action persists archived status', (tester) async {
    SponsorContentEntry? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: SponsorContentAdminPage(
          loadEntries: () async => <SponsorContentEntry>[sample()],
          saveEntry: (entry) async {
            saved = entry;
            return entry.id;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('sponsor-content-archive-s1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sponsor kaydını arşivle'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Arşivle'));
    await tester.pumpAndSettle();

    expect(saved?.status, 'archived');
  });

  testWidgets('new sponsor dialog keeps logo content editable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SponsorContentAdminPage(
          loadEntries: () async => const <SponsorContentEntry>[],
          saveEntry: (entry) async => 'new-id',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('sponsor-content-create-action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yeni sponsor ekle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sponsor-editor-logo-url')),
      findsOneWidget,
    );
  });
}
