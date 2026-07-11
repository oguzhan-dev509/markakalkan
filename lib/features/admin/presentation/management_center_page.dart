import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/admin/data/platform_admin_access_service.dart';
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
            ],
          ),
        ),
      ),
    );
  }
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
