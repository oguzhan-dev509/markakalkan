import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../data/traceability_models.dart';
import '../data/traceability_service.dart';

class SuspiciousVerificationScansPage extends StatefulWidget {
  const SuspiciousVerificationScansPage({super.key});

  @override
  State<SuspiciousVerificationScansPage> createState() =>
      _SuspiciousVerificationScansPageState();
}

class _SuspiciousVerificationScansPageState
    extends State<SuspiciousVerificationScansPage> {
  final TraceabilityService _service = TraceabilityService();

  List<SuspiciousVerificationScan> _items =
      const <SuspiciousVerificationScan>[];
  bool _loading = true;
  String? _error;
  String? _reviewFilter;
  String? _riskFilter;
  String? _busyScanId;

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
      final items = await _service.listSuspiciousScans(
        reviewStatus: _reviewFilter,
        riskLevel: _riskFilter,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _error = _functionMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Şüpheli taramalar yüklenemedi: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(SuspiciousVerificationScan scan) async {
    final input = await showDialog<_ReviewInput>(
      context: context,
      builder: (_) => _ReviewScanDialog(scan: scan),
    );
    if (input == null || !mounted) return;

    setState(() => _busyScanId = scan.id);
    try {
      await _service.reviewScan(
        scanId: scan.id,
        reviewStatus: input.status,
        reviewNotes: input.notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarama inceleme sonucu kaydedildi.')),
      );
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_functionMessage(error))));
    } finally {
      if (mounted) setState(() => _busyScanId = null);
    }
  }

  Future<void> _createCase(SuspiciousVerificationScan scan) async {
    final input = await showDialog<_CaseInput>(
      context: context,
      builder: (_) => _CreateCaseDialog(scan: scan),
    );
    if (input == null || !mounted) return;

    setState(() => _busyScanId = scan.id);
    try {
      final created = await _service.createCaseFromScan(
        scanId: scan.id,
        title: input.title,
        summary: input.summary,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vaka dosyası açıldı: ${created.caseCode.isEmpty ? created.id : created.caseCode}',
          ),
        ),
      );
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_functionMessage(error))));
    } finally {
      if (mounted) setState(() => _busyScanId = null);
    }
  }

  String _functionMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Şüpheli taramaları görüntülemek için oturum açmalısınız.';
      case 'permission-denied':
        return 'Bu kayıt için işlem yetkiniz bulunmuyor.';
      case 'failed-precondition':
        return error.message ?? 'Kayıt işleme uygun durumda değil.';
      case 'not-found':
        return error.message ?? 'Kayıt bulunamadı.';
      case 'invalid-argument':
        return error.message ?? 'Gönderilen bilgileri kontrol edin.';
      default:
        return error.message ?? 'İşlem tamamlanamadı.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final critical = _items
        .where((item) => item.riskLevel == 'critical')
        .length;
    final pending = _items
        .where((item) => item.reviewStatus == 'pending')
        .length;
    final escalated = _items.where((item) => item.caseId.isNotEmpty).length;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Şüpheli Taramalar',
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
            const _PageHero(
              icon: Icons.warning_amber_rounded,
              title: 'Ürün doğrulama risk merkezi',
              description:
                  'Tekrarlanan, hızlı, engellenmiş veya iptal edilmiş kod '
                  'taramalarını inceleyin; gerekli kayıtları doğrudan vaka '
                  'dosyasına taşıyın.',
            ),
            const SizedBox(height: 20),
            _KpiGrid(
              items: [
                _KpiItem(
                  label: 'Şüpheli tarama',
                  value: '${_items.length}',
                  icon: Icons.qr_code_scanner_outlined,
                ),
                _KpiItem(
                  label: 'Kritik risk',
                  value: '$critical',
                  icon: Icons.gpp_bad_outlined,
                ),
                _KpiItem(
                  label: 'İnceleme bekliyor',
                  value: '$pending',
                  icon: Icons.pending_actions_outlined,
                ),
                _KpiItem(
                  label: 'Vakaya taşındı',
                  value: '$escalated',
                  icon: Icons.folder_copy_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _FilterPanel(
              reviewValue: _reviewFilter,
              riskValue: _riskFilter,
              onReviewChanged: (value) {
                setState(() => _reviewFilter = value);
                _load();
              },
              onRiskChanged: (value) {
                setState(() => _riskFilter = value);
                _load();
              },
              onClear: () {
                setState(() {
                  _reviewFilter = null;
                  _riskFilter = null;
                });
                _load();
              },
            ),
            const SizedBox(height: 20),
            if (_loading)
              const _StatePanel(
                icon: Icons.hourglass_top_rounded,
                title: 'Şüpheli taramalar yükleniyor',
                message: 'Risk kayıtları güvenli biçimde hazırlanıyor.',
                loading: true,
              )
            else if (_error != null)
              _StatePanel(
                icon: Icons.error_outline,
                title: 'Şüpheli taramalar yüklenemedi',
                message: _error!,
                actionLabel: 'Yeniden dene',
                onAction: _load,
              )
            else if (_items.isEmpty)
              const _StatePanel(
                icon: Icons.verified_user_outlined,
                title: 'Şüpheli tarama bulunmuyor',
                message:
                    'Seçilen filtrelerde inceleme gerektiren bir doğrulama '
                    'taraması bulunmadı.',
              )
            else
              ..._items.map(
                (scan) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ScanCard(
                    scan: scan,
                    busy: _busyScanId == scan.id,
                    onReview: () => _review(scan),
                    onCreateCase: scan.caseId.isEmpty
                        ? () => _createCase(scan)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.scan,
    required this.busy,
    required this.onReview,
    required this.onCreateCase,
  });

  final SuspiciousVerificationScan scan;
  final bool busy;
  final VoidCallback onReview;
  final VoidCallback? onCreateCase;

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(scan.riskLevel);

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
                scan.publicCode.isEmpty ? 'Kod bilgisi yok' : scan.publicCode,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _Tag(
                label: '${_riskLabel(scan.riskLevel)} · ${scan.riskScore}/100',
                color: riskColor,
              ),
              _Tag(
                label: _reviewLabel(scan.reviewStatus),
                color: const Color(0xFF176B87),
              ),
              if (scan.caseId.isNotEmpty)
                const _Tag(
                  label: 'Vaka dosyasına bağlı',
                  color: Color(0xFF6B4EFF),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            scan.productName.isEmpty ? 'Ürün bilgisi yok' : scan.productName,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            [
              if (scan.brandName.isNotEmpty) scan.brandName,
              if (scan.batchNumber.isNotEmpty) 'Parti: ${scan.batchNumber}',
              if (scan.scanNumber > 0) 'Tarama: ${scan.scanNumber}',
              '${scan.platform.toUpperCase()} / ${scan.source.toUpperCase()}',
            ].join(' · '),
            style: const TextStyle(color: Color(0xFF667785), height: 1.4),
          ),
          if (scan.createdAt != null) ...[
            const SizedBox(height: 5),
            Text(
              _formatDate(scan.createdAt!),
              style: const TextStyle(color: Color(0xFF8A98A4), fontSize: 12),
            ),
          ],
          if (scan.riskReasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scan.riskReasons
                  .map(
                    (reason) => Chip(
                      avatar: const Icon(Icons.bolt_outlined, size: 16),
                      label: Text(_reasonLabel(reason)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (scan.reviewNotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                scan.reviewNotes,
                style: const TextStyle(color: Color(0xFF425466), height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onReview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('İncele'),
              ),
              if (onCreateCase != null)
                FilledButton.icon(
                  onPressed: busy ? null : onCreateCase,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Vaka Dosyası Aç'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.reviewValue,
    required this.riskValue,
    required this.onReviewChanged,
    required this.onRiskChanged,
    required this.onClear,
  });

  final String? reviewValue;
  final String? riskValue;
  final ValueChanged<String?> onReviewChanged;
  final ValueChanged<String?> onRiskChanged;
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
      child: LayoutBuilder(
        builder: (_, constraints) {
          final review = DropdownButtonFormField<String>(
            initialValue: reviewValue,
            decoration: const InputDecoration(labelText: 'İnceleme durumu'),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
              DropdownMenuItem(value: 'reviewed', child: Text('İncelendi')),
              DropdownMenuItem(value: 'dismissed', child: Text('Risk değil')),
              DropdownMenuItem(
                value: 'escalated',
                child: Text('Vakaya taşındı'),
              ),
            ],
            onChanged: onReviewChanged,
          );
          final risk = DropdownButtonFormField<String>(
            initialValue: riskValue,
            decoration: const InputDecoration(labelText: 'Risk seviyesi'),
            items: const [
              DropdownMenuItem(value: 'critical', child: Text('Kritik')),
              DropdownMenuItem(value: 'high', child: Text('Yüksek')),
              DropdownMenuItem(value: 'medium', child: Text('Orta')),
              DropdownMenuItem(value: 'low', child: Text('Düşük')),
            ],
            onChanged: onRiskChanged,
          );
          final clear = OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Filtreleri Temizle'),
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                review,
                const SizedBox(height: 12),
                risk,
                const SizedBox(height: 12),
                clear,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: review),
              const SizedBox(width: 12),
              Expanded(child: risk),
              const SizedBox(width: 12),
              clear,
            ],
          );
        },
      ),
    );
  }
}

class _ReviewScanDialog extends StatefulWidget {
  const _ReviewScanDialog({required this.scan});

  final SuspiciousVerificationScan scan;

  @override
  State<_ReviewScanDialog> createState() => _ReviewScanDialogState();
}

class _ReviewScanDialogState extends State<_ReviewScanDialog> {
  late String _status;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _status = widget.scan.reviewStatus == 'dismissed'
        ? 'dismissed'
        : 'reviewed';
    _notes = TextEditingController(text: widget.scan.reviewNotes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şüpheli Taramayı İncele'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'İnceleme sonucu'),
              items: const [
                DropdownMenuItem(value: 'reviewed', child: Text('İncelendi')),
                DropdownMenuItem(value: 'dismissed', child: Text('Risk değil')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'İnceleme notu',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_ReviewInput(status: _status, notes: _notes.text.trim())),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _CreateCaseDialog extends StatefulWidget {
  const _CreateCaseDialog({required this.scan});

  final SuspiciousVerificationScan scan;

  @override
  State<_CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<_CreateCaseDialog> {
  late final TextEditingController _title;
  final TextEditingController _summary = TextEditingController();

  @override
  void initState() {
    super.initState();
    final product = widget.scan.productName.isEmpty
        ? 'Ürün kodu'
        : widget.scan.productName;
    _title = TextEditingController(text: '$product şüpheli tarama vakası');
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vaka Dosyası Aç'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 240,
              decoration: const InputDecoration(labelText: 'Vaka başlığı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summary,
              minLines: 3,
              maxLines: 6,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'İlk değerlendirme',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            _CaseInput(
              title: _title.text.trim(),
              summary: _summary.text.trim(),
            ),
          ),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Vaka Aç'),
        ),
      ],
    );
  }
}

class _ReviewInput {
  const _ReviewInput({required this.status, required this.notes});

  final String status;
  final String notes;
}

class _CaseInput {
  const _CaseInput({required this.title, required this.summary});

  final String title;
  final String summary;
}

class _PageHero extends StatelessWidget {
  const _PageHero({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

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
      child: Row(
        children: [
          Icon(icon, color: MarkaKalkanTheme.teal, size: 44),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
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
                (item) => SizedBox(
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
                        Icon(item.icon, color: MarkaKalkanTheme.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.value,
                                style: const TextStyle(
                                  color: MarkaKalkanTheme.navy,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.label,
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

class _KpiItem {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
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
            textAlign: TextAlign.center,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

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

Color _riskColor(String value) {
  switch (value) {
    case 'critical':
      return const Color(0xFFB42318);
    case 'high':
      return const Color(0xFFD65A1F);
    case 'medium':
      return const Color(0xFFB7791F);
    case 'low':
      return const Color(0xFF176B87);
    default:
      return const Color(0xFF667785);
  }
}

String _riskLabel(String value) {
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

String _reviewLabel(String value) {
  switch (value) {
    case 'reviewed':
      return 'İncelendi';
    case 'dismissed':
      return 'Risk değil';
    case 'escalated':
      return 'Vakaya taşındı';
    case 'not_required':
      return 'İnceleme gerekmiyor';
    default:
      return 'İnceleme bekliyor';
  }
}

String _reasonLabel(String value) {
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
