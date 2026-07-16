import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/app/router.dart';

import '../data/traceability_models.dart';
import '../data/traceability_service.dart';

class TraceabilityCasesPage extends StatefulWidget {
  const TraceabilityCasesPage({super.key});

  @override
  State<TraceabilityCasesPage> createState() => _TraceabilityCasesPageState();
}

class _TraceabilityCasesPageState extends State<TraceabilityCasesPage> {
  final TraceabilityService _service = TraceabilityService();

  List<TraceabilityCaseSummary> _items = const <TraceabilityCaseSummary>[];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.listCases(status: _statusFilter);
      if (!mounted) return;
      setState(() => _items = items);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _error = _functionMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Vaka dosyaları yüklenemedi: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _functionMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Vaka dosyalarını görüntülemek için oturum açmalısınız.';
      case 'permission-denied':
        return 'Vaka dosyalarını görüntüleme yetkiniz bulunmuyor.';
      case 'invalid-argument':
        return error.message ?? 'Filtre bilgilerini kontrol edin.';
      default:
        return error.message ?? 'Vaka dosyaları yüklenemedi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _items.where((item) => item.status == 'open').length;
    final critical = _items
        .where((item) => item.riskLevel == 'critical')
        .length;
    final resolved = _items
        .where((item) => <String>{'resolved', 'closed'}.contains(item.status))
        .length;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Vaka Dosyaları',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _CaseHero(),
            const SizedBox(height: 20),
            _CaseKpis(
              total: _items.length,
              open: openCount,
              critical: critical,
              resolved: resolved,
            ),
            const SizedBox(height: 20),
            _StatusFilter(
              value: _statusFilter,
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _load();
              },
              onClear: () {
                setState(() => _statusFilter = null);
                _load();
              },
            ),
            const SizedBox(height: 20),
            if (_loading)
              const _CaseStatePanel(
                icon: Icons.folder_open_outlined,
                title: 'Vaka dosyaları yükleniyor',
                message: 'İzlenebilirlik vakaları hazırlanıyor.',
                loading: true,
              )
            else if (_error != null)
              _CaseStatePanel(
                icon: Icons.error_outline,
                title: 'Vaka dosyaları yüklenemedi',
                message: _error!,
                actionLabel: 'Yeniden dene',
                onAction: _load,
              )
            else if (_items.isEmpty)
              _CaseStatePanel(
                icon: Icons.create_new_folder_outlined,
                title: 'Vaka dosyası bulunmuyor',
                message:
                    'Şüpheli Taramalar ekranından riskli bir taramayı '
                    'vaka dosyasına taşıyabilirsiniz.',
                actionLabel: 'Şüpheli Taramalara Git',
                onAction: () =>
                    AppRouter.openSuspiciousVerificationScans(context),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CaseCard(item: item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item});

  final TraceabilityCaseSummary item;

  @override
  Widget build(BuildContext context) {
    final riskColor = _caseRiskColor(item.riskLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E2E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.caseCode.isEmpty ? item.id : item.caseCode,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _CaseTag(
                label: _caseStatusLabel(item.status),
                color: const Color(0xFF176B87),
              ),
              _CaseTag(
                label:
                    '${_caseRiskLabel(item.riskLevel)} · ${item.riskScore}/100',
                color: riskColor,
              ),
              _CaseTag(
                label: _priorityLabel(item.priority),
                color: const Color(0xFF6B4EFF),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.title.isEmpty ? 'İzlenebilirlik vakası' : item.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.summary,
              style: const TextStyle(color: Color(0xFF526574), height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MiniInfo(
                icon: Icons.qr_code_2_outlined,
                text: '${item.publicCodes.length} ürün kodu',
              ),
              _MiniInfo(
                icon: Icons.warning_amber_outlined,
                text: '${item.scanIds.length} şüpheli tarama',
              ),
              _MiniInfo(
                icon: Icons.inventory_2_outlined,
                text: '${item.productIds.length} ürün',
              ),
              _MiniInfo(
                icon: Icons.factory_outlined,
                text: '${item.batchIds.length} parti',
              ),
            ],
          ),
          if (item.riskReasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.riskReasons
                  .map(
                    (reason) => Chip(
                      label: Text(_caseReasonLabel(reason)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (item.updatedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Son güncelleme: ${_caseFormatDate(item.updatedAt!)}',
              style: const TextStyle(color: Color(0xFF8A98A4), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaseHero extends StatelessWidget {
  const _CaseHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.folder_copy_outlined,
            color: MarkaKalkanTheme.teal,
            size: 44,
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İzlenebilirlik vaka merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Şüpheli ürün doğrulama taramalarını; ürün, parti, tekil '
                  'kod ve risk nedenleriyle kalıcı vaka dosyalarında yönetin.',
                  style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseKpis extends StatelessWidget {
  const _CaseKpis({
    required this.total,
    required this.open,
    required this.critical,
    required this.resolved,
  });

  final int total;
  final int open;
  final int critical;
  final int resolved;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData)>[
      ('Toplam vaka', total, Icons.folder_copy_outlined),
      ('Açık vaka', open, Icons.folder_open_outlined),
      ('Kritik risk', critical, Icons.gpp_bad_outlined),
      ('Çözümlenen', resolved, Icons.task_alt_outlined),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth < 680 ? 2 : 4;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (entry) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFD8E2E7)),
                    ),
                    child: Row(
                      children: [
                        Icon(entry.$3, color: MarkaKalkanTheme.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.$2}',
                                style: const TextStyle(
                                  color: MarkaKalkanTheme.navy,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                entry.$1,
                                style: const TextStyle(
                                  color: Color(0xFF667785),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E2E7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: const InputDecoration(labelText: 'Vaka durumu'),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Açık')),
                DropdownMenuItem(
                  value: 'under_review',
                  child: Text('İncelemede'),
                ),
                DropdownMenuItem(value: 'confirmed', child: Text('Doğrulandı')),
                DropdownMenuItem(
                  value: 'false_positive',
                  child: Text('Yanlış alarm'),
                ),
                DropdownMenuItem(
                  value: 'action_required',
                  child: Text('Aksiyon gerekli'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Çözümlendi')),
                DropdownMenuItem(value: 'closed', child: Text('Kapatıldı')),
                DropdownMenuItem(value: 'archived', child: Text('Arşivlendi')),
              ],
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: MarkaKalkanTheme.teal),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF667785),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CaseTag extends StatelessWidget {
  const _CaseTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CaseStatePanel extends StatelessWidget {
  const _CaseStatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E2E7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: MarkaKalkanTheme.teal, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667785), height: 1.5),
          ),
          if (loading) ...[
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Color _caseRiskColor(String value) {
  switch (value) {
    case 'critical':
      return const Color(0xFFB42318);
    case 'high':
      return const Color(0xFFD65A1F);
    case 'medium':
      return const Color(0xFFB7791F);
    default:
      return const Color(0xFF176B87);
  }
}

String _caseRiskLabel(String value) {
  switch (value) {
    case 'critical':
      return 'Kritik';
    case 'high':
      return 'Yüksek';
    case 'medium':
      return 'Orta';
    case 'low':
      return 'Düşük';
    default:
      return 'Risk yok';
  }
}

String _caseStatusLabel(String value) {
  switch (value) {
    case 'under_review':
      return 'İncelemede';
    case 'confirmed':
      return 'Doğrulandı';
    case 'false_positive':
      return 'Yanlış alarm';
    case 'action_required':
      return 'Aksiyon gerekli';
    case 'resolved':
      return 'Çözümlendi';
    case 'closed':
      return 'Kapatıldı';
    case 'archived':
      return 'Arşivlendi';
    default:
      return 'Açık';
  }
}

String _priorityLabel(String value) {
  switch (value) {
    case 'critical':
      return 'Kritik öncelik';
    case 'high':
      return 'Yüksek öncelik';
    case 'normal':
      return 'Normal öncelik';
    default:
      return 'Düşük öncelik';
  }
}

String _caseReasonLabel(String value) {
  const labels = <String, String>{
    'unknown_code': 'Bilinmeyen ürün kodu',
    'revoked_code': 'İptal edilmiş kod',
    'blocked_code': 'Engellenmiş kod',
    'inactive_code': 'Aktif olmayan kod',
    'scan_volume_critical': 'Kritik tarama yoğunluğu',
    'scan_volume_high': 'Yüksek tarama yoğunluğu',
    'repeated_scan': 'Tekrarlanan tarama',
    'repeat_scan_observed': 'Yeniden tarama',
    'rapid_repeat_scan': 'Kısa sürede tekrar',
    'platform_changed': 'Platform değişimi',
    'scan_source_changed': 'Tarama yöntemi değişimi',
  };
  return labels[value] ?? value;
}

String _caseFormatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
