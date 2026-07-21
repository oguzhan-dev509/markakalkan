/// Centralized Turkish presentation labels for canonical Risk Operations values.
///
/// These mappings never alter values sent to or received from the server.
abstract final class RiskOperationsLabels {
  static const sourceSystems = <String>[
    'monitoring',
    'traceability',
    'digital_detective',
    'shared_risk',
  ];
  static const riskClasses = <String>[
    'counterfeit',
    'traceability_anomaly',
    'marketplace_abuse',
    'identity_risk',
    'safety_risk',
    'other',
  ];
  static const severities = <String>[
    'info',
    'low',
    'medium',
    'high',
    'critical',
  ];
  static const evidenceQualities = <String>[
    'verified_primary',
    'corroborated',
    'single_source',
    'insufficient',
    'unavailable',
  ];
  static const caseCandidacies = <String>[
    'not_candidate',
    'review_candidate',
    'strong_candidate',
    'blocked_insufficient_evidence',
  ];

  static const _sourceSystemLabels = <String, String>{
    'traceability': 'İzlenebilirlik',
    'monitoring': 'İzleme',
    'digital_detective': 'Dijital Dedektif',
    'shared_risk': 'Ortak Risk',
  };
  static const _severityLabels = <String, String>{
    'critical': 'Kritik',
    'high': 'Yüksek',
    'medium': 'Orta',
    'low': 'Düşük',
    'info': 'Bilgilendirme',
  };
  static const _evidenceQualityLabels = <String, String>{
    'verified_primary': 'Doğrulanmış Birincil Delil',
    'corroborated': 'Birden Fazla Kaynakla Desteklenmiş',
    'single_source': 'Tek Kaynak',
    'insufficient': 'Yetersiz Delil',
    'unavailable': 'Değerlendirilemiyor',
  };
  static const _caseCandidacyLabels = <String, String>{
    'not_candidate': 'Vaka Adayı Değil',
    'review_candidate': 'İnceleme Adayı',
    'strong_candidate': 'Güçlü Vaka Adayı',
    'blocked_insufficient_evidence': 'Yetersiz Delil Nedeniyle Engelli',
  };
  static const _riskClassLabels = <String, String>{
    'counterfeit': 'Sahtecilik',
    'traceability_anomaly': 'İzlenebilirlik Anomalisi',
    'marketplace_abuse': 'Dijital Pazar İhlali',
    'identity_risk': 'Kimlik Riski',
    'safety_risk': 'Güvenlik Riski',
    'other': 'Diğer',
  };
  static const _timelineEventLabels = <String, String>{
    'source_observed': 'Kaynakta Gözlemlendi',
  };
  static const _relationshipNodeLabels = <String, String>{
    'brand': 'Marka',
    'product': 'Ürün',
    'listing': 'İlan',
    'source_record': 'Kaynak Kaydı',
    'seller': 'Satıcı',
    'account': 'Hesap',
    'domain': 'Alan Adı',
  };
  static const _relationshipEdgeLabels = <String, String>{
    'related_to': 'İlişkili',
    'belongs_to': 'Bağlı',
    'observed_on': 'Üzerinde Gözlemlendi',
    'sold_by': 'Satıcı Tarafından Sunuldu',
  };
  static const _statusLabels = <String, String>{
    'new': 'Yeni',
    'active': 'Aktif',
    'pending': 'Bekliyor',
    'not_required': 'İnceleme Gerekmiyor',
    'open': 'Açık',
    'under_review': 'İnceleniyor',
    'in_review': 'İnceleniyor',
    'reviewing': 'İnceleniyor',
    'reviewed': 'İncelendi',
    'confirmed': 'Doğrulandı',
    'approved': 'Onaylandı',
    'accepted': 'Kabul Edildi',
    'identified': 'Tespit Edildi',
    'mitigating': 'Önlem Alınıyor',
    'completed': 'Tamamlandı',
    'escalated': 'Üst İncelemeye Aktarıldı',
    'resolved': 'Çözüldü',
    'dismissed': 'Kapatıldı',
    'closed': 'Kapatıldı',
    'archived': 'Arşivlendi',
    'unknown': 'Bilinmiyor',
  };
  static const _reasonCodeLabels = <String, String>{
    'repeat_scan_observed': 'Tekrarlanan Tarama Tespit Edildi',
    'repeated_scan': 'Tekrarlanan Tarama Tespit Edildi',
    'rapid_repeat_scan': 'Kısa Sürede Tekrarlanan Tarama',
    'platform_changed': 'Tarama Platformu Değişti',
    'revoked_code': 'İptal Edilmiş Kod Kullanıldı',
    'evidence.assessment_unavailable': 'Delil Değerlendirmesi Yapılamadı',
    'evidence.primary_verified': 'Birincil Delil Doğrulandı',
    'evidence.multiple_independent_sources':
        'Birden Fazla Bağımsız Kaynak Doğruladı',
    'evidence.single_source_only': 'Yalnız Tek Kaynak Bulunuyor',
    'evidence.references_missing': 'Delil Referansı Bulunmuyor',
    'case.evidence_insufficient': 'Vaka İçin Delil Yetersiz',
    'case.high_risk_corroborated':
        'Yüksek Risk Birden Fazla Kaynakla Doğrulandı',
    'case.human_review_threshold': 'İnsan İncelemesi Eşiğine Ulaştı',
    'case.threshold_not_met': 'Vaka Adaylığı Eşiğine Ulaşmadı',
    'source.read_failed': 'Kaynak Geçici Olarak Okunamadı',
  };

  static const _months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static String sourceSystem(String value) =>
      _sourceSystemLabels[value] ?? 'Bilinmeyen Kaynak';
  static String severity(String value) =>
      _severityLabels[value] ?? 'Bilinmeyen';
  static String evidenceQuality(String value) =>
      _evidenceQualityLabels[value] ?? 'Değerlendirilemiyor';
  static String caseCandidacy(String value) =>
      _caseCandidacyLabels[value] ?? 'Bilinmeyen';
  static String riskClass(String value) => _riskClassLabels[value] ?? 'Diğer';
  static String timelineEvent(String value) =>
      _timelineEventLabels[value] ?? 'Bilinmeyen Olay';
  static String relationshipNode(String value) =>
      _relationshipNodeLabels[value] ?? 'Diğer İlişki';
  static String relationshipEdge(String value) =>
      _relationshipEdgeLabels[value] ?? 'Diğer İlişki';
  static String status(String value) => _statusLabels[value] ?? 'Bilinmiyor';
  static String reasonCode(String value) =>
      _reasonCodeLabels[value] ?? 'Diğer İnceleme Gerekçesi';

  /// Converts adapter summaries made solely from reason codes while preserving
  /// ordinary user-facing Turkish summaries.
  static String summary(String value) {
    final parts = value.split(',').map((part) => part.trim()).toList();
    if (parts.isNotEmpty && parts.every(_reasonCodeLabels.containsKey)) {
      return parts.map(reasonCode).join(' · ');
    }
    return value;
  }

  static String dateTime(DateTime? value) {
    if (value == null) return 'Zaman bilinmiyor';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year}, $hour:$minute';
  }
}
