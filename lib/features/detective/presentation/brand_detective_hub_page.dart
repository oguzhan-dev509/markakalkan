import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class BrandDetectiveHubPage extends StatelessWidget {
  const BrandDetectiveHubPage({super.key});

  static const List<_DetectiveModule> _modules = [
    _DetectiveModule(
      id: 'consumer',
      title: 'Tüketici Dedektifi',
      description:
          'Tüketiciler tekil ürün kodunu veya QR kodunu kontrol eder, '
          'şüpheli ürünleri MarkaKalkan’a bildirir.',
      icon: Icons.qr_code_scanner_outlined,
      status: _DetectiveStatus.active,
      actionText: 'Ürün Doğrula',
    ),
    _DetectiveModule(
      id: 'digital',
      title: 'Dijital Dedektif',
      description:
          'Pazaryeri ilanlarını, sosyal medya satışlarını, sahte siteleri, '
          'riskli fiyatları ve marka taklitlerini otomasyonla araştırır.',
      icon: Icons.travel_explore_outlined,
      status: _DetectiveStatus.pilot,
      actionText: 'Dijital Görev Oluştur',
    ),
    _DetectiveModule(
      id: 'intelligence_report',
      title: 'Marka İstihbarat Raporu',
      description:
          'Türkiye genelindeki dijital marka ihlallerini, risk dağılımını, '
          'şüpheli satıcıları, coğrafi yoğunluğu, delil durumunu ve müdahale '
          'önceliklerini tek raporda analiz edin.',
      icon: Icons.analytics_outlined,
      status: _DetectiveStatus.pilot,
      actionText: 'Raporu Gör',
    ),
    _DetectiveModule(
      id: 'field',
      title: 'Saha Dedektifi',
      description:
          'Mağaza, pazar, fuar ve izinli saha noktalarında inceleme '
          'görevlerini oluşturun, yetkili saha görevlilerine atayın ve '
          'görev sürecini takip edin.',
      icon: Icons.location_searching_outlined,
      status: _DetectiveStatus.soon,
      actionText: 'Yakında',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Marka Dedektifi',
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
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DetectiveHeader(),
                const SizedBox(height: 30),
                const Text(
                  'Dedektif Hizmetleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ürünün tüketici tarafından doğrulanmasından dijital '
                  'pazar ve saha araştırmalarına kadar marka koruma '
                  'operasyonlarını yönetin.',
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

                    final columns = width < 700
                        ? 1
                        : width < 1050
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
                              child: _DetectiveModuleCard(module: module),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),
                const _SafetyNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectiveHeader extends StatelessWidget {
  const _DetectiveHeader();

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
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF254D60),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.manage_search_outlined,
              size: 44,
              color: MarkaKalkanTheme.teal,
            ),
          );

          const content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Markanızı yalnız doğrulamayın, izini de sürün.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'MarkaKalkan; tüketici doğrulamalarını, dijital sahtecilik '
                'araştırmalarını ve saha görevlerini tek operasyon '
                'merkezinde birleştirir.',
                style: TextStyle(
                  color: Color(0xFFD9E5EA),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Icon(
                    Icons.manage_search_outlined,
                    size: 44,
                    color: MarkaKalkanTheme.teal,
                  ),
                ),
                SizedBox(height: 20),
                content,
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 24),
              const Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _DetectiveModuleCard extends StatelessWidget {
  const _DetectiveModuleCard({required this.module});

  final _DetectiveModule module;

  void _openModule(BuildContext context) {
    switch (module.id) {
      case 'consumer':
        AppRouter.openProductVerification(context);
        return;
      case 'digital':
        AppRouter.openDigitalDetectiveTask(context);
        return;
      case 'intelligence_report':
        AppRouter.openDigitalBrandIntelligenceReport(context);
        return;
      case 'field':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saha Dedektifi hizmeti yakında kullanıma açılacaktır.',
            ),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: module.id == 'digital' ? null : () => _openModule(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
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
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F6F4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            module.icon,
                            color: MarkaKalkanTheme.teal,
                            size: 31,
                          ),
                        ),
                        const Spacer(),
                        _DetectiveStatusBadge(status: module.status),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      module.title,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      module.description,
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (module.id == 'digital')
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  AppRouter.openDigitalDetectiveTask(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Görev Oluştur'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  AppRouter.openDigitalDetectiveTasks(context),
                              icon: const Icon(
                                Icons.assignment_outlined,
                                size: 18,
                              ),
                              label: const Text('Görevlerim'),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.actionText,
                              style: const TextStyle(
                                color: MarkaKalkanTheme.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E0EC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: MarkaKalkanTheme.blue),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Marka Dedektifi bulguları risk ve inceleme göstergeleridir. '
              'Bir ürünün veya satıcının hukuki niteliği, yetkili uzman ve '
              'kurumların incelemesi sonucunda kesinleşir.',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectiveModule {
  const _DetectiveModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    required this.actionText,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final _DetectiveStatus status;
  final String actionText;
}

enum _DetectiveStatus {
  active,
  pilot,
  soon;

  String get label {
    return switch (this) {
      _DetectiveStatus.active => 'Aktif',
      _DetectiveStatus.pilot => 'Pilot',
      _DetectiveStatus.soon => 'Yakında',
    };
  }

  Color get accentColor {
    return switch (this) {
      _DetectiveStatus.active => MarkaKalkanTheme.teal,
      _DetectiveStatus.pilot => MarkaKalkanTheme.blue,
      _DetectiveStatus.soon => const Color(0xFF9AA6AE),
    };
  }

  Color get backgroundColor {
    return switch (this) {
      _DetectiveStatus.active => const Color(0xFFE8F6F4),
      _DetectiveStatus.pilot => const Color(0xFFEAF1F8),
      _DetectiveStatus.soon => const Color(0xFFF0F2F4),
    };
  }

  Color get textColor {
    return switch (this) {
      _DetectiveStatus.active => MarkaKalkanTheme.teal,
      _DetectiveStatus.pilot => MarkaKalkanTheme.blue,
      _DetectiveStatus.soon => const Color(0xFF687580),
    };
  }
}

class _DetectiveStatusBadge extends StatelessWidget {
  const _DetectiveStatusBadge({required this.status});

  final _DetectiveStatus status;

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
