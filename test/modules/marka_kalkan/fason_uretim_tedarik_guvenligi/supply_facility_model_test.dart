import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/constants/supply_facility_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/models/supply_facility_model.dart';

void main() {
  group('SupplyFacilityModel', () {
    test('tesis kodunu normalize eder ve vardiyaları serileştirir', () {
      final model = _model(
        facilityCode: ' ist-plant-01 ',
        shiftCodes: const <SupplyShiftCode>[
          SupplyShiftCode.day,
          SupplyShiftCode.night,
        ],
      );

      final map = model.toMap();

      expect(model.normalizedFacilityCode, 'IST-PLANT-01');
      expect(map['facilityCode'], 'ist-plant-01');
      expect(map['facilityCodeNormalized'], 'IST-PLANT-01');
      expect(map['shiftCodes'], containsAll(<String>['day', 'night']));
    });

    test('şüpheli üretim göstergelerini yüksek risk olarak işaretler', () {
      final model = _model(
        facilityType: SupplyFacilityType.suspectedUnauthorizedSite,
        authorizationStatus: SupplyFacilityAuthorizationStatus.unauthorized,
        suspiciousNightShiftObserved: true,
      );

      expect(model.isUnauthorizedOrSuspicious, isTrue);
      expect(model.isHighRisk, isTrue);
    });

    test('Firestore haritasından enum, koordinat ve tarihi geri yükler', () {
      final model = SupplyFacilityModel.fromMap(
        id: 'facility-1',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'partnerId': 'partner-1',
          'facilityCode': 'FAC-001',
          'name': 'Örnek Fason Üretim Tesisi',
          'facilityType': 'contract_manufacturing_plant',
          'status': 'active',
          'verificationStatus': 'verified',
          'riskLevel': 'medium',
          'authorizationStatus': 'authorized',
          'latitude': 41.015,
          'longitude': 28.979,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 7)),
          'createdBy': 'user-1',
        },
      );

      expect(model.facilityType, SupplyFacilityType.contractManufacturingPlant);
      expect(
        model.authorizationStatus,
        SupplyFacilityAuthorizationStatus.authorized,
      );
      expect(model.hasCoordinates, isTrue);
      expect(model.createdAt.toUtc(), DateTime.utc(2026, 7, 7));
    });

    test('güncelleme haritasında değişmez kimlik alanlarını çıkarır', () {
      final map = _model().toUpdateMap(actorId: 'editor-1');

      expect(map.containsKey('tenantId'), isFalse);
      expect(map.containsKey('brandId'), isFalse);
      expect(map.containsKey('partnerId'), isFalse);
      expect(map.containsKey('facilityCode'), isFalse);
      expect(map.containsKey('facilityCodeNormalized'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('createdBy'), isFalse);
      expect(map['updatedBy'], 'editor-1');
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('kapasite alanını nullable int olarak korur', () {
      final withoutCapacity = SupplyFacilityModel.fromMap(
        id: 'without-capacity',
        data: _baseMap(monthlyCapacity: null),
      );

      final withCapacity = SupplyFacilityModel.fromMap(
        id: 'with-capacity',
        data: _baseMap(monthlyCapacity: 250000),
      );

      expect(withoutCapacity.monthlyCapacity, isNull);
      expect(withCapacity.monthlyCapacity, 250000);
    });
  });
}

SupplyFacilityModel _model({
  String facilityCode = 'FAC-001',
  SupplyFacilityType facilityType = SupplyFacilityType.factory,
  SupplyFacilityAuthorizationStatus authorizationStatus =
      SupplyFacilityAuthorizationStatus.authorized,
  List<SupplyShiftCode> shiftCodes = const <SupplyShiftCode>[
    SupplyShiftCode.day,
  ],
  bool suspiciousNightShiftObserved = false,
}) {
  return SupplyFacilityModel(
    id: 'facility-1',
    tenantId: 'tenant-1',
    brandId: 'brand-1',
    partnerId: 'partner-1',
    facilityCode: facilityCode,
    name: 'Örnek Tesis',
    facilityType: facilityType,
    status: SupplyFacilityStatus.active,
    verificationStatus: SupplyFacilityVerificationStatus.verified,
    riskLevel: SupplyFacilityRiskLevel.medium,
    authorizationStatus: authorizationStatus,
    shiftCodes: shiftCodes,
    suspiciousNightShiftObserved: suspiciousNightShiftObserved,
    createdAt: DateTime.utc(2026, 7, 7),
    createdBy: 'user-1',
  );
}

Map<String, dynamic> _baseMap({required int? monthlyCapacity}) {
  return <String, dynamic>{
    'tenantId': 'tenant-1',
    'brandId': 'brand-1',
    'partnerId': 'partner-1',
    'facilityCode': 'FAC-002',
    'name': 'Örnek Depo',
    'facilityType': 'finished_goods_warehouse',
    'status': 'active',
    'verificationStatus': 'verified',
    'riskLevel': 'low',
    'authorizationStatus': 'authorized',
    'monthlyCapacity': monthlyCapacity,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 7)),
    'createdBy': 'user-1',
  };
}
