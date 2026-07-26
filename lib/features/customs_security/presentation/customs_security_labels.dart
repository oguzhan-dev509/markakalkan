import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

const customsProfileStatuses = <String>[
  'draft',
  'under_review',
  'active',
  'suspended',
  'expired',
  'archived',
];

const customsInterventionStatuses = <String>[
  'draft',
  'risk_review',
  'under_preliminary_review',
  'temporarily_detained',
  'awaiting_right_holder',
  'authentication_in_progress',
  'infringement_not_confirmed',
  'infringement_suspected',
  'infringement_confirmed',
  'importer_objection',
  'legal_action_required',
  'destruction_pending',
  'destroyed',
  'released',
  'referred_to_authority',
  'closed',
  'archived',
];

const customsPriorities = <String>['low', 'normal', 'high', 'critical'];

const customsSourceTypes = <String>[
  'customs_notification',
  'brand_report',
  'risk_signal',
  'field_report',
  'law_enforcement_referral',
  'other',
];

const customsBorderPointTypes = <String>[
  'seaport',
  'airport',
  'land_border',
  'rail',
  'postal_center',
  'free_zone',
  'warehouse',
  'other',
];

const customsAuthenticationResults = <String>[
  'not_started',
  'inconclusive',
  'likely_authentic',
  'likely_counterfeit',
  'confirmed_authentic',
  'confirmed_counterfeit',
];

const customsDeclaredUnits = <String>[
  'unit',
  'pair',
  'set',
  'box',
  'carton',
  'pallet',
  'kilogram',
  'liter',
  'meter',
  'other',
];

const customsProfileTransitions = <String, List<String>>{
  'draft': ['under_review', 'archived'],
  'under_review': ['draft', 'active', 'archived'],
  'active': ['suspended', 'expired', 'archived'],
  'suspended': ['active', 'expired', 'archived'],
  'expired': ['archived'],
  'archived': [],
};

const customsInterventionTransitions = <String, List<String>>{
  'draft': ['risk_review', 'under_preliminary_review', 'closed', 'archived'],
  'risk_review': ['under_preliminary_review', 'temporarily_detained', 'closed'],
  'under_preliminary_review': [
    'temporarily_detained',
    'awaiting_right_holder',
    'authentication_in_progress',
    'infringement_not_confirmed',
    'infringement_suspected',
    'closed',
  ],
  'temporarily_detained': [
    'awaiting_right_holder',
    'authentication_in_progress',
    'released',
    'referred_to_authority',
  ],
  'awaiting_right_holder': [
    'authentication_in_progress',
    'infringement_not_confirmed',
    'infringement_suspected',
    'released',
    'legal_action_required',
  ],
  'authentication_in_progress': [
    'infringement_not_confirmed',
    'infringement_suspected',
    'infringement_confirmed',
  ],
  'infringement_not_confirmed': ['released', 'closed'],
  'infringement_suspected': [
    'temporarily_detained',
    'awaiting_right_holder',
    'authentication_in_progress',
    'legal_action_required',
    'released',
  ],
  'infringement_confirmed': [
    'importer_objection',
    'legal_action_required',
    'destruction_pending',
    'referred_to_authority',
  ],
  'importer_objection': [
    'authentication_in_progress',
    'legal_action_required',
    'destruction_pending',
    'released',
    'referred_to_authority',
  ],
  'legal_action_required': [
    'destruction_pending',
    'released',
    'referred_to_authority',
    'closed',
  ],
  'destruction_pending': ['destroyed', 'legal_action_required'],
  'destroyed': ['closed'],
  'released': ['closed'],
  'referred_to_authority': ['legal_action_required', 'closed'],
  'closed': ['archived'],
  'archived': [],
};

String customsProfileStatusLabel(String value) => switch (value) {
  'draft' => 'Taslak',
  'under_review' => 'İncelemede',
  'active' => 'Aktif',
  'suspended' => 'Askıda',
  'expired' => 'Süresi doldu',
  'archived' => 'Arşivlendi',
  _ => 'Bilinmeyen durum',
};

String customsInterventionStatusLabel(String value) => switch (value) {
  'draft' => 'Taslak',
  'risk_review' => 'Risk incelemesi',
  'under_preliminary_review' => 'Ön incelemede',
  'temporarily_detained' => 'Geçici olarak alıkondu',
  'awaiting_right_holder' => 'Hak sahibi yanıtı bekleniyor',
  'authentication_in_progress' => 'Ürün doğrulaması sürüyor',
  'infringement_not_confirmed' => 'İhlal doğrulanmadı',
  'infringement_suspected' => 'İhlal şüphesi',
  'infringement_confirmed' => 'İhlal doğrulandı',
  'importer_objection' => 'İthalatçı itirazı',
  'legal_action_required' => 'Hukuki işlem gerekiyor',
  'destruction_pending' => 'İmha kararı bekleniyor',
  'destroyed' => 'İmha edildi',
  'released' => 'Serbest bırakıldı',
  'referred_to_authority' => 'Yetkili makama sevk edildi',
  'closed' => 'Kapatıldı',
  'archived' => 'Arşivlendi',
  _ => 'Bilinmeyen durum',
};

String customsPriorityLabel(String value) => switch (value) {
  'low' => 'Düşük',
  'normal' => 'Normal',
  'high' => 'Yüksek',
  'critical' => 'Kritik',
  _ => 'Belirsiz',
};

String customsSourceTypeLabel(String value) => switch (value) {
  'customs_notification' => 'Gümrük bildirimi',
  'brand_report' => 'Marka bildirimi',
  'risk_signal' => 'Risk sinyali',
  'field_report' => 'Saha bildirimi',
  'law_enforcement_referral' => 'Kolluk sevki',
  'other' => 'Diğer',
  _ => 'Belirsiz kaynak',
};

String customsBorderPointTypeLabel(String value) => switch (value) {
  'seaport' => 'Deniz limanı',
  'airport' => 'Havalimanı',
  'land_border' => 'Kara sınır kapısı',
  'rail' => 'Demiryolu',
  'postal_center' => 'Posta merkezi',
  'free_zone' => 'Serbest bölge',
  'warehouse' => 'Depo',
  'other' => 'Diğer',
  _ => 'Belirsiz sınır noktası',
};

String customsAuthenticationResultLabel(String value) => switch (value) {
  'not_started' => 'Başlatılmadı',
  'inconclusive' => 'Sonuçsuz',
  'likely_authentic' => 'Orijinal olasılığı yüksek',
  'likely_counterfeit' => 'Taklit olasılığı yüksek',
  'confirmed_authentic' => 'Orijinal olduğu doğrulandı',
  'confirmed_counterfeit' => 'Taklit olduğu doğrulandı',
  _ => 'Belirsiz doğrulama sonucu',
};

String customsIntegrityStatusLabel(String value) => switch (value) {
  'no_integrity_signal' => 'Bütünlük sinyali yok',
  'integrity_signal_detected' => 'İşlem bütünlüğü sinyali',
  'explanation_requested' => 'Açıklama istendi',
  'independent_review_required' => 'Bağımsız inceleme gerekiyor',
  'review_in_progress' => 'İnceleme sürüyor',
  'signal_not_substantiated' => 'Sinyal doğrulanmadı',
  'irregularity_confirmed' => 'İşlem düzensizliği doğrulandı',
  'referred_to_authority' => 'Yetkili makama sevk edildi',
  'closed' => 'Kapatıldı',
  _ => 'Belirsiz bütünlük durumu',
};

String customsDeclaredUnitLabel(String value) => switch (value) {
  'unit' => 'Adet',
  'pair' => 'Çift',
  'set' => 'Set',
  'box' => 'Kutu',
  'carton' => 'Koli',
  'pallet' => 'Palet',
  'kilogram' => 'Kilogram',
  'liter' => 'Litre',
  'meter' => 'Metre',
  'other' => 'Diğer',
  _ => 'Birim',
};

Color customsStatusColor(String status) {
  if (status == 'active' || status == 'infringement_not_confirmed') {
    return const Color(0xFF1F7A69);
  }
  if (status == 'infringement_confirmed' ||
      status == 'critical' ||
      status == 'destroyed') {
    return const Color(0xFFB33A3A);
  }
  if (status == 'infringement_suspected' ||
      status == 'temporarily_detained' ||
      status == 'legal_action_required' ||
      status == 'destruction_pending') {
    return const Color(0xFFB56B18);
  }
  if (status == 'archived' || status == 'closed' || status == 'expired') {
    return const Color(0xFF687580);
  }
  return const Color(0xFF315B7A);
}

String customsSecurityErrorMessage(Object error) {
  if (error is AppCheckUnavailableException) {
    return 'Uygulama güvenlik doğrulaması tamamlanamadı. '
        'Bağlantınızı kontrol edip yeniden deneyin.';
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Devam etmek için oturum açmanız gerekir.',
      'permission-denied' =>
        'Bu işlem için aktif marka sahibi yetkisi gerekir.',
      'not-found' => 'Gümrük güvenliği kaydı bulunamadı.',
      'failed-precondition' =>
        'İşlem mevcut kayıt durumu veya doğrulama dayanaklarıyla uyumlu değil.',
      'already-exists' =>
        'Aynı işlem kimliği daha önce farklı içerikle kullanılmış.',
      'resource-exhausted' =>
        'Gümrük güvenliği kapsamı güvenli işlem sınırını aşıyor.',
      'invalid-argument' =>
        'Formdaki alanları ve zorunlu dayanakları kontrol edin.',
      _ => 'Gümrük güvenliği işlemi tamamlanamadı.',
    };
  }
  if (error is FormatException) {
    return 'Sunucu yanıtı güvenli sözleşmeyle eşleşmedi.';
  }
  return 'Gümrük güvenliği işlemi tamamlanamadı.';
}
