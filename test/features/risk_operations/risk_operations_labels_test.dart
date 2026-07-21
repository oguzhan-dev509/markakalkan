import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_labels.dart';

void main() {
  test('all canonical source systems have Turkish labels', () {
    expect(
      RiskOperationsLabels.sourceSystems.map(RiskOperationsLabels.sourceSystem),
      ['İzleme', 'İzlenebilirlik', 'Dijital Dedektif', 'Ortak Risk'],
    );
  });

  test('all canonical severities have Turkish labels', () {
    expect(RiskOperationsLabels.severities.map(RiskOperationsLabels.severity), [
      'Bilgilendirme',
      'Düşük',
      'Orta',
      'Yüksek',
      'Kritik',
    ]);
  });

  test('all canonical evidence qualities have Turkish labels', () {
    expect(
      RiskOperationsLabels.evidenceQualities.map(
        RiskOperationsLabels.evidenceQuality,
      ),
      [
        'Doğrulanmış Birincil Delil',
        'Birden Fazla Kaynakla Desteklenmiş',
        'Tek Kaynak',
        'Yetersiz Delil',
        'Değerlendirilemiyor',
      ],
    );
  });

  test('all canonical case candidacies have Turkish labels', () {
    expect(
      RiskOperationsLabels.caseCandidacies.map(
        RiskOperationsLabels.caseCandidacy,
      ),
      [
        'Vaka Adayı Değil',
        'İnceleme Adayı',
        'Güçlü Vaka Adayı',
        'Yetersiz Delil Nedeniyle Engelli',
      ],
    );
  });

  test('the complete server risk class inventory has Turkish labels', () {
    expect(RiskOperationsLabels.riskClasses, [
      'counterfeit',
      'traceability_anomaly',
      'marketplace_abuse',
      'identity_risk',
      'safety_risk',
      'other',
    ]);
    expect(
      RiskOperationsLabels.riskClasses.map(RiskOperationsLabels.riskClass),
      [
        'Sahtecilik',
        'İzlenebilirlik Anomalisi',
        'Dijital Pazar İhlali',
        'Kimlik Riski',
        'Güvenlik Riski',
        'Diğer',
      ],
    );
  });

  test('unknown canonical values never expose raw snake case', () {
    expect(
      RiskOperationsLabels.sourceSystem('future_source'),
      'Bilinmeyen Kaynak',
    );
    expect(RiskOperationsLabels.severity('future_level'), 'Bilinmeyen');
    expect(
      RiskOperationsLabels.evidenceQuality('future_evidence'),
      'Değerlendirilemiyor',
    );
    expect(RiskOperationsLabels.caseCandidacy('future_case'), 'Bilinmeyen');
    expect(RiskOperationsLabels.riskClass('future_risk'), 'Diğer');
    expect(
      RiskOperationsLabels.timelineEvent('future_event'),
      'Bilinmeyen Olay',
    );
    expect(
      RiskOperationsLabels.relationshipNode('future_node'),
      'Diğer İlişki',
    );
    expect(
      RiskOperationsLabels.relationshipEdge('future_edge'),
      'Diğer İlişki',
    );
    expect(
      RiskOperationsLabels.reasonCode('future_reason'),
      'Diğer İnceleme Gerekçesi',
    );
  });

  test('all repository reason codes have Turkish labels', () {
    const reasons = {
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
    for (final entry in reasons.entries) {
      expect(RiskOperationsLabels.reasonCode(entry.key), entry.value);
    }
  });

  test('all source status values have Turkish labels', () {
    expect(RiskOperationsLabels.status('active'), 'Aktif');
    expect(RiskOperationsLabels.status('pending'), 'Bekliyor');
    expect(RiskOperationsLabels.status('completed'), 'Tamamlandı');
    expect(
      RiskOperationsLabels.status('escalated'),
      'Üst İncelemeye Aktarıldı',
    );
    expect(RiskOperationsLabels.status('closed'), 'Kapatıldı');
    expect(RiskOperationsLabels.status('archived'), 'Arşivlendi');
    expect(RiskOperationsLabels.status('unknown'), 'Bilinmiyor');
  });

  test('reason-only summaries and dates are presentation-safe', () {
    expect(
      RiskOperationsLabels.summary('repeat_scan_observed, rapid_repeat_scan'),
      'Tekrarlanan Tarama Tespit Edildi · Kısa Sürede Tekrarlanan Tarama',
    );
    expect(
      RiskOperationsLabels.summary('Mevcut Türkçe başlık'),
      'Mevcut Türkçe başlık',
    );
    expect(
      RiskOperationsLabels.dateTime(DateTime(2026, 7, 16, 16, 19)),
      '16 Temmuz 2026, 16:19',
    );
  });
}
