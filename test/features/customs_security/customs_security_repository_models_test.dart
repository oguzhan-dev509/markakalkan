import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';

void main() {
  test('profile list accepts only the read-only backend contract', () {
    final result = CustomsProtectionProfileList.fromMap({
      'contractVersion': 'customs-protection-profile-list-v1',
      'readOnly': true,
      'writesPerformed': 0,
      'nextPageToken': null,
      'items': [
        {
          'profileId': 'profile-1',
          'profileNumber': 'GKP-2026-ABC12345',
          'profileName': 'Test profil',
          'status': 'draft',
          'rightHolderName': 'Hak sahibi',
          'rightHolderReferenceIds': <String>[],
          'authorizedRepresentativeIds': <String>[],
          'authorizedManufacturerIds': <String>[],
          'authorizedImporterIds': <String>[],
          'protectedProductIds': <String>[],
          'hsCodes': <String>[],
          'productCategories': <String>[],
          'originCountries': <String>[],
          'authorizedImportCountries': <String>[],
          'authenticationInstructions': 'Doğrulama talimatı.',
          'serialVerificationMethods': <String>[],
          'securityFeatureSummaries': <String>[],
          'counterfeitTwinRecordIds': <String>[],
          'productionAssetIds': <String>[],
          'riskCountryCodes': <String>[],
          'riskRouteSummaries': <String>[],
          'emergencyContactIds': <String>[],
          'validFrom': null,
          'validUntil': null,
          'reviewDueAt': null,
          'eventCount': 1,
          'lastEventType': 'protection_profile_created',
          'lastEventAt': '2026-07-25T07:00:00.000Z',
          'createdAt': '2026-07-25T07:00:00.000Z',
          'updatedAt': '2026-07-25T07:00:00.000Z',
        },
      ],
    });

    expect(result.items.single.profileId, 'profile-1');
    expect(result.items.single.status, 'draft');
  });

  test('read contract rejects a response that claims a write', () {
    expect(
      () => CustomsProtectionProfileList.fromMap({
        'contractVersion': 'customs-protection-profile-list-v1',
        'readOnly': true,
        'writesPerformed': 1,
        'items': <Object>[],
        'nextPageToken': null,
      }),
      throwsFormatException,
    );
  });

  test('draft request maps preserve server field names and UTC dates', () {
    final profile = CustomsProtectionProfileDraft(
      profileName: 'Profil',
      rightHolderName: 'Hak sahibi',
      authenticationInstructions: 'Doğrulama talimatı yeterince uzundur.',
      protectedProductIds: const ['product-1'],
      validUntil: DateTime.utc(2027, 1, 1),
    ).toRequestMap();
    expect(profile['protectedProductIds'], ['product-1']);
    expect(profile['validUntil'], '2027-01-01T00:00:00.000Z');

    const intervention = CustomsBorderInterventionDraft(
      protectionProfileId: 'profile-1',
      priority: 'high',
      sourceType: 'customs_notification',
      countryCode: 'tr',
      customsAuthorityName: 'Gümrük Müdürlüğü',
      borderPointType: 'seaport',
      borderPointName: 'Ambarlı',
      declaredProductDescription: 'Fren balatası',
      authenticationResult: 'not_started',
      suspicionReasons: ['Ambalaj uyumsuzluğu'],
      independentReviewRequired: true,
    );
    final map = intervention.toRequestMap();
    expect(map['countryCode'], 'TR');
    expect(map['independentReviewRequired'], true);
    expect(map.containsKey('declaredQuantity'), false);
  });

  test('request id generator returns UUID v4 compatible identifiers', () {
    final value = generateCustomsRequestId();
    expect(
      value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
