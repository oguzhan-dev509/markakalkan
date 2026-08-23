import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/features/auth/domain/markakalkan_auth_intent.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_command_repository.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

typedef InterventionLegalLoginOpener =
    Future<bool?> Function(BuildContext context);
typedef InterventionLegalAuthenticationResolver =
    Future<bool> Function(bool forceRefresh);

final class InterventionLegalCreateMatterHandoff {
  const InterventionLegalCreateMatterHandoff({
    required this.tenantId,
    required this.canonicalBrandId,
    required this.caseId,
  });

  final String tenantId;
  final String canonicalBrandId;
  final String caseId;
}

class InterventionLegalHubPage extends StatefulWidget {
  const InterventionLegalHubPage({
    super.key,
    this.repository,
    this.commandRepository,
    this.createMatterHandoff,
    this.authenticationChanges,
    this.loginOpener,
    this.authenticationResolver,
    this.appCheckReadinessResolver,
  });

  final InterventionLegalWorkspaceRepository? repository;
  final InterventionLegalCommandRepository? commandRepository;
  final InterventionLegalCreateMatterHandoff? createMatterHandoff;
  final Stream<bool>? authenticationChanges;
  final InterventionLegalLoginOpener? loginOpener;
  final InterventionLegalAuthenticationResolver? authenticationResolver;
  final Future<void> Function()? appCheckReadinessResolver;

  @override
  State<InterventionLegalHubPage> createState() =>
      _InterventionLegalHubPageState();
}

class _InterventionLegalHubPageState extends State<InterventionLegalHubPage> {
  late final InterventionLegalWorkspaceRepository _repository;
  late final InterventionLegalCommandRepository? _commandRepository;

  StreamSubscription<bool>? _authenticationSubscription;
  InterventionLegalWorkspaceSnapshot? _snapshot;
  Object? _error;
  Future<void>? _reloadInFlight;
  bool _authenticationResolved = false;
  bool _authenticationRequired = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableInterventionLegalWorkspaceRepository();

    _commandRepository =
        widget.commandRepository ??
        (widget.repository == null
            ? CallableInterventionLegalCommandRepository()
            : null);
    final injectedAuthenticationChanges = widget.authenticationChanges;
    if (injectedAuthenticationChanges != null) {
      _observeAuthentication(injectedAuthenticationChanges);
      return;
    }

    if (widget.repository != null) {
      _authenticationResolved = true;
      _reload();
      return;
    }

    _observeAuthentication(
      FirebaseAuth.instance.idTokenChanges().map((user) => user != null),
    );
  }

  void _observeAuthentication(Stream<bool> changes) {
    _authenticationSubscription = changes.distinct().listen(
      _handleAuthentication,
      onError: _handleAuthenticationError,
    );
  }

  void _handleAuthentication(bool authenticated) {
    if (!mounted) {
      return;
    }

    if (!authenticated) {
      setState(() {
        _authenticationResolved = true;
        _authenticationRequired = true;
        _snapshot = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    final shouldReload =
        !_authenticationResolved ||
        _authenticationRequired ||
        _snapshot == null;

    setState(() {
      _authenticationResolved = true;
      _authenticationRequired = false;
      _error = null;
    });

    if (shouldReload) {
      unawaited(_reload());
    }
  }

  void _handleAuthenticationError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    setState(() {
      _authenticationResolved = true;
      _authenticationRequired = false;
      _loading = false;
      _error = error;
    });
  }

  Future<void> _openLogin() async {
    final opener = widget.loginOpener;
    bool? result;

    if (opener != null) {
      result = await opener(context);
    } else {
      final navigator = Navigator.of(context);
      result = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const BrandLoginPage(
            intent: MarkaKalkanAuthIntent.generalAccount,
          ),
        ),
      );
    }

    if (!mounted || result != true) {
      return;
    }

    await _reconcileAuthentication(forceRefresh: true);
  }

  Future<bool> _resolveFirebaseAuthentication(bool forceRefresh) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    if (forceRefresh) {
      await user.getIdToken(true);
    }
    return true;
  }

  Future<void> _reconcileAuthentication({required bool forceRefresh}) async {
    final resolver =
        widget.authenticationResolver ?? _resolveFirebaseAuthentication;

    try {
      final authenticated = await resolver(forceRefresh);
      if (!mounted) {
        return;
      }

      if (!authenticated) {
        _handleAuthentication(false);
        return;
      }

      final shouldReload = _snapshot == null || _authenticationRequired;
      _handleAuthentication(true);
      if (shouldReload) {
        await _reload();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authenticationResolved = true;
        _authenticationRequired = false;
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _ensureAppCheckReady() async {
    final resolver = widget.appCheckReadinessResolver;
    if (resolver != null) {
      await resolver();
      return;
    }

    final productionRepository =
        widget.repository == null && widget.authenticationChanges == null;
    if (!productionRepository) {
      return;
    }

    await AppCheckBootstrap.instance.ensureReady();
  }

  Future<InterventionLegalWorkspaceSnapshot>
  _loadWorkspaceWithAuthRecovery() async {
    await _ensureAppCheckReady();
    try {
      return await _repository.loadWorkspace();
    } catch (error) {
      final productionRepository =
          widget.repository == null && widget.authenticationChanges == null;
      if (!productionRepository || !_isUnauthenticatedError(error)) {
        rethrow;
      }

      final authenticated = await _resolveFirebaseAuthentication(true);
      if (!authenticated) {
        rethrow;
      }
      return _repository.loadWorkspace();
    }
  }

  Future<void> _reload() {
    final activeRequest = _reloadInFlight;
    if (activeRequest != null) {
      return activeRequest;
    }

    late final Future<void> request;
    request = _performReload().whenComplete(() {
      if (identical(_reloadInFlight, request)) {
        _reloadInFlight = null;
      }
    });
    _reloadInFlight = request;
    return request;
  }

  Future<void> _performReload() async {
    if (mounted) {
      setState(() {
        _loading = _snapshot == null;
        _error = null;
      });
    }

    try {
      final snapshot = await _loadWorkspaceWithAuthRecovery();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
        _authenticationRequired = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  bool _isUnauthenticatedError(Object? error) {
    return error is FirebaseFunctionsException &&
        error.code == 'unauthenticated';
  }

  @override
  void dispose() {
    _authenticationSubscription?.cancel();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is AppCheckUnavailableException) {
      return 'Uygulama doğrulaması tamamlanamadı. Sayfayı yenileyin.';
    }
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Oturum sunucu tarafından doğrulanamadı. '
              'Marka Girişi ile oturumu yenileyin.';
        case 'failed-precondition':
          return 'Uygulama doğrulaması tamamlanamadı. Sayfayı yenileyin.';
        case 'permission-denied':
          return 'Bu çalışma alanını görüntüleme yetkiniz bulunmuyor.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Hizmete şu anda ulaşılamıyor. Biraz sonra yeniden deneyin.';
      }
      return error.message ?? 'Müdahale ve Hukuk Merkezi yüklenemedi.';
    }
    if (error is FormatException) {
      return 'Çalışma alanı yanıtı doğrulanamadı.';
    }
    return 'Müdahale ve Hukuk Merkezi yüklenemedi.';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final authenticationRequired = _authenticationRequired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müdahale ve Hukuk'),
        actions: [
          IconButton(
            key: const ValueKey<String>('intervention-legal-refresh'),
            tooltip: 'Yenile',
            onPressed: _loading || authenticationRequired ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: !_authenticationResolved && snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : authenticationRequired && snapshot == null
            ? _AuthenticationRequiredPanel(
                onLogin: _openLogin,
                onRetry: () => _reconcileAuthentication(forceRefresh: true),
              )
            : _loading && snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && snapshot == null
            ? _ErrorPanel(message: _errorMessage(_error!), onRetry: _reload)
            : RefreshIndicator(
                onRefresh: _reload,
                child: _WorkspaceBody(
                  snapshot: snapshot!,
                  createMatterHandoff: widget.createMatterHandoff,
                  refreshError: _error == null ? null : _errorMessage(_error!),
                  commandRepository: _commandRepository,
                  onCommandCompleted: _reload,
                ),
              ),
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.snapshot,
    this.createMatterHandoff,
    this.refreshError,
    required this.commandRepository,
    required this.onCommandCompleted,
  });

  final InterventionLegalWorkspaceSnapshot snapshot;
  final InterventionLegalCreateMatterHandoff? createMatterHandoff;
  final String? refreshError;

  final InterventionLegalCommandRepository? commandRepository;
  final Future<void> Function() onCommandCompleted;
  @override
  Widget build(BuildContext context) {
    final matters = snapshot.matters;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const _HeroPanel(),
        const SizedBox(height: 16),
        const _ProcessStrip(),
        const SizedBox(height: 16),
        const _InformationGrid(),
        const SizedBox(height: 20),
        _SummaryGrid(counts: snapshot.counts),
        if (refreshError != null) ...[
          const SizedBox(height: 14),
          MaterialBanner(
            content: Text(refreshError!),
            actions: const [SizedBox.shrink()],
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hukuki dosyalar',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Son güncelleme: ${_formatDate(snapshot.generatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (createMatterHandoff != null && commandRepository != null) ...[
          _CreateLegalMatterPanel(
            handoff: createMatterHandoff!,
            repository: commandRepository!,
            onCompleted: onCommandCompleted,
          ),
          const SizedBox(height: 16),
        ],
        if (matters.isEmpty)
          const _EmptyState()
        else
          ...matters.map(
            (matter) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LegalMatterCard(
                matter: matter,
                commandRepository: commandRepository,
                onCommandCompleted: onCommandCompleted,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.gavel_outlined, size: 34),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doğrulanmış vakadan denetlenebilir hukuki müdahaleye',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hukuki dosyaları, durum geçişlerini, müşteri veya hukuk '
                    'uzmanı onaylarını ve değiştirilemez karar zincirini tek '
                    'çalışma alanında izleyin.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessStrip extends StatelessWidget {
  const _ProcessStrip();

  static const _steps = <(IconData, String)>[
    (Icons.folder_copy_outlined, 'Vaka ve delil bağlantısı'),
    (Icons.fact_check_outlined, 'Hukuki inceleme'),
    (Icons.verified_user_outlined, 'Yetkilendirme'),
    (Icons.description_outlined, 'Müdahale hazırlığı'),
    (Icons.account_balance_outlined, 'Başvuru ve sonuç'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 720
                ? constraints.maxWidth
                : (constraints.maxWidth - 48) / 5;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _steps
                  .asMap()
                  .entries
                  .map(
                    (entry) => SizedBox(
                      width: itemWidth,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            child: Text('${entry.key + 1}'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.$2,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}

class _InformationGrid extends StatelessWidget {
  const _InformationGrid();

  static const _items = <(IconData, String, String)>[
    (
      Icons.info_outline,
      'Bu bölüm ne işe yarar?',
      'Vaka kaynaklı hukuki dosyaları, onay taleplerini ve kararları birlikte '
          'görünür kılar.',
    ),
    (
      Icons.schedule_outlined,
      'Ne zaman kullanmalısınız?',
      'Doğrulanmış bir ihlal için platform, idari, adli veya sözleşmesel '
          'müdahale değerlendirmesi başladığında.',
    ),
    (
      Icons.checklist_outlined,
      'Bu işlem için ne gerekir?',
      'Yetkili kullanıcı, kanonik marka ve vaka bağlantısı ile hukuken '
          'doğrulanabilir kapsam bilgileri gerekir.',
    ),
    (
      Icons.inventory_2_outlined,
      'İşlem sonunda ne elde edersiniz?',
      'Sürümlü hukuki dosya, değiştirilemez onay kaydı ve denetlenebilir '
          'müdahale zinciri elde edersiniz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(item.$3),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.counts});

  final InterventionLegalWorkspaceCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, int)>[
      (Icons.folder_open_outlined, 'Toplam dosya', counts.legalMatterCount),
      (Icons.autorenew, 'Aktif dosya', counts.activeLegalMatterCount),
      (
        Icons.pending_actions_outlined,
        'Bekleyen onay',
        counts.pendingApprovalCount,
      ),
      (Icons.verified_outlined, 'Onaylanan', counts.approvedApprovalCount),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(item.$1),
                          const SizedBox(height: 8),
                          Text(
                            '${item.$3}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
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

class _CreateLegalMatterPanel extends StatefulWidget {
  const _CreateLegalMatterPanel({
    required this.handoff,
    required this.repository,
    required this.onCompleted,
  });

  final InterventionLegalCreateMatterHandoff handoff;
  final InterventionLegalCommandRepository repository;
  final Future<void> Function() onCompleted;

  @override
  State<_CreateLegalMatterPanel> createState() =>
      _CreateLegalMatterPanelState();
}

class _CreateLegalMatterPanelState extends State<_CreateLegalMatterPanel> {
  final TextEditingController _jurisdictionController = TextEditingController();
  final TextEditingController _matterScopeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _confirmed = false;
  bool _submitting = false;
  bool _completed = false;
  String? _message;

  @override
  void dispose() {
    _jurisdictionController.dispose();
    _matterScopeController.dispose();
    _countryController.dispose();
    _priorityController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (_submitting || _completed) return;

    final jurisdictionCode = _jurisdictionController.text.trim();
    final matterScopeCode = _matterScopeController.text.trim();
    final countryCode = _countryController.text.trim();

    if (jurisdictionCode.isEmpty ||
        matterScopeCode.isEmpty ||
        countryCode.isEmpty) {
      setState(() {
        _message = 'Yargı alanı, müdahale kapsamı ve ülke kodu zorunludur.';
      });
      return;
    }

    if (!_confirmed) {
      setState(() {
        _message =
            'Yeni hukuki dosyanın bu vaka bağlamıyla oluşturulacağını onaylayın.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      await widget.repository.createLegalMatter(
        context: InterventionLegalCreateMatterContext(
          tenantId: widget.handoff.tenantId,
          canonicalBrandId: widget.handoff.canonicalBrandId,
          caseId: widget.handoff.caseId,
        ),
        input: InterventionLegalCreateMatterInput(
          jurisdictionCode: jurisdictionCode,
          matterScopeCode: matterScopeCode,
          countryCode: countryCode,
          priorityCode: _optional(_priorityController),
          title: _optional(_titleController),
        ),
      );
      await widget.onCompleted();
      if (!mounted) return;
      setState(() {
        _completed = true;
        _message = 'Hukuki dosya oluşturuldu.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _message =
            'İşlem tamamlanamadı. Bilgileri kontrol edip yeniden deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('create-legal-matter-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yeni hukuki dosya',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Vaka ve marka bağlamı doğrulanmış çalışma alanından gelir ve değiştirilemez. '
              'Alanları doldurmak veya seçim yapmak tek başına işlem çalıştırmaz.',
            ),
            const SizedBox(height: 12),
            SelectableText('Vaka kimliği: ${widget.handoff.caseId}'),
            SelectableText('Marka kimliği: ${widget.handoff.canonicalBrandId}'),
            SelectableText('Tenant kimliği: ${widget.handoff.tenantId}'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('create-matter-jurisdiction-code'),
              controller: _jurisdictionController,
              enabled: !_submitting && !_completed,
              decoration: const InputDecoration(
                labelText: 'Yargı alanı kodu',
                helperText: 'Dil bağımsız operasyon kodu kullanın.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create-matter-scope-code'),
              controller: _matterScopeController,
              enabled: !_submitting && !_completed,
              decoration: const InputDecoration(
                labelText: 'Müdahale kapsamı kodu',
                helperText: 'Dil bağımsız operasyon kodu kullanın.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create-matter-country-code'),
              controller: _countryController,
              enabled: !_submitting && !_completed,
              decoration: const InputDecoration(
                labelText: 'Ülke kodu',
                helperText: 'Sözleşmenin kabul ettiği ülke kodunu kullanın.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create-matter-priority-code'),
              controller: _priorityController,
              enabled: !_submitting && !_completed,
              decoration: const InputDecoration(
                labelText: 'Öncelik kodu (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create-matter-title'),
              controller: _titleController,
              enabled: !_submitting && !_completed,
              decoration: const InputDecoration(
                labelText: 'Dosya başlığı (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('create-matter-confirm'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: _submitting || _completed
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'Bu doğrulanmış vaka bağlamıyla yeni hukuki dosya oluşturulacağını onaylıyorum.',
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('create-legal-matter-submit'),
              onPressed: _submitting || _completed || !_confirmed
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gavel),
              label: Text(
                _submitting ? 'Oluşturuluyor…' : 'Hukuki dosyayı oluştur',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalMatterCard extends StatelessWidget {
  const _LegalMatterCard({
    required this.matter,
    required this.commandRepository,
    required this.onCommandCompleted,
  });

  final InterventionLegalMatterSummary matter;
  final InterventionLegalCommandRepository? commandRepository;
  final Future<void> Function() onCommandCompleted;

  @override
  Widget build(BuildContext context) {
    final title =
        matter.title ?? 'Hukuki dosya ${_shortId(matter.legalMatterId)}';

    final activeCommandRepository = commandRepository;
    final matterCard = Card(
      key: ValueKey<String>('legal-matter-${matter.legalMatterId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.balance_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: _matterStatusLabel(matter.status),
                icon: Icons.account_tree_outlined,
              ),
              _StatusChip(
                label: 'Sürüm ${matter.version}',
                icon: Icons.history_outlined,
              ),
              if (matter.priorityCode != null)
                _StatusChip(
                  label: _priorityLabel(matter.priorityCode!),
                  icon: Icons.flag_outlined,
                ),
              _StatusChip(
                label: matter.jurisdictionCode,
                icon: Icons.public_outlined,
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Divider(),
          _DetailGrid(
            items: [
              ('Hukuki dosya kimliği', matter.legalMatterId),
              ('Vaka kimliği', matter.caseId),
              ('Marka kimliği', matter.canonicalBrandId),
              ('Kapsam kodu', matter.matterScopeCode ?? 'Belirtilmedi'),
              ('Kaynak sistemi', matter.sourceSystemCode ?? 'Belirtilmedi'),
              ('Son güncelleme', _formatDate(matter.updatedAt)),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Onay talepleri',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (matter.approvalRequests.isEmpty)
            const _InlineEmpty(message: 'Bu dosyada onay talebi bulunmuyor.')
          else
            ...matter.approvalRequests.map(
              (request) => _ApprovalRequestTile(request: request),
            ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Değiştirilemez kararlar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (matter.approvalDecisions.isEmpty)
            const _InlineEmpty(message: 'Henüz karar kaydı bulunmuyor.')
          else
            ...matter.approvalDecisions.map(
              (decision) => _ApprovalDecisionTile(decision: decision),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        matterCard,
        if (activeCommandRepository != null) ...[
          const SizedBox(height: 12),
          _InterventionLegalMatterCommandPanel(
            key: ValueKey<String>(
              'legal-matter-actions-${matter.legalMatterId}',
            ),
            matter: matter,
            repository: activeCommandRepository,
            onCompleted: onCommandCompleted,
          ),
        ],
      ],
    );
  }
}

class _ApprovalRequestTile extends StatelessWidget {
  const _ApprovalRequestTile({required this.request});

  final InterventionLegalApprovalRequestSummary request;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        request.status == 'approved'
            ? Icons.verified_outlined
            : request.status == 'rejected'
            ? Icons.cancel_outlined
            : Icons.pending_actions_outlined,
      ),
      title: Text(_approvalTypeLabel(request.approvalType)),
      subtitle: Text(
        '${_approvalStatusLabel(request.status)} · '
        'Talep sürümü ${request.version} · '
        '${_formatDate(request.updatedAt ?? request.createdAt)}',
      ),
      trailing: Text(_shortId(request.approvalRequestId)),
    );
  }
}

class _ApprovalDecisionTile extends StatelessWidget {
  const _ApprovalDecisionTile({required this.decision});

  final InterventionLegalApprovalDecisionSummary decision;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        decision.decision == 'approved'
            ? Icons.check_circle_outline
            : Icons.highlight_off_outlined,
      ),
      title: Text(decision.decision == 'approved' ? 'Onaylandı' : 'Reddedildi'),
      subtitle: Text(
        '${_decisionReasonLabel(decision.decisionReasonCode)} · '
        '${_formatDate(decision.decidedAt)}'
        '${decision.immutable ? ' · Değiştirilemez kayıt' : ''}',
      ),
      trailing: Text(_shortId(decision.decisionId)),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 680
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(item.$2),
                        ],
                      ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('intervention-legal-empty'),
      margin: EdgeInsets.zero,
      child: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.folder_off_outlined, size: 44),
            SizedBox(height: 12),
            Text(
              'Henüz hukuki dosya bulunmuyor.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Doğrulanmış bir vaka hukuki müdahale akışına aktarıldığında '
              'dosya burada görünür.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticationRequiredPanel extends StatelessWidget {
  const _AuthenticationRequiredPanel({
    required this.onLogin,
    required this.onRetry,
  });

  final Future<void> Function() onLogin;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        key: const ValueKey<String>('intervention-legal-auth-required'),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_outlined, size: 46),
                const SizedBox(height: 12),
                const Text(
                  'Müdahale ve Hukuk Merkezi için oturum açmanız gerekir.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mevcut MarkaKalkan hesabınızla giriş yaptıktan sonra çalışma '
                  'alanı otomatik olarak yeniden yüklenecektir.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey<String>(
                        'intervention-legal-login-action',
                      ),
                      onPressed: onLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Marka Girişi'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'intervention-legal-auth-retry',
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yeniden dene'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _matterStatusLabel(String value) {
  const labels = <String, String>{
    'intake_pending': 'Kabul bekliyor',
    'legal_review': 'Hukuki inceleme',
    'evidence_required': 'Delil gerekiyor',
    'strategy_preparation': 'Strateji hazırlanıyor',
    'awaiting_authorization': 'Yetkilendirme bekliyor',
    'approved': 'Onaylandı',
    'in_preparation': 'Hazırlanıyor',
    'submitted': 'Başvuru yapıldı',
    'in_progress': 'Devam ediyor',
    'awaiting_response': 'Cevap bekleniyor',
    'escalated': 'Üst incelemeye taşındı',
    'resolved': 'Çözüldü',
    'closed': 'Kapandı',
    'cancelled': 'İptal edildi',
    'archived': 'Arşivlendi',
  };
  return labels[value] ?? value;
}

String _approvalStatusLabel(String value) {
  const labels = <String, String>{
    'pending': 'Karar bekliyor',
    'approved': 'Onaylandı',
    'rejected': 'Reddedildi',
    'expired': 'Süresi doldu',
    'withdrawn': 'Geri çekildi',
  };
  return labels[value] ?? value;
}

String _approvalTypeLabel(String value) {
  const labels = <String, String>{
    'client_action_authorization': 'Müşteri işlem yetkilendirmesi',
    'client_budget_authorization': 'Müşteri bütçe yetkilendirmesi',
    'client_litigation_authorization': 'Dava yetkilendirmesi',
    'client_settlement_authorization': 'Uzlaşma yetkilendirmesi',
    'lawyer_legal_approval': 'Hukukçu onayı',
    'senior_legal_review': 'Kıdemli hukuk incelemesi',
  };
  return labels[value] ?? value;
}

String _decisionReasonLabel(String? value) {
  const labels = <String, String>{
    'client_action_authorized': 'Müşteri işlemi yetkilendirdi',
  };
  if (value == null) {
    return 'Gerekçe kodu bulunmuyor';
  }
  return labels[value] ?? value;
}

String _priorityLabel(String value) {
  const labels = <String, String>{
    'low': 'Düşük öncelik',
    'normal': 'Normal öncelik',
    'medium': 'Orta öncelik',
    'high': 'Yüksek öncelik',
    'urgent': 'Acil',
    'critical': 'Kritik',
  };
  return labels[value] ?? value;
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Tarih yok';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _shortId(String value) {
  if (value.length <= 12) {
    return value;
  }
  return '${value.substring(0, 8)}…';
}

const Map<String, List<String>> _legalMatterUiTransitions =
    <String, List<String>>{
      'intake_pending': <String>['legal_review', 'cancelled'],
      'legal_review': <String>[
        'evidence_required',
        'strategy_preparation',
        'cancelled',
      ],
      'evidence_required': <String>['legal_review', 'cancelled'],
      'strategy_preparation': <String>[
        'awaiting_authorization',
        'legal_review',
        'cancelled',
      ],
      'awaiting_authorization': <String>[
        'approved',
        'strategy_preparation',
        'cancelled',
      ],
      'approved': <String>['in_preparation', 'cancelled'],
      'in_preparation': <String>[
        'submitted',
        'in_progress',
        'awaiting_authorization',
        'cancelled',
      ],
      'submitted': <String>[
        'in_progress',
        'awaiting_response',
        'escalated',
        'resolved',
      ],
      'in_progress': <String>['awaiting_response', 'escalated', 'resolved'],
      'awaiting_response': <String>['in_progress', 'escalated', 'resolved'],
      'escalated': <String>['in_progress', 'awaiting_response', 'resolved'],
      'resolved': <String>['closed', 'in_progress'],
      'closed': <String>['in_progress', 'archived'],
      'cancelled': <String>['archived'],
      'archived': <String>[],
    };

const List<String> _legalApprovalTypes = <String>[
  'lawyer_legal_approval',
  'client_action_authorization',
  'client_budget_authorization',
];

String _legalMatterTransitionLabel(String status) {
  return switch (status) {
    'intake_pending' => 'Kabul bekliyor',
    'legal_review' => 'Hukuki inceleme',
    'evidence_required' => 'Ek delil gerekli',
    'strategy_preparation' => 'Müdahale stratejisi hazırlanıyor',
    'awaiting_authorization' => 'Yetkilendirme bekliyor',
    'approved' => 'Onaylandı',
    'in_preparation' => 'İşlem hazırlanıyor',
    'submitted' => 'Resmî işleme sunuldu',
    'in_progress' => 'İşlem devam ediyor',
    'awaiting_response' => 'Cevap bekleniyor',
    'escalated' => 'Üst aşamaya taşındı',
    'resolved' => 'Sonuçlandı',
    'closed' => 'Kapatıldı',
    'cancelled' => 'İptal edildi',
    'archived' => 'Arşivlendi',
    _ => status,
  };
}

String _legalApprovalTypeLabel(String value) {
  return switch (value) {
    'lawyer_legal_approval' => 'Avukat hukuki onayı',
    'client_action_authorization' => 'Müşteri işlem yetkilendirmesi',
    'client_budget_authorization' => 'Müşteri bütçe yetkilendirmesi',
    _ => value,
  };
}

String _legalDecisionLabel(String value) {
  return switch (value) {
    'approved' => 'Onayla',
    'rejected' => 'Reddet',
    _ => value,
  };
}

final class _InterventionLegalMatterCommandPanel extends StatefulWidget {
  const _InterventionLegalMatterCommandPanel({
    super.key,
    required this.matter,
    required this.repository,
    required this.onCompleted,
  });

  final InterventionLegalMatterSummary matter;
  final InterventionLegalCommandRepository repository;
  final Future<void> Function() onCompleted;

  @override
  State<_InterventionLegalMatterCommandPanel> createState() =>
      _InterventionLegalMatterCommandPanelState();
}

final class _InterventionLegalMatterCommandPanelState
    extends State<_InterventionLegalMatterCommandPanel> {
  final TextEditingController _transitionReasonController =
      TextEditingController();
  final TextEditingController _transitionNoteController =
      TextEditingController();
  final TextEditingController _approvalReasonController =
      TextEditingController();
  final TextEditingController _approvalNoteController = TextEditingController();

  String? _selectedTransition;
  String? _selectedApprovalType;
  bool _busy = false;

  List<String> get _allowedTransitions =>
      _legalMatterUiTransitions[widget.matter.status] ?? const <String>[];

  List<InterventionLegalApprovalRequestSummary> get _pendingApprovals => widget
      .matter
      .approvalRequests
      .where((request) => request.status == 'pending')
      .toList(growable: false);

  @override
  void didUpdateWidget(
    covariant _InterventionLegalMatterCommandPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matter.status != widget.matter.status ||
        oldWidget.matter.version != widget.matter.version) {
      _selectedTransition = null;
      _transitionReasonController.clear();
      _transitionNoteController.clear();
    }
  }

  @override
  void dispose() {
    _transitionReasonController.dispose();
    _transitionNoteController.dispose();
    _approvalReasonController.dispose();
    _approvalNoteController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    if (error.code == 'aborted') {
      return 'Çalışma alanı değişti. Güncel sürümü yükleyip işlemi yeniden '
          'değerlendirin. Otomatik tekrar yapılmadı.';
    }
    if (error.code == 'permission-denied') {
      return 'Bu hukuki işlem için yetkiniz bulunmuyor.';
    }
    if (error.code == 'failed-precondition') {
      return 'İşlem mevcut hukuki durum için uygun değil.';
    }
    if (error.code == 'unauthenticated') {
      return 'Oturum doğrulanamadı. Marka Girişi ile oturumu yenileyin.';
    }
    return 'Hukuki işlem tamamlanamadı (${error.code}).';
  }

  Future<void> _runCommand(
    Future<InterventionLegalCommandResponse> Function() command, {
    required String successMessage,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await command();
      await widget.onCompleted();
      if (!mounted) {
        return;
      }
      _message(successMessage);
    } on FirebaseFunctionsException catch (error) {
      _message(_functionsErrorMessage(error));
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'İşlem alanlarını kontrol edin.');
    } catch (_) {
      _message('Hukuki işlem tamamlanamadı.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitTransition() async {
    final nextStatus = _selectedTransition;
    final reasonCode = _transitionReasonController.text.trim();
    if (nextStatus == null || reasonCode.isEmpty) {
      _message('Sıradaki durum ve geçiş gerekçesi zorunludur.');
      return;
    }
    await _runCommand(
      () => widget.repository.transitionLegalMatter(
        context: InterventionLegalMatterVersionContext(
          legalMatterId: widget.matter.legalMatterId,
          expectedVersion: widget.matter.version,
        ),
        input: InterventionLegalTransitionInput(
          nextStatus: nextStatus,
          reasonCode: reasonCode,
          note: _transitionNoteController.text,
        ),
      ),
      successMessage: 'Hukuki dosya durumu güncellendi.',
    );
  }

  Future<void> _submitApprovalRequest() async {
    final approvalType = _selectedApprovalType;
    final reasonCode = _approvalReasonController.text.trim();
    if (approvalType == null || reasonCode.isEmpty) {
      _message('Onay türü ve talep gerekçesi zorunludur.');
      return;
    }
    await _runCommand(
      () => widget.repository.createApprovalRequest(
        context: InterventionLegalApprovalRequestContext(
          legalMatterId: widget.matter.legalMatterId,
          expectedLegalMatterVersion: widget.matter.version,
        ),
        input: InterventionLegalApprovalRequestInput(
          approvalType: approvalType,
          requestReasonCode: reasonCode,
          requestNote: _approvalNoteController.text,
        ),
      ),
      successMessage: 'Onay / yetki talebi oluşturuldu.',
    );
  }

  Future<void> _evaluateApproval(
    InterventionLegalApprovalRequestSummary request,
  ) async {
    if (_busy || request.status != 'pending') {
      return;
    }

    final draft = await showDialog<_ApprovalDecisionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ApprovalDecisionDialog(request: request),
    );
    if (draft == null || !mounted) {
      return;
    }

    await _runCommand(
      () => widget.repository.recordApprovalDecision(
        context: InterventionLegalApprovalDecisionContext(
          approvalRequestId: request.approvalRequestId,
          legalMatterId: request.legalMatterId,
          approvalType: request.approvalType,
          expectedApprovalRequestVersion: request.version,
        ),
        input: InterventionLegalApprovalDecisionInput(
          decision: draft.decision,
          decisionReasonCode: draft.reasonCode,
          decisionNote: draft.note,
        ),
      ),
      successMessage: 'Değiştirilemez onay kararı kaydedildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowedTransitions = _allowedTransitions;
    final pendingApprovals = _pendingApprovals;

    return Card(
      key: ValueKey<String>(
        'legal-matter-command-panel-${widget.matter.legalMatterId}',
      ),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hukuki işlemler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kimlik ve sürüm bilgileri çalışma alanından alınır. '
              'Kartı açmak veya seçim yapmak tek başına işlem çalıştırmaz.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Text(
              'Sıradaki doğru işlem',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (allowedTransitions.isEmpty)
              const Text('Bu hukuki dosya için yeni durum geçişi bulunmuyor.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'mhl-transition-status-${widget.matter.legalMatterId}',
                ),
                initialValue: _selectedTransition,
                decoration: const InputDecoration(
                  labelText: 'Sıradaki durum',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final status in allowedTransitions)
                    DropdownMenuItem<String>(
                      key: ValueKey<String>(
                        'mhl-transition-option-'
                        '${widget.matter.legalMatterId}-$status',
                      ),
                      value: status,
                      child: Text(_legalMatterTransitionLabel(status)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _selectedTransition = value),
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey<String>(
                  'mhl-transition-reason-${widget.matter.legalMatterId}',
                ),
                controller: _transitionReasonController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Geçiş gerekçe kodu',
                  helperText: 'Dil bağımsız operasyon kodu kullanın.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey<String>(
                  'mhl-transition-note-${widget.matter.legalMatterId}',
                ),
                controller: _transitionNoteController,
                enabled: !_busy,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: ValueKey<String>(
                    'mhl-transition-submit-${widget.matter.legalMatterId}',
                  ),
                  onPressed: _busy ? null : _submitTransition,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Durum geçişini uygula'),
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Onay / yetki talebi oluştur',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'mhl-approval-type-${widget.matter.legalMatterId}',
              ),
              initialValue: _selectedApprovalType,
              decoration: const InputDecoration(
                labelText: 'Onay / yetki türü',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final approvalType in _legalApprovalTypes)
                  DropdownMenuItem<String>(
                    key: ValueKey<String>(
                      'mhl-approval-type-option-'
                      '${widget.matter.legalMatterId}-$approvalType',
                    ),
                    value: approvalType,
                    child: Text(_legalApprovalTypeLabel(approvalType)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _selectedApprovalType = value),
            ),
            const SizedBox(height: 10),
            TextField(
              key: ValueKey<String>(
                'mhl-approval-reason-${widget.matter.legalMatterId}',
              ),
              controller: _approvalReasonController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Talep gerekçe kodu',
                helperText: 'Dil bağımsız operasyon kodu kullanın.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: ValueKey<String>(
                'mhl-approval-note-${widget.matter.legalMatterId}',
              ),
              controller: _approvalNoteController,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Talep notu (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: ValueKey<String>(
                  'mhl-approval-submit-${widget.matter.legalMatterId}',
                ),
                onPressed: _busy ? null : _submitApprovalRequest,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Onay talebi oluştur'),
              ),
            ),
            if (pendingApprovals.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Değerlendirme bekleyen onay talepleri',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final request in pendingApprovals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_legalApprovalTypeLabel(request.approvalType)),
                  subtitle: Text(
                    'Talep sürümü ${request.version} · '
                    '${request.requestReasonCode}',
                  ),
                  trailing: OutlinedButton(
                    key: ValueKey<String>(
                      'mhl-approval-evaluate-${request.approvalRequestId}',
                    ),
                    onPressed: _busy ? null : () => _evaluateApproval(request),
                    child: const Text('Onay talebini değerlendir'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ApprovalDecisionDraft {
  const _ApprovalDecisionDraft({
    required this.decision,
    required this.reasonCode,
    required this.note,
  });

  final String decision;
  final String reasonCode;
  final String note;
}

final class _ApprovalDecisionDialog extends StatefulWidget {
  const _ApprovalDecisionDialog({required this.request});

  final InterventionLegalApprovalRequestSummary request;

  @override
  State<_ApprovalDecisionDialog> createState() =>
      _ApprovalDecisionDialogState();
}

final class _ApprovalDecisionDialogState
    extends State<_ApprovalDecisionDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _decision;
  String? _validationMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final decision = _decision;
    final reason = _reasonController.text.trim();
    if (decision == null || reason.isEmpty) {
      setState(() {
        _validationMessage = 'Karar ve karar gerekçe kodu zorunludur.';
      });
      return;
    }

    Navigator.of(context).pop(
      _ApprovalDecisionDraft(
        decision: decision,
        reasonCode: reason,
        note: _noteController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ValueKey<String>(
        'mhl-approval-decision-dialog-${widget.request.approvalRequestId}',
      ),
      title: const Text('Onay talebini değerlendir'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bu karar denetim zincirine değiştirilemez kayıt olarak '
                'eklenecektir. Kaydetmeden önce karar ve gerekçeyi kontrol edin.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'mhl-decision-value-${widget.request.approvalRequestId}',
                ),
                initialValue: _decision,
                decoration: const InputDecoration(
                  labelText: 'Karar',
                  border: OutlineInputBorder(),
                ),
                items: const <String>['approved', 'rejected']
                    .map(
                      (value) => DropdownMenuItem<String>(
                        key: ValueKey<String>('mhl-decision-option-$value'),
                        value: value,
                        child: Text(_legalDecisionLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _decision = value),
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey<String>(
                  'mhl-decision-reason-${widget.request.approvalRequestId}',
                ),
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Karar gerekçe kodu',
                  helperText: 'Dil bağımsız operasyon kodu kullanın.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey<String>(
                  'mhl-decision-note-${widget.request.approvalRequestId}',
                ),
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Karar notu (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: ValueKey<String>(
            'mhl-decision-confirm-${widget.request.approvalRequestId}',
          ),
          onPressed: _confirm,
          child: const Text('Onayla ve kaydet'),
        ),
      ],
    );
  }
}
