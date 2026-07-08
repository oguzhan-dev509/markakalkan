import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../utils/ip_model_utils.dart';

class IpCreationPriorityRecordModel {
  const IpCreationPriorityRecordModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.recordCode,
    required this.title,
    required this.creationType,
    required this.status,
    required this.confidentialityLevel,
    required this.sealStatus,
    required this.createdAt,
    required this.createdBy,
    this.summary,
    this.creatorName,
    this.currentVersion = 1,
    this.activeVersionId,
    this.coCreatorIds = const <String>[],
    this.authorizedUserIds = const <String>[],
    this.tags = const <String>[],
    this.relatedAssetIds = const <String>[],
    this.evidencePackageIds = const <String>[],
    this.firstThoughtAt,
    this.sealedAt,
    this.archivedAt,
    this.archiveReason,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String recordCode;
  final String title;
  final String? summary;
  final String? creatorName;

  final IpCreationType creationType;
  final IpCreationPriorityStatus status;
  final IpCreationConfidentialityLevel confidentialityLevel;
  final IpCreationSealStatus sealStatus;

  final int currentVersion;
  final String? activeVersionId;

  final List<String> coCreatorIds;
  final List<String> authorizedUserIds;
  final List<String> tags;
  final List<String> relatedAssetIds;
  final List<String> evidencePackageIds;

  final DateTime? firstThoughtAt;
  final DateTime? sealedAt;
  final DateTime? archivedAt;
  final String? archiveReason;

  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpCreationPriorityRecordModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Yarat\u0131m \u00f6ncelik kayd\u0131 veri i\u00e7ermiyor: ${document.id}',
      );
    }

    return IpCreationPriorityRecordModel.fromMap(id: document.id, data: data);
  }

  factory IpCreationPriorityRecordModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError(
        'Yarat\u0131m \u00f6ncelik kayd\u0131 olu\u015fturma tarihi eksik: $id',
      );
    }

    return IpCreationPriorityRecordModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      recordCode: IpModelUtils.requiredString(data['recordCode']),
      title: IpModelUtils.requiredString(data['title']),
      summary: IpModelUtils.nullableString(data['summary']),
      creatorName: IpModelUtils.nullableString(data['creatorName']),
      creationType: IpCreationType.fromValue(data['creationType']?.toString()),
      status: IpCreationPriorityStatus.fromValue(data['status']?.toString()),
      confidentialityLevel: IpCreationConfidentialityLevel.fromValue(
        data['confidentialityLevel']?.toString(),
      ),
      sealStatus: IpCreationSealStatus.fromValue(
        data['sealStatus']?.toString(),
      ),
      currentVersion: _positiveVersion(data['currentVersion']),
      activeVersionId: IpModelUtils.nullableString(data['activeVersionId']),
      coCreatorIds: IpModelUtils.stringListFromValue(data['coCreatorIds']),
      authorizedUserIds: IpModelUtils.stringListFromValue(
        data['authorizedUserIds'],
      ),
      tags: IpModelUtils.stringListFromValue(data['tags']),
      relatedAssetIds: IpModelUtils.stringListFromValue(
        data['relatedAssetIds'],
      ),
      evidencePackageIds: IpModelUtils.stringListFromValue(
        data['evidencePackageIds'],
      ),
      firstThoughtAt: IpModelUtils.dateTimeFromValue(data['firstThoughtAt']),
      sealedAt: IpModelUtils.dateTimeFromValue(data['sealedAt']),
      archivedAt: IpModelUtils.dateTimeFromValue(data['archivedAt']),
      archiveReason: IpModelUtils.nullableString(data['archiveReason']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  String get normalizedRecordCode => recordCode.trim().toUpperCase();

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        recordCode.trim().isNotEmpty &&
        title.trim().isNotEmpty;
  }

  bool get isSealed {
    return sealStatus == IpCreationSealStatus.sealed ||
        sealStatus == IpCreationSealStatus.timestampPending ||
        sealStatus == IpCreationSealStatus.timestamped;
  }

  bool get isArchived =>
      status == IpCreationPriorityStatus.archived || archivedAt != null;

  bool get canCreateNewVersion => isSealed && !isArchived;

  bool get patentDisclosureWarningRequired {
    return confidentialityLevel ==
            IpCreationConfidentialityLevel.publicStatement &&
        (creationType == IpCreationType.invention ||
            creationType == IpCreationType.utilityModel ||
            creationType == IpCreationType.industrialDesign);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'recordCode': recordCode.trim(),
      'recordCodeNormalized': normalizedRecordCode,
      'title': title.trim(),
      'summary': IpModelUtils.cleanNullable(summary),
      'creatorName': IpModelUtils.cleanNullable(creatorName),
      'creationType': creationType.value,
      'status': status.value,
      'confidentialityLevel': confidentialityLevel.value,
      'sealStatus': sealStatus.value,
      'currentVersion': currentVersion < 1 ? 1 : currentVersion,
      'activeVersionId': IpModelUtils.cleanNullable(activeVersionId),
      'coCreatorIds': IpModelUtils.cleanStringList(coCreatorIds),
      'authorizedUserIds': IpModelUtils.cleanStringList(authorizedUserIds),
      'tags': IpModelUtils.cleanStringList(tags),
      'relatedAssetIds': IpModelUtils.cleanStringList(relatedAssetIds),
      'evidencePackageIds': IpModelUtils.cleanStringList(evidencePackageIds),
      'firstThoughtAt': IpModelUtils.timestampOrNull(firstThoughtAt),
      'sealedAt': IpModelUtils.timestampOrNull(sealedAt),
      'archivedAt': IpModelUtils.timestampOrNull(archivedAt),
      'archiveReason': IpModelUtils.cleanNullable(archiveReason),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': IpModelUtils.timestampOrNull(updatedAt),
      'updatedBy': IpModelUtils.cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();

    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();

    return map;
  }

  static int _positiveVersion(Object? value) {
    final parsed = IpModelUtils.intFromValue(value, fallback: 1);

    return parsed < 1 ? 1 : parsed;
  }
}
