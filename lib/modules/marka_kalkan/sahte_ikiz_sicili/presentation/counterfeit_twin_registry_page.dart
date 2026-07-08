import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/counterfeit_twin_enums.dart';
import '../models/counterfeit_twin_model.dart';
import '../repositories/counterfeit_twin_repository.dart';
import 'counterfeit_twin_create_dialog.dart';
import 'counterfeit_twin_detail_edit_dialog.dart';

class CounterfeitTwinRegistryPage extends StatefulWidget {
  const CounterfeitTwinRegistryPage({super.key});

  @override
  State<CounterfeitTwinRegistryPage> createState() =>
      _CounterfeitTwinRegistryPageState();
}

class _CounterfeitTwinRegistryPageState
    extends State<CounterfeitTwinRegistryPage> {
  CounterfeitTwinStatus? _statusFilter;
  CounterfeitTwinRiskLevel? _riskFilter;
  CounterfeitTwinReviewStatus? _reviewFilter;
  CounterfeitTwinCloneMethod? _cloneMethodFilter;

  bool get _hasActiveFilter =>
      _statusFilter != null ||
      _riskFilter != null ||
      _reviewFilter != null ||
      _cloneMethodFilter != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _riskFilter = null;
      _reviewFilter = null;
      _cloneMethodFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutPage();
    }

    final repository = CounterfeitTwinRepository.instance(tenantId: user.uid);

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Sahte İkiz Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCounterfeitTwinCreateDialog(
          context: context,
          user: user,
          repository: repository,
        ),
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Yeni Sahte İkiz Kaydı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<CounterfeitTwinModel>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Sahte ikiz kayıtları yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? const <CounterfeitTwinModel>[];
          final active = records
              .where((item) => !item.isArchived)
              .toList(growable: false);
          final filtered = active
              .where(_matchesFilters)
              .toList(growable: false);

          final confirmed = active.where((item) => item.isConfirmed).length;
          final highRisk = active.where((item) => item.isHighRisk).length;
          final waveLinked = active.where((item) => item.hasWaveLink).length;
          final digitalEvidence = active
              .where((item) => item.hasDigitalEvidence)
              .length;
          final archived = records.length - active.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      active: active.length,
                      confirmed: confirmed,
                      highRisk: highRisk,
                      waveLinked: waveLinked,
                      digitalEvidence: digitalEvidence,
                      archived: archived,
                    ),
                    const SizedBox(height: 18),
                    _FilterPanel(
                      status: _statusFilter,
                      risk: _riskFilter,
                      review: _reviewFilter,
                      cloneMethod: _cloneMethodFilter,
                      hasActiveFilter: _hasActiveFilter,
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onRiskChanged: (value) =>
                          setState(() => _riskFilter = value),
                      onReviewChanged: (value) =>
                          setState(() => _reviewFilter = value),
                      onCloneMethodChanged: (value) =>
                          setState(() => _cloneMethodFilter = value),
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 18),
                    if (active.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.content_copy_outlined,
                        title: 'Henüz sahte ikiz kaydı yok',
                        description:
                            'Şüpheli marka, ürün, satıcı, mağaza, ilan ve '
                            'kanıt bağlantıları oluşturulduğunda burada '
                            'kalıcı bir savunma dosyası olarak görüntülenecek.',
                      )
                    else if (filtered.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Filtrelerle eşleşen kayıt yok',
                        description:
                            'Filtreleri temizleyerek aktif kayıtların '
                            'tamamını görüntüleyebilirsiniz.',
                      )
                    else ...[
                      Text(
                        '${filtered.length} kayıt gösteriliyor',
                        style: const TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...filtered.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _RecordCard(
                            record: record,
                            onTap: () => showCounterfeitTwinDetailEditDialog(
                              context: context,
                              user: user,
                              repository: repository,
                              record: record,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(CounterfeitTwinModel record) {
    if (_statusFilter != null && record.status != _statusFilter) {
      return false;
    }
    if (_riskFilter != null && record.riskLevel != _riskFilter) {
      return false;
    }
    if (_reviewFilter != null && record.reviewStatus != _reviewFilter) {
      return false;
    }
    if (_cloneMethodFilter != null &&
        record.primaryCloneMethod != _cloneMethodFilter) {
      return false;
    }
    return true;
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.active,
    required this.confirmed,
    required this.highRisk,
    required this.waveLinked,
    required this.digitalEvidence,
    required this.archived,
  });

  final int active;
  final int confirmed;
  final int highRisk;
  final int waveLinked;
  final int digitalEvidence;
  final int archived;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Aktif kayıt', value: '$active'),
        _MetricCard(label: 'Teyitli sahte ikiz', value: '$confirmed'),
        _MetricCard(label: 'Yüksek / kritik risk', value: '$highRisk'),
        _MetricCard(label: 'Dalga / aile bağlantılı', value: '$waveLinked'),
        _MetricCard(label: 'Dijital kanıtlı', value: '$digitalEvidence'),
        _MetricCard(label: 'Arşivlenen', value: '$archived'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 184,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.status,
    required this.risk,
    required this.review,
    required this.cloneMethod,
    required this.hasActiveFilter,
    required this.onStatusChanged,
    required this.onRiskChanged,
    required this.onReviewChanged,
    required this.onCloneMethodChanged,
    required this.onClear,
  });

  final CounterfeitTwinStatus? status;
  final CounterfeitTwinRiskLevel? risk;
  final CounterfeitTwinReviewStatus? review;
  final CounterfeitTwinCloneMethod? cloneMethod;
  final bool hasActiveFilter;
  final ValueChanged<CounterfeitTwinStatus?> onStatusChanged;
  final ValueChanged<CounterfeitTwinRiskLevel?> onRiskChanged;
  final ValueChanged<CounterfeitTwinReviewStatus?> onReviewChanged;
  final ValueChanged<CounterfeitTwinCloneMethod?> onCloneMethodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = <Widget>[
            DropdownButtonFormField<CounterfeitTwinStatus>(
              key: ValueKey('status-${status?.value ?? 'all'}'),
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: CounterfeitTwinStatus.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: onStatusChanged,
            ),
            DropdownButtonFormField<CounterfeitTwinRiskLevel>(
              key: ValueKey('risk-${risk?.value ?? 'all'}'),
              initialValue: risk,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Risk'),
              items: CounterfeitTwinRiskLevel.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: onRiskChanged,
            ),
            DropdownButtonFormField<CounterfeitTwinReviewStatus>(
              key: ValueKey('review-${review?.value ?? 'all'}'),
              initialValue: review,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'İnceleme'),
              items: CounterfeitTwinReviewStatus.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: onReviewChanged,
            ),
            DropdownButtonFormField<CounterfeitTwinCloneMethod>(
              key: ValueKey('method-${cloneMethod?.value ?? 'all'}'),
              initialValue: cloneMethod,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ana klon yöntemi'),
              items: CounterfeitTwinCloneMethod.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: onCloneMethodChanged,
            ),
          ];

          final clearButton = OutlinedButton.icon(
            onPressed: hasActiveFilter ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Filtreleri Temizle'),
          );

          if (constraints.maxWidth < 920) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields) ...[
                  field,
                  const SizedBox(height: 12),
                ],
                clearButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final field in fields) ...[
                Expanded(child: field),
                const SizedBox(width: 12),
              ],
              clearButton,
            ],
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final CounterfeitTwinModel record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final danger = record.isHighRisk || record.isConfirmed;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: danger ? const Color(0xFFF0B7B3) : const Color(0xFFE0E7EC),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: danger
                    ? const Color(0xFFFFE9E7)
                    : const Color(0xFFE8F6F4),
                foregroundColor: danger
                    ? const Color(0xFFB42318)
                    : MarkaKalkanTheme.teal,
                child: const Icon(Icons.content_copy_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${record.recordCode} · '
                      '${record.primaryCloneMethod.label}',
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _identityLine(record),
                      style: const TextStyle(
                        color: Color(0xFF4D6470),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: record.status.label),
                        _Badge(label: 'Risk: ${record.riskLevel.label}'),
                        _Badge(label: 'İnceleme: ${record.reviewStatus.label}'),
                        _Badge(
                          label:
                              'Genel benzerlik: %${record.overallSimilarityScore}',
                          foreground: danger
                              ? const Color(0xFFB42318)
                              : MarkaKalkanTheme.teal,
                        ),
                        if (record.cloneFamilyId != null)
                          _Badge(label: 'Klon ailesi: ${record.cloneFamilyId}'),
                        if (record.waveId != null)
                          _Badge(label: 'Dalga: ${record.waveId}'),
                        if (record.recurrenceCount > 0)
                          _Badge(
                            label: 'Tekrar: ${record.recurrenceCount}',
                            foreground: const Color(0xFFB54708),
                          ),
                        _Badge(label: 'İlan: ${record.listingIds.length}'),
                        _Badge(label: 'Satıcı: ${record.sellerIds.length}'),
                        _Badge(label: 'Mağaza: ${record.storeIds.length}'),
                        _Badge(
                          label: 'Sayfa: ${record.monitoredPageIds.length}',
                        ),
                        _Badge(
                          label: 'Kanıt: ${record.evidencePackageIds.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: MarkaKalkanTheme.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _identityLine(CounterfeitTwinModel record) {
    final original =
        record.originalProductName ??
        record.originalBrandName ??
        'Orijinal ürün bağlantısı yok';
    final suspected =
        record.suspectedProductName ??
        record.suspectedBrandName ??
        'Şüpheli ürün adı yok';
    return '$original → $suspected';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.foreground = const Color(0xFF4D6470),
  });

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RegistryMessage extends StatelessWidget {
  const _RegistryMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOutPage extends StatelessWidget {
  const _SignedOutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(title: const Text('Sahte İkiz Sicili')),
      body: const _RegistryMessage(
        icon: Icons.lock_outline,
        title: 'Oturum gerekli',
        description: 'Bu sicili görüntülemek için marka hesabıyla giriş yapın.',
      ),
    );
  }
}
