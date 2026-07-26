import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';

Map<String, dynamic> activeProfileMap({String status = 'active'}) => {
  'profileId': 'profile-active',
  'profileNumber': 'GKP-2026-ACTIVE01',
  'profileName': 'Aktif profil',
  'status': status,
  'rightHolderName': 'Hak sahibi',
  'rightHolderReferenceIds': <String>['right-1'],
  'authorizedRepresentativeIds': <String>[],
  'authorizedManufacturerIds': <String>[],
  'authorizedImporterIds': <String>[],
  'protectedProductIds': <String>['product-1'],
  'hsCodes': <String>[],
  'productCategories': <String>[],
  'originCountries': <String>[],
  'authorizedImportCountries': <String>[],
  'authenticationInstructions': 'Doğrulama talimatı yeterince uzundur.',
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
  'eventCount': 3,
  'lastEventType': 'protection_profile_status_transitioned',
  'lastEventAt': '2026-07-26T07:00:00.000Z',
  'createdAt': '2026-07-26T07:00:00.000Z',
  'updatedAt': '2026-07-26T07:00:00.000Z',
};

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
          'productCategories': <String>['Otomotiv yedek parçası'],
          'originCountries': <String>['DE'],
          'authorizedImportCountries': <String>['TR'],
          'authenticationInstructions': 'Doğrulama talimatı.',
          'serialVerificationMethods': <String>['Üretici seri sorgusu'],
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
    expect(result.items.single.productCategories, ['Otomotiv yedek parçası']);
    expect(result.items.single.serialVerificationMethods, [
      'Üretici seri sorgusu',
    ]);
    expect(result.items.single.originCountries, ['DE']);
    expect(result.items.single.authorizedImportCountries, ['TR']);
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
      productCategories: const ['Otomotiv yedek parçası'],
      serialVerificationMethods: const ['Üretici seri sorgusu'],
      originCountries: const ['DE'],
      authorizedImportCountries: const ['TR'],
      validUntil: DateTime.utc(2027, 1, 1),
    ).toRequestMap();
    expect(profile['protectedProductIds'], ['product-1']);
    expect(profile['productCategories'], ['Otomotiv yedek parçası']);
    expect(profile['serialVerificationMethods'], ['Üretici seri sorgusu']);
    expect(profile['originCountries'], ['DE']);
    expect(profile['authorizedImportCountries'], ['TR']);
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

  test(
    'create-and-activate sends the strict atomic request and accepts duplicate',
    () async {
      String? name;
      Map<String, dynamic>? request;
      final repository = CallableCustomsSecurityRepository(
        ensureAppCheckReady: () async {},
        callable: (callableName, payload) async {
          name = callableName;
          request = payload;
          return {
            'contractVersion':
                'customs-protection-profile-create-and-activate-result-v1',
            'ok': true,
            'duplicate': true,
            'transactionApplied': false,
            'profile': activeProfileMap(),
          };
        },
      );
      const draft = CustomsProtectionProfileDraft(
        profileName: 'Profil',
        rightHolderName: 'Hak sahibi',
        authenticationInstructions: 'Doğrulama talimatı yeterince uzundur.',
        rightHolderReferenceIds: ['right-1'],
        protectedProductIds: ['product-1'],
      );
      final result = await repository.createAndActivateProfile(
        draft,
        requestId: '123e4567-e89b-42d3-a456-426614174000',
      );

      expect(name, 'createAndActivateCustomsProtectionProfile');
      expect(
        request?['contractVersion'],
        'customs-protection-profile-create-and-activate-request-v1',
      );
      expect(request?['activationConfirmation'], true);
      expect(
        request?['activationConfirmationVersion'],
        'customs-profile-activation-confirmation-v1',
      );
      expect(
        (request?['activationReason'] as String).length,
        greaterThanOrEqualTo(10),
      );
      expect(request?['requestId'], '123e4567-e89b-42d3-a456-426614174000');
      expect(result.duplicate, true);
      expect(result.transactionApplied, false);
      expect(result.profile.status, 'active');
    },
  );

  test(
    'create-and-activate fails closed on inconsistent result or profile',
    () {
      Future<void> verify(Map<String, dynamic> response) async {
        final repository = CallableCustomsSecurityRepository(
          ensureAppCheckReady: () async {},
          callable: (_, _) async => response,
        );
        await expectLater(
          repository.createAndActivateProfile(
            const CustomsProtectionProfileDraft(
              profileName: 'Profil',
              rightHolderName: 'Hak sahibi',
              authenticationInstructions:
                  'Doğrulama talimatı yeterince uzundur.',
            ),
            requestId: '123e4567-e89b-42d3-a456-426614174000',
          ),
          throwsFormatException,
        );
      }

      return Future.wait([
        verify({
          'contractVersion':
              'customs-protection-profile-create-and-activate-result-v1',
          'ok': true,
          'duplicate': false,
          'transactionApplied': false,
          'profile': activeProfileMap(),
        }),
        verify({
          'contractVersion':
              'customs-protection-profile-create-and-activate-result-v1',
          'ok': true,
          'duplicate': false,
          'transactionApplied': true,
          'profile': activeProfileMap(status: 'draft'),
        }),
      ]);
    },
  );
}
