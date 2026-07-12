import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCreationPriority registry integration contract', () {
    final pageSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_registry_page.dart',
    ).readAsStringSync();

    final routerSource = File('lib/app/router.dart').readAsStringSync();

    final hubSource = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();

    test('registry page exposes tenant-safe live repository stream', () {
      expect(pageSource, contains('IpCreationPriorityRepository.instance'));
      expect(pageSource, contains('repository.watchRecords()'));
      expect(pageSource, contains('FirebaseAuth.instance.currentUser'));
    });

    test('registry page exposes legal notice and four filters', () {
      expect(
        pageSource,
        contains('Bu fikir benim, bu eser benim, bu buluş benim'),
      );
      expect(pageSource, contains('IpCreationType? _creationTypeFilter'));
      expect(pageSource, contains('IpCreationPriorityStatus? _statusFilter'));
      expect(
        pageSource,
        contains('IpCreationConfidentialityLevel? _confidentialityFilter'),
      );
      expect(pageSource, contains('IpCreationSealStatus? _sealFilter'));
    });

    test('router opens registry page', () {
      expect(routerSource, contains('openIpCreationPriorityRegistry'));
      expect(routerSource, contains('const IpCreationPriorityRegistryPage()'));
    });

    test('signed-out registry uses the common login gateway', () {
      expect(pageSource, contains('AppRouter.openBrandLogin('));
      expect(pageSource, contains('MarkaKalkanAuthIntent.creationRegistry'));
      expect(pageSource, contains('Marka Girişi ile Devam Et'));
    });

    test('corporate hub exposes active registry card', () {
      expect(hubSource, contains("id: 'creation_priority'"));
      expect(hubSource, contains("title: 'Yaratım Öncelik Sicili'"));
      expect(
        hubSource,
        contains('AppRouter.openIpCreationPriorityRegistry(context)'),
      );
    });
  });
}
