import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_party_relationship_presentation_labels.dart';

const _partyTypes = [
  'person',
  'organization',
  'seller_account',
  'marketplace_store',
  'marketplace_operator',
  'website',
  'social_media_account',
  'manufacturer',
  'supplier',
  'logistics_provider',
  'payment_intermediary',
  'laboratory',
  'expert',
  'public_authority',
  'legal_representative',
  'address',
  'other',
];
const _partyRoles = [
  'suspected_seller',
  'suspected_operator',
  'manufacturer',
  'supplier',
  'marketplace',
  'payment_recipient',
  'logistics_provider',
  'complainant',
  'reporter',
  'witness',
  'expert',
  'laboratory',
  'authority',
  'legal_representative',
  'related_party',
  'other',
];

abstract interface class CasePartyRepository {
  Future<Map<String, dynamic>> workspace();
  Future<Map<String, dynamic>> partyDetail(String partyId);
  Future<Map<String, dynamic>> timeline(String caseId);
  Future<Map<String, dynamic>> createParty(Map<String, dynamic> request);
  Future<Map<String, dynamic>> createRelationship(Map<String, dynamic> request);
  Future<Map<String, dynamic>> append(Map<String, dynamic> request);
}

class CallableCasePartyRepository implements CasePartyRepository {
  CallableCasePartyRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async =>
      _map(_normalize((await _functions.httpsCallable(name).call(data)).data));
  @override
  Future<Map<String, dynamic>> workspace() => _call('listCasePartyWorkspace', {
    'contractVersion': 'case-party-workspace-list-request-v1',
  });
  @override
  Future<Map<String, dynamic>> partyDetail(String partyId) => _call(
    'getCasePartyDetail',
    {'contractVersion': 'case-party-detail-request-v1', 'partyId': partyId},
  );
  @override
  Future<Map<String, dynamic>> timeline(String caseId) => _call(
    'getCaseUnifiedTimeline',
    {'contractVersion': 'case-unified-timeline-request-v1', 'caseId': caseId},
  );
  @override
  Future<Map<String, dynamic>> createParty(Map<String, dynamic> request) =>
      _call('createCaseParty', request);
  @override
  Future<Map<String, dynamic>> createRelationship(
    Map<String, dynamic> request,
  ) => _call('createCaseRelationship', request);
  @override
  Future<Map<String, dynamic>> append(Map<String, dynamic> request) =>
      _call('appendCaseGraphEvent', request);
}

class CasePartiesRelationshipsPage extends StatefulWidget {
  const CasePartiesRelationshipsPage({
    super.key,
    this.repository,
    this.partyDetailOpener,
    this.timelineOpener,
  });
  final CasePartyRepository? repository;
  final Future<void> Function(BuildContext, String)? partyDetailOpener;
  final Future<void> Function(BuildContext, String)? timelineOpener;
  @override
  State<CasePartiesRelationshipsPage> createState() =>
      _CasePartiesRelationshipsPageState();
}

class _CasePartiesRelationshipsPageState
    extends State<CasePartiesRelationshipsPage> {
  late final CasePartyRepository _repository =
      widget.repository ?? CallableCasePartyRepository();
  Map<String, dynamic>? _result;
  String? _error;
  String _caseId = '';
  String _partyType = '';
  String _partyStatus = '';
  String _partyRole = '';
  String _relationshipType = '';
  String _relationshipStatus = '';
  String _confidence = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await _repository.workspace();
      if (value['contractVersion'] != 'case-party-workspace-list-v1' ||
          value['readOnly'] != true ||
          value['writesPerformed'] != 0) {
        throw const FormatException('Geçersiz çalışma alanı.');
      }
      if (mounted) setState(() => _result = value);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'generic');
    }
  }

  List<Map<String, dynamic>> get _cases => _maps(_result?['cases']);
  List<Map<String, dynamic>> get _parties => _maps(_result?['parties'])
      .where(
        (item) =>
            (_caseId.isEmpty || item['caseId'] == _caseId) &&
            (_partyType.isEmpty || item['partyType'] == _partyType) &&
            (_partyStatus.isEmpty || item['status'] == _partyStatus) &&
            (_partyRole.isEmpty ||
                _strings(item['caseRoles']).contains(_partyRole)),
      )
      .toList();
  List<Map<String, dynamic>> get _relationships =>
      _maps(_result?['relationships'])
          .where(
            (item) =>
                (_caseId.isEmpty || item['caseId'] == _caseId) &&
                (_relationshipType.isEmpty ||
                    item['relationshipType'] == _relationshipType) &&
                (_relationshipStatus.isEmpty ||
                    item['status'] == _relationshipStatus) &&
                (_confidence.isEmpty || item['confidence'] == _confidence),
          )
          .toList();

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Taraflar, İlişkiler ve Olay Zaman Çizelgesi'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Taraflar'),
            Tab(text: 'İlişkiler'),
            Tab(text: 'Olay Zaman Çizelgesi'),
          ],
        ),
      ),
      floatingActionButton: _result == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('create-party'),
              onPressed: _showCreateParty,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Taraf ekle'),
            ),
      body: _result == null
          ? _error == null
                ? const Center(
                    key: ValueKey('party-workspace-loading'),
                    child: CircularProgressIndicator(),
                  )
                : _Error(error: _error!, retry: _load)
          : Column(
              children: [
                _Stats(stats: _map(_result!['stats'])),
                _CaseFilter(
                  cases: _cases,
                  value: _caseId,
                  changed: (value) => setState(() => _caseId = value ?? ''),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _partyView(),
                      _relationshipView(),
                      _timelineEntry(),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _partyView() => Column(
    children: [
      _Filters(
        children: [
          _filter(
            'Taraf türü',
            _partyType,
            const ['seller_account', 'person', 'organization', 'website'],
            casePartyTypeLabel,
            (value) => setState(() => _partyType = value ?? ''),
          ),
          _filter(
            'Durum',
            _partyStatus,
            const [
              'observed',
              'under_review',
              'verified',
              'disputed',
              'inactive',
            ],
            casePartyStatusLabel,
            (value) => setState(() => _partyStatus = value ?? ''),
          ),
          _filter(
            'Vaka rolü',
            _partyRole,
            const ['suspected_seller', 'manufacturer', 'related_party'],
            casePartyRoleLabel,
            (value) => setState(() => _partyRole = value ?? ''),
          ),
        ],
      ),
      Expanded(
        child: _parties.isEmpty
            ? const Center(child: Text('Henüz taraf kaydı bulunmuyor.'))
            : ListView(
                children: _parties.map((item) {
                  final id = _string(item, 'partyId');
                  return Card(
                    child: ListTile(
                      key: ValueKey('party-$id'),
                      title: Text(
                        '${_string(item, 'partyNumber')} · ${_string(item, 'displayName')}',
                      ),
                      subtitle: Text(
                        '${casePartyTypeLabel(_string(item, 'partyType'))} · '
                        '${casePartyStatusLabel(_string(item, 'status'))}\n'
                        '${_string(item, 'caseNumber')} · ${_string(item, 'caseTitle')}\n'
                        '${_strings(item['caseRoles']).map(casePartyRoleLabel).join(', ')} · '
                        '${item['relationshipCount'] ?? 0} ilişki · '
                        '${caseLocalDateTime(item['lastEventAt'])}',
                      ),
                      isThreeLine: true,
                      onTap: id.isEmpty
                          ? null
                          : () => widget.partyDetailOpener != null
                                ? widget.partyDetailOpener!(context, id)
                                : AppRouter.openCasePartyDetail(
                                    context,
                                    partyId: id,
                                  ),
                    ),
                  );
                }).toList(),
              ),
      ),
    ],
  );

  Widget _relationshipView() => Column(
    children: [
      _Filters(
        children: [
          _filter(
            'İlişki türü',
            _relationshipType,
            const ['linked_to', 'assigned_to_task', 'appears_in_evidence'],
            caseRelationshipTypeLabel,
            (value) => setState(() => _relationshipType = value ?? ''),
          ),
          _filter(
            'Durum',
            _relationshipStatus,
            const [
              'observed',
              'under_review',
              'confirmed',
              'disputed',
              'inactive',
            ],
            caseRelationshipStatusLabel,
            (value) => setState(() => _relationshipStatus = value ?? ''),
          ),
          _filter(
            'Güven',
            _confidence,
            const ['low', 'medium', 'high', 'confirmed'],
            caseConfidenceLabel,
            (value) => setState(() => _confidence = value ?? ''),
          ),
        ],
      ),
      Expanded(
        child: _relationships.isEmpty
            ? const Center(child: Text('Henüz ilişki kaydı bulunmuyor.'))
            : ListView(
                children: _relationships
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(
                            '${_string(item, 'sourceLabel')} '
                            '${caseRelationshipTypeLabel(_string(item, 'relationshipType'))} '
                            '${_string(item, 'targetLabel')}',
                          ),
                          subtitle: Text(
                            '${_string(item, 'relationshipNumber')} · '
                            '${caseRelationshipStatusLabel(_string(item, 'status'))} · '
                            '${caseConfidenceLabel(_string(item, 'confidence'))}\n'
                            '${_string(item, 'summary')}\n'
                            'Son hareket: ${caseLocalDateTime(item['lastEventAt'])}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    ],
  );

  Widget _timelineEntry() {
    final selected = _caseId.isNotEmpty
        ? _caseId
        : (_cases.isEmpty ? '' : _string(_cases.first, 'caseId'));
    return Center(
      child: FilledButton.icon(
        key: const ValueKey('open-unified-timeline'),
        onPressed: selected.isEmpty
            ? null
            : () => widget.timelineOpener != null
                  ? widget.timelineOpener!(context, selected)
                  : AppRouter.openCaseUnifiedTimeline(
                      context,
                      caseId: selected,
                    ),
        icon: const Icon(Icons.timeline),
        label: const Text('Birleşik zaman çizelgesini aç'),
      ),
    );
  }

  Future<void> _showCreateParty() async {
    if (_cases.isEmpty) return;
    final name = TextEditingController();
    final publicAlias = TextEditingController();
    final organizationName = TextEditingController();
    final countryCode = TextEditingController();
    final city = TextEditingController();
    final description = TextEditingController();
    var selectedCase = _caseId.isEmpty
        ? _string(_cases.first, 'caseId')
        : _caseId;
    var partyType = 'person';
    final caseRoles = <String>[];
    final requestId = _uuid();
    var submitting = false;
    String? message;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Taraf ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCase,
                  decoration: const InputDecoration(labelText: 'Bağlı vaka'),
                  items: _cases
                      .map(
                        (item) => DropdownMenuItem(
                          value: _string(item, 'caseId'),
                          child: Text(_string(item, 'caseNumber')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => selectedCase = value ?? selectedCase,
                ),
                TextField(
                  key: const ValueKey('party-name'),
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Taraf adı'),
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('party-type'),
                  initialValue: partyType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Taraf türü'),
                  items: _partyTypes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(casePartyTypeLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (value) => setDialogState(
                          () => partyType = value ?? partyType,
                        ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Vaka rolleri (1–5)'),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _partyRoles
                      .map(
                        (role) => FilterChip(
                          key: ValueKey('party-role-$role'),
                          label: Text(casePartyRoleLabel(role)),
                          selected: caseRoles.contains(role),
                          onSelected:
                              submitting ||
                                  (!caseRoles.contains(role) &&
                                      caseRoles.length >= 5)
                              ? null
                              : (selected) => setDialogState(() {
                                  if (selected) {
                                    if (!caseRoles.contains(role)) {
                                      caseRoles.add(role);
                                    }
                                  } else {
                                    caseRoles.remove(role);
                                  }
                                }),
                        ),
                      )
                      .toList(),
                ),
                TextField(
                  key: const ValueKey('party-public-alias'),
                  controller: publicAlias,
                  decoration: const InputDecoration(
                    labelText: 'Kamuya açık ad veya kullanıcı adı',
                  ),
                ),
                TextField(
                  key: const ValueKey('party-organization'),
                  controller: organizationName,
                  decoration: const InputDecoration(labelText: 'Kuruluş'),
                ),
                TextField(
                  key: const ValueKey('party-country-code'),
                  controller: countryCode,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ülke kodu',
                    hintText: 'TR',
                  ),
                ),
                TextField(
                  key: const ValueKey('party-city'),
                  controller: city,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                ),
                TextField(
                  key: const ValueKey('party-description'),
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                if (message != null) Text(message!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const ValueKey('submit-party'),
              onPressed: submitting
                  ? null
                  : () async {
                      if (submitting) return;
                      final normalizedCountry = countryCode.text
                          .trim()
                          .toUpperCase();
                      if (name.text.trim().length < 3 ||
                          description.text.trim().length < 10 ||
                          caseRoles.isEmpty) {
                        setDialogState(
                          () => message =
                              'Taraf adı, açıklama ve en az bir vaka rolü zorunludur.',
                        );
                        return;
                      }
                      if (normalizedCountry.isNotEmpty &&
                          !RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCountry)) {
                        setDialogState(
                          () => message =
                              'Ülke kodu iki harften oluşmalıdır (ör. TR).',
                        );
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        message = null;
                      });
                      final request = <String, dynamic>{
                        'contractVersion': 'case-party-create-request-v1',
                        'caseId': selectedCase,
                        'displayName': name.text.trim(),
                        'partyType': partyType,
                        'caseRoles': List<String>.of(caseRoles),
                        if (publicAlias.text.trim().isNotEmpty)
                          'publicAlias': publicAlias.text.trim(),
                        if (organizationName.text.trim().isNotEmpty)
                          'organizationName': organizationName.text.trim(),
                        if (normalizedCountry.isNotEmpty)
                          'countryCode': normalizedCountry,
                        if (city.text.trim().isNotEmpty)
                          'city': city.text.trim(),
                        'description': description.text.trim(),
                        'requestId': requestId,
                      };
                      Map<String, dynamic> result;
                      try {
                        result = await _repository.createParty(request);
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          submitting = false;
                          message =
                              'İşlem sonucu doğrulanamadı. Aynı istekle yeniden deneyin.';
                        });
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      final duplicate = result['duplicate'] == true;
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      if (duplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bu işlem daha önce kaydedildi.'),
                          ),
                        );
                      }
                      final partyId = _string(result, 'partyId');
                      if (widget.partyDetailOpener != null) {
                        await widget.partyDetailOpener!(context, partyId);
                      } else {
                        await AppRouter.openCasePartyDetail(
                          context,
                          partyId: partyId,
                        );
                      }
                    },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    await _load();
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final Map<String, dynamic> stats;
  @override
  Widget build(BuildContext context) {
    const values = {
      'totalParties': 'Toplam Taraf',
      'observedParties': 'Gözlemlenen',
      'underReviewParties': 'İncelenen',
      'verifiedParties': 'Doğrulanan',
      'disputedParties': 'İhtilaflı',
      'activeRelationships': 'Aktif İlişki',
    };
    return Wrap(
      children: values.entries
          .map(
            (item) => Padding(
              padding: const EdgeInsets.all(8),
              child: Chip(
                label: Text('${item.value}: ${stats[item.key] ?? 0}'),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CaseFilter extends StatelessWidget {
  const _CaseFilter({
    required this.cases,
    required this.value,
    required this.changed,
  });
  final List<Map<String, dynamic>> cases;
  final String value;
  final ValueChanged<String?> changed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Vaka filtresi'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tüm Vakalar')),
        ...cases.map(
          (item) => DropdownMenuItem(
            value: _string(item, 'caseId'),
            child: Text(
              '${_string(item, 'caseNumber')} · ${_string(item, 'caseTitle')}',
            ),
          ),
        ),
      ],
      onChanged: changed,
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(spacing: 12, runSpacing: 8, children: children),
  );
}

Widget _filter(
  String label,
  String value,
  List<String> values,
  String Function(String) labeler,
  ValueChanged<String?> changed,
) => SizedBox(
  width: 210,
  child: DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tümü')),
      ...values.map(
        (item) => DropdownMenuItem(value: item, child: Text(labeler(item))),
      ),
    ],
    onChanged: changed,
  ),
);

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.retry});
  final String error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error == 'permission-denied'
              ? 'Bu çalışma alanını görüntüleme yetkiniz bulunmuyor.'
              : error == 'not-found'
              ? 'Vaka bağlantısı kaydı bulunamadı.'
              : 'Çalışma alanı yüklenemedi.',
        ),
        TextButton(onPressed: retry, child: const Text('Yeniden dene')),
      ],
    ),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Geçersiz yanıt.');
}

Object? _normalize(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _normalize(item)));
  }
  if (value is Iterable && value is! String) {
    return value.map(_normalize).toList();
  }
  return value;
}

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
