class CounterfeitTwinComparisonRow {
  const CounterfeitTwinComparisonRow({
    required this.checkpoint,
    required this.originalValue,
    required this.suspectedValue,
  });

  final String checkpoint;
  final String originalValue;
  final String suspectedValue;
}

class CounterfeitTwinDecodedComparison {
  const CounterfeitTwinDecodedComparison({
    required this.rows,
    required this.legacyNotes,
    required this.priceObservedAt,
    required this.originalImageSource,
    required this.suspectedImageSource,
  });

  final List<CounterfeitTwinComparisonRow> rows;
  final List<String> legacyNotes;
  final String priceObservedAt;
  final String originalImageSource;
  final String suspectedImageSource;
}

abstract final class CounterfeitTwinComparisonCodec {
  static const String _rowPrefix = '[KARSILASTIRMA]';
  static const String _priceDatePrefix = '[FIYAT_TARIHI]';
  static const String _originalImageSourcePrefix = '[GERCEK_GORSEL_KAYNAGI]';
  static const String _suspectedImageSourcePrefix = '[SUPHELI_GORSEL_KAYNAGI]';

  static List<String> encode({
    required List<CounterfeitTwinComparisonRow> rows,
    required List<String> legacyNotes,
    required String priceObservedAt,
    required String originalImageSource,
    required String suspectedImageSource,
  }) {
    final values = <String>[];

    for (final row in rows.take(8)) {
      values.add(
        '$_rowPrefix Kontrol: ${_clean(row.checkpoint)}'
        ' || Gerçek: ${_clean(row.originalValue)}'
        ' || Sahte / doğrulanmamış: ${_clean(row.suspectedValue)}',
      );
    }

    final priceDate = _clean(priceObservedAt);
    if (priceDate.isNotEmpty) {
      values.add('$_priceDatePrefix $priceDate');
    }

    final originalSource = _clean(originalImageSource);
    if (originalSource.isNotEmpty) {
      values.add('$_originalImageSourcePrefix $originalSource');
    }

    final suspectedSource = _clean(suspectedImageSource);
    if (suspectedSource.isNotEmpty) {
      values.add('$_suspectedImageSourcePrefix $suspectedSource');
    }

    values.addAll(legacyNotes.map(_clean).where((item) => item.isNotEmpty));

    if (values.length > 20) {
      throw StateError(
        'Karşılaştırma satırları, kaynak bilgileri ve fark notlarının '
        'toplamı 20 kaydı aşamaz.',
      );
    }

    for (final value in values) {
      if (value.length > 500) {
        throw StateError(
          'Karşılaştırma ve fark kayıtlarının her biri en fazla '
          '500 karakter olabilir.',
        );
      }
    }

    return List<String>.unmodifiable(values);
  }

  static CounterfeitTwinDecodedComparison decode(List<String> values) {
    final rows = <CounterfeitTwinComparisonRow>[];
    final legacyNotes = <String>[];
    var priceObservedAt = '';
    var originalImageSource = '';
    var suspectedImageSource = '';

    for (final raw in values) {
      final value = raw.trim();
      if (value.startsWith(_rowPrefix)) {
        final body = value.substring(_rowPrefix.length).trim();
        final parts = body.split(' || ');
        if (parts.length == 3) {
          rows.add(
            CounterfeitTwinComparisonRow(
              checkpoint: _after(parts[0], 'Kontrol:'),
              originalValue: _after(parts[1], 'Gerçek:'),
              suspectedValue: _after(parts[2], 'Sahte / doğrulanmamış:'),
            ),
          );
          continue;
        }
      }

      if (value.startsWith(_priceDatePrefix)) {
        priceObservedAt = value.substring(_priceDatePrefix.length).trim();
        continue;
      }
      if (value.startsWith(_originalImageSourcePrefix)) {
        originalImageSource = value
            .substring(_originalImageSourcePrefix.length)
            .trim();
        continue;
      }
      if (value.startsWith(_suspectedImageSourcePrefix)) {
        suspectedImageSource = value
            .substring(_suspectedImageSourcePrefix.length)
            .trim();
        continue;
      }

      if (value.isNotEmpty) {
        legacyNotes.add(value);
      }
    }

    return CounterfeitTwinDecodedComparison(
      rows: List<CounterfeitTwinComparisonRow>.unmodifiable(rows),
      legacyNotes: List<String>.unmodifiable(legacyNotes),
      priceObservedAt: priceObservedAt,
      originalImageSource: originalImageSource,
      suspectedImageSource: suspectedImageSource,
    );
  }

  static String _after(String value, String prefix) {
    final trimmed = value.trim();
    return trimmed.startsWith(prefix)
        ? trimmed.substring(prefix.length).trim()
        : trimmed;
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll('||', '/')
        .trim();
  }
}
