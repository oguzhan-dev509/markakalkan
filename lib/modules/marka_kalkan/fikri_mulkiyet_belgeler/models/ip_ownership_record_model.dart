import '../constants/ip_enums.dart';

enum IpOwnershipKind {
  legalOwner('legal_owner', 'Hukuki Hak Sahibi'),
  economicOwner('economic_owner', 'Ekonomik Hak Sahibi'),
  jointOwner('joint_owner', 'Ortak Hak Sahibi'),
  creator('creator', 'Oluşturan / Eser Sahibi'),
  inventor('inventor', 'Buluşçu'),
  designer('designer', 'Tasarımcı'),
  employeeCreation('employee_creation', 'Çalışan Üretimi'),
  founderContribution('founder_contribution', 'Kurucu Katkısı'),
  contractorCreation('contractor_creation', 'Yüklenici Üretimi'),
  agencyCreation('agency_creation', 'Ajans Üretimi'),
  commissionedWork('commissioned_work', 'Sipariş Üzerine Üretim'),
  contractManufacturing('contract_manufacturing', 'Fason Üretim Kaynaklı Hak'),
  assignee('assignee', 'Devralan'),
  assignor('assignor', 'Devreden'),
  licensor('licensor', 'Lisans Veren'),
  licensee('licensee', 'Lisans Alan'),
  beneficialOwner('beneficial_owner', 'Nihai Faydalanıcı'),
  custodian('custodian', 'Hak Koruyucusu / Emanetçi'),
  other('other', 'Diğer');

  const IpOwnershipKind(this.value, this.label);

  final String value;
  final String label;

  static IpOwnershipKind fromValue(String? value) {
    return IpOwnershipKind.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpOwnershipKind.other,
    );
  }
}

enum IpOwnershipPartyType {
  person('person', 'Gerçek Kişi'),
  company('company', 'Şirket'),
  institution('institution', 'Kurum'),
  publicBody('public_body', 'Kamu Kurumu'),
  university('university', 'Üniversite'),
  researchOrganization('research_organization', 'Araştırma Kuruluşu'),
  partnership('partnership', 'Ortaklık'),
  team('team', 'Ekip'),
  unknown('unknown', 'Bilinmiyor');

  const IpOwnershipPartyType(this.value, this.label);

  final String value;
  final String label;

  static IpOwnershipPartyType fromValue(String? value) {
    return IpOwnershipPartyType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpOwnershipPartyType.unknown,
    );
  }
}

enum IpOwnershipAcquisitionType {
  originalCreation('original_creation', 'Aslen Kazanım / Üretim'),
  employment('employment', 'Çalışan Üretimi'),
  commissionedWork('commissioned_work', 'Sipariş Üzerine Üretim'),
  assignment('assignment', 'Devir'),
  license('license', 'Lisans'),
  inheritance('inheritance', 'Miras'),
  merger('merger', 'Birleşme'),
  acquisition('acquisition', 'Şirket Satın Alımı'),
  courtDecision('court_decision', 'Mahkeme Kararı'),
  statutoryTransfer('statutory_transfer', 'Kanuni Devir'),
  jointDevelopment('joint_development', 'Ortak Geliştirme'),
  other('other', 'Diğer');

  const IpOwnershipAcquisitionType(this.value, this.label);

  final String value;
  final String label;

  static IpOwnershipAcquisitionType fromValue(String? value) {
    return IpOwnershipAcquisitionType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpOwnershipAcquisitionType.other,
    );
  }
}

enum IpOwnershipStatus {
  draft('draft', 'Taslak'),
  underReview('under_review', 'İncelemede'),
  active('active', 'Aktif'),
  disputed('disputed', 'Uyuşmazlık Konusu'),
  suspended('suspended', 'Askıda'),
  transferred('transferred', 'Devredildi'),
  expired('expired', 'Süresi Doldu'),
  revoked('revoked', 'İptal Edildi'),
  ended('ended', 'Sona Erdi'),
  archived('archived', 'Arşivlendi');

  const IpOwnershipStatus(this.value, this.label);

  final String value;
  final String label;

  static IpOwnershipStatus fromValue(String? value) {
    return IpOwnershipStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpOwnershipStatus.draft,
    );
  }
}

class IpOwnershipRecordModel {
  const IpOwnershipRecordModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.assetId,
    required this.recordCode,
    required this.ownershipKind,
    required this.partyType,
    required this.partyName,
    required this.acquisitionType,
    required this.status,
    required this.ownershipPercentage,
    required this.jurisdictionScope,
    required this.createdAt,
    required this.createdBy,
    this.partyId,
    this.partyExternalId,
    this.partyCountryCode,
    this.partyRegistrationNumber,
    this.partyTaxNumber,
    this.partyContactEmail,
    this.countryCodes = const <String>[],
    this.regionCode,
    this.rightId,
    this.sourceOwnershipRecordId,
    this.previousOwnershipRecordId,
    this.nextOwnershipRecordId,
    this.agreementNumber,
    this.agreementDate,
    this.effectiveFrom,
    this.effectiveUntil,
    this.isExclusive = false,
    this.isPrimaryOwner = false,
    this.isBeneficialOwner = false,
    this.isOwnershipVerified = false,
    this.verificationDate,
    this.verifiedBy,
    this.documentIds = const <String>[],
    this.relationshipIds = const <String>[],
    this.transferChainRecordIds = const <String>[],
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String assetId;

  final String recordCode;
  final IpOwnershipKind ownershipKind;
  final IpOwnershipPartyType partyType;
  final String partyName;

  final String? partyId;
  final String? partyExternalId;
  final String? partyCountryCode;
  final String? partyRegistrationNumber;
  final String? partyTaxNumber;
  final String? partyContactEmail;

  final IpOwnershipAcquisitionType acquisitionType;
  final IpOwnershipStatus status;
  final double ownershipPercentage;

  final IpJurisdictionScope jurisdictionScope;
  final List<String> countryCodes;
  final String? regionCode;

  final String? rightId;
  final String? sourceOwnershipRecordId;
  final String? previousOwnershipRecordId;
  final String? nextOwnershipRecordId;

  final String? agreementNumber;
  final DateTime? agreementDate;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;

  final bool isExclusive;
  final bool isPrimaryOwner;
  final bool isBeneficialOwner;

  final bool isOwnershipVerified;
  final DateTime? verificationDate;
  final String? verifiedBy;

  final List<String> documentIds;
  final List<String> relationshipIds;
  final List<String> transferChainRecordIds;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool get isActive {
    return status == IpOwnershipStatus.active;
  }

  bool get isHistorical {
    return status == IpOwnershipStatus.transferred ||
        status == IpOwnershipStatus.expired ||
        status == IpOwnershipStatus.revoked ||
        status == IpOwnershipStatus.ended ||
        status == IpOwnershipStatus.archived;
  }

  bool get isOwnershipRole {
    return ownershipKind == IpOwnershipKind.legalOwner ||
        ownershipKind == IpOwnershipKind.economicOwner ||
        ownershipKind == IpOwnershipKind.jointOwner ||
        ownershipKind == IpOwnershipKind.assignee ||
        ownershipKind == IpOwnershipKind.beneficialOwner;
  }

  bool get hasSupportingDocuments {
    return documentIds.isNotEmpty;
  }

  bool get hasTransferChain {
    return sourceOwnershipRecordId != null ||
        previousOwnershipRecordId != null ||
        nextOwnershipRecordId != null ||
        transferChainRecordIds.isNotEmpty;
  }

  bool get hasDefinedPeriod {
    return effectiveFrom != null || effectiveUntil != null;
  }

  bool isEffectiveAt(DateTime date) {
    if (!isActive) {
      return false;
    }

    if (effectiveFrom != null && date.isBefore(effectiveFrom!)) {
      return false;
    }

    if (effectiveUntil != null && date.isAfter(effectiveUntil!)) {
      return false;
    }

    return true;
  }

  bool overlapsPeriod(IpOwnershipRecordModel other) {
    final thisStart = effectiveFrom;
    final thisEnd = effectiveUntil;
    final otherStart = other.effectiveFrom;
    final otherEnd = other.effectiveUntil;

    if (thisEnd != null && otherStart != null && thisEnd.isBefore(otherStart)) {
      return false;
    }

    if (otherEnd != null && thisStart != null && otherEnd.isBefore(thisStart)) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'assetId': assetId,
      'recordCode': recordCode,
      'ownershipKind': ownershipKind.value,
      'partyType': partyType.value,
      'partyName': partyName,
      'partyId': partyId,
      'partyExternalId': partyExternalId,
      'partyCountryCode': partyCountryCode,
      'partyRegistrationNumber': partyRegistrationNumber,
      'partyTaxNumber': partyTaxNumber,
      'partyContactEmail': partyContactEmail,
      'acquisitionType': acquisitionType.value,
      'status': status.value,
      'ownershipPercentage': ownershipPercentage,
      'jurisdictionScope': jurisdictionScope.value,
      'countryCodes': countryCodes,
      'regionCode': regionCode,
      'rightId': rightId,
      'sourceOwnershipRecordId': sourceOwnershipRecordId,
      'previousOwnershipRecordId': previousOwnershipRecordId,
      'nextOwnershipRecordId': nextOwnershipRecordId,
      'agreementNumber': agreementNumber,
      'agreementDate': agreementDate,
      'effectiveFrom': effectiveFrom,
      'effectiveUntil': effectiveUntil,
      'isExclusive': isExclusive,
      'isPrimaryOwner': isPrimaryOwner,
      'isBeneficialOwner': isBeneficialOwner,
      'isOwnershipVerified': isOwnershipVerified,
      'verificationDate': verificationDate,
      'verifiedBy': verifiedBy,
      'documentIds': documentIds,
      'relationshipIds': relationshipIds,
      'transferChainRecordIds': transferChainRecordIds,
      'notes': notes,
      'metadata': metadata,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  factory IpOwnershipRecordModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return IpOwnershipRecordModel(
      id: id,
      tenantId: _stringValue(data['tenantId']),
      brandId: _stringValue(data['brandId']),
      assetId: _stringValue(data['assetId']),
      recordCode: _stringValue(data['recordCode']),
      ownershipKind: IpOwnershipKind.fromValue(
        data['ownershipKind'] as String?,
      ),
      partyType: IpOwnershipPartyType.fromValue(data['partyType'] as String?),
      partyName: _stringValue(data['partyName']),
      partyId: _nullableString(data['partyId']),
      partyExternalId: _nullableString(data['partyExternalId']),
      partyCountryCode: _nullableString(data['partyCountryCode']),
      partyRegistrationNumber: _nullableString(data['partyRegistrationNumber']),
      partyTaxNumber: _nullableString(data['partyTaxNumber']),
      partyContactEmail: _nullableString(data['partyContactEmail']),
      acquisitionType: IpOwnershipAcquisitionType.fromValue(
        data['acquisitionType'] as String?,
      ),
      status: IpOwnershipStatus.fromValue(data['status'] as String?),
      ownershipPercentage: _doubleValue(data['ownershipPercentage']),
      jurisdictionScope: IpJurisdictionScope.fromValue(
        data['jurisdictionScope'] as String?,
      ),
      countryCodes: _stringList(data['countryCodes']),
      regionCode: _nullableString(data['regionCode']),
      rightId: _nullableString(data['rightId']),
      sourceOwnershipRecordId: _nullableString(data['sourceOwnershipRecordId']),
      previousOwnershipRecordId: _nullableString(
        data['previousOwnershipRecordId'],
      ),
      nextOwnershipRecordId: _nullableString(data['nextOwnershipRecordId']),
      agreementNumber: _nullableString(data['agreementNumber']),
      agreementDate: _dateValue(data['agreementDate']),
      effectiveFrom: _dateValue(data['effectiveFrom']),
      effectiveUntil: _dateValue(data['effectiveUntil']),
      isExclusive: data['isExclusive'] == true,
      isPrimaryOwner: data['isPrimaryOwner'] == true,
      isBeneficialOwner: data['isBeneficialOwner'] == true,
      isOwnershipVerified: data['isOwnershipVerified'] == true,
      verificationDate: _dateValue(data['verificationDate']),
      verifiedBy: _nullableString(data['verifiedBy']),
      documentIds: _stringList(data['documentIds']),
      relationshipIds: _stringList(data['relationshipIds']),
      transferChainRecordIds: _stringList(data['transferChainRecordIds']),
      notes: _nullableString(data['notes']),
      metadata: _mapValue(data['metadata']),
      createdAt:
          _dateValue(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: _stringValue(data['createdBy']),
      updatedAt: _dateValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  IpOwnershipRecordModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? assetId,
    String? recordCode,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    String? partyName,
    String? partyId,
    String? partyExternalId,
    String? partyCountryCode,
    String? partyRegistrationNumber,
    String? partyTaxNumber,
    String? partyContactEmail,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    double? ownershipPercentage,
    IpJurisdictionScope? jurisdictionScope,
    List<String>? countryCodes,
    String? regionCode,
    String? rightId,
    String? sourceOwnershipRecordId,
    String? previousOwnershipRecordId,
    String? nextOwnershipRecordId,
    String? agreementNumber,
    DateTime? agreementDate,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
    bool? isExclusive,
    bool? isPrimaryOwner,
    bool? isBeneficialOwner,
    bool? isOwnershipVerified,
    DateTime? verificationDate,
    String? verifiedBy,
    List<String>? documentIds,
    List<String>? relationshipIds,
    List<String>? transferChainRecordIds,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return IpOwnershipRecordModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      assetId: assetId ?? this.assetId,
      recordCode: recordCode ?? this.recordCode,
      ownershipKind: ownershipKind ?? this.ownershipKind,
      partyType: partyType ?? this.partyType,
      partyName: partyName ?? this.partyName,
      partyId: partyId ?? this.partyId,
      partyExternalId: partyExternalId ?? this.partyExternalId,
      partyCountryCode: partyCountryCode ?? this.partyCountryCode,
      partyRegistrationNumber:
          partyRegistrationNumber ?? this.partyRegistrationNumber,
      partyTaxNumber: partyTaxNumber ?? this.partyTaxNumber,
      partyContactEmail: partyContactEmail ?? this.partyContactEmail,
      acquisitionType: acquisitionType ?? this.acquisitionType,
      status: status ?? this.status,
      ownershipPercentage: ownershipPercentage ?? this.ownershipPercentage,
      jurisdictionScope: jurisdictionScope ?? this.jurisdictionScope,
      countryCodes: countryCodes ?? this.countryCodes,
      regionCode: regionCode ?? this.regionCode,
      rightId: rightId ?? this.rightId,
      sourceOwnershipRecordId:
          sourceOwnershipRecordId ?? this.sourceOwnershipRecordId,
      previousOwnershipRecordId:
          previousOwnershipRecordId ?? this.previousOwnershipRecordId,
      nextOwnershipRecordId:
          nextOwnershipRecordId ?? this.nextOwnershipRecordId,
      agreementNumber: agreementNumber ?? this.agreementNumber,
      agreementDate: agreementDate ?? this.agreementDate,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveUntil: effectiveUntil ?? this.effectiveUntil,
      isExclusive: isExclusive ?? this.isExclusive,
      isPrimaryOwner: isPrimaryOwner ?? this.isPrimaryOwner,
      isBeneficialOwner: isBeneficialOwner ?? this.isBeneficialOwner,
      isOwnershipVerified: isOwnershipVerified ?? this.isOwnershipVerified,
      verificationDate: verificationDate ?? this.verificationDate,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      documentIds: documentIds ?? this.documentIds,
      relationshipIds: relationshipIds ?? this.relationshipIds,
      transferChainRecordIds:
          transferChainRecordIds ?? this.transferChainRecordIds,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _nullableString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }

    return const <String, dynamic>{};
  }

  static DateTime? _dateValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    try {
      final dynamic converted = value.toDate();

      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {
      // Firestore Timestamp olmayan değerlerde aşağıdaki parse denenir.
    }

    return DateTime.tryParse(value.toString());
  }
}
