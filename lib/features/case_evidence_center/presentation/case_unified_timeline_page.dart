import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_party_relationship_presentation_labels.dart';

class CaseUnifiedTimelinePage extends StatefulWidget {
  const CaseUnifiedTimelinePage({
    super.key,
    required this.caseId,
    this.repository,
  });
  final String caseId;
  final CasePartyRepository? repository;
  @override
  State<CaseUnifiedTimelinePage> createState() =>
      _CaseUnifiedTimelinePageState();
}

class _CaseUnifiedTimelinePageState extends State<CaseUnifiedTimelinePage> {
  late final CasePartyRepository _repository =
      widget.repository ?? CallableCasePartyRepository();
  Map<String, dynamic>? _result;
  String? _error;
  final Set<String> _categories = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _repository.timeline(widget.caseId);
      if (value['contractVersion'] != 'case-unified-timeline-v1' ||
          value['readOnly'] != true ||
          value['writesPerformed'] != 0) {
        throw const FormatException('Geçersiz zaman çizelgesi.');
      }
      if (mounted) setState(() => _result = value);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'generic');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Birleşik Olay Zaman Çizelgesi')),
    body: _result == null
        ? _error == null
              ? const Center(
                  key: ValueKey('unified-timeline-loading'),
                  child: CircularProgressIndicator(),
                )
              : Center(
                  child: Text(
                    _error == 'not-found'
                        ? 'Vaka dosyası bulunamadı.'
                        : _error == 'permission-denied'
                        ? 'Bu zaman çizelgesini görüntüleme yetkiniz bulunmuyor.'
                        : 'Zaman çizelgesi yüklenemedi.',
                  ),
                )
        : _content(),
  );

  Widget _content() {
    final caseItem = _map(_result!['case']);
    final stats = _map(_result!['stats']);
    final events = _maps(_result!['events'])
        .where(
          (item) =>
              _categories.isEmpty ||
              _categories.contains(_string(item, 'category')),
        )
        .toList();
    const categories = ['case', 'evidence', 'task', 'party', 'relationship'];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${_string(caseItem, 'caseNumber')} · ${_string(caseItem, 'caseTitle')}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Toplam olay: ${stats['totalEvents'] ?? 0}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: categories
              .map(
                (category) => FilterChip(
                  label: Text(caseTimelineCategoryLabel(category)),
                  selected: _categories.contains(category),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _categories.add(category)
                        : _categories.remove(category),
                  ),
                ),
              )
              .toList(),
        ),
        const Divider(height: 28),
        if (events.isEmpty)
          const Text('Bu filtrede olay bulunmuyor.')
        else
          ...events.map(
            (item) => ListTile(
              leading: Chip(
                label: Text(
                  caseTimelineCategoryLabel(_string(item, 'category')),
                ),
              ),
              title: Text(
                _string(item, 'eventLabel').isEmpty
                    ? 'Vaka olayı'
                    : _string(item, 'eventLabel'),
              ),
              subtitle: Text(
                '${_string(item, 'summary')}\n'
                '${caseLocalDateTime(item['occurredAt'])}',
              ),
            ),
          ),
      ],
    );
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : {};
List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.map(_map).toList() : const [];
String _string(Map<String, dynamic> map, String key) =>
    map[key] is String ? map[key] as String : '';
