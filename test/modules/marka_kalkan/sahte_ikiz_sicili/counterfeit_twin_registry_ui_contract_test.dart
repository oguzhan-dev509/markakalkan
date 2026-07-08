import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation';

  late String registry;
  late String createDialog;
  late String editDialog;

  setUpAll(() {
    registry = File(
      '$base/counterfeit_twin_registry_page.dart',
    ).readAsStringSync();
    createDialog = File(
      '$base/counterfeit_twin_create_dialog.dart',
    ).readAsStringSync();
    editDialog = File(
      '$base/counterfeit_twin_detail_edit_dialog.dart',
    ).readAsStringSync();
  });

  test('registry uses authenticated tenant repository and live stream', () {
    expect(registry, contains('FirebaseAuth.instance.currentUser'));
    expect(registry, contains('CounterfeitTwinRepository.instance'));
    expect(registry, contains('tenantId: user.uid'));
    expect(registry, contains('stream: repository.watchAll()'));
  });

  test('registry exposes four filters and summary metrics', () {
    expect(registry, contains('CounterfeitTwinStatus? _statusFilter'));
    expect(registry, contains('CounterfeitTwinRiskLevel? _riskFilter'));
    expect(registry, contains('CounterfeitTwinReviewStatus? _reviewFilter'));
    expect(
      registry,
      contains('CounterfeitTwinCloneMethod? _cloneMethodFilter'),
    );
    expect(registry, contains("'Teyitli sahte ikiz'"));
    expect(registry, contains("'Dalga / aile bağlantılı'"));
    expect(registry, contains("'Dijital kanıtlı'"));
  });

  test('registry cards expose score, wave and digital link counts', () {
    expect(registry, contains('overallSimilarityScore'));
    expect(registry, contains('cloneFamilyId'));
    expect(registry, contains('waveId'));
    expect(registry, contains('recurrenceCount'));
    expect(registry, contains('listingIds.length'));
    expect(registry, contains('sellerIds.length'));
    expect(registry, contains('evidencePackageIds.length'));
  });

  test('create dialog builds a tenant-safe model', () {
    expect(createDialog, contains('tenantId: widget.user.uid'));
    expect(createDialog, contains('brandId: widget.user.uid'));
    expect(createDialog, contains('repository.create(record)'));
    expect(createDialog, contains('overallSimilarityScore'));
    expect(createDialog, contains('cloneFamilyId'));
    expect(createDialog, contains('waveId'));
  });

  test(
    'detail dialog preserves identity and uses callable repository update',
    () {
      expect(editDialog, contains('recordCode: old.recordCode'));
      expect(editDialog, contains('brandId: old.brandId'));
      expect(editDialog, contains('tenantId: old.tenantId'));
      expect(editDialog, contains('repository.update('));
      expect(editDialog, contains('actorId: widget.user.uid'));
      expect(editDialog, contains('Değişiklikleri Kaydet'));
    },
  );
}
