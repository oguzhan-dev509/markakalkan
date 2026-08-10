import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

void main() {
  test('sponsor content model parses and emits admin payload', () {
    final entry = SponsorContentEntry.fromMap(<String, dynamic>{
      'id': 's1',
      'displayName': 'Örnek',
      'categoryCode': 'technology',
      'categoryLabel': 'Teknoloji',
      'websiteUrl': 'https://example.com/',
      'logoUrl': 'https://example.com/logo.png',
      'logoAlt': 'Örnek logo',
      'displayOrder': 5,
      'status': 'active',
      'startsAt': '2026-08-01T00:00:00.000Z',
      'endsAt': '',
    });

    expect(entry.id, 's1');
    expect(entry.isActive, isTrue);
    expect(entry.toAdminPayload()['displayOrder'], 5);
  });

  test('service locks europe-west3 and exact callable names', () {
    final source = File(
      'lib/features/sponsor_content/data/sponsor_content_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("FirebaseFunctions.instanceFor(region: 'europe-west3')"),
    );
    expect(source, contains("'listPublicSponsorContent'"));
    expect(source, contains("'listSponsorContentForAdmin'"));
    expect(source, contains("'upsertSponsorContentForAdmin'"));
  });

  test('backend is server-only and super-admin writes are enforced', () {
    final backend = File(
      'functions/sponsor_content/v1/sponsor_content.js',
    ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(backend, contains('"platform_sponsor_content"'));
    expect(backend, contains('"platform_sponsor_content_events"'));
    expect(backend, contains('ROLES.superAdmin'));
    expect(backend, contains('requirePlatformRole'));
    expect(backend, contains('enforceAppCheck: true'));
    expect(backend, contains('enforceAppCheck: false'));

    final marker = 'match /platform_sponsor_content/';
    final index = rules.indexOf(marker);
    if (index >= 0) {
      final end = (index + 800).clamp(0, rules.length);
      final window = rules.substring(index, end);
      expect(window, isNot(contains('allow read: if true')));
      expect(window, isNot(contains('allow write: if true')));
      expect(window, isNot(contains('allow read, write: if true')));
    }
  });

  test('root functions index exports the three sponsor callables', () {
    final index = File('functions/index.js').readAsStringSync();

    expect(index, contains('buildListPublicSponsorContent'));
    expect(index, contains('buildListSponsorContentForAdmin'));
    expect(index, contains('buildUpsertSponsorContentForAdmin'));
    expect(index, contains('exports.listPublicSponsorContent'));
    expect(index, contains('exports.listSponsorContentForAdmin'));
    expect(index, contains('exports.upsertSponsorContentForAdmin'));
  });
}
