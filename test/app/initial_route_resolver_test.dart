import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/app/initial_route_resolver.dart';

void main() {
  group('resolveInitialCounterfeitTwinSlug', () {
    test('resolves Flutter web hash route', () {
      final uri = Uri.parse(
        'https://markakalkan.com/#/sahte-ikiz/'
        'beauty-of-joseon-relief-sun-rice-probiotics-spf50-pa-txo7g7fnsi',
      );

      expect(
        resolveInitialCounterfeitTwinSlug(uri),
        'beauty-of-joseon-relief-sun-rice-probiotics-spf50-pa-txo7g7fnsi',
      );
    });

    test('resolves path-based route', () {
      final uri = Uri.parse(
        'https://markakalkan.com/sahte-ikiz/jakavi-orijinal-sahte-karsilastirma',
      );

      expect(
        resolveInitialCounterfeitTwinSlug(uri),
        'jakavi-orijinal-sahte-karsilastirma',
      );
    });

    test('supports a query string inside the hash route', () {
      final uri = Uri.parse(
        'https://markakalkan.com/#/sahte-ikiz/kayit-kodu?source=share',
      );

      expect(resolveInitialCounterfeitTwinSlug(uri), 'kayit-kodu');
    });

    test('returns null for the home page', () {
      expect(
        resolveInitialCounterfeitTwinSlug(
          Uri.parse('https://markakalkan.com/#/'),
        ),
        isNull,
      );
    });

    test('returns null for an unrelated route', () {
      expect(
        resolveInitialCounterfeitTwinSlug(
          Uri.parse('https://markakalkan.com/#/marka-girisi'),
        ),
        isNull,
      );
    });
  });
}
