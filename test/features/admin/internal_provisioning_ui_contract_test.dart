import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostic remains inside authorized management surface', () {
    final source = File(
      'lib/features/admin/presentation/management_center_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (access == null || !access.isSuperAdmin)'));
    expect(source, contains('const _InternalProvisioningDryRunPanel()'));
    expect(source, contains("'internal-provisioning-dry-run-action'"));
    expect(source, contains('verified && !_submitting ? _run : null'));
    expect(source, contains('if (_submitting) return;'));
    expect(source, isNot(contains('dryRun: false')));
  });

  test('real action is super-admin scoped, confirmed and single-submit', () {
    final source = File(
      'lib/features/admin/presentation/management_center_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (access == null || !access.isSuperAdmin)'));
    expect(source, contains('const _InternalRealProvisioningPanel()'));
    expect(source, contains('InternalRealProvisioningGate.enabled'));
    expect(source, contains('FirebaseAuth.instance.currentUser == null'));
    expect(source, contains('verifyTokenAcquisition()'));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('barrierDismissible: false'));
    expect(source, contains('_controller.canSubmit'));
    expect(source, isNot(contains('provisioned')));
  });

  test('production source contains no debug App Check provider', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources, contains('ReCaptchaEnterpriseProvider'));
    expect(sources, isNot(contains('ReCaptchaV3Provider')));
    expect(sources, isNot(contains('AndroidProvider.debug')));
    expect(sources, isNot(contains('AppleProvider.debug')));
  });
}
