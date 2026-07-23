String casePartyTypeLabel(String value) =>
    const {
      'person': 'Kişi',
      'organization': 'Kuruluş',
      'seller_account': 'Satıcı hesabı',
      'marketplace_store': 'Pazar yeri mağazası',
      'marketplace_operator': 'Pazar yeri işletmecisi',
      'website': 'İnternet sitesi',
      'social_media_account': 'Sosyal medya hesabı',
      'manufacturer': 'Üretici',
      'supplier': 'Tedarikçi',
      'logistics_provider': 'Lojistik sağlayıcısı',
      'payment_intermediary': 'Ödeme aracısı',
      'laboratory': 'Laboratuvar',
      'expert': 'Uzman',
      'public_authority': 'Kamu kurumu',
      'legal_representative': 'Hukuki temsilci',
      'address': 'Adres veya konum',
      'other': 'Diğer taraf',
    }[value] ??
    'Taraf kaydı';

String casePartyRoleLabel(String value) =>
    const {
      'suspected_seller': 'Şüpheli satıcı',
      'suspected_operator': 'Şüpheli işletmeci',
      'manufacturer': 'Üretici',
      'supplier': 'Tedarikçi',
      'marketplace': 'Pazar yeri',
      'payment_recipient': 'Ödeme alıcısı',
      'logistics_provider': 'Lojistik sağlayıcısı',
      'complainant': 'Şikâyetçi',
      'reporter': 'Bildirim sahibi',
      'witness': 'Tanık',
      'expert': 'Uzman',
      'laboratory': 'Laboratuvar',
      'authority': 'Yetkili kurum',
      'legal_representative': 'Hukuki temsilci',
      'related_party': 'İlgili taraf',
      'other': 'Diğer rol',
    }[value] ??
    'Diğer rol';

String casePartyStatusLabel(String value) =>
    const {
      'observed': 'Gözlemlendi',
      'under_review': 'İnceleniyor',
      'verified': 'Doğrulandı',
      'disputed': 'İhtilaflı',
      'inactive': 'Pasif',
    }[value] ??
    'Durum bilgisi yok';

String caseRelationshipTypeLabel(String value) =>
    const {
      'owns': 'Sahibi',
      'operates': 'İşletiyor',
      'manages': 'Yönetiyor',
      'sells_for': 'Adına satış yapıyor',
      'supplies': 'Tedarik ediyor',
      'manufactures_for': 'Adına üretim yapıyor',
      'ships_for': 'Sevkiyat yapıyor',
      'receives_payment_for': 'Adına ödeme alıyor',
      'represents': 'Temsil ediyor',
      'uses_same_identity': 'Aynı kimliği kullanıyor',
      'uses_same_contact_point': 'Aynı iletişim noktasını kullanıyor',
      'uses_same_address': 'Aynı adresi kullanıyor',
      'appears_in_evidence': 'Delilde yer alıyor',
      'assigned_to_task': 'Göreve bağlı',
      'reported_by': 'Tarafından bildirildi',
      'investigated_by': 'Tarafından inceleniyor',
      'verified_by': 'Tarafından doğrulandı',
      'linked_to': 'Bağlantılı',
      'other': 'Diğer ilişki',
    }[value] ??
    'İlişki kaydı';

String caseRelationshipStatusLabel(String value) =>
    const {
      'observed': 'Gözlemlendi',
      'under_review': 'İnceleniyor',
      'confirmed': 'Doğrulandı',
      'disputed': 'İhtilaflı',
      'inactive': 'Pasif',
    }[value] ??
    'Durum bilgisi yok';

String caseConfidenceLabel(String value) =>
    const {
      'low': 'Düşük güven',
      'medium': 'Orta güven',
      'high': 'Yüksek güven',
      'confirmed': 'Kesinleşmiş',
    }[value] ??
    'Güven bilgisi yok';

String caseGraphEventLabel(String value) =>
    const {
      'party_created': 'Taraf kaydı oluşturuldu',
      'party_review_started': 'Taraf incelemesi başlatıldı',
      'party_verified': 'Taraf doğrulandı',
      'party_disputed': 'Taraf ihtilaflı olarak işaretlendi',
      'party_note_added': 'Taraf notu eklendi',
      'party_deactivated': 'Taraf pasife alındı',
      'relationship_created': 'İlişki kaydı oluşturuldu',
      'relationship_review_started': 'İlişki incelemesi başlatıldı',
      'relationship_confirmed': 'İlişki doğrulandı',
      'relationship_disputed': 'İlişki ihtilaflı olarak işaretlendi',
      'relationship_note_added': 'İlişki notu eklendi',
      'relationship_deactivated': 'İlişki pasife alındı',
    }[value] ??
    'Vaka bağlantısı işlemi';

String caseTimelineCategoryLabel(String value) =>
    const {
      'case': 'Vaka',
      'evidence': 'Delil',
      'task': 'Görev',
      'party': 'Taraf',
      'relationship': 'İlişki',
    }[value] ??
    'Vaka';

String caseGraphActionLabel(String value) =>
    const {
      'start_review': 'İncelemeyi başlat',
      'verify': 'Doğrula',
      'confirm': 'Doğrula',
      'dispute': 'İhtilaflı olarak işaretle',
      'add_note': 'Not ekle',
      'deactivate': 'Pasife al',
    }[value] ??
    'İşlem';

String caseLocalDateTime(Object? value) {
  final date = DateTime.tryParse(value is String ? value : '')?.toLocal();
  if (date == null) return 'Tarih bilgisi yok';
  String two(int item) => item.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
