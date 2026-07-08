import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../models/ip_creation_priority_record_model.dart';
import '../repositories/ip_creation_priority_repository.dart';
import 'ip_creation_priority_create_dialog.dart';
import 'ip_creation_priority_detail_page.dart';

class IpCreationPriorityRegistryPage extends StatefulWidget {
  const IpCreationPriorityRegistryPage({super.key});

  @override
  State<IpCreationPriorityRegistryPage> createState() =>
      _IpCreationPriorityRegistryPageState();
}

class _IpCreationPriorityRegistryPageState
    extends State<IpCreationPriorityRegistryPage> {
  IpCreationType? _creationTypeFilter;
  IpCreationPriorityStatus? _statusFilter;
  IpCreationConfidentialityLevel? _confidentialityFilter;
  IpCreationSealStatus? _sealFilter;

  bool get _hasActiveFilter =>
      _creationTypeFilter != null ||
      _statusFilter != null ||
      _confidentialityFilter != null ||
      _sealFilter != null;

  void _clearFilters() {
    setState(() {
      _creationTypeFilter = null;
      _statusFilter = null;
      _confidentialityFilter = null;
      _sealFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutPage();
    }

    final repository = IpCreationPriorityRepository.instance(
      tenantId: user.uid,
    );

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Yaratım Öncelik Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showIpCreationPriorityCreateDialog(
            context: context,
            user: user,
            repository: repository,
          );

          if (created && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Yaratım öncelik taslağı başarıyla oluşturuldu.'),
              ),
            );
          }
        },
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Yeni Kayıt',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<IpCreationPriorityRecordModel>>(
        stream: repository.watchRecords(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Yaratım öncelik kayıtları yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records =
              snapshot.data ?? const <IpCreationPriorityRecordModel>[];
          final filtered = records
              .where(_matchesFilters)
              .toList(growable: false);

          final sealed = records.where((item) => item.isSealed).length;
          final drafts = records
              .where((item) => item.status == IpCreationPriorityStatus.draft)
              .length;
          final developing = records
              .where(
                (item) => item.status == IpCreationPriorityStatus.developing,
              )
              .length;
          final patentWarnings = records
              .where((item) => item.patentDisclosureWarningRequired)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LegalNotice(),
                    const SizedBox(height: 18),
                    _SummaryStrip(
                      total: records.length,
                      sealed: sealed,
                      drafts: drafts,
                      developing: developing,
                      patentWarnings: patentWarnings,
                    ),
                    const SizedBox(height: 18),
                    _FilterPanel(
                      creationType: _creationTypeFilter,
                      status: _statusFilter,
                      confidentiality: _confidentialityFilter,
                      sealStatus: _sealFilter,
                      hasActiveFilter: _hasActiveFilter,
                      onCreationTypeChanged: (value) =>
                          setState(() => _creationTypeFilter = value),
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onConfidentialityChanged: (value) =>
                          setState(() => _confidentialityFilter = value),
                      onSealStatusChanged: (value) =>
                          setState(() => _sealFilter = value),
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 18),
                    if (records.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.lightbulb_outline,
                        title: 'Henüz yaratım öncelik kaydı yok',
                        description:
                            'Fikir, buluş, eser, tasarım, yazılım veya '
                            'araştırmanızın sizde ne zaman ve hangi içerikle '
                            'bulunduğunu belgeleyen ilk kaydı oluşturun.',
                      )
                    else if (filtered.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Filtrelerle eşleşen kayıt yok',
                        description:
                            'Filtreleri temizleyerek kayıtların tamamını '
                            'görüntüleyebilirsiniz.',
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
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => IpCreationPriorityDetailPage(
                                    recordId: record.id,
                                    repository: repository,
                                  ),
                                ),
                              );
                            },
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

  bool _matchesFilters(IpCreationPriorityRecordModel record) {
    if (_creationTypeFilter != null &&
        record.creationType != _creationTypeFilter) {
      return false;
    }
    if (_statusFilter != null && record.status != _statusFilter) {
      return false;
    }
    if (_confidentialityFilter != null &&
        record.confidentialityLevel != _confidentialityFilter) {
      return false;
    }
    if (_sealFilter != null && record.sealStatus != _sealFilter) {
      return false;
    }
    return true;
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7EA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“Bu fikir benim. Bu eser benim. Bu buluş benim.”',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Fikrinizi tescil etmez; fikrinizin ne zaman, hangi içerikle '
            'sizde bulunduğunu güçlü biçimde belgeler.',
            style: TextStyle(
              color: Color(0xFF425B66),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.sealed,
    required this.drafts,
    required this.developing,
    required this.patentWarnings,
  });

  final int total;
  final int sealed;
  final int drafts;
  final int developing;
  final int patentWarnings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Toplam kayıt', value: '$total'),
        _MetricCard(label: 'Mühürlü', value: '$sealed'),
        _MetricCard(label: 'Taslak', value: '$drafts'),
        _MetricCard(label: 'Geliştiriliyor', value: '$developing'),
        _MetricCard(label: 'Patent uyarısı', value: '$patentWarnings'),
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
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607982),
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
    required this.creationType,
    required this.status,
    required this.confidentiality,
    required this.sealStatus,
    required this.hasActiveFilter,
    required this.onCreationTypeChanged,
    required this.onStatusChanged,
    required this.onConfidentialityChanged,
    required this.onSealStatusChanged,
    required this.onClear,
  });

  final IpCreationType? creationType;
  final IpCreationPriorityStatus? status;
  final IpCreationConfidentialityLevel? confidentiality;
  final IpCreationSealStatus? sealStatus;
  final bool hasActiveFilter;
  final ValueChanged<IpCreationType?> onCreationTypeChanged;
  final ValueChanged<IpCreationPriorityStatus?> onStatusChanged;
  final ValueChanged<IpCreationConfidentialityLevel?> onConfidentialityChanged;
  final ValueChanged<IpCreationSealStatus?> onSealStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7EA)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _EnumDropdown<IpCreationType>(
            label: 'Yaratım türü',
            value: creationType,
            values: IpCreationType.values,
            itemLabel: (item) => item.label,
            onChanged: onCreationTypeChanged,
          ),
          _EnumDropdown<IpCreationPriorityStatus>(
            label: 'Durum',
            value: status,
            values: IpCreationPriorityStatus.values,
            itemLabel: (item) => item.label,
            onChanged: onStatusChanged,
          ),
          _EnumDropdown<IpCreationConfidentialityLevel>(
            label: 'Gizlilik',
            value: confidentiality,
            values: IpCreationConfidentialityLevel.values,
            itemLabel: (item) => item.label,
            onChanged: onConfidentialityChanged,
          ),
          _EnumDropdown<IpCreationSealStatus>(
            label: 'Mühür',
            value: sealStatus,
            values: IpCreationSealStatus.values,
            itemLabel: (item) => item.label,
            onChanged: onSealStatusChanged,
          ),
          TextButton.icon(
            onPressed: hasActiveFilter ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Filtreleri temizle'),
          ),
        ],
      ),
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: values
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final IpCreationPriorityRecordModel record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE7EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _Chip(label: record.creationType.label),
                _Chip(label: record.status.label),
                _Chip(label: record.sealStatus.label),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${record.recordCode} • Sürüm ${record.currentVersion}',
              style: const TextStyle(
                color: Color(0xFF607982),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (record.summary?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(
                record.summary!.trim(),
                style: const TextStyle(color: Color(0xFF425B66), height: 1.45),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _InfoLine(
                  icon: Icons.lock_outline,
                  text: record.confidentialityLevel.label,
                ),
                _InfoLine(
                  icon: Icons.calendar_today_outlined,
                  text: _formatDate(record.createdAt),
                ),
                if (record.creatorName?.trim().isNotEmpty ?? false)
                  _InfoLine(
                    icon: Icons.person_outline,
                    text: record.creatorName!.trim(),
                  ),
              ],
            ),
            if (record.patentDisclosureWarningRequired) ...[
              const SizedBox(height: 12),
              const _PatentWarning(),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MarkaKalkanTheme.teal,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF607982)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF607982),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PatentWarning extends StatelessWidget {
  const _PatentWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD28A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5A00)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Patent veya faydalı model adayı için kamuya açıklama, '
              'yenilik değerlendirmesini etkileyebilir.',
              style: TextStyle(
                color: Color(0xFF7A4B00),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: MarkaKalkanTheme.teal),
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
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF607982), height: 1.5),
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
    return const Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      body: _RegistryMessage(
        icon: Icons.lock_outline,
        title: 'Oturum gerekli',
        description:
            'Yaratım Öncelik Sicili kayıtlarını görüntülemek için marka '
            'hesabınızla oturum açın.',
      ),
    );
  }
}
