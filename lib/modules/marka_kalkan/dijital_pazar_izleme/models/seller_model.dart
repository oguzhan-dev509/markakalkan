import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class SellerModel {
  const SellerModel({
    required this.id,
    required this.tenantId,
    required this.displayName,
    required this.normalizedName,
    required this.sellerType,
    required this.phoneHashes,
    required this.emailHashes,
    required this.addressHashes,
    required this.ibanHashes,
    required this.domainIds,
    required this.socialAccountIds,
    required this.identityStatus,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.activityStatus,
    required this.createdAt,
    this.legalName,
    this.taxNumberHash,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String displayName;
  final String normalizedName;
  final String? legalName;
  final MonitoringSellerType sellerType;
  final String? taxNumberHash;
  final List<String> phoneHashes;
  final List<String> emailHashes;
  final List<String> addressHashes;
  final List<String> ibanHashes;
  final List<String> domainIds;
  final List<String> socialAccountIds;
  final MonitoringIdentityStatus identityStatus;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final MonitoringSellerActivityStatus activityStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory SellerModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Seller document has no data: ${document.id}');
    }

    return SellerModel.fromMap(id: document.id, data: data);
  }

  factory SellerModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final firstSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['firstSeenAt'],
    );
    final lastSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['lastSeenAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (firstSeenAt == null || lastSeenAt == null || createdAt == null) {
      throw StateError('Seller timestamps are incomplete: $id');
    }

    return SellerModel(
      id: id,
      tenantId: (data['tenantId'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim(),
      normalizedName: (data['normalizedName'] ?? '').toString().trim(),
      legalName: _nullableString(data['legalName']),
      sellerType: MonitoringSellerTypeX.fromValue(
        data['sellerType']?.toString(),
      ),
      taxNumberHash: _nullableString(data['taxNumberHash']),
      phoneHashes: MonitoringModelUtils.stringListFromValue(
        data['phoneHashes'],
      ),
      emailHashes: MonitoringModelUtils.stringListFromValue(
        data['emailHashes'],
      ),
      addressHashes: MonitoringModelUtils.stringListFromValue(
        data['addressHashes'],
      ),
      ibanHashes: MonitoringModelUtils.stringListFromValue(data['ibanHashes']),
      domainIds: MonitoringModelUtils.stringListFromValue(data['domainIds']),
      socialAccountIds: MonitoringModelUtils.stringListFromValue(
        data['socialAccountIds'],
      ),
      identityStatus: MonitoringIdentityStatusX.fromValue(
        data['identityStatus']?.toString(),
      ),
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt,
      activityStatus: MonitoringSellerActivityStatusX.fromValue(
        data['activityStatus']?.toString(),
      ),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'displayName': displayName.trim(),
      'normalizedName': normalizedName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(displayName)
          : normalizedName.trim(),
      'legalName': _cleanNullable(legalName),
      'sellerType': sellerType.value,
      'taxNumberHash': _cleanNullable(taxNumberHash),
      'phoneHashes': phoneHashes,
      'emailHashes': emailHashes,
      'addressHashes': addressHashes,
      'ibanHashes': ibanHashes,
      'domainIds': domainIds,
      'socialAccountIds': socialAccountIds,
      'identityStatus': identityStatus.value,
      'firstSeenAt': Timestamp.fromDate(firstSeenAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'activityStatus': activityStatus.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'displayName': displayName.trim(),
      'normalizedName': normalizedName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(displayName)
          : normalizedName.trim(),
      'legalName': _cleanNullable(legalName),
      'sellerType': sellerType.value,
      'taxNumberHash': _cleanNullable(taxNumberHash),
      'phoneHashes': phoneHashes,
      'emailHashes': emailHashes,
      'addressHashes': addressHashes,
      'ibanHashes': ibanHashes,
      'domainIds': domainIds,
      'socialAccountIds': socialAccountIds,
      'identityStatus': identityStatus.value,
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'activityStatus': activityStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
