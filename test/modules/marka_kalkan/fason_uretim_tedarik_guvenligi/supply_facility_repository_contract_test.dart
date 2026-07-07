import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String refs;
  late String repository;

  setUpAll(() {
    refs = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_security_firestore_refs.dart',
    ).readAsStringSync();

    repository = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_facility_repository.dart',
    ).readAsStringSync();
  });

  group('SupplyFacilityRepository contract', () {
    test(
      'Firestore refs facilities koleksiyonunu ve belge referansını açar',
      () {
        expect(
          refs,
          contains('CollectionReference<Map<String, dynamic>> get facilities'),
        );
        expect(
          refs,
          contains('DocumentReference<Map<String, dynamic>> facilityDocument'),
        );
        expect(refs, contains('SupplySecurityCollections.facilities'));
      },
    );

    test('repository tenant ve tesis kodu izolasyonunu uygular', () {
      expect(
        repository,
        contains(
          'Supply facility tenantId ile repository tenantId eşleşmiyor.',
        ),
      );
      expect(repository, contains('findByFacilityCode'));
      expect(repository, contains("'facilityCodeNormalized'"));
    });

    test('repository yüksek risk ve filtreli listeleme sağlar', () {
      expect(repository, contains('listHighRisk'));
      expect(repository, contains('SupplyFacilityRiskLevel? riskLevel'));
      expect(
        repository,
        contains('SupplyFacilityAuthorizationStatus? authorizationStatus'),
      );
      expect(repository, contains('String? partnerId'));
    });

    test('repository kritik tesis ve operasyon yetkilerini doğrular', () {
      expect(
        repository,
        contains(
          'Kritik risk seviyesindeki tesiste denetim zorunlu olmalıdır.',
        ),
      );
      expect(
        repository,
        contains(
          'Yetkili tesiste en az bir operasyon yetkisi tanımlanmalıdır.',
        ),
      );
      expect(
        repository,
        contains('Şüpheli yetkisiz üretim noktası authorized olamaz.'),
      );
    });

    test('repository güvenli arşivleme ve silme koruması uygular', () {
      expect(repository, contains('Future<void> archive'));
      expect(repository, contains('Future<void> delete'));
      expect(
        repository,
        contains('Tesis kaydı silinmeden önce arşivlenmelidir.'),
      );
      expect(
        repository,
        contains(
          'Ürün, sertifika veya denetim bağlantısı bulunan tesis silinemez.',
        ),
      );
    });
  });
}
