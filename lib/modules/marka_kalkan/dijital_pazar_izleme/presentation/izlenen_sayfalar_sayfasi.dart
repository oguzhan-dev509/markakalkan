import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/brand_monitoring_profile_model.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_source_model.dart';
import '../repositories/brand_monitoring_profile_repository.dart';
import '../repositories/monitored_page_repository.dart';
import '../repositories/monitoring_source_repository.dart';

class IzlenenSayfalarSayfasi extends StatefulWidget {
  const IzlenenSayfalarSayfasi({super.key});

  @override
  State<IzlenenSayfalarSayfasi> createState() => _IzlenenSayfalarSayfasiState();
}

class _IzlenenSayfalarSayfasiState extends State<IzlenenSayfalarSayfasi> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  MonitoredPageRepository? get _repository {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    return MonitoredPageRepository.instance(tenantId: user.uid);
  }

  Future<void> _openCreateDialog() async {
    final user = _currentUser;
    final repository = _repository;

    if (user == null || repository == null) {
      _showMessage('İzlenen sayfa eklemek için giriş yapılmalıdır.');
      return;
    }

    final profileRepository = BrandMonitoringProfileRepository.instance(
      tenantId: user.uid,
    );
    final sourceRepository = MonitoringSourceRepository.instance(
      tenantId: user.uid,
    );

    try {
      final results = await Future.wait<dynamic>([
        profileRepository.listActive(limit: 200),
        sourceRepository.listActive(limit: 200),
      ]);

      if (!mounted) {
        return;
      }

      final profiles = results[0] as List<BrandMonitoringProfileModel>;
      final sources = results[1] as List<MonitoringSourceModel>;

      if (profiles.isEmpty) {
        _showMessage(
          'Önce en az bir aktif Marka İzleme Profili oluşturmalısınız.',
        );
        return;
      }

      if (sources.isEmpty) {
        _showMessage('Önce en az bir aktif İzleme Kaynağı oluşturmalısınız.');
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateMonitoredPageDialog(
          repository: repository,
          user: user,
          profiles: profiles,
          sources: sources,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'failed-precondition'
            ? 'Firestore indeksleri hazırlanıyor. Birkaç dakika sonra tekrar deneyin.'
            : 'Profil ve kaynak bilgileri yüklenemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Profil ve kaynak bilgileri yüklenemedi.');
    }
  }

  Future<void> _toggleTrackingStatus(MonitoredPageModel page) async {
    final user = _currentUser;
    final repository = _repository;

    if (user == null || repository == null) {
      return;
    }

    final nextStatus =
        page.trackingStatus == MonitoringPageTrackingStatus.active
        ? MonitoringPageTrackingStatus.paused
        : MonitoringPageTrackingStatus.active;

    try {
      await repository.updateTrackingStatus(
        pageId: page.id,
        trackingStatus: nextStatus,
        updatedBy: user.uid,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        nextStatus == MonitoringPageTrackingStatus.active
            ? 'Sayfa izleme yeniden etkinleştirildi.'
            : 'Sayfa izleme duraklatıldı.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu sayfayı değiştirme yetkiniz bulunmuyor.'
            : 'İzleme durumu güncellenemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('İzleme durumu güncellenemedi.');
    }
  }

  Future<void> _archivePage(MonitoredPageModel page) async {
    final user = _currentUser;
    final repository = _repository;

    if (user == null || repository == null) {
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İzlenen sayfayı arşivle'),
        content: Text(
          '"${page.title ?? page.url}" kaydı arşivlensin mi? '
          'Geçmiş olaylar ve kanıtlar korunacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arşivle'),
          ),
        ],
      ),
    );

    if (approved != true) {
      return;
    }

    try {
      await repository.updateTrackingStatus(
        pageId: page.id,
        trackingStatus: MonitoringPageTrackingStatus.archived,
        updatedBy: user.uid,
      );

      if (!mounted) {
        return;
      }

      _showMessage('İzlenen sayfa arşivlendi.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Sayfa arşivlenemedi.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final repository = _repository;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'İzlenen Sayfalar',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                user?.email ?? 'Marka kullanıcısı',
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: repository == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_link_outlined),
              label: const Text(
                'Yeni Sayfa',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: repository == null
          ? const _SignedOutView()
          : StreamBuilder<List<MonitoredPageModel>>(
              stream: repository.watchAll(limit: 300),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorView(error: snapshot.error);
                }

                final allPages = snapshot.data ?? const <MonitoredPageModel>[];

                final visiblePages = allPages
                    .where(
                      (page) =>
                          page.trackingStatus !=
                          MonitoringPageTrackingStatus.archived,
                    )
                    .toList(growable: false);

                return _PageBody(
                  pages: visiblePages,
                  archivedCount: allPages.length - visiblePages.length,
                  onCreate: _openCreateDialog,
                  onToggleStatus: _toggleTrackingStatus,
                  onArchive: _archivePage,
                );
              },
            ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.pages,
    required this.archivedCount,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onArchive,
  });

  final List<MonitoredPageModel> pages;
  final int archivedCount;
  final VoidCallback onCreate;
  final ValueChanged<MonitoredPageModel> onToggleStatus;
  final ValueChanged<MonitoredPageModel> onArchive;

  @override
  Widget build(BuildContext context) {
    final activeCount = pages
        .where(
          (page) => page.trackingStatus == MonitoringPageTrackingStatus.active,
        )
        .length;

    final highRiskCount = pages.where((page) => page.isHighRisk).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHeader(
                totalCount: pages.length,
                activeCount: activeCount,
                highRiskCount: highRiskCount,
                archivedCount: archivedCount,
                onCreate: onCreate,
              ),
              const SizedBox(height: 24),
              if (pages.isEmpty)
                _EmptyPageView(onCreate: onCreate)
              else
                _PageGrid(
                  pages: pages,
                  onToggleStatus: onToggleStatus,
                  onArchive: onArchive,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.totalCount,
    required this.activeCount,
    required this.highRiskCount,
    required this.archivedCount,
    required this.onCreate,
  });

  final int totalCount;
  final int activeCount;
  final int highRiskCount;
  final int archivedCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 26,
        runSpacing: 22,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dijital Hedef Envanteri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ürün ilanı, mağaza, satıcı profili, sosyal medya hesabı, '
                  'web sitesi ve şüpheli alan adlarını tek merkezden izleyin.',
                  style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_link_outlined),
            label: const Text('Yeni Sayfa Ekle'),
            style: FilledButton.styleFrom(
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryChip(
                  label: 'Toplam',
                  value: totalCount,
                  icon: Icons.language_outlined,
                ),
                _SummaryChip(
                  label: 'Aktif',
                  value: activeCount,
                  icon: Icons.visibility_outlined,
                ),
                _SummaryChip(
                  label: 'Yüksek Risk',
                  value: highRiskCount,
                  icon: Icons.warning_amber_outlined,
                ),
                _SummaryChip(
                  label: 'Arşiv',
                  value: archivedCount,
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF25576B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MarkaKalkanTheme.teal),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageGrid extends StatelessWidget {
  const _PageGrid({
    required this.pages,
    required this.onToggleStatus,
    required this.onArchive,
  });

  final List<MonitoredPageModel> pages;
  final ValueChanged<MonitoredPageModel> onToggleStatus;
  final ValueChanged<MonitoredPageModel> onArchive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 920
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final page in pages)
              SizedBox(
                width: cardWidth,
                child: _PageCard(
                  page: page,
                  onToggleStatus: () => onToggleStatus(page),
                  onArchive: () => onArchive(page),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.page,
    required this.onToggleStatus,
    required this.onArchive,
  });

  final MonitoredPageModel page;
  final VoidCallback onToggleStatus;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final trackingActive =
        page.trackingStatus == MonitoringPageTrackingStatus.active;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: page.isHighRisk
              ? const Color(0xFFD92D20)
              : trackingActive
              ? MarkaKalkanTheme.teal
              : const Color(0xFFE0E7EC),
          width: page.isHighRisk ? 1.7 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _pageTypeIcon(page.pageType),
                  color: MarkaKalkanTheme.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title?.trim().isNotEmpty == true
                          ? page.title!
                          : page.domain ?? 'Başlıksız sayfa',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _pageTypeLabel(page.pageType),
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggleStatus();
                  } else if (value == 'archive') {
                    onArchive();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      trackingActive
                          ? 'İzlemeyi duraklat'
                          : 'İzlemeyi etkinleştir',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Kaydı arşivle'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            page.url,
            maxLines: 2,
            style: const TextStyle(
              color: MarkaKalkanTheme.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.visibility_outlined,
                label: _trackingStatusLabel(page.trackingStatus),
              ),
              _InfoChip(
                icon: Icons.public_outlined,
                label: _pageStatusLabel(page.status),
              ),
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: _frequencyLabel(page.scanFrequency),
              ),
              _RiskChip(score: page.riskScore, level: page.riskLevel),
            ],
          ),
          if (_sellerText(page) != null) ...[
            const SizedBox(height: 16),
            _InfoLine(
              icon: Icons.storefront_outlined,
              text: _sellerText(page)!,
            ),
          ],
          if (page.productName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 9),
            _InfoLine(
              icon: Icons.inventory_2_outlined,
              text: page.productName!,
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _SmallStat(label: 'Olay', value: page.eventCount.toString()),
              _SmallStat(label: 'Sinyal', value: page.signalCount.toString()),
              _SmallStat(
                label: 'Açık sinyal',
                value: page.openSignalCount.toString(),
              ),
              _SmallStat(
                label: 'Son tarama',
                value: _dateLabel(page.lastScannedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _sellerText(MonitoredPageModel page) {
    final values = <String>[
      if (page.storeName?.trim().isNotEmpty == true) page.storeName!,
      if (page.sellerName?.trim().isNotEmpty == true) page.sellerName!,
    ];

    if (values.isEmpty) {
      return null;
    }

    return values.toSet().join(' • ');
  }
}

class _CreateMonitoredPageDialog extends StatefulWidget {
  const _CreateMonitoredPageDialog({
    required this.repository,
    required this.user,
    required this.profiles,
    required this.sources,
  });

  final MonitoredPageRepository repository;
  final User user;
  final List<BrandMonitoringProfileModel> profiles;
  final List<MonitoringSourceModel> sources;

  @override
  State<_CreateMonitoredPageDialog> createState() =>
      _CreateMonitoredPageDialogState();
}

class _CreateMonitoredPageDialogState
    extends State<_CreateMonitoredPageDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _sellerController = TextEditingController();
  final _storeController = TextEditingController();
  final _productController = TextEditingController();
  final _brandController = TextEditingController();
  final _platformController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  late String _selectedProfileId;
  late String _selectedSourceId;

  MonitoringPageType _pageType = MonitoringPageType.productListing;
  MonitoringScanFrequency _frequency = MonitoringScanFrequency.daily;
  MonitoringPriority _priority = MonitoringPriority.normal;
  MonitoringPageTrackingStatus _trackingStatus =
      MonitoringPageTrackingStatus.active;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _selectedProfileId = widget.profiles.first.id;
    _selectedSourceId = widget.sources.first.id;

    final selectedSource = widget.sources.first;
    _platformController.text = selectedSource.name;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _sellerController.dispose();
    _storeController.dispose();
    _productController.dispose();
    _brandController.dispose();
    _platformController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final normalizedUrl = MonitoredPageModel.normalizeUrl(_urlController.text);

    final page = MonitoredPageModel(
      id: '',
      tenantId: widget.user.uid,
      brandId: _selectedProfileId,
      sourceId: _selectedSourceId,
      pageType: _pageType,
      title: _cleanNullable(_titleController.text),
      url: _urlController.text.trim(),
      normalizedUrl: normalizedUrl,
      domain: MonitoredPageModel.domainFromUrl(normalizedUrl),
      platform: _cleanNullable(_platformController.text),
      marketplace: _cleanNullable(_platformController.text),
      sellerName: _cleanNullable(_sellerController.text),
      storeName: _cleanNullable(_storeController.text),
      productName: _cleanNullable(_productController.text),
      productBrand: _cleanNullable(_brandController.text),
      status: MonitoringPageStatus.unknown,
      trackingStatus: _trackingStatus,
      discoveryMethod: MonitoringPageDiscoveryMethod.manual,
      scanFrequency: _frequency,
      priority: _priority,
      firstSeenAt: now,
      lastSeenAt: null,
      consecutiveFailureCount: 0,
      riskScore: 0,
      riskLevel: MonitoringSignalLevel.info,
      eventCount: 0,
      signalCount: 0,
      openSignalCount: 0,
      tags: _splitValues(_tagsController.text),
      notes: _cleanNullable(_notesController.text),
      createdAt: now,
      createdBy: widget.user.uid,
    );

    try {
      await widget.repository.create(page);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzlenen sayfa oluşturuldu.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Bu sayfayı ekleme yetkiniz bulunmuyor.'
                : error.code == 'failed-precondition'
                ? 'Firestore indeksi hazırlanıyor. Birkaç dakika sonra yeniden deneyin.'
                : 'İzlenen sayfa kaydedilemedi.',
          ),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzlenen sayfa kaydedilemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni İzlenen Sayfa',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      _ResponsiveFields(
                        first: DropdownButtonFormField<String>(
                          initialValue: _selectedProfileId,
                          decoration: const InputDecoration(
                            labelText: 'Marka izleme profili',
                            prefixIcon: Icon(Icons.manage_search_outlined),
                          ),
                          items: widget.profiles
                              .map(
                                (profile) => DropdownMenuItem(
                                  value: profile.id,
                                  child: Text(
                                    '${profile.profileName} • ${profile.brandName}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProfileId = value;
                              });
                            }
                          },
                        ),
                        second: DropdownButtonFormField<String>(
                          initialValue: _selectedSourceId,
                          decoration: const InputDecoration(
                            labelText: 'Bağlı kaynak',
                            prefixIcon: Icon(Icons.hub_outlined),
                          ),
                          items: widget.sources
                              .map(
                                (source) => DropdownMenuItem(
                                  value: source.id,
                                  child: Text(
                                    source.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            final selectedSource = widget.sources.firstWhere(
                              (source) => source.id == value,
                            );

                            setState(() {
                              _selectedSourceId = value;
                              _platformController.text = selectedSource.name;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'Sayfa URL',
                          hintText:
                              'https://www.trendyol.com/marka/urun-p-123456',
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                        validator: (value) {
                          final cleaned = value?.trim() ?? '';

                          if (cleaned.isEmpty) {
                            return 'İzlenecek sayfa adresini girin.';
                          }

                          final normalized = MonitoredPageModel.normalizeUrl(
                            cleaned,
                          );
                          final uri = Uri.tryParse(normalized);

                          if (uri == null ||
                              !uri.hasScheme ||
                              uri.host.trim().isEmpty) {
                            return 'Geçerli bir HTTP veya HTTPS adresi girin.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveFields(
                        first: TextFormField(
                          controller: _titleController,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Sayfa başlığı',
                            hintText: 'Ürün veya mağaza başlığı',
                            prefixIcon: Icon(Icons.title_outlined),
                          ),
                        ),
                        second: DropdownButtonFormField<MonitoringPageType>(
                          initialValue: _pageType,
                          decoration: const InputDecoration(
                            labelText: 'Sayfa türü',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: MonitoringPageType.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_pageTypeLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _pageType = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveFields(
                        first: TextFormField(
                          controller: _platformController,
                          decoration: const InputDecoration(
                            labelText: 'Platform / pazaryeri',
                            hintText: 'Trendyol, Hepsiburada, Instagram',
                            prefixIcon: Icon(Icons.public_outlined),
                          ),
                        ),
                        second: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'İlanda görünen marka',
                            prefixIcon: Icon(Icons.verified_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveFields(
                        first: TextFormField(
                          controller: _sellerController,
                          decoration: const InputDecoration(
                            labelText: 'Satıcı adı',
                            prefixIcon: Icon(Icons.person_search_outlined),
                          ),
                        ),
                        second: TextFormField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            labelText: 'Mağaza adı',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _productController,
                        decoration: const InputDecoration(
                          labelText: 'Ürün adı',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveFields(
                        first: DropdownButtonFormField<MonitoringScanFrequency>(
                          initialValue: _frequency,
                          decoration: const InputDecoration(
                            labelText: 'Tarama sıklığı',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          items: MonitoringScanFrequency.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_frequencyLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _frequency = value;
                              });
                            }
                          },
                        ),
                        second: DropdownButtonFormField<MonitoringPriority>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'İzleme önceliği',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: MonitoringPriority.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_priorityLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _priority = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<MonitoringPageTrackingStatus>(
                        initialValue: _trackingStatus,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç izleme durumu',
                          prefixIcon: Icon(Icons.visibility_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: MonitoringPageTrackingStatus.active,
                            child: Text('Aktif izleme'),
                          ),
                          DropdownMenuItem(
                            value: MonitoringPageTrackingStatus.pending,
                            child: Text('İlk tarama bekliyor'),
                          ),
                          DropdownMenuItem(
                            value: MonitoringPageTrackingStatus.paused,
                            child: Text('Duraklatılmış'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _trackingStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Etiketler',
                          hintText: 'kozmetik, serum, fiyat-anomalisi',
                          helperText:
                              'Birden fazla etiketi virgülle ayırabilirsiniz.',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          labelText: 'İnceleme notları',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Kaydediliyor' : 'Sayfayı Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _cleanNullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static List<String> _splitValues(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MarkaKalkanTheme.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.score, required this.level});

  final int score;
  final MonitoringSignalLevel level;

  @override
  Widget build(BuildContext context) {
    final high =
        level == MonitoringSignalLevel.high ||
        level == MonitoringSignalLevel.critical;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFFEDEC) : const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color: high ? const Color(0xFFD92D20) : MarkaKalkanTheme.navy,
          ),
          const SizedBox(width: 6),
          Text(
            'Risk: $score • ${_riskLabel(level)}',
            style: TextStyle(
              color: high ? const Color(0xFFD92D20) : MarkaKalkanTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MarkaKalkanTheme.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF687580), height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: Color(0xFF687580),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyPageView extends StatelessWidget {
  const _EmptyPageView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 62),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.language_outlined,
            size: 64,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 18),
          const Text(
            'Henüz izlenen sayfa yok',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'İlk ürün ilanını, mağazayı, sosyal medya hesabını veya '
            'şüpheli alan adını izlemeye ekleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_link_outlined),
            label: const Text('İlk Sayfayı Ekle'),
          ),
        ],
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'İzlenen sayfaları görüntülemek için giriş yapın.',
        style: TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final text = error.toString();

    final message = text.contains('failed-precondition')
        ? 'İzlenen sayfalar indeksi hazırlanıyor. Birkaç dakika sonra yeniden deneyin.'
        : text.contains('permission-denied')
        ? 'İzlenen sayfaları görüntüleme yetkiniz bulunmuyor.'
        : 'İzlenen sayfalar yüklenemedi.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

IconData _pageTypeIcon(MonitoringPageType type) {
  switch (type) {
    case MonitoringPageType.productListing:
      return Icons.inventory_2_outlined;
    case MonitoringPageType.sellerStore:
      return Icons.storefront_outlined;
    case MonitoringPageType.sellerProfile:
      return Icons.person_search_outlined;
    case MonitoringPageType.searchResult:
      return Icons.search_outlined;
    case MonitoringPageType.categoryPage:
      return Icons.category_outlined;
    case MonitoringPageType.socialProfile:
      return Icons.account_circle_outlined;
    case MonitoringPageType.socialPost:
      return Icons.post_add_outlined;
    case MonitoringPageType.websiteHome:
      return Icons.home_outlined;
    case MonitoringPageType.websiteProduct:
      return Icons.shopping_cart_outlined;
    case MonitoringPageType.independentWebsite:
      return Icons.language_outlined;
    case MonitoringPageType.suspiciousDomain:
      return Icons.warning_amber_outlined;
    case MonitoringPageType.domainRecord:
      return Icons.dns_outlined;
    case MonitoringPageType.other:
      return Icons.link_outlined;
  }
}

String _pageTypeLabel(MonitoringPageType type) {
  switch (type) {
    case MonitoringPageType.productListing:
      return 'Ürün ilanı';
    case MonitoringPageType.sellerStore:
      return 'Satıcı mağazası';
    case MonitoringPageType.sellerProfile:
      return 'Satıcı profili';
    case MonitoringPageType.searchResult:
      return 'Arama sonucu';
    case MonitoringPageType.categoryPage:
      return 'Kategori sayfası';
    case MonitoringPageType.socialProfile:
      return 'Sosyal medya hesabı';
    case MonitoringPageType.socialPost:
      return 'Sosyal medya gönderisi';
    case MonitoringPageType.websiteHome:
      return 'Web sitesi ana sayfası';
    case MonitoringPageType.websiteProduct:
      return 'Web sitesi ürün sayfası';
    case MonitoringPageType.independentWebsite:
      return 'Bağımsız satış sitesi';
    case MonitoringPageType.suspiciousDomain:
      return 'Şüpheli alan adı';
    case MonitoringPageType.domainRecord:
      return 'Alan adı kaydı';
    case MonitoringPageType.other:
      return 'Diğer hedef';
  }
}

String _trackingStatusLabel(MonitoringPageTrackingStatus status) {
  switch (status) {
    case MonitoringPageTrackingStatus.pending:
      return 'Tarama bekliyor';
    case MonitoringPageTrackingStatus.active:
      return 'Aktif izleme';
    case MonitoringPageTrackingStatus.paused:
      return 'Duraklatıldı';
    case MonitoringPageTrackingStatus.archived:
      return 'Arşivlendi';
  }
}

String _pageStatusLabel(MonitoringPageStatus status) {
  switch (status) {
    case MonitoringPageStatus.active:
      return 'Sayfa aktif';
    case MonitoringPageStatus.inactive:
      return 'Pasif';
    case MonitoringPageStatus.removed:
      return 'Kaldırıldı';
    case MonitoringPageStatus.blocked:
      return 'Erişim engelli';
    case MonitoringPageStatus.redirected:
      return 'Yönlendirildi';
    case MonitoringPageStatus.republished:
      return 'Yeniden yayınlandı';
    case MonitoringPageStatus.unreachable:
      return 'Erişilemiyor';
    case MonitoringPageStatus.error:
      return 'Tarama hatası';
    case MonitoringPageStatus.unknown:
      return 'Henüz kontrol edilmedi';
  }
}

String _frequencyLabel(MonitoringScanFrequency frequency) {
  switch (frequency) {
    case MonitoringScanFrequency.hourly:
      return 'Saatlik';
    case MonitoringScanFrequency.every6Hours:
      return '6 saatte bir';
    case MonitoringScanFrequency.daily:
      return 'Günlük';
    case MonitoringScanFrequency.weekly:
      return 'Haftalık';
    case MonitoringScanFrequency.manual:
      return 'Manuel';
  }
}

String _priorityLabel(MonitoringPriority priority) {
  switch (priority) {
    case MonitoringPriority.low:
      return 'Düşük öncelik';
    case MonitoringPriority.normal:
      return 'Normal öncelik';
    case MonitoringPriority.high:
      return 'Yüksek öncelik';
    case MonitoringPriority.critical:
      return 'Kritik öncelik';
  }
}

String _riskLabel(MonitoringSignalLevel level) {
  switch (level) {
    case MonitoringSignalLevel.info:
      return 'Bilgi';
    case MonitoringSignalLevel.low:
      return 'Düşük';
    case MonitoringSignalLevel.medium:
      return 'Orta';
    case MonitoringSignalLevel.high:
      return 'Yüksek';
    case MonitoringSignalLevel.critical:
      return 'Kritik';
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return 'Henüz yok';
  }

  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
