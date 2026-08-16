import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const solutionPath =
      'lib/features/home/presentation/widgets/home_solution_families_section.dart';
  const routerPath = 'lib/app/router.dart';

  test('KTG is placed before Case and Evidence in counterfeit defense', () {
    final source = File(solutionPath).readAsStringSync();

    const ktgTitle = 'Kaçakçılık, Taklit ve Gümrük Güvenliği';
    const caseTitle = 'Vaka ve Delil Merkezi';

    expect(source.split(ktgTitle).length - 1, 1);
    expect(
      source.indexOf(ktgTitle),
      greaterThan(source.indexOf('Marka Dedektifi')),
    );
    expect(source.indexOf(ktgTitle), lessThan(source.indexOf(caseTitle)));

    expect(
      source,
      contains('destination: _Destination.customsSecurity,'),
    );
    expect(
      source,
      contains(
        'case _Destination.customsSecurity:\n'
        '        return AppRouter.openCustomsSecurityHub(context);',
      ),
    );
    expect(
      source,
      contains(
        'brandDetective,\n'
        '  customsSecurity,\n'
        '  caseEvidence,',
      ),
    );
  });

  test('KTG card preserves approved user-facing copy', () {
    final source = File(solutionPath).readAsStringSync();

    expect(
      source,
      contains("'Kaçakçılık, Taklit ve Gümrük Güvenliği'"),
    );
    expect(
      source,
      contains(
        "'Markanızı sınırda, gümrük süreçlerinde ve resmî kurumlar nezdinde koruyun.'",
      ),
    );
  });

  test('KTG destination uses the existing customs security hub route', () {
    final router = File(routerPath).readAsStringSync();

    expect(
      router,
      contains(
        'static Future<void> openCustomsSecurityHub(BuildContext context)',
      ),
    );
    expect(
      router,
      contains("RouteSettings(name: '/customs-security')"),
    );
    expect(
      router,
      contains('builder: (_) => const CustomsSecurityHubPage()'),
    );
  });
}
