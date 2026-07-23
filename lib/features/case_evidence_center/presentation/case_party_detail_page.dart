import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_parties_relationships_page.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_party_relationship_presentation_labels.dart';

class CasePartyDetailPage extends StatefulWidget {
  const CasePartyDetailPage({
    super.key,
    required this.partyId,
    this.repository,
    this.linkOpener,
  });
  final String partyId;
  final CasePartyRepository? repository;
  final Future<void> Function(BuildContext, String, String)? linkOpener;
  @override
  State<CasePartyDetailPage> createState() => _CasePartyDetailPageState();
}

class _CasePartyDetailPageState extends State<CasePartyDetailPage> {
  late final CasePartyRepository _repository =
      widget.repository ?? CallableCasePartyRepository();
  Map<String, dynamic>? _detail;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await _repository.partyDetail(widget.partyId);
      if (value['contractVersion'] != 'case-party-detail-v1' ||
          value['readOnly'] != true ||
          value['writesPerformed'] != 0) {
        throw const FormatException('Geçersiz taraf ayrıntısı.');
      }
      if (mounted) setState(() => _detail = value);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'generic');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Taraf Ayrıntısı')),
    body: _detail == null
        ? _error == null
              ? const Center(
                  key: ValueKey('party-detail-loading'),
                  child: CircularProgressIndicator(),
                )
              : Center(
                  child: Text(
                    _error == 'not-found'
                        ? 'Taraf kaydı bulunamadı.'
                        : _error == 'permission-denied'
                        ? 'Bu taraf kaydını görüntüleme yetkiniz bulunmuyor.'
                        : 'Taraf ayrıntısı yüklenemedi.',
                  ),
                )
        : _content(),
  );

  Widget _content() {
    final party = _map(_detail!['party']);
    final relationships = _maps(_detail!['relationships']);
    final events = _maps(_detail!['timelineEvents']);
    final actions = _strings(_detail!['allowedActions']);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _string(party, 'partyNumber'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _string(party, 'displayName'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${casePartyTypeLabel(_string(party, 'partyType'))} · '
          '${casePartyStatusLabel(_string(party, 'status'))}',
        ),
        Text(_strings(party['caseRoles']).map(casePartyRoleLabel).join(', ')),
        ListTile(
          key: const ValueKey('linked-case'),
          title: Text(
            '${_string(party, 'caseNumber')} · ${_string(party, 'caseTitle')}',
          ),
          leading: const Icon(Icons.folder_outlined),
          onTap: () => _open('case', _string(party, 'caseId')),
        ),
        if (_string(party, 'publicAlias').isNotEmpty)
          Text('Kamuya açık ad: ${_string(party, 'publicAlias')}'),
        if (_string(party, 'organizationName').isNotEmpty)
          Text('Kuruluş: ${_string(party, 'organizationName')}'),
        if (_string(party, 'city').isNotEmpty ||
            _string(party, 'countryCode').isNotEmpty)
          Text(
            'Konum: ${[_string(party, 'city'), _string(party, 'countryCode')].where((item) => item.isNotEmpty).join(' / ')}',
          ),
        const SizedBox(height: 8),
        Text(_string(party, 'description')),
        Text('Oluşturulma: ${caseLocalDateTime(party['createdAt'])}'),
        Text('Son güncelleme: ${caseLocalDateTime(party['updatedAt'])}'),
        const Divider(height: 32),
        Text('İlişkiler', style: Theme.of(context).textTheme.titleLarge),
        if (relationships.isEmpty)
          const Text('Henüz ilişki kaydı bulunmuyor.')
        else
          ...relationships.map((item) {
            final partyIsSource =
                item['sourceEntityType'] == 'party' &&
                item['sourceEntityId'] == widget.partyId;
            final type = _string(
              item,
              partyIsSource ? 'targetEntityType' : 'sourceEntityType',
            );
            final id = _string(
              item,
              partyIsSource ? 'targetEntityId' : 'sourceEntityId',
            );
            final label = _string(
              item,
              partyIsSource ? 'targetLabel' : 'sourceLabel',
            );
            return ListTile(
              title: Text(label),
              subtitle: Text(
                '${caseRelationshipTypeLabel(_string(item, 'relationshipType'))} · '
                '${caseRelationshipStatusLabel(_string(item, 'status'))}',
              ),
              onTap: id.isEmpty ? null : () => _open(type, id),
            );
          }),
        const Divider(height: 32),
        Text(
          'Taraf Zaman Çizelgesi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (events.isEmpty)
          const Text('Henüz taraf olayı bulunmuyor.')
        else
          ...events.map(
            (item) => ListTile(
              title: Text(caseGraphEventLabel(_string(item, 'eventType'))),
              subtitle: Text(
                '${_string(item, 'note')}\n${caseLocalDateTime(item['recordedAt'])}',
              ),
            ),
          ),
        if (actions.isNotEmpty) const Divider(height: 32),
        Wrap(
          spacing: 8,
          children: actions
              .map(
                (action) => OutlinedButton(
                  onPressed: () => _act(action),
                  child: Text(caseGraphActionLabel(action)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _open(String type, String id) {
    if (widget.linkOpener != null) return widget.linkOpener!(context, type, id);
    return switch (type) {
      'case' => AppRouter.openCaseEvidenceDetail(context, caseId: id),
      'evidence' => AppRouter.openCaseEvidenceItemDetail(
        context,
        evidenceRefId: id,
      ),
      'task' => AppRouter.openCaseReviewTaskDetail(context, taskId: id),
      'party' => AppRouter.openCasePartyDetail(context, partyId: id),
      _ => Future.value(),
    };
  }

  Future<void> _act(String action) async {
    final note = TextEditingController();
    final event = {
      'start_review': 'party_review_started',
      'verify': 'party_verified',
      'dispute': 'party_disputed',
      'add_note': 'party_note_added',
      'deactivate': 'party_deactivated',
    }[action]!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(caseGraphActionLabel(action)),
        content: TextField(
          key: const ValueKey('graph-event-note'),
          controller: note,
          decoration: const InputDecoration(labelText: 'İşlem notu'),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              if (note.text.trim().length < 3) return;
              final result = await _repository.append({
                'contractVersion': 'case-graph-event-request-v1',
                'targetType': 'party',
                'targetId': widget.partyId,
                'eventType': event,
                'note': note.text,
                'requestId': _uuid(),
              });
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (result['duplicate'] == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu işlem daha önce kaydedildi.'),
                  ),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    note.dispose();
    await _load();
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : {};
List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.map(_map).toList() : const [];
List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
String _string(Map<String, dynamic> map, String key) =>
    map[key] is String ? map[key] as String : '';
String _uuid() {
  final random = Random.secure();
  String hex(int length) =>
      List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-'
      '${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}
