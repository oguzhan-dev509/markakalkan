import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/sponsor_content/data/sponsor_content_service.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

typedef SponsorContentLoader = Future<List<SponsorContentEntry>> Function();
typedef SponsorContentSaver =
    Future<String> Function(SponsorContentEntry entry);

class SponsorContentAdminPage extends StatefulWidget {
  const SponsorContentAdminPage({super.key, this.loadEntries, this.saveEntry});

  final SponsorContentLoader? loadEntries;
  final SponsorContentSaver? saveEntry;

  @override
  State<SponsorContentAdminPage> createState() =>
      _SponsorContentAdminPageState();
}

class _SponsorContentAdminPageState extends State<SponsorContentAdminPage> {
  SponsorContentService? _service;

  List<SponsorContentEntry> _entries = const <SponsorContentEntry>[];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  SponsorContentService get _resolvedService =>
      _service ??= SponsorContentService();

  SponsorContentLoader get _loader =>
      widget.loadEntries ?? _resolvedService.listForAdmin;

  SponsorContentSaver get _saver =>
      widget.saveEntry ?? _resolvedService.upsertForAdmin;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _loader();
      if (!mounted) return;
      setState(() {
        _entries = [...entries]
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({SponsorContentEntry? entry}) async {
    final draft = await showDialog<SponsorContentEntry>(
      context: context,
      builder: (context) => _SponsorEditorDialog(initial: entry),
    );
    if (draft == null || !mounted) return;

    await _save(draft);
  }

  Future<void> _save(SponsorContentEntry entry) async {
    setState(() => _saving = true);
    try {
      await _saver(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sponsor kaydı kaydedildi.')),
        );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Kayıt kaydedilemedi: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _archive(SponsorContentEntry entry) async {
    if (entry.status == 'archived') return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sponsor kaydını arşivle'),
        content: Text(
          '${entry.displayName} artık kamu sponsor listesinde '
          'gösterilmeyecek. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Arşivle'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    await _save(
      SponsorContentEntry(
        id: entry.id,
        displayName: entry.displayName,
        categoryCode: entry.categoryCode,
        categoryLabel: entry.categoryLabel,
        websiteUrl: entry.websiteUrl,
        logoUrl: entry.logoUrl,
        logoAlt: entry.logoAlt,
        displayOrder: entry.displayOrder,
        status: 'archived',
        startsAt: entry.startsAt,
        endsAt: entry.endsAt,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Sponsor / İş Ortağı Yönetimi',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  saving: _saving,
                  onCreate: _saving ? null : () => _openEditor(),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  _ErrorPanel(onRetry: _reload)
                else if (_entries.isEmpty)
                  const _EmptyPanel()
                else
                  _SponsorList(
                    entries: _entries,
                    disabled: _saving,
                    onEdit: (entry) => _openEditor(entry: entry),
                    onArchive: _archive,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.saving, required this.onCreate});

  final bool saving;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;

          final text = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İş Ortaklarımız / Sponsorlarımız',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Kamu sayfasındaki sponsor içeriklerini, sırasını, '
                'yayın durumunu ve tarih aralığını yönetin.',
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.45),
              ),
            ],
          );

          final button = FilledButton.icon(
            key: const ValueKey<String>('sponsor-content-create-action'),
            onPressed: onCreate,
            icon: saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business_outlined),
            label: const Text('Yeni sponsor'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 18), button],
            );
          }

          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _SponsorList extends StatelessWidget {
  const _SponsorList({
    required this.entries,
    required this.disabled,
    required this.onEdit,
    required this.onArchive,
  });

  final List<SponsorContentEntry> entries;
  final bool disabled;
  final ValueChanged<SponsorContentEntry> onEdit;
  final ValueChanged<SponsorContentEntry> onArchive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 2 : 1;
        const gap = 14.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in entries)
              SizedBox(
                width: cardWidth,
                child: _SponsorAdminCard(
                  entry: entry,
                  disabled: disabled,
                  onEdit: () => onEdit(entry),
                  onArchive: () => onArchive(entry),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SponsorAdminCard extends StatelessWidget {
  const _SponsorAdminCard({
    required this.entry,
    required this.disabled,
    required this.onEdit,
    required this.onArchive,
  });

  final SponsorContentEntry entry;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archived = entry.status == 'archived';

    return Container(
      key: ValueKey<String>('sponsor-content-card-${entry.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF6F8),
                child: Icon(
                  Icons.handshake_outlined,
                  color: MarkaKalkanTheme.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.categoryLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687580),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 16),
          _MetaLine(label: 'Sıra', value: '${entry.displayOrder}'),
          _MetaLine(
            label: 'Web',
            value: entry.websiteUrl.isEmpty ? '—' : entry.websiteUrl,
          ),
          _MetaLine(
            label: 'Logo',
            value: entry.logoUrl.isEmpty ? 'Henüz eklenmedi' : 'Tanımlı',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('sponsor-content-edit-${entry.id}'),
                onPressed: disabled || archived ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                key: ValueKey<String>('sponsor-content-archive-${entry.id}'),
                onPressed: disabled || archived ? null : onArchive,
                icon: const Icon(Icons.archive_outlined),
                label: Text(archived ? 'Arşivlendi' : 'Arşivle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'active' => 'Aktif',
      'inactive' => 'Pasif',
      'archived' => 'Arşiv',
      _ => 'Taslak',
    };

    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            const Text('Sponsor kayıtları yüklenemedi.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.add_business_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'Henüz yönetilen sponsor kaydı yok.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorEditorDialog extends StatefulWidget {
  const _SponsorEditorDialog({this.initial});

  final SponsorContentEntry? initial;

  @override
  State<_SponsorEditorDialog> createState() => _SponsorEditorDialogState();
}

class _SponsorEditorDialogState extends State<_SponsorEditorDialog> {
  static const _categoryLabels = <String, String>{
    'technology': 'Teknoloji',
    'legal_ip': 'Hukuk ve IP',
    'ecommerce': 'E-ticaret',
    'telecom': 'Telekom',
    'logistics': 'Lojistik',
    'corporate': 'Kurumsal',
    'other': 'Diğer',
  };

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _website;
  late final TextEditingController _logoUrl;
  late final TextEditingController _logoAlt;
  late final TextEditingController _order;
  late final TextEditingController _startsAt;
  late final TextEditingController _endsAt;

  late String _categoryCode;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.displayName ?? '');
    _website = TextEditingController(text: initial?.websiteUrl ?? '');
    _logoUrl = TextEditingController(text: initial?.logoUrl ?? '');
    _logoAlt = TextEditingController(text: initial?.logoAlt ?? '');
    _order = TextEditingController(text: '${initial?.displayOrder ?? 100}');
    _startsAt = TextEditingController(
      text: initial?.startsAt?.toUtc().toIso8601String() ?? '',
    );
    _endsAt = TextEditingController(
      text: initial?.endsAt?.toUtc().toIso8601String() ?? '',
    );
    _categoryCode = initial?.categoryCode.isNotEmpty == true
        ? initial!.categoryCode
        : 'corporate';
    _status = initial?.status.isNotEmpty == true ? initial!.status : 'draft';
  }

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _logoUrl.dispose();
    _logoAlt.dispose();
    _order.dispose();
    _startsAt.dispose();
    _endsAt.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label zorunludur.';
    return null;
  }

  String? _httpsUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'HTTPS adresi girin.';
    }
    return null;
  }

  String? _optionalDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text) == null ? 'Geçerli tarih girin.' : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final order = int.tryParse(_order.text.trim());
    if (order == null || order < 0 || order > 9999) return;

    final startsAt = _startsAt.text.trim().isEmpty
        ? null
        : DateTime.parse(_startsAt.text.trim()).toUtc();
    final endsAt = _endsAt.text.trim().isEmpty
        ? null
        : DateTime.parse(_endsAt.text.trim()).toUtc();

    if (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Bitiş tarihi başlangıç tarihinden sonra olmalı.'),
          ),
        );
      return;
    }

    final initial = widget.initial;
    Navigator.of(context).pop(
      SponsorContentEntry(
        id: initial?.id ?? '',
        displayName: _name.text.trim(),
        categoryCode: _categoryCode,
        categoryLabel: _categoryLabels[_categoryCode] ?? 'Diğer',
        websiteUrl: _website.text.trim(),
        logoUrl: _logoUrl.text.trim(),
        logoAlt: _logoAlt.text.trim(),
        displayOrder: order,
        status: _status,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: initial?.createdAt,
        updatedAt: initial?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return AlertDialog(
      title: Text(editing ? 'Sponsor kaydını düzenle' : 'Yeni sponsor ekle'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey<String>('sponsor-editor-name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Sponsor / iş ortağı adı *',
                  ),
                  validator: (value) => _required(value, 'Ad'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryCode,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    for (final entry in _categoryLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _categoryCode = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _website,
                  decoration: const InputDecoration(
                    labelText: 'Web adresi (HTTPS)',
                  ),
                  validator: _httpsUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('sponsor-editor-logo-url'),
                  controller: _logoUrl,
                  decoration: const InputDecoration(
                    labelText: 'Logo adresi (HTTPS)',
                    helperText:
                        'Dosya yükleme ayrıca etkinleştirilecek; şimdilik HTTPS URL.',
                  ),
                  validator: _httpsUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _logoAlt,
                  decoration: const InputDecoration(
                    labelText: 'Logo alternatif metni',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gösterim sırası (0-9999)',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0 || parsed > 9999) {
                      return '0-9999 arasında sayı girin.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Taslak')),
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
                    DropdownMenuItem(value: 'archived', child: Text('Arşiv')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startsAt,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç tarihi (ISO, isteğe bağlı)',
                  ),
                  validator: _optionalDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endsAt,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş tarihi (ISO, isteğe bağlı)',
                  ),
                  validator: _optionalDate,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey<String>('sponsor-editor-save'),
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
