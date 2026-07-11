import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/models/counterfeit_twin_admin_report.dart';

void main() {
  test('generalized digital report is parsed for admin review', () {
    final report = CounterfeitTwinAdminReport.fromMap(<String, dynamic>{
      'id': 'report-1',
      'status': 'submitted',
      'publicCategory': 'digital',
      'publicSubcategory': 'website_domain',
      'targetType': 'website',
      'originalEntityName': 'Gerçek Platform',
      'suspectedEntityName': 'Şüpheli Platform',
      'createdAtMillis': 1783750000000,
      'differenceNotes': <String>['Alan adı farklı', 'Logo taklit edilmiş'],
      'financialImpact': <String, dynamic>{
        'hasMonetaryLoss': true,
        'currency': 'TRY',
      },
    });

    expect(report.id, 'report-1');
    expect(report.status, 'submitted');
    expect(report.publicCategory, 'digital');
    expect(report.originalName, 'Gerçek Platform');
    expect(report.suspectedName, 'Şüpheli Platform');
    expect(report.isOpen, isTrue);
    expect(report.texts('differenceNotes'), hasLength(2));
    expect(report.object('financialImpact')['currency'], 'TRY');
    expect(report.createdAt, isNotNull);
  });

  test('published reports are read-only in the queue', () {
    final report = CounterfeitTwinAdminReport.fromMap(<String, dynamic>{
      'id': 'report-2',
      'status': 'published',
    });

    expect(report.isOpen, isFalse);
  });
}
