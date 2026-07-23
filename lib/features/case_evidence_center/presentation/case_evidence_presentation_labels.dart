const String _signalFallback = 'İnceleme sinyali';

const Map<String, String> _signalLabels = {
  'repeat_scan_observed': 'Tekrarlanan tarama gözlendi',
  'rapid_repeat_scan': 'Kısa sürede tekrar tarandı',
};

final RegExp _technicalSignalToken = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)+$');

String caseEvidenceSignalLabel(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return _signalFallback;

  final labels = <String>{};
  for (final rawPart in input.split(',')) {
    final part = rawPart.trim();
    if (part.isEmpty) continue;
    labels.add(
      _signalLabels[part] ??
          (_technicalSignalToken.hasMatch(part) ? _signalFallback : part),
    );
  }
  return labels.isEmpty ? _signalFallback : labels.join(', ');
}
