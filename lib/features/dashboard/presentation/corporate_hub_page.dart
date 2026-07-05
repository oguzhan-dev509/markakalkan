import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class CorporateHubPage extends StatelessWidget {
  const CorporateHubPage({super.key});

  static const List<_CorporateModule> _modules = [
    _CorporateModule(
      id: 'brands',
      title: 'Markalarım',
      description:
          'Koruma altındaki markalarınızı görüntüleyin ve marka bazlı operasyon paneline geçin.',
      icon: Icons.verified_outlined,
      status: _ModuleStatus.active,
    ),
    _CorporateModule(
      id: 'new_brand',
      title: 'Yeni Marka Ekle',
      description:
          'Yeni bir markayı sahiplik ve yetki belgeleriyle incelemeye gönderin.',
      icon: Icons.add_business_outlined,
      status: _ModuleStatus.active,
    ),
    _CorporateModule(
      id: 'ip_documents',
      title: 'Fikri Mülkiyet ve Belgeler',
      description:
          'Marka tescili, patent, tasarım, lisans ve yetki belgelerini yönetin.',
      icon: Icons.workspace_premium_outlined,
      status: _ModuleStatus.active,
    ),
    _CorporateModule(
      id: 'traceability',
      title: 'Ürün Kimliği ve İzlenebilirlik',
      description:
          'Ürün, üretim partisi, tekil kod ve yaşam döngüsü kayıtlarını yönetin.',
      icon: Icons.fingerprint,
      status: _ModuleStatus.active,
    ),
    _CorporateModule(
      id: 'detective',
      title: 'Marka Dedektifi',
      description:
          'Tüketici doğrulaması, dijital araştırma ve saha dedektifi görevlerini yönetin.',
      icon: Icons.manage_search_outlined,
      status: _ModuleStatus.pilot,
    ),
    _CorporateModule(
      id: 'digital_market',
      title: 'Dijital Pazar İzleme',
      description:
          'Pazaryeri, sosyal medya, sahte site, alan adı ve yetkisiz satıcıları izleyin.',
      icon: Icons.public_outlined,
      status: _ModuleStatus.active,
    ),
    _CorporateModule(
      id: 'supply_security',
      title: 'Fason Üretim ve Tedarik Güvenliği',
      description:
          'Yetkili üretim, fire, sevk, fazla üretim ve tedarik sapmalarını takip edin.',
      icon: Icons.factory_outlined,
      status: _ModuleStatus.pilot,
    ),
    _CorporateModule(
      id: 'risk_scans',
      title: 'Risk ve Şüpheli Taramalar',
      description:
          'Tekrarlanan kodları, bölgesel anomalileri ve sahtecilik risklerini inceleyin.',
      icon: Icons.warning_amber_rounded,
      status: _ModuleStatus.pilot,
    ),
    _CorporateModule(
      id: 'cases',
      title: 'Vaka ve Delil Merkezi',
      description:
          'Fotoğraf, fiş, ürün kodu, numune, konum ve tarih kayıtlarını '
          'görev ve vaka bazında güvenli biçimde yönetin; delil '
          'bütünlüğünü ve işlem geçmişini koruyun.',
      icon: Icons.folder_copy_outlined,
      status: _ModuleStatus.soon,
    ),
    _CorporateModule(
      id: 'legal',
      title: 'Müdahale ve Hukuk',
      description:
          'Doğrulanmış ihlalleri marka vekiline veya hukuk bürosuna '
          'aktarın; platform şikâyetlerini, kaldırma taleplerini ve '
          'resmî süreçleri takip edin.',
      icon: Icons.gavel_outlined,
      status: _ModuleStatus.soon,
    ),
    _CorporateModule(
      id: 'reports',
      title: 'Raporlama ve Yönetici Özeti',
      description:
          'Risk eğilimlerini, operasyon sonuçlarını ve marka koruma performansını görün.',
      icon: Icons.analytics_outlined,
      status: _ModuleStatus.soon,
    ),
    _CorporateModule(
      id: 'subscription',
      title: 'Abonelik ve Hizmetler',
      description:
          'Korunan marka sayısını, paket kapsamını ve uzman hizmetlerini yönetin.',
      icon: Icons.credit_card_outlined,
      status: _ModuleStatus.soon,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Kurumsal Ana Merkez',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                user?.email ?? 'MarkaKalkan kullanıcısı',
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CorporateHeader(email: user?.email),
                const SizedBox(height: 30),
                const Text(
                  'Marka Koruma Merkezleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Markalarınızı, ürünlerinizi, sahtecilik risklerini ve '
                  'koruma operasyonlarınızı tek merkezden yönetin.',
                  style: TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    final columns = width < 650
                        ? 1
                        : width < 1000
                        ? 2
                        : 3;

                    const spacing = 18.0;
                    final cardWidth =
                        (width - ((columns - 1) * spacing)) / columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: _modules
                          .map(
                            (module) => SizedBox(
                              width: cardWidth,
                              child: _CorporateModuleCard(module: module),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CorporateHeader extends StatelessWidget {
  const _CorporateHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
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

          final icon = Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFF254D60),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              color: MarkaKalkanTheme.teal,
              size: 42,
            ),
          );

          final content = Column(
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'MarkaKalkan Kurumsal Ana Merkez',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'MarkaKalkan kullanıcısı',
                style: const TextStyle(
                  color: Color(0xFFD9E5EA),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Marka portföyünüzden saha araştırmalarına, ürün '
                'izlenebilirliğinden hukuki vaka yönetimine kadar bütün '
                'koruma faaliyetlerinizi buradan yönetin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [icon, const SizedBox(height: 20), content],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 24),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _CorporateModuleCard extends StatelessWidget {
  const _CorporateModuleCard({required this.module});

  final _CorporateModule module;

  void _openModule(BuildContext context) {
    switch (module.id) {
      case 'brands':
        AppRouter.openBrandOperations(context);
        return;
      case 'new_brand':
        AppRouter.openBrandApplication(context);
        return;
      case 'ip_documents':
        AppRouter.openIpDocumentVault(context);
        return;
      case 'traceability':
        AppRouter.openBrandOperations(context);
        return;
      case 'detective':
        AppRouter.openBrandDetectiveHub(context);
        return;
      case 'digital_market':
        AppRouter.openDijitalPazarIzleme(context);
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          module.status == _ModuleStatus.soon
              ? '${module.title} modülü yakında kullanıma açılacaktır.'
              : '${module.title} merkezi ${module.status.label.toLowerCase()} durumundadır.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openModule(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 270),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 5, color: module.status.accentColor),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F6F4),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            module.icon,
                            color: MarkaKalkanTheme.teal,
                            size: 29,
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(status: module.status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      module.title,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      module.description,
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.status == _ModuleStatus.soon
                                ? 'Yakında'
                                : 'Merkezi Aç',
                            style: const TextStyle(
                              color: MarkaKalkanTheme.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: MarkaKalkanTheme.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _ModuleStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CorporateModule {
  const _CorporateModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final _ModuleStatus status;
}

enum _ModuleStatus {
  active,
  pilot,
  soon;

  String get label {
    return switch (this) {
      _ModuleStatus.active => 'Aktif',
      _ModuleStatus.pilot => 'Pilot',
      _ModuleStatus.soon => 'Yakında',
    };
  }

  Color get accentColor {
    return switch (this) {
      _ModuleStatus.active => MarkaKalkanTheme.teal,
      _ModuleStatus.pilot => MarkaKalkanTheme.blue,
      _ModuleStatus.soon => const Color(0xFF9AA6AE),
    };
  }

  Color get backgroundColor {
    return switch (this) {
      _ModuleStatus.active => const Color(0xFFE8F6F4),
      _ModuleStatus.pilot => const Color(0xFFEAF1F8),
      _ModuleStatus.soon => const Color(0xFFF0F2F4),
    };
  }

  Color get textColor {
    return switch (this) {
      _ModuleStatus.active => MarkaKalkanTheme.teal,
      _ModuleStatus.pilot => MarkaKalkanTheme.blue,
      _ModuleStatus.soon => const Color(0xFF687580),
    };
  }
}
