import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/brand_monitoring_profile_model.dart';
import '../models/crawl_job_model.dart';
import '../models/crawl_run_model.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_source_model.dart';
import '../repositories/brand_monitoring_profile_repository.dart';
import '../repositories/crawl_job_repository.dart';
import '../repositories/crawl_run_repository.dart';
import '../repositories/monitored_page_repository.dart';
import '../repositories/monitoring_source_repository.dart';

class TaramaGorevleriSayfasi extends StatefulWidget {
  const TaramaGorevleriSayfasi({super.key});

  @override
  State<TaramaGorevleriSayfasi> createState() => _TaramaGorevleriSayfasiState();
}

class _TaramaGorevleriSayfasiState extends State<TaramaGorevleriSayfasi> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  List<BrandMonitoringProfileModel> _profiles = const [];
  List<MonitoringSourceModel> _sources = const [];
  List<MonitoredPageModel> _pages = const [];

  final Set<String> _busyJobIds = <String>{};

  bool _loadingReferences = true;
  String? _referenceError;

  CrawlJobRepository? get _jobRepository {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    return CrawlJobRepository.instance(tenantId: user.uid);
  }

  CrawlRunRepository? get _runRepository {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    return CrawlRunRepository.instance(tenantId: user.uid);
  }

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    final user = _currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingReferences = false;
        });
      }
      return;
    }

    setState(() {
      _loadingReferences = true;
      _referenceError = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        BrandMonitoringProfileRepository.instance(
          tenantId: user.uid,
        ).listActive(limit: 200),
        MonitoringSourceRepository.instance(
          tenantId: user.uid,
        ).listActive(limit: 200),
        MonitoredPageRepository.instance(
          tenantId: user.uid,
        ).listAll(limit: 500),
      ]);

      if (!mounted) {
        return;
      }

      final profiles = results[0] as List<BrandMonitoringProfileModel>;
      final sources = results[1] as List<MonitoringSourceModel>;
      final pages = results[2] as List<MonitoredPageModel>;

      setState(() {
        _profiles = profiles;
        _sources = sources;
        _pages = pages
            .where(
              (page) =>
                  page.trackingStatus != MonitoringPageTrackingStatus.archived,
            )
            .toList(growable: false);
        _loadingReferences = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingReferences = false;
        _referenceError = error.code == 'failed-precondition'
            ? 'Firestore indeksleri hazırlanıyor.'
            : 'Profil, kaynak ve sayfa bilgileri yüklenemedi.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingReferences = false;
        _referenceError = 'Profil, kaynak ve sayfa bilgileri yüklenemedi.';
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final user = _currentUser;
    final repository = _jobRepository;

    if (user == null || repository == null) {
      _showMessage('Tarama görevi oluşturmak için giriş yapılmalıdır.');
      return;
    }

    if (_profiles.isEmpty) {
      _showMessage('Önce aktif bir Marka İzleme Profili oluşturmalısınız.');
      return;
    }

    if (_sources.isEmpty) {
      _showMessage('Önce aktif bir İzleme Kaynağı oluşturmalısınız.');
      return;
    }

    if (_pages.isEmpty) {
      _showMessage('Önce en az bir İzlenen Sayfa oluşturmalısınız.');
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateCrawlJobDialog(
        repository: repository,
        user: user,
        profiles: _profiles,
        sources: _sources,
        pages: _pages,
      ),
    );
  }

  Future<void> _toggleStatus(CrawlJobModel job) async {
    final user = _currentUser;
    final repository = _jobRepository;

    if (user == null || repository == null) {
      return;
    }

    final nextStatus = job.status == MonitoringCrawlJobStatus.active
        ? MonitoringCrawlJobStatus.paused
        : MonitoringCrawlJobStatus.active;

    await _runBusyAction(
      job.id,
      action: () => repository.updateStatus(
        jobId: job.id,
        status: nextStatus,
        updatedBy: user.uid,
      ),
      successMessage: nextStatus == MonitoringCrawlJobStatus.active
          ? 'Tarama görevi etkinleştirildi.'
          : 'Tarama görevi duraklatıldı.',
    );
  }

  Future<void> _archive(CrawlJobModel job) async {
    final user = _currentUser;
    final repository = _jobRepository;

    if (user == null || repository == null) {
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tarama görevini arşivle'),
        content: Text(
          '"${job.name}" görevi arşivlensin mi? '
          'Çalışma geçmişi korunacaktır.',
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

    await _runBusyAction(
      job.id,
      action: () => repository.archive(jobId: job.id, updatedBy: user.uid),
      successMessage: 'Tarama görevi arşivlendi.',
    );
  }

  Future<void> _enqueue(CrawlJobModel job) async {
    final user = _currentUser;
    final repository = _jobRepository;

    if (user == null || repository == null) {
      return;
    }

    final requestKey = '${job.id}_${DateTime.now().microsecondsSinceEpoch}';

    await _runBusyAction(
      job.id,
      action: () => repository.enqueueRun(
        jobId: job.id,
        requestedBy: user.uid,
        requestKey: requestKey,
        triggerType: MonitoringCrawlTriggerType.manual,
      ),
      successMessage: 'Tarama talebi güvenli kuyruğa alındı.',
    );
  }

  Future<void> _runBusyAction(
    String jobId, {
    required Future<dynamic> Function() action,
    required String successMessage,
  }) async {
    if (_busyJobIds.contains(jobId)) {
      return;
    }

    setState(() {
      _busyJobIds.add(jobId);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      _showMessage(successMessage);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'İşlem güvenlik kuralları tarafından reddedildi.'
            : error.code == 'failed-precondition'
            ? 'Gerekli Firestore indeksi hazırlanıyor.'
            : 'İşlem tamamlanamadı.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('İşlem tamamlanamadı.');
    } finally {
      if (mounted) {
        setState(() {
          _busyJobIds.remove(jobId);
        });
      }
    }
  }

  Future<void> _openHistory(CrawlJobModel job) async {
    final repository = _runRepository;

    if (repository == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _CrawlRunHistoryDialog(job: job, repository: repository),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final repository = _jobRepository;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Tarama Görevleri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Bağlantıları yenile',
            onPressed: _loadingReferences ? null : _loadReferences,
            icon: const Icon(Icons.refresh_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: repository == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _loadingReferences ? null : _openCreateDialog,
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text(
                'Yeni Görev',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: user == null || repository == null
          ? const _SignedOutView()
          : StreamBuilder<List<CrawlJobModel>>(
              stream: repository.watchAll(limit: 300),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorView(error: snapshot.error);
                }

                final jobs = (snapshot.data ?? const <CrawlJobModel>[])
                    .where(
                      (job) => job.status != MonitoringCrawlJobStatus.archived,
                    )
                    .toList(growable: false);

                return _JobBody(
                  jobs: jobs,
                  loadingReferences: _loadingReferences,
                  referenceError: _referenceError,
                  busyJobIds: _busyJobIds,
                  pageById: {for (final page in _pages) page.id: page},
                  sourceById: {
                    for (final source in _sources) source.id: source,
                  },
                  profileById: {
                    for (final profile in _profiles) profile.id: profile,
                  },
                  onCreate: _openCreateDialog,
                  onToggleStatus: _toggleStatus,
                  onArchive: _archive,
                  onEnqueue: _enqueue,
                  onHistory: _openHistory,
                );
              },
            ),
    );
  }
}

class _JobBody extends StatelessWidget {
  const _JobBody({
    required this.jobs,
    required this.loadingReferences,
    required this.referenceError,
    required this.busyJobIds,
    required this.pageById,
    required this.sourceById,
    required this.profileById,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onArchive,
    required this.onEnqueue,
    required this.onHistory,
  });

  final List<CrawlJobModel> jobs;
  final bool loadingReferences;
  final String? referenceError;
  final Set<String> busyJobIds;

  final Map<String, MonitoredPageModel> pageById;
  final Map<String, MonitoringSourceModel> sourceById;
  final Map<String, BrandMonitoringProfileModel> profileById;

  final VoidCallback onCreate;
  final ValueChanged<CrawlJobModel> onToggleStatus;
  final ValueChanged<CrawlJobModel> onArchive;
  final ValueChanged<CrawlJobModel> onEnqueue;
  final ValueChanged<CrawlJobModel> onHistory;

  @override
  Widget build(BuildContext context) {
    final activeCount = jobs
        .where((job) => job.status == MonitoringCrawlJobStatus.active)
        .length;

    final leasedCount = jobs.where((job) => job.isLeased).length;

    final failedCount = jobs
        .where(
          (job) =>
              job.lastRunStatus == MonitoringCrawlLastRunStatus.failed ||
              job.lastRunStatus == MonitoringCrawlLastRunStatus.blocked,
        )
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OperationHeader(
                totalCount: jobs.length,
                activeCount: activeCount,
                leasedCount: leasedCount,
                failedCount: failedCount,
                onCreate: onCreate,
              ),
              if (loadingReferences) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
              if (referenceError != null) ...[
                const SizedBox(height: 18),
                _ReferenceWarning(message: referenceError!),
              ],
              const SizedBox(height: 24),
              if (jobs.isEmpty)
                _EmptyJobView(onCreate: onCreate)
              else
                _JobGrid(
                  jobs: jobs,
                  busyJobIds: busyJobIds,
                  pageById: pageById,
                  sourceById: sourceById,
                  profileById: profileById,
                  onToggleStatus: onToggleStatus,
                  onArchive: onArchive,
                  onEnqueue: onEnqueue,
                  onHistory: onHistory,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationHeader extends StatelessWidget {
  const _OperationHeader({
    required this.totalCount,
    required this.activeCount,
    required this.leasedCount,
    required this.failedCount,
    required this.onCreate,
  });

  final int totalCount;
  final int activeCount;
  final int leasedCount;
  final int failedCount;
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
        spacing: 24,
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox(
            width: 690,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarama Operasyon Merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Planlı görevleri yönetin, güvenli tarama taleplerini '
                  'kuyruğa alın ve her çalışmanın operasyon geçmişini izleyin.',
                  style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Yeni Görev Oluştur'),
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
                  icon: Icons.radar_outlined,
                ),
                _SummaryChip(
                  label: 'Aktif',
                  value: activeCount,
                  icon: Icons.play_circle_outline,
                ),
                _SummaryChip(
                  label: 'Kuyruk / Lease',
                  value: leasedCount,
                  icon: Icons.pending_actions_outlined,
                ),
                _SummaryChip(
                  label: 'Hata',
                  value: failedCount,
                  icon: Icons.error_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobGrid extends StatelessWidget {
  const _JobGrid({
    required this.jobs,
    required this.busyJobIds,
    required this.pageById,
    required this.sourceById,
    required this.profileById,
    required this.onToggleStatus,
    required this.onArchive,
    required this.onEnqueue,
    required this.onHistory,
  });

  final List<CrawlJobModel> jobs;
  final Set<String> busyJobIds;

  final Map<String, MonitoredPageModel> pageById;
  final Map<String, MonitoringSourceModel> sourceById;
  final Map<String, BrandMonitoringProfileModel> profileById;

  final ValueChanged<CrawlJobModel> onToggleStatus;
  final ValueChanged<CrawlJobModel> onArchive;
  final ValueChanged<CrawlJobModel> onEnqueue;
  final ValueChanged<CrawlJobModel> onHistory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 940
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final job in jobs)
              SizedBox(
                width: cardWidth,
                child: _JobCard(
                  job: job,
                  busy: busyJobIds.contains(job.id),
                  page: pageById[job.pageId ?? job.targetId],
                  source: sourceById[job.sourceId],
                  profile: profileById[job.profileId],
                  onToggleStatus: () => onToggleStatus(job),
                  onArchive: () => onArchive(job),
                  onEnqueue: () => onEnqueue(job),
                  onHistory: () => onHistory(job),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.busy,
    required this.page,
    required this.source,
    required this.profile,
    required this.onToggleStatus,
    required this.onArchive,
    required this.onEnqueue,
    required this.onHistory,
  });

  final CrawlJobModel job;
  final bool busy;
  final MonitoredPageModel? page;
  final MonitoringSourceModel? source;
  final BrandMonitoringProfileModel? profile;

  final VoidCallback onToggleStatus;
  final VoidCallback onArchive;
  final VoidCallback onEnqueue;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final active = job.status == MonitoringCrawlJobStatus.active;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: job.isLeased
              ? const Color(0xFFF79009)
              : active
              ? MarkaKalkanTheme.teal
              : const Color(0xFFE0E7EC),
          width: job.isLeased ? 1.8 : 1.2,
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
                child: const Icon(
                  Icons.radar_outlined,
                  color: MarkaKalkanTheme.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      page?.title ??
                          page?.domain ??
                          job.targetUrl ??
                          'Bağlı sayfa',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggleStatus();
                  }

                  if (value == 'history') {
                    onHistory();
                  }

                  if (value == 'archive') {
                    onArchive();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      active ? 'Görevi duraklat' : 'Görevi etkinleştir',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Text('Çalışma geçmişi'),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Görevi arşivle'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: active
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                label: _jobStatusLabel(job.status),
              ),
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: _frequencyLabel(job.scheduleType),
              ),
              _InfoChip(
                icon: Icons.flag_outlined,
                label: _priorityLabel(job.priority),
              ),
              _InfoChip(
                icon: Icons.fact_check_outlined,
                label: _lastRunStatusLabel(job.lastRunStatus),
              ),
              if (job.isLeased)
                const _InfoChip(
                  icon: Icons.lock_clock_outlined,
                  label: 'Kuyrukta / çalışıyor',
                ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoLine(
            icon: Icons.manage_search_outlined,
            text: profile == null
                ? 'Profil: ${job.profileId}'
                : '${profile!.profileName} • ${profile!.brandName}',
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.hub_outlined,
            text: source == null ? 'Kaynak: ${job.sourceId}' : source!.name,
          ),
          if (job.targetUrl != null) ...[
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.link_outlined, text: job.targetUrl!),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _SmallStat(label: 'Toplam', value: job.totalRunCount.toString()),
              _SmallStat(label: 'Başarılı', value: job.successCount.toString()),
              _SmallStat(
                label: 'Kısmi',
                value: job.partialSuccessCount.toString(),
              ),
              _SmallStat(label: 'Hata', value: job.failureCount.toString()),
              _SmallStat(label: 'Engelli', value: job.blockedCount.toString()),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onHistory,
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('Geçmiş'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || !job.canRun ? null : onEnqueue,
                  icon: busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(job.isLeased ? 'Kuyrukta' : 'Şimdi Tara'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MarkaKalkanTheme.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateCrawlJobDialog extends StatefulWidget {
  const _CreateCrawlJobDialog({
    required this.repository,
    required this.user,
    required this.profiles,
    required this.sources,
    required this.pages,
  });

  final CrawlJobRepository repository;
  final User user;
  final List<BrandMonitoringProfileModel> profiles;
  final List<MonitoringSourceModel> sources;
  final List<MonitoredPageModel> pages;

  @override
  State<_CreateCrawlJobDialog> createState() => _CreateCrawlJobDialogState();
}

class _CreateCrawlJobDialogState extends State<_CreateCrawlJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedPageId;

  MonitoringScanFrequency _frequency = MonitoringScanFrequency.daily;
  MonitoringPriority _priority = MonitoringPriority.normal;
  MonitoringCrawlJobStatus _status = MonitoringCrawlJobStatus.active;

  bool _saving = false;

  MonitoredPageModel get _selectedPage {
    return widget.pages.firstWhere((page) => page.id == _selectedPageId);
  }

  BrandMonitoringProfileModel? get _selectedProfile {
    final page = _selectedPage;

    for (final profile in widget.profiles) {
      if (profile.id == page.brandId) {
        return profile;
      }
    }

    return null;
  }

  MonitoringSourceModel? get _selectedSource {
    final page = _selectedPage;

    for (final source in widget.sources) {
      if (source.id == page.sourceId) {
        return source;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    _selectedPageId = widget.pages.first.id;
    _applyPageDefaults(widget.pages.first);
  }

  void _applyPageDefaults(MonitoredPageModel page) {
    _nameController.text =
        '${page.title ?? page.domain ?? 'İzlenen Sayfa'} Tarama Görevi';
    _frequency = page.scanFrequency;
    _priority = page.priority;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final page = _selectedPage;
    final profile = _selectedProfile;
    final source = _selectedSource;

    if (profile == null) {
      _showMessage('Seçilen sayfanın aktif Marka İzleme Profili bulunamadı.');
      return;
    }

    if (source == null) {
      _showMessage('Seçilen sayfanın aktif kaynağı bulunamadı.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();

    final job = CrawlJobModel(
      id: '',
      tenantId: widget.user.uid,
      brandId: profile.brandId,
      profileId: profile.id,
      sourceId: source.id,
      name: _nameController.text.trim(),
      description: _cleanNullable(_descriptionController.text),
      jobType: MonitoringCrawlJobType.pageScan,
      targetType: MonitoringCrawlTargetType.page,
      targetId: page.id,
      pageId: page.id,
      targetUrl: page.url,
      scheduleType: _frequency,
      triggerType: MonitoringCrawlTriggerType.scheduled,
      executionMode: MonitoringCrawlExecutionMode.queue,
      priority: _priority,
      status: _status,
      nextRunAt: null,
      lastRunAt: null,
      lastRunId: null,
      lastRunStatus: MonitoringCrawlLastRunStatus.neverRun,
      totalRunCount: 0,
      successCount: 0,
      partialSuccessCount: 0,
      failureCount: 0,
      blockedCount: 0,
      consecutiveFailureCount: 0,
      maxRetryCount: 3,
      retryDelayMinutes: 15,
      createdAt: now,
      createdBy: widget.user.uid,
    );

    try {
      await widget.repository.create(job);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarama görevi oluşturuldu.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(
        error.code == 'permission-denied'
            ? 'Tarama görevi oluşturma yetkiniz bulunmuyor.'
            : error.code == 'failed-precondition'
            ? 'Firestore indeksi hazırlanıyor.'
            : 'Tarama görevi oluşturulamadı.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage('Tarama görevi oluşturulamadı.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final page = _selectedPage;
    final profile = _selectedProfile;
    final source = _selectedSource;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 790),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni Tarama Görevi',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
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
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPageId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'İzlenen sayfa',
                          prefixIcon: Icon(Icons.language_outlined),
                        ),
                        items: widget.pages
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.title ?? item.domain ?? item.url,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          final selected = widget.pages.firstWhere(
                            (item) => item.id == value,
                          );

                          setState(() {
                            _selectedPageId = value;
                            _applyPageDefaults(selected);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReadOnlyConnectionCard(
                        profileName: profile == null
                            ? 'Aktif profil bulunamadı'
                            : '${profile.profileName} • ${profile.brandName}',
                        sourceName: source?.name ?? 'Aktif kaynak bulunamadı',
                        url: page.url,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Görev adı',
                          prefixIcon: Icon(Icons.title_outlined),
                        ),
                        validator: (value) {
                          final cleaned = value?.trim() ?? '';

                          if (cleaned.length < 2) {
                            return 'Görev adı en az 2 karakter olmalıdır.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Görev açıklaması',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
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
                            labelText: 'Görev önceliği',
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
                      DropdownButtonFormField<MonitoringCrawlJobStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç durumu',
                          prefixIcon: Icon(Icons.tune_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: MonitoringCrawlJobStatus.active,
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: MonitoringCrawlJobStatus.paused,
                            child: Text('Duraklatılmış'),
                          ),
                          DropdownMenuItem(
                            value: MonitoringCrawlJobStatus.draft,
                            child: Text('Taslak'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _status = value;
                            });
                          }
                        },
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Kaydediliyor' : 'Görevi Kaydet'),
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
}

class _CrawlRunHistoryDialog extends StatelessWidget {
  const _CrawlRunHistoryDialog({required this.job, required this.repository});

  final CrawlJobModel job;
  final CrawlRunRepository repository;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${job.name} • Çalışma Geçmişi',
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<CrawlRunModel>>(
                stream: repository.watchForJob(job.id, limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Çalışma geçmişi yüklenemedi.',
                        style: TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  final runs = snapshot.data ?? const <CrawlRunModel>[];

                  if (runs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Bu görev henüz çalıştırılmadı.',
                        style: TextStyle(
                          color: Color(0xFF687580),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: runs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final run = runs[index];

                      return _RunHistoryCard(run: run);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunHistoryCard extends StatelessWidget {
  const _RunHistoryCard({required this.run});

  final CrawlRunModel run;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _runStatusIcon(run.runStatus),
                color: _runStatusColor(run.runStatus),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _runStatusLabel(run.runStatus),
                  style: TextStyle(
                    color: _runStatusColor(run.runStatus),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _dateLabel(run.queuedAt),
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _SmallStat(label: 'Bulgu', value: run.itemsFound.toString()),
              _SmallStat(
                label: 'Snapshot',
                value: run.snapshotsCreated.toString(),
              ),
              _SmallStat(label: 'Olay', value: run.eventsCreated.toString()),
              _SmallStat(label: 'Sinyal', value: run.signalsCreated.toString()),
              _SmallStat(
                label: 'Deneme',
                value: run.executionAttempt.toString(),
              ),
            ],
          ),
          if (run.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              run.errorMessage!,
              style: const TextStyle(color: Color(0xFFB42318), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyConnectionCard extends StatelessWidget {
  const _ReadOnlyConnectionCard({
    required this.profileName,
    required this.sourceName,
    required this.url,
  });

  final String profileName;
  final String sourceName;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _InfoLine(icon: Icons.manage_search_outlined, text: profileName),
          const SizedBox(height: 9),
          _InfoLine(icon: Icons.hub_outlined, text: sourceName),
          const SizedBox(height: 9),
          _InfoLine(icon: Icons.link_outlined, text: url),
        ],
      ),
    );
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

class _ReferenceWarning extends StatelessWidget {
  const _ReferenceWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDB022)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Color(0xFFB54708)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A2E0E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyJobView extends StatelessWidget {
  const _EmptyJobView({required this.onCreate});

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
            Icons.radar_outlined,
            size: 64,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 18),
          const Text(
            'Henüz tarama görevi yok',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'İlk izlenen sayfanızı bir tarama göreviyle '
            'operasyon kuyruğuna bağlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('İlk Görevi Oluştur'),
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
        'Tarama görevlerini görüntülemek için giriş yapın.',
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
        ? 'Tarama görevleri indeksi hazırlanıyor.'
        : text.contains('permission-denied')
        ? 'Tarama görevlerini görüntüleme yetkiniz bulunmuyor.'
        : 'Tarama görevleri yüklenemedi.';

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

String _frequencyLabel(MonitoringScanFrequency value) {
  switch (value) {
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

String _priorityLabel(MonitoringPriority value) {
  switch (value) {
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

String _jobStatusLabel(MonitoringCrawlJobStatus value) {
  switch (value) {
    case MonitoringCrawlJobStatus.draft:
      return 'Taslak';
    case MonitoringCrawlJobStatus.active:
      return 'Aktif';
    case MonitoringCrawlJobStatus.paused:
      return 'Duraklatıldı';
    case MonitoringCrawlJobStatus.disabled:
      return 'Devre dışı';
    case MonitoringCrawlJobStatus.archived:
      return 'Arşivlendi';
  }
}

String _lastRunStatusLabel(MonitoringCrawlLastRunStatus value) {
  switch (value) {
    case MonitoringCrawlLastRunStatus.neverRun:
      return 'Henüz çalışmadı';
    case MonitoringCrawlLastRunStatus.success:
      return 'Son çalışma başarılı';
    case MonitoringCrawlLastRunStatus.partialSuccess:
      return 'Son çalışma kısmi';
    case MonitoringCrawlLastRunStatus.failed:
      return 'Son çalışma hatalı';
    case MonitoringCrawlLastRunStatus.blocked:
      return 'Son çalışma engelli';
    case MonitoringCrawlLastRunStatus.cancelled:
      return 'Son çalışma iptal';
  }
}

String _runStatusLabel(MonitoringCrawlRunStatus value) {
  switch (value) {
    case MonitoringCrawlRunStatus.queued:
      return 'Kuyrukta';
    case MonitoringCrawlRunStatus.running:
      return 'Çalışıyor';
    case MonitoringCrawlRunStatus.success:
      return 'Başarılı';
    case MonitoringCrawlRunStatus.partialSuccess:
      return 'Kısmi başarılı';
    case MonitoringCrawlRunStatus.failed:
      return 'Başarısız';
    case MonitoringCrawlRunStatus.blocked:
      return 'Engellendi';
    case MonitoringCrawlRunStatus.cancelled:
      return 'İptal edildi';
  }
}

IconData _runStatusIcon(MonitoringCrawlRunStatus value) {
  switch (value) {
    case MonitoringCrawlRunStatus.queued:
      return Icons.schedule_outlined;
    case MonitoringCrawlRunStatus.running:
      return Icons.sync_outlined;
    case MonitoringCrawlRunStatus.success:
      return Icons.check_circle_outline;
    case MonitoringCrawlRunStatus.partialSuccess:
      return Icons.rule_outlined;
    case MonitoringCrawlRunStatus.failed:
      return Icons.error_outline;
    case MonitoringCrawlRunStatus.blocked:
      return Icons.block_outlined;
    case MonitoringCrawlRunStatus.cancelled:
      return Icons.cancel_outlined;
  }
}

Color _runStatusColor(MonitoringCrawlRunStatus value) {
  switch (value) {
    case MonitoringCrawlRunStatus.queued:
      return const Color(0xFFB54708);
    case MonitoringCrawlRunStatus.running:
      return const Color(0xFF175CD3);
    case MonitoringCrawlRunStatus.success:
      return const Color(0xFF027A48);
    case MonitoringCrawlRunStatus.partialSuccess:
      return const Color(0xFFB54708);
    case MonitoringCrawlRunStatus.failed:
      return const Color(0xFFB42318);
    case MonitoringCrawlRunStatus.blocked:
      return const Color(0xFFB42318);
    case MonitoringCrawlRunStatus.cancelled:
      return const Color(0xFF667085);
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
