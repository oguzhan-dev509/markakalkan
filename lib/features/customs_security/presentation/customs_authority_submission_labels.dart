import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

const customsAuthoritySubmissionStatuses = <String>[
  'draft',
  'awaiting_human_review',
  'awaiting_rights_holder_approval',
  'approved_for_package',
  'package_generated',
  'submitted_externally',
  'receipt_recorded',
  'authority_review',
  'additional_information_requested',
  'concluded',
  'withdrawn',
  'rejected',
  'archived',
];

const customsAuthoritySubmissionTypes = <String>[
  'fsmh_protection_application',
  'customs_smuggling_notification',
  'domestic_organized_counterfeit_notification',
  'emergency_incident_notification',
  'digital_cyber_referral',
  'additional_information_response',
  'other_official_submission',
];

const customsAuthorityTargets = <String>[
  'customs_enforcement',
  'police_anti_smuggling',
  'emergency_112',
  'cyber_crime',
  'fsmh_program',
  'other_authorized_body',
];

const customsAuthorityChannels = <String>[
  'fsmh_portal',
  'official_online_form',
  'electronic_signature',
  'registered_email',
  'physical_delivery',
  'telephone_136',
  'emergency_112',
  'official_correspondence',
  'other',
];

const customsAuthoritySubmissionTransitions = <String, List<String>>{
  'draft': ['awaiting_human_review', 'archived'],
  'awaiting_human_review': [
    'draft',
    'awaiting_rights_holder_approval',
    'rejected',
  ],
  'awaiting_rights_holder_approval': [
    'awaiting_human_review',
    'approved_for_package',
    'rejected',
  ],
  'approved_for_package': ['awaiting_human_review'],
  'package_generated': ['approved_for_package', 'submitted_externally'],
  'submitted_externally': ['authority_review', 'withdrawn'],
  'receipt_recorded': [
    'authority_review',
    'additional_information_requested',
    'concluded',
  ],
  'authority_review': ['additional_information_requested', 'concluded'],
  'additional_information_requested': ['authority_review', 'concluded'],
  'concluded': ['archived'],
  'withdrawn': ['archived'],
  'rejected': ['archived'],
  'archived': [],
};

String customsAuthoritySubmissionStatusLabel(String value) => switch (value) {
  'draft' => 'Taslak',
  'awaiting_human_review' => 'İnsan incelemesi bekleniyor',
  'awaiting_rights_holder_approval' => 'Hak sahibi onayı bekleniyor',
  'approved_for_package' => 'Paket hazırlamaya onaylandı',
  'package_generated' => 'Başvuru paketi hazırlandı',
  'submitted_externally' => 'Resmî kanaldan iletildi',
  'receipt_recorded' => 'Teslim kaydı alındı',
  'authority_review' => 'Kurum incelemesinde',
  'additional_information_requested' => 'Ek bilgi talep edildi',
  'concluded' => 'Sonuçlandı',
  'withdrawn' => 'Geri çekildi',
  'rejected' => 'Reddedildi',
  'archived' => 'Arşivlendi',
  _ => 'Bilinmeyen durum',
};

String customsAuthoritySubmissionTypeLabel(String value) => switch (value) {
  'fsmh_protection_application' => 'FSMH koruma başvurusu',
  'customs_smuggling_notification' => 'Gümrük kaçakçılık bildirimi',
  'domestic_organized_counterfeit_notification' =>
    'Yurt içi organize taklit bildirimi',
  'emergency_incident_notification' => 'Acil olay bildirimi',
  'digital_cyber_referral' => 'Dijital veya siber sevk',
  'additional_information_response' => 'Ek bilgi cevabı',
  'other_official_submission' => 'Diğer resmî iletim',
  _ => 'Belirsiz iletim türü',
};

String customsAuthorityTargetLabel(String value) => switch (value) {
  'customs_enforcement' => 'Gümrükler Muhafaza',
  'police_anti_smuggling' => 'Emniyet KOM',
  'emergency_112' => '112 Acil Çağrı',
  'cyber_crime' => 'Siber Suçlarla Mücadele',
  'fsmh_program' => 'FSMH Programı',
  'other_authorized_body' => 'Diğer yetkili kurum',
  _ => 'Belirsiz kurum',
};

String customsAuthorityChannelLabel(String value) => switch (value) {
  'fsmh_portal' => 'FSMH Portalı',
  'official_online_form' => 'Resmî çevrim içi form',
  'electronic_signature' => 'Elektronik imza',
  'registered_email' => 'Kayıtlı elektronik posta',
  'physical_delivery' => 'Fiziksel teslim',
  'telephone_136' => 'ALO 136',
  'emergency_112' => '112',
  'official_correspondence' => 'Resmî yazışma',
  'other' => 'Diğer',
  _ => 'Belirsiz kanal',
};

Color customsAuthoritySubmissionStatusColor(String status) {
  if (status == 'concluded' || status == 'receipt_recorded') {
    return const Color(0xFF1F7A69);
  }
  if (status == 'rejected' || status == 'withdrawn') {
    return const Color(0xFFB33A3A);
  }
  if (status == 'additional_information_requested' ||
      status == 'awaiting_human_review' ||
      status == 'awaiting_rights_holder_approval') {
    return const Color(0xFFB56B18);
  }
  if (status == 'archived') return const Color(0xFF687580);
  return const Color(0xFF315B7A);
}

String customsAuthoritySubmissionErrorMessage(Object error) {
  if (error is AppCheckUnavailableException) {
    return 'Uygulama güvenlik doğrulaması tamamlanamadı. '
        'Bağlantınızı kontrol edip yeniden deneyin.';
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Devam etmek için oturum açmanız gerekir.',
      'permission-denied' =>
        'Bu işlem için aktif marka sahibi yetkisi gerekir.',
      'not-found' => 'Resmî iletim veya bağlı kaynak kaydı bulunamadı.',
      'failed-precondition' =>
        'İşlem mevcut durum, kaynak veya güvenlik kapılarıyla uyumlu değil.',
      'already-exists' =>
        'Aynı işlem kimliği daha önce farklı içerikle kullanılmış.',
      'resource-exhausted' =>
        'Resmî iletim kapsamı güvenli işlem sınırını aşıyor.',
      'invalid-argument' =>
        'Formdaki alanları ve zorunlu dayanakları kontrol edin.',
      _ => 'Resmî başvuru ve iletim işlemi tamamlanamadı.',
    };
  }
  if (error is FormatException) {
    return 'Sunucu yanıtı güvenli resmî iletim sözleşmesiyle eşleşmedi.';
  }
  return 'Resmî başvuru ve iletim işlemi tamamlanamadı.';
}
