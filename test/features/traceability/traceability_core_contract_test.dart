import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final indexSource = File('functions/index.js').readAsStringSync();
  final backendSource = File(
    'functions/traceability/traceability.js',
  ).readAsStringSync();
  final modelSource = File(
    'lib/features/traceability/data/traceability_models.dart',
  ).readAsStringSync();
  final serviceSource = File(
    'lib/features/traceability/data/traceability_service.dart',
  ).readAsStringSync();
  final indexes = File('firestore.indexes.json').readAsStringSync();

  test('verification callable uses traceability risk engine', () {
    expect(indexSource, contains('buildTraceabilityCallables'));
    expect(backendSource, contains('evaluateVerificationRisk'));
    expect(backendSource, contains('rapid_repeat_scan'));
    expect(backendSource, contains('scan_volume_high'));
    expect(backendSource, contains('revoked_code'));
    expect(backendSource, contains('riskVersion: 1'));
  });

  test('suspicious scan callables are available', () {
    expect(indexSource, contains('listSuspiciousVerificationScans'));
    expect(indexSource, contains('reviewSuspiciousVerificationScan'));
    expect(backendSource, contains('reviewStatus'));
    expect(backendSource, contains('riskReasons'));
  });

  test('traceability cases can be opened from suspicious scans', () {
    expect(indexSource, contains('createTraceabilityCaseFromScan'));
    expect(indexSource, contains('listTraceabilityCases'));
    expect(backendSource, contains('traceabilityCases'));
    expect(backendSource, contains('sourceType: "verification_scan"'));
    expect(backendSource, contains('status: "open"'));
  });

  test('flutter service and models expose both centers', () {
    expect(modelSource, contains('class SuspiciousVerificationScan'));
    expect(modelSource, contains('class TraceabilityCaseSummary'));
    expect(serviceSource, contains('listSuspiciousScans'));
    expect(serviceSource, contains('reviewScan'));
    expect(serviceSource, contains('createCaseFromScan'));
    expect(serviceSource, contains('listCases'));
  });

  test('required composite indexes are declared', () {
    expect(indexes, contains('"collectionGroup": "verificationScans"'));
    expect(indexes, contains('"collectionGroup": "traceabilityCases"'));
  });
}
