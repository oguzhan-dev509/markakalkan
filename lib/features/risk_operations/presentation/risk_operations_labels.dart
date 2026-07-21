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
  static const _relationshipTypeLabels = <String, String>{
    'brand': 'Marka',
    'product': 'Ürün',
    'listing': 'İlan',
    'source_record': 'Kaynak Kaydı',
    'seller': 'Satıcı',
    'account': 'Hesap',
    'domain': 'Alan Adı',
  };
  static const _statusLabels = <String, String>{
    'new': 'Yeni',
    'pending': 'Bekliyor',
    'open': 'Açık',
    'reviewed': 'İncelendi',
    'resolved': 'Çözüldü',
    'dismissed': 'Kapatıldı',
    'unknown': 'Bilinmeyen',
  };

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
  static String relationshipType(String value) =>
      _relationshipTypeLabels[value] ?? 'Diğer İlişki';
  static String status(String value) => _statusLabels[value] ?? 'Bilinmeyen';
}
