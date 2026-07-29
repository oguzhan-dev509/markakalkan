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

const customsExternalReferenceTypes = <String>[
  'none',
  'kep_message_id',
  'portal_transaction_id',
  'physical_delivery_reference',
  'official_correspondence_reference',
  'telephone_reference',
  'other_reference',
];

const reviewApprovalSectionTitle = 'Başvuru İnceleme ve Onay İşlemleri';
const reviewApprovalDescription =
    'Başvuruyu aynı kanonik dosyada insan incelemesine, hak sahibi veya temsilci '
    'onayına ve paket hazırlama onayına taşıyın. Bu işlemler kuruma otomatik '
    'gönderim yapmaz.';
const submitForHumanReview = 'İnsan İncelemesine Gönder';
const retrySubmitForHumanReview = 'Aynı Geçişle Yeniden Dene';
const completeHumanReview = 'İnsan İncelemesini Tamamla';
const retryCompleteHumanReview = 'Aynı İncelemeyle Yeniden Dene';
const approveForPackage =
    'Hak Sahibi Onayını Kaydet ve Paket Hazırlamaya Onayla';
const retryApproveForPackage = 'Aynı Onayla Yeniden Dene';

const externalSubmissionSectionTitle = 'Kuruma Dış Teslim Kaydı';
const recordExternalSubmission = 'Dış Teslimi Kaydet';
const retryExternalSubmission = 'Aynı Kayıtla Yeniden Dene';
const externalSubmissionNotAutomaticDescription =
    'Bu işlem paketi kuruma otomatik göndermez. Yalnız kurum dışında gerçekten '
    'tamamlanan teslimi, güncel değiştirilemez paketle ilişkilendirerek kaydeder.';

const authorityReceiptSectionTitle = 'Resmî Alındı Kaydı';
const recordAuthorityReceipt = 'Resmî Alındıyı Kaydet';
const retryAuthorityReceipt = 'Aynı Alındıyla Yeniden Dene';
const authorityReceiptDescription =
    'Kurumun başvuruyu fiilen teslim aldığını gösteren resmî referans, zaman, '
    'kanal ve isteğe bağlı belge bütünlüğü bilgilerini değiştirilemez biçimde kaydedin.';

const authorityInterimResponseSectionTitle = 'Kurum Ara Cevabı';
const appendAuthorityInterimResponse = 'Ara Cevabı Kaydet';
const retryAuthorityInterimResponse = 'Aynı Cevapla Yeniden Dene';
const authorityInterimResponseDescription =
    'Kurumdan gelen teslim teyidi, ek bilgi talebi veya durum güncellemesini aynı '
    'kanonik dosyada değiştirilemez cevap olarak kaydedin.';

const authorityOutcomeSectionTitle = 'Nihai Kurum Sonucu';
const recordAuthorityOutcome = 'Nihai Sonucu Kaydet';
const retryAuthorityOutcome = 'Aynı Sonuçla Yeniden Dene';
const authorityOutcomeDescription =
    'Kurum belgesindeki nihai sonucu insan tarafından sınıflandırarak dosyayı '
    'sonuçlandırın. Bu sınıflandırma MarkaKalkan tarafından verilmiş hukukî karar değildir.';

const artifactSectionTitle = 'Resmî Paket ve Güvenli İndirme';
const materializePackage = 'Resmî Paketi Oluştur';
const retryMaterialization = 'Yeniden Dene';
const downloadPdf = 'PDF İndir';
const downloadManifest = 'Manifest İndir';
const legacyArtifactDescription =
    'Bu paket için güvenli indirme dosyaları henüz oluşturulmadı.';
const pendingArtifactDescription = 'Paket oluşturma işlemi hazırlanıyor.';
const materializingArtifactDescription =
    'Resmî paket güvenli biçimde oluşturuluyor.';
const failedRecoverableArtifactDescription =
    'Paket oluşturma tamamlanamadı. Aynı güvenli istekle yeniden deneyebilirsiniz.';
const integrityFailedArtifactDescription = 'Paket bütünlüğü doğrulanamadı.';
const integrityFailedArtifactActionDescription =
    'İndirme güvenlik nedeniyle durduruldu. İnceleme için destek ekibine başvurun.';
const disabledArtifactDescription =
    'Güvenli paket oluşturma işlemi şu anda kapalı.';
const unknownArtifactDescription = 'Paket durumu doğrulanamadı.';
const scopeUnavailableDescription =
    'Bu eski kaydın güvenli paket kapsamı henüz doğrulanamadı. Paket oluşturma ve indirme işlemleri kullanılamıyor.';
const downloadOpenFailed =
    'İndirme bağlantısı açılamadı. Lütfen yeniden deneyin.';

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

String customsExternalReferenceTypeLabel(String value) => switch (value) {
  'none' => 'Dış referans yok',
  'kep_message_id' => 'KEP ileti numarası',
  'portal_transaction_id' => 'Portal işlem numarası',
  'physical_delivery_reference' => 'Fiziksel teslim referansı',
  'official_correspondence_reference' => 'Resmî yazışma referansı',
  'telephone_reference' => 'Telefon kayıt referansı',
  'other_reference' => 'Diğer dış referans',
  _ => 'Belirsiz dış referans',
};

String customsAuthorityResponseTypeLabel(String value) => switch (value) {
  'receipt' => 'Resmî alındı',
  'acknowledgement' => 'Teslim / inceleme teyidi',
  'information_request' => 'Ek bilgi talebi',
  'status_update' => 'Durum güncellemesi',
  'decision' => 'Kurum kararı',
  'closure_notice' => 'Kapanış bildirimi',
  'rejection_notice' => 'Ret bildirimi',
  'other' => 'Diğer ara cevap',
  _ => 'Belirsiz kurum cevabı',
};

String customsAuthorityOutcomeCodeLabel(String value) => switch (value) {
  'pending' => 'Sonuç bekleniyor',
  'accepted_for_review' => 'İncelemeye kabul edildi',
  'action_taken' => 'İşlem yapıldı',
  'temporary_measure_recorded' => 'Geçici tedbir kaydedildi',
  'goods_detained_or_suspended' =>
    'Eşyaya el koyma / işlemi durdurma bildirildi',
  'goods_seizure_reported' => 'Eşya müsaderesi / yakalama bildirildi',
  'no_action' => 'İşlem yapılmadı',
  'referred_to_other_authority' => 'Başka kuruma sevk edildi',
  'additional_procedure_required' => 'Ek işlem gerekiyor',
  'closed' => 'Dosya kapatıldı',
  'rejected' => 'Başvuru reddedildi',
  'other' => 'Diğer sonuç',
  _ => 'Belirsiz sonuç',
};

String customsAuthorityOutcomeFinalityLabel(String value) => switch (value) {
  'informational' => 'Bilgilendirme',
  'preliminary' => 'Ön değerlendirme',
  'administrative_final' => 'İdarî olarak kesin',
  'judicial_final' => 'Yargısal olarak kesin',
  'not_stated' => 'Belgede belirtilmedi',
  _ => 'Belirsiz kesinlik',
};

bool customsAuthoritySubmissionErrorIsRetryable(Object error) {
  if (error is FormatException) return false;
  if (error is FirebaseFunctionsException) {
    return !{
      'unauthenticated',
      'permission-denied',
      'failed-precondition',
      'already-exists',
      'resource-exhausted',
      'invalid-argument',
    }.contains(error.code);
  }
  return true;
}

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

bool customsArtifactErrorIsRetryable(Object error) {
  if (error is FormatException) return false;
  if (error is FirebaseFunctionsException) {
    return !{
      'unauthenticated',
      'permission-denied',
      'failed-precondition',
      'already-exists',
      'resource-exhausted',
      'invalid-argument',
    }.contains(error.code);
  }
  return true;
}

String customsArtifactErrorMessage(Object error) {
  if (error is AppCheckUnavailableException) {
    return 'Uygulama güvenlik doğrulaması tamamlanamadı. '
        'Bağlantınızı kontrol edip yeniden deneyin.';
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' =>
        'Oturumunuz sona ermiş olabilir. Lütfen yeniden giriş yapın.',
      'permission-denied' => 'Bu işlem için yetkiniz bulunmuyor.',
      'failed-precondition' =>
        'Paket mevcut durumunda bu işlem gerçekleştirilemiyor.',
      'already-exists' =>
        'İstek daha önce farklı bilgilerle kullanılmış. Sayfayı yenileyip tekrar deneyin.',
      'resource-exhausted' => 'Paket boyutu güvenli işlem sınırını aşıyor.',
      'unavailable' =>
        'Paket hizmetine şu anda ulaşılamıyor. Lütfen yeniden deneyin.',
      _ => 'Paket işlemi güvenli biçimde tamamlanamadı.',
    };
  }
  if (error is FormatException) {
    return 'Paket hizmetinden beklenmeyen bir yanıt alındı.';
  }
  return 'Paket işlemi güvenli biçimde tamamlanamadı.';
}
