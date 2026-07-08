import 'package:cloud_functions/cloud_functions.dart';

import '../models/supply_protection_control_model.dart';

class SupplyProtectionControlCommandService {
  SupplyProtectionControlCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<String> create(SupplyProtectionControlModel control) async {
    final callable = _functions.httpsCallable('createSupplyProtectionControl');

    final response = await callable
        .call<Map<String, dynamic>>(<String, dynamic>{
          'controlCode': control.controlCode.trim(),
          'title': control.title.trim(),
          'controlType': control.controlType.value,
          'scope': control.scope.value,
          'riskLevel': control.riskLevel.value,
          'partnerId': _cleanNullable(control.partnerId),
          'facilityId': _cleanNullable(control.facilityId),
          'description': _cleanNullable(control.description),
          'assignedToName': _cleanNullable(control.assignedToName),
          'plannedAt': control.plannedAt?.toUtc().toIso8601String(),
          'notes': _cleanNullable(control.notes),
        });

    final controlId = response.data['controlId'];

    if (controlId is! String || controlId.trim().isEmpty) {
      throw StateError(
        'Koruma kontrolü sunucu tarafından oluşturuldu ancak kimlik dönmedi.',
      );
    }

    return controlId.trim();
  }

  Future<void> update(SupplyProtectionControlModel control) async {
    final controlId = control.id.trim();

    if (controlId.isEmpty) {
      throw ArgumentError.value(
        control.id,
        'control.id',
        'controlId boş olamaz.',
      );
    }

    final callable = _functions.httpsCallable('updateSupplyProtectionControl');

    await callable.call<void>(<String, dynamic>{
      'controlId': controlId,
      'title': control.title.trim(),
      'controlType': control.controlType.value,
      'scope': control.scope.value,
      'status': control.status.value,
      'result': control.result.value,
      'riskLevel': control.riskLevel.value,
      'partnerId': _cleanNullable(control.partnerId),
      'facilityId': _cleanNullable(control.facilityId),
      'description': _cleanNullable(control.description),
      'assignedToId': _cleanNullable(control.assignedToId),
      'assignedToName': _cleanNullable(control.assignedToName),
      'plannedAt': _dateToIso(control.plannedAt),
      'startedAt': _dateToIso(control.startedAt),
      'nextControlAt': _dateToIso(control.nextControlAt),
      'findings': _cleanNullable(control.findings),
      'evidenceDocumentIds': List<String>.from(control.evidenceDocumentIds),
      'relatedProductIds': List<String>.from(control.relatedProductIds),
      'correctiveAction': _cleanNullable(control.correctiveAction),
      'correctiveActionOwnerId': _cleanNullable(
        control.correctiveActionOwnerId,
      ),
      'correctiveActionOwnerName': _cleanNullable(
        control.correctiveActionOwnerName,
      ),
      'correctiveActionDueAt': _dateToIso(control.correctiveActionDueAt),
      'correctiveActionCompletedAt': _dateToIso(
        control.correctiveActionCompletedAt,
      ),
      'notes': _cleanNullable(control.notes),
      'metadata': Map<String, dynamic>.from(control.metadata),
    });
  }

  static String? _dateToIso(DateTime? value) {
    return value?.toUtc().toIso8601String();
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
