import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../models/ip_creation_priority_record_model.dart';
import '../models/ip_creation_priority_version_model.dart';
import '../repositories/ip_creation_priority_repository.dart';

class IpCreationPriorityDetailPage extends StatefulWidget {
  const IpCreationPriorityDetailPage({
    super.key,
    required this.recordId,
    required this.repository,
  });

  final String recordId;
  final IpCreationPriorityRepository repository;

  @override
  State<IpCreationPriorityDetailPage> createState() =>
      _IpCreationPriorityDetailPageState();
}

class _IpCreationPriorityDetailPageState
    extends State<IpCreationPriorityDetailPage> {
  late Future<_DetailData> _detailFuture;
  bool _sealing = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<_DetailData> _loadDetail() async {
    final record = await widget.repository.getRecordById(widget.recordId);

    if (record == null) {
      throw StateError('Yaratım öncelik kaydı bulunamadı.');
    }

    final versions = await widget.repository.listVersions(recordId: record.id);
    IpCreationPriorityVersionModel? activeVersion;

    final activeVersionId = record.activeVersionId?.trim();
    if (activeVersionId != null && activeVersionId.isNotEmpty) {
      for (final version in versions) {
        if (version.id == activeVersionId) {
          activeVersion = version;
          break;
        }
      }

      activeVersion ??= await widget.repository.getActiveVersion(record);
    }

    return _DetailData(
      record: record,
      activeVersion: activeVersion,
      versions: versions,
    );
  }

  void _reload() {
    setState(() {
      _detailFuture = _loadDetail();
    });
  }

  Future<void> _sealRecord(IpCreationPriorityRecordModel record) async {
    if (_sealing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kaydı mühürle'),
          content: const Text(
            'Bu işlem ilk sürümün içeriğini SHA-256 özetiyle mühürler. '
            'Mühürlenen ilk sürüm artık taslak olarak değiştirilemez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Kaydı Mühürle'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _sealing = true);

    try {
      final contentHash = await widget.repository.sealRecord(record: record);

      if (!mounted) {
        return;
      }

      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kayıt mühürlendi. SHA-256: ${_shortHash(contentHash)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt mühürlenemedi: $error')));
    } finally {
      if (mounted) {
        setState(() => _sealing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Yaratım Öncelik Kaydı',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _sealing ? null : _reload,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_DetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _DetailMessage(
              icon: Icons.error_outline,
              title: 'Kayıt ayrıntıları yüklenemedi',
              description: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden dene'),
              ),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;
          final record = data.record;
          final activeVersion = data.activeVersion;
          final canSeal =
              record.status == IpCreationPriorityStatus.draft &&
              record.sealStatus == IpCreationSealStatus.unsealed &&
              activeVersion != null &&
              activeVersion.sealStatus == IpCreationSealStatus.unsealed;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecordHeader(record: record),
                    const SizedBox(height: 18),
                    if (activeVersion != null)
                      _ActiveVersionCard(version: activeVersion)
                    else
                      const _DetailMessage(
                        icon: Icons.layers_clear_outlined,
                        title: 'Aktif sürüm bulunamadı',
                        description:
                            'Ana kayıtta aktif sürüm bağlantısı bulunmuyor.',
                      ),
                    if (canSeal) ...[
                      const SizedBox(height: 18),
                      _SealPanel(
                        sealing: _sealing,
                        onSeal: () => _sealRecord(record),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _VersionHistory(versions: data.versions),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _shortHash(String value) {
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }
}

class _DetailData {
  const _DetailData({
    required this.record,
    required this.activeVersion,
    required this.versions,
  });

  final IpCreationPriorityRecordModel record;
  final IpCreationPriorityVersionModel? activeVersion;
  final List<IpCreationPriorityVersionModel> versions;
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({required this.record});

  final IpCreationPriorityRecordModel record;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: record.creationType.label),
              _StatusChip(label: record.status.label),
              _StatusChip(label: record.sealStatus.label),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            record.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${record.recordCode} • Aktif sürüm ${record.currentVersion}',
            style: const TextStyle(
              color: Color(0xFF607982),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (record.summary?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Text(
              record.summary!.trim(),
              style: const TextStyle(color: Color(0xFF425B66), height: 1.5),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _MetaLine(
                icon: Icons.lock_outline,
                text: record.confidentialityLevel.label,
              ),
              _MetaLine(
                icon: Icons.calendar_today_outlined,
                text: 'Oluşturuldu: ${_formatDateTime(record.createdAt)}',
              ),
              if (record.sealedAt != null)
                _MetaLine(
                  icon: Icons.verified_outlined,
                  text: 'Mühürlendi: ${_formatDateTime(record.sealedAt!)}',
                ),
              if (record.creatorName?.trim().isNotEmpty ?? false)
                _MetaLine(
                  icon: Icons.person_outline,
                  text: record.creatorName!.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveVersionCard extends StatelessWidget {
  const _ActiveVersionCard({required this.version});

  final IpCreationPriorityVersionModel version;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktif Sürüm',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sürüm ${version.versionNumber} — ${version.title}',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ContentSection(label: 'Kısa özet', value: version.summary),
          _ContentSection(
            label: 'İçerik açıklaması',
            value: version.description,
          ),
          _ContentSection(
            label: 'Özgün unsurlar',
            value: version.originalElements,
          ),
          _ContentSection(
            label: 'Çözülmek istenen problem',
            value: version.problemStatement,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MetaLine(
                icon: Icons.science_outlined,
                text: version.developmentStage.label,
              ),
              _MetaLine(
                icon: Icons.shield_outlined,
                text: version.sealStatus.label,
              ),
              _MetaLine(
                icon: Icons.attach_file,
                text: '${version.fileManifest.length} dosya bildirimi',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HashPanel(version: version),
        ],
      ),
    );
  }
}

class _HashPanel extends StatelessWidget {
  const _HashPanel({required this.version});

  final IpCreationPriorityVersionModel version;

  @override
  Widget build(BuildContext context) {
    final hash = version.contentHash?.trim();
    final validSha256 =
        hash != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(hash);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: validSha256 ? const Color(0xFFEAF8F4) : const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: validSha256
              ? const Color(0xFF9ED8C8)
              : const Color(0xFFDCE7EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                validSha256
                    ? Icons.verified_user_outlined
                    : Icons.pending_outlined,
                color: validSha256
                    ? MarkaKalkanTheme.teal
                    : const Color(0xFF607982),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  validSha256
                      ? '${version.hashAlgorithm} bütünlük özeti hazır'
                      : 'SHA-256 bütünlük özeti henüz oluşturulmadı',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hash != null && hash.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              hash,
              style: const TextStyle(
                color: Color(0xFF425B66),
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SealPanel extends StatelessWidget {
  const _SealPanel({required this.sealing, required this.onSeal});

  final bool sealing;
  final VoidCallback onSeal;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      borderColor: const Color(0xFFFFD28A),
      backgroundColor: const Color(0xFFFFFBF1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined, color: Color(0xFF9A5A00)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taslak kayıt mühürlenmeye hazır',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Mühürleme, aktif ilk sürümün kanonik içeriğinden SHA-256 '
                  'özeti üretir ve kayıtla sürümü atomik olarak kilitler.',
                  style: TextStyle(
                    color: Color(0xFF6D542D),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: sealing ? null : onSeal,
            icon: sealing
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(sealing ? 'Mühürleniyor…' : 'Kaydı Mühürle'),
          ),
        ],
      ),
    );
  }
}

class _VersionHistory extends StatelessWidget {
  const _VersionHistory({required this.versions});

  final List<IpCreationPriorityVersionModel> versions;

  @override
  Widget build(BuildContext context) {
    final ordered = versions.reversed.toList(growable: false);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sürüm Geçmişi (${versions.length})',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (ordered.isEmpty)
            const Text(
              'Bu kayıt için sürüm bulunamadı.',
              style: TextStyle(color: Color(0xFF607982)),
            )
          else
            ...ordered.map(
              (version) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VersionTile(version: version),
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version});

  final IpCreationPriorityVersionModel version;

  @override
  Widget build(BuildContext context) {
    final hash = version.contentHash?.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(14),
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
                'Sürüm ${version.versionNumber}',
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _StatusChip(label: version.developmentStage.label),
              _StatusChip(label: version.sealStatus.label),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            version.title,
            style: const TextStyle(
              color: Color(0xFF425B66),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _formatDateTime(version.createdAt),
            style: const TextStyle(color: Color(0xFF607982), fontSize: 12),
          ),
          if (hash != null && hash.isNotEmpty) ...[
            const SizedBox(height: 9),
            SelectableText(
              '${version.hashAlgorithm}: $hash',
              style: const TextStyle(
                color: Color(0xFF607982),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
          if (version.versionNumber > 1) ...[
            const SizedBox(height: 8),
            Text(
              version.hasValidChainLink
                  ? 'Önceki sürüm zinciri bağlı'
                  : 'Önceki sürüm zinciri eksik',
              style: TextStyle(
                color: version.hasValidChainLink
                    ? MarkaKalkanTheme.teal
                    : const Color(0xFF9A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            cleaned,
            style: const TextStyle(color: Color(0xFF425B66), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.borderColor = const Color(0xFFDCE7EA),
    this.backgroundColor = Colors.white,
  });

  final Widget child;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

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

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _CardShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: MarkaKalkanTheme.teal),
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
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF607982), height: 1.45),
              ),
              if (action != null) ...[const SizedBox(height: 10), action!],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
