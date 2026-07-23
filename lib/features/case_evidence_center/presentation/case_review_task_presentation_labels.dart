import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_chain_presentation_labels.dart';

String reviewTaskTypeLabel(String value) =>
    const {
      'evidence_review': 'Delil incelemesi',
      'source_verification': 'Kaynak doğrulama',
      'marketplace_check': 'Pazar yeri kontrolü',
      'technical_analysis': 'Teknik analiz',
      'laboratory_analysis': 'Laboratuvar analizi',
      'legal_assessment': 'Hukuki değerlendirme',
      'field_investigation': 'Saha incelemesi',
      'other': 'Diğer inceleme',
    }[value] ??
    'İnceleme görevi';

String reviewTaskStatusLabel(String value) =>
    const {
      'open': 'Açık',
      'assigned': 'Atandı',
      'in_review': 'İncelemede',
      'completed': 'Tamamlandı',
      'cancelled': 'İptal edildi',
    }[value] ??
    'Durum bilinmiyor';

String reviewTaskPriorityLabel(String value) =>
    const {
      'low': 'Düşük',
      'medium': 'Orta',
      'high': 'Yüksek',
      'critical': 'Kritik',
    }[value] ??
    'Öncelik belirtilmedi';

String reviewTaskAssigneeLabel(String value) =>
    const {
      'unassigned': 'Atanmadı',
      'internal_member': 'İç kullanıcı',
      'external_expert': 'Dış uzman',
      'laboratory': 'Laboratuvar',
    }[value] ??
    'Atama bilgisi yok';

String reviewTaskOutcomeLabel(String? value) =>
    const {
      'confirmed': 'Bulgular doğrulandı',
      'inconclusive': 'Kesin sonuca ulaşılamadı',
      'not_confirmed': 'Bulgular doğrulanmadı',
      'action_required': 'Ek işlem gerekli',
      'not_applicable': 'Uygulanabilir değil',
    }[value] ??
    'Sonuç belirtilmedi';

String reviewTaskEventLabel(String value) =>
    const {
      'task_created': 'Görev oluşturuldu',
      'assignment_set': 'Görev atandı',
      'assignment_changed': 'Görev ataması değiştirildi',
      'review_started': 'İnceleme başlatıldı',
      'note_added': 'İnceleme notu eklendi',
      'due_date_changed': 'Son tarih değiştirildi',
      'review_completed': 'İnceleme tamamlandı',
      'task_cancelled': 'Görev iptal edildi',
    }[value] ??
    'Görev işlemi';

String reviewTaskActionLabel(String value) =>
    const {
      'assign': 'Görev ata',
      'change_assignment': 'Atamayı değiştir',
      'start_review': 'İncelemeyi başlat',
      'add_note': 'Not ekle',
      'change_due_date': 'Son tarihi değiştir',
      'complete_review': 'İncelemeyi tamamla',
      'cancel_task': 'Görevi iptal et',
    }[value] ??
    'Görev işlemi';

String reviewTaskDateLabel(Object? value) => caseEvidenceDateTimeLabel(value);

String? reviewTaskDueInputToIso(String value) {
  final match = RegExp(
    r'^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final parts = List<int>.generate(
    5,
    (index) => int.parse(match.group(index + 1)!),
  );
  final local = DateTime(parts[2], parts[1], parts[0], parts[3], parts[4]);
  if (local.year != parts[2] ||
      local.month != parts[1] ||
      local.day != parts[0] ||
      local.hour != parts[3] ||
      local.minute != parts[4]) {
    return null;
  }
  return local.toUtc().toIso8601String();
}
