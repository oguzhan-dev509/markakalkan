import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_comparison_codec.dart';

class CounterfeitTwinAdminReport {
  CounterfeitTwinAdminReport({
    required this.id,
    required Map<String, dynamic> data,
  }) : data = Map<String, dynamic>.unmodifiable(data);

  final String id;
  final Map<String, dynamic> data;

  factory CounterfeitTwinAdminReport.fromMap(Object? value) {
    final map = _map(value);
    final id = _text(map['id']);
    if (id.isEmpty) {
      throw const FormatException('Sahte ikiz bildirim kimliği eksik.');
    }
    return CounterfeitTwinAdminReport(id: id, data: map);
  }

  String text(String key) => _text(data[key]);

  List<String> texts(String key) {
    final value = data[key];
    if (value is! Iterable) return const <String>[];
    return value
        .map(_text)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> object(String key) => _map(data[key]);

  double? number(String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  CounterfeitTwinDecodedComparison get decodedComparison =>
      CounterfeitTwinComparisonCodec.decode(texts('differenceNotes'));

  DateTime? dateFromMillis(String key) {
    final value = data[key];
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  String get status {
    final value = text('status');
    return value.isEmpty ? 'submitted' : value;
  }

  String get publicCategory => text('publicCategory');
  String get publicSubcategory => text('publicSubcategory');
  String get targetType => text('targetType');
  String get robotType => text('robotType');

  String get originalName => _first(<String>[
    text('originalEntityName'),
    text('originalProductName'),
    text('originalBrandName'),
  ]);

  String get suspectedName => _first(<String>[
    text('suspectedEntityName'),
    text('suspectedProductName'),
    text('suspectedBrandName'),
  ]);

  String get platformName => text('platformName');
  String get storeDisplayName => text('storeDisplayName');
  String get listingUrl => text('listingUrl');
  String get reporterEmail => text('reporterEmail');
  String get reporterUid => text('reporterUid');
  String get evidenceNotes => text('evidenceNotes');
  String get usagePurpose => text('usagePurpose');
  String get technicalIdentity => text('technicalIdentity');
  String get counterfeitRisk => text('counterfeitRisk');
  String get reviewNote => text('reviewNote');
  String get publicSummary => text('publicSummary');
  String get publicComparisonId => text('publicComparisonId');

  DateTime? get createdAt => dateFromMillis('createdAtMillis');
  DateTime? get reviewedAt => dateFromMillis('reviewedAtMillis');

  bool get isOpen => status == 'submitted' || status == 'under_review';
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map<String, dynamic>(
    (key, item) => MapEntry<String, dynamic>(key.toString(), item),
  );
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _first(Iterable<String> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return '';
}
