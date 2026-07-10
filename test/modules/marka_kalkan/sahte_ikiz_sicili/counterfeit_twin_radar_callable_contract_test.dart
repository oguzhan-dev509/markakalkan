import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Counterfeit Twin Radar callable contract', () {
    final source = File(
      'functions/counterfeit_twin/counterfeit_twin_radar.js',
    ).readAsStringSync();
    final index = File('functions/index.js').readAsStringSync();

    test('exports report, admin review and public list callables', () {
      expect(index, contains('exports.submitCounterfeitTwinReport'));
      expect(index, contains('exports.listCounterfeitTwinReportsForAdmin'));
      expect(index, contains('exports.reviewCounterfeitTwinReport'));
      expect(index, contains('exports.listPublicCounterfeitTwinComparisons'));
    });

    test('publishing creates only the safe public projection', () {
      expect(source, contains('"counterfeit_twin_reports"'));
      expect(source, contains('"counterfeit_twin_public_comparisons"'));
      expect(source, contains('decision === "published"'));
      expect(source, contains('verificationLabel: "delille_dogrulandi"'));
    });

    test('public projection never exposes administrator identity', () {
      expect(source, isNot(contains('publishedByUid:')));
      expect(source, isNot(contains('publishedByEmail:')));
    });

    test('callable responses omit timestamps safely', () {
      expect(source, contains('...safeData'));
      expect(source, isNot(contains('createdAt: undefined')));
      expect(source, isNot(contains('publishedAt: undefined')));
    });

    test('review and publish require platform roles', () {
      expect(source, contains('ROLES.counterfeitTwinReviewer'));
      expect(source, contains('ROLES.counterfeitTwinPublisher'));
      expect(source, contains('requirePlatformRole'));
    });

    test('report payload carries comparison evidence fields', () {
      expect(source, contains('originalImageUrls'));
      expect(source, contains('suspectedImageUrls'));
      expect(source, contains('authorizedPriceMin'));
      expect(source, contains('suspectedPrice'));
      expect(source, contains('differenceNotes'));
    });
  });
}
