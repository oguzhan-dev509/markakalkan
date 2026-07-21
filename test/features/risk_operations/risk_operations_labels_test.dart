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
      RiskOperationsLabels.relationshipType('future_node'),
      'Diğer İlişki',
    );
  });
}
