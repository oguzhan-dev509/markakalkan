import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/admin/data/internal_provisioning_dry_run_service.dart';
import 'package:markakalkan/features/admin/data/internal_real_provisioning_controller.dart';
import 'package:markakalkan/features/admin/data/platform_admin_access_service.dart';
import 'package:markakalkan/features/admin/models/internal_provisioning_dry_run_result.dart';
import 'package:markakalkan/features/admin/models/internal_real_provisioning_gate.dart';
import 'package:markakalkan/features/admin/models/platform_admin_access.dart';

class ManagementCenterPage extends StatefulWidget {
  const ManagementCenterPage({super.key});

  @override
  State<ManagementCenterPage> createState() => _ManagementCenterPageState();
}

class _ManagementCenterPageState extends State<ManagementCenterPage> {
  final PlatformAdminAccessService _accessService =
      PlatformAdminAccessService();

  late Future<PlatformAdminAccess> _accessFuture;

  @override
  void initState() {
    super.initState();
    _accessFuture = _accessService.getMyAccess();
  }

  void _retry() {
    setState(() {
      _accessFuture = _accessService.getMyAccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'MarkaKalkan Yönetim Merkezi',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<PlatformAdminAccess>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _AccessMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Yönetim erişimi doğrulanamadı',
              message:
                  'Sunucu bağlantısı kurulamadı. Bağlantınızı kontrol ederek '
                  'yeniden deneyin.',
              actionLabel: 'Yeniden Dene',
              onAction: _retry,
            );
          }

          final access = snapshot.data;
          if (access == null || !access.isSuperAdmin) {
            return const _AccessMessage(
              icon: Icons.lock_outline,
              title: 'Erişim reddedildi',
              message: 'Bu alana erişim yetkiniz bulunmuyor.',
            );
          }

          return _AuthorizedManagementCenter(access: access);
        },
      ),
    );
  }
}

class _AuthorizedManagementCenter extends StatelessWidget {
  const _AuthorizedManagementCenter({required this.access});

  final PlatformAdminAccess access;

  @override
  Widget build(BuildContext context) {
    final name = access.displayName.isEmpty
        ? 'MarkaKalkan yöneticisi'
        : access.displayName;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;

                    final identity = Column(
                      crossAxisAlignment: isNarrow
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          textAlign: isNarrow
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          access.email,
                          textAlign: isNarrow
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            color: Color(0xFFD9E5EA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: isNarrow
                              ? WrapAlignment.center
                              : WrapAlignment.start,
                          children: access.roles
                              .map((role) => _RoleBadge(role: role))
                              .toList(growable: false),
                        ),
                      ],
                    );

                    final icon = Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF254D60),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: MarkaKalkanTheme.teal,
                        size: 40,
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [icon, const SizedBox(height: 20), identity],
                      );
                    }

                    return Row(
                      children: [
                        icon,
                        const SizedBox(width: 22),
                        Expanded(child: identity),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Yönetim Modülleri',
                style: TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Platform başvurularını ve kamuya açık sahte ikiz '
                'karşılaştırmalarını güvenli yönetim akışıyla inceleyin.',
                style: TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width < 720 ? 1 : 2;
                  const spacing = 18.0;
                  final cardWidth =
                      (width - ((columns - 1) * spacing)) / columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: const _ManagementModuleCard(
                          title: 'Marka Başvuruları',
                          description:
                              'Başvuruları inceleyin, değerlendirmeye alın, '
                              'onaylayın veya gerekçeli olarak reddedin.',
                          icon: Icons.fact_check_outlined,
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey<String>(
                          'counterfeit-twin-admin-review-action',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            AppRouter.openCounterfeitTwinReviewQueue(context),
                        child: SizedBox(
                          width: cardWidth,
                          child: const _ManagementModuleCard(
                            title: 'Sahte İkiz Radarı',
                            description:
                                'Kullanıcı bildirimlerini, delilleri ve kamu '
                                'karşılaştırması yayın kararlarını yönetin.',
                            icon: Icons.radar_outlined,
                            actionLabel: 'İnceleme kuyruğunu aç',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              const _InternalProvisioningDryRunPanel(),
              const SizedBox(height: 18),
              const _InternalRealProvisioningPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalRealProvisioningPanel extends StatefulWidget {
  const _InternalRealProvisioningPanel();

  @override
  State<_InternalRealProvisioningPanel> createState() =>
      _InternalRealProvisioningPanelState();
}

class _InternalRealProvisioningPanelState
    extends State<_InternalRealProvisioningPanel> {
  late final InternalRealProvisioningController _controller;
  late final Future<bool> _ready;
  String? _safeError;

  @override
  void initState() {
    super.initState();
    _controller = InternalRealProvisioningController()..addListener(_refresh);
    _ready = _verifyReadiness();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<bool> _verifyReadiness() async {
    if (!InternalRealProvisioningGate.enabled ||
        FirebaseAuth.instance.currentUser == null ||
        !AppCheckBootstrap.instance.isReady) {
      return false;
    }
    return AppCheckBootstrap.instance.verifyTokenAcquisition();
  }

  Future<void> _confirmAndSubmit() async {
    if (!_controller.canSubmit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerçek provisioning onayı'),
        content: const Text(
          'Bu işlem internal tenant, marka ve üyelik kayıtlarını atomik olarak '
          'oluşturur. İşlemi yalnız canlı rollout ve pilot izni açıkken onaylayın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey<String>(
              'internal-real-provisioning-confirm-action',
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Gerçek işlemi onaylıyorum'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _safeError = null);
    try {
      await _controller.submitConfirmed(confirmed: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _safeError = 'Gerçek provisioning güvenli biçimde tamamlanamadı.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;
    final submitting =
        _controller.state == InternalRealProvisioningSubmissionState.submitting;
    return Container(
      key: const ValueKey<String>('internal-real-provisioning-panel'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Internal Real Provisioning',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Varsayılan olarak kapalıdır ve yalnız tek pilot için açık onayla çalışır.',
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: _ready,
            builder: (context, snapshot) {
              final ready = snapshot.data == true;
              return FilledButton.icon(
                key: const ValueKey<String>(
                  'internal-real-provisioning-action',
                ),
                onPressed: ready && _controller.canSubmit
                    ? _confirmAndSubmit
                    : null,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(
                  submitting ? 'İşleniyor…' : 'Gerçek provisioning başlat',
                ),
              );
            },
          ),
          if (_safeError != null) ...[
            const SizedBox(height: 14),
            Text(_safeError!, style: const TextStyle(color: Colors.red)),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            Text(
              'Sonuç: ${result.outcome.wireValue} · commit: '
              '${result.transactionCommitted} · rollout: ${result.rolloutMode}',
              key: const ValueKey<String>(
                'internal-real-provisioning-safe-result',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _InternalProvisioningDryRunPanel extends StatefulWidget {
  const _InternalProvisioningDryRunPanel();

  @override
  State<_InternalProvisioningDryRunPanel> createState() =>
      _InternalProvisioningDryRunPanelState();
}

class _InternalProvisioningDryRunPanelState
    extends State<_InternalProvisioningDryRunPanel> {
  final InternalProvisioningDryRunService _service =
      InternalProvisioningDryRunService();
  late final Future<bool> _tokenVerified;
  bool _submitting = false;
  InternalProvisioningDryRunResult? _result;
  String? _safeError;

  @override
  void initState() {
    super.initState();
    _tokenVerified = AppCheckBootstrap.instance.verifyTokenAcquisition();
  }

  Future<void> _run() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _result = null;
      _safeError = null;
    });
    try {
      final result = await _service.run();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _safeError = 'Dry-run güvenli biçimde tamamlanamadı.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('internal-provisioning-dry-run-panel'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Internal Provisioning Dry-Run',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yalnız doğrulama yapar; tenant, marka veya üyelik oluşturmaz.',
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: _tokenVerified,
            builder: (context, snapshot) {
              final verified = snapshot.data == true;
              return FilledButton.icon(
                key: const ValueKey<String>(
                  'internal-provisioning-dry-run-action',
                ),
                onPressed: verified && !_submitting ? _run : null,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  _submitting ? 'Doğrulanıyor…' : 'Güvenli dry-run çalıştır',
                ),
              );
            },
          ),
          if (_safeError != null) ...[
            const SizedBox(height: 14),
            Text(_safeError!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 14),
            Text(
              'Sonuç: ${_result!.outcome.wireValue} · commit: '
              '${_result!.transactionCommitted} · rollout: '
              '${_result!.rolloutMode}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              <String?>[
                _result!.tenantId,
                _result!.brandId,
                _result!.membershipId,
                _result!.receiptId,
                _result!.auditEventId,
              ].map(_maskIdentifier).join(' · '),
              key: const ValueKey<String>(
                'internal-provisioning-masked-identifiers',
              ),
              style: const TextStyle(color: Color(0xFF687580)),
            ),
          ],
        ],
      ),
    );
  }
}

String _maskIdentifier(String? value) {
  if (value == null || value.isEmpty) return '—';
  if (value.length <= 8) return '${value.substring(0, 2)}…';
  return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final label = role == 'super_admin' ? 'Süper Yönetici' : role;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(99),
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

class _ManagementModuleCard extends StatelessWidget {
  const _ManagementModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    this.actionLabel = 'Sıradaki aşamada etkinleştirilecek',
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: MarkaKalkanTheme.teal, size: 29),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != 'Sıradaki aşamada etkinleştirilecek')
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: MarkaKalkanTheme.blue,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: MarkaKalkanTheme.navy),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
