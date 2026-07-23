final RegExp _technical = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)+$');

String evidenceEventLabel(String value) =>
    const {
      'chain_started': 'Delil zinciri başlatıldı',
      'custody_received': 'Delil teslim alındı',
      'custody_transferred': 'Delil teslim edildi',
      'review_started': 'İnceleme başlatıldı',
      'review_completed': 'İnceleme tamamlandı',
      'sealed': 'Delil mühürlendi',
      'unsealed': 'Delil mührü açıldı',
    }[value] ??
    'Delil zinciri işlemi';

String evidenceReviewLabel(String value) =>
    const {
      'pending': 'İnceleme bekliyor',
      'awaiting_review': 'İnceleme bekliyor',
      'under_review': 'İncelemede',
      'verified': 'Doğrulandı',
    }[value] ??
    'İnceleme bekliyor';

String evidenceCustodyLabel(String value) =>
    const {
      'not_started': 'Zincir başlatılmadı',
      'registered': 'Kayıtlı',
      'sealed': 'Mühürlü',
    }[value] ??
    'Kayıtlı';

String evidenceIntegrityLabel(String value) =>
    const {
      'not_started': 'Zincir başlatılmadı',
      'verified': 'Bütünlük doğrulandı',
      'broken': 'Bütünlük doğrulanamadı',
    }[value] ??
    'Bütünlük durumu bilinmiyor';

String evidenceTypeLabel(String value) =>
    const {'source_record': 'Kaynak risk kaydı'}[value] ??
    (_technical.hasMatch(value) ? 'Delil kaydı' : value);

String evidenceActionLabel(String value) =>
    const {
      'chain_started': 'Delil zincirini başlat',
      'custody_received': 'Teslim al',
      'custody_transferred': 'Teslim et',
      'review_started': 'İncelemeyi başlat',
      'review_completed': 'İncelemeyi tamamla',
      'sealed': 'Mühürle',
      'unsealed': 'Mührü aç',
    }[value] ??
    'Delil zinciri işlemi';

String caseEvidenceDateTimeLabel(Object? value) {
  final parsed = switch (value) {
    DateTime date => date,
    String text when text.trim().isNotEmpty => DateTime.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null) return 'Tarih bilgisi yok';
  final local = parsed.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
