import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class DijitalPazarIzlemeSayfasi extends StatelessWidget {
  const DijitalPazarIzlemeSayfasi({super.key});

  static const List<_MonitoringModule> _modules = [
    _MonitoringModule(
      title: 'Marka İzleme Profili',
      description:
          'İzlenecek marka, ürün, kategori, anahtar kelime ve risk önceliklerini tanımlayın.',
      icon: Icons.manage_search_outlined,
      statusText: 'İzleme kapsamı',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'Kaynak Yönetimi',
      description:
          'Pazaryeri, web sitesi, sosyal medya ve diğer dijital kaynakları yönetin.',
      icon: Icons.hub_outlined,
      statusText: 'Kaynak merkezi',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'İzlenen Sayfalar',
      description:
          'Ürün ilanlarını, satıcı mağazalarını ve takip edilen sayfaları inceleyin.',
      icon: Icons.language_outlined,
      statusText: 'Sayfa takibi',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'Tarama Görevleri',
      description:
          'Planlanan taramaları, çalışma geçmişini ve veri toplama durumunu izleyin.',
      icon: Icons.radar_outlined,
      statusText: 'Tarama operasyonu',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'İzleme Olayları',
      description:
          'Fiyat, stok, satıcı, içerik ve sayfa değişikliklerini olay akışında görün.',
      icon: Icons.timeline_outlined,
      statusText: 'Değişim akışı',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'Risk Sinyalleri',
      description:
          'Kural motorunun ürettiği düşük, orta, yüksek ve kritik sinyalleri yönetin.',
      icon: Icons.notification_important_outlined,
      statusText: 'Sinyal merkezi',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'Ana Panel',
      description:
          'Kaynak sağlığı, tarama operasyonu, olaylar ve risk sinyallerini tek görünümde izleyin.',
      icon: Icons.dashboard_outlined,
      statusText: 'Yönetici görünümü',
      isActive: true,
    ),
    _MonitoringModule(
      title: 'Rapor Merkezi',
      description:
          'Yönetici özeti, marka risk ve vaka/kanıt raporlarını oluşturun.',
      icon: Icons.assessment_outlined,
      statusText: 'Kurumsal raporlar',
      isActive: true,
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
          'Dijital Pazar İzleme',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonitoringHeader(email: user?.email),
                const SizedBox(height: 28),
                const Text(
                  'İzleme Operasyonları',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dijital pazardaki ürün, satıcı ve sayfa hareketlerini '
                  'tek merkezden yönetin.',
                  style: TextStyle(color: Color(0xFF687580), fontSize: 15),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    int columns;
                    if (width < 650) {
                      columns = 1;
                    } else if (width < 1000) {
                      columns = 2;
                    } else {
                      columns = 3;
                    }

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
                              child: _MonitoringModuleCard(module: module),
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

class _MonitoringHeader extends StatelessWidget {
  final String? email;

  const _MonitoringHeader({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          final icon = Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFF25576B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.travel_explore_outlined,
              size: 42,
              color: MarkaKalkanTheme.teal,
            ),
          );

          final content = Column(
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Dijital Pazar İzleme Merkezi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'Marka kullanıcısı',
                style: const TextStyle(
                  color: Color(0xFFD9E5EA),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pazaryerlerini, satıcıları, ürün ilanlarını ve sayfa '
                'değişikliklerini sürekli izleyen operasyon katmanı.',
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

class _MonitoringModuleCard extends StatelessWidget {
  final _MonitoringModule module;

  const _MonitoringModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (module.title == 'Marka İzleme Profili') {
          AppRouter.openMarkaIzlemeProfili(context);
          return;
        }

        if (module.title == 'Kaynak Yönetimi') {
          AppRouter.openKaynakYonetimi(context);
          return;
        }

        if (module.title == 'İzlenen Sayfalar') {
          AppRouter.openIzlenenSayfalar(context);
          return;
        }

        if (module.title == 'Tarama Görevleri') {
          AppRouter.openTaramaGorevleri(context);
          return;
        }

        if (module.title == 'İzleme Olayları') {
          AppRouter.openIzlemeOlaylari(context);
          return;
        }

        if (module.title == 'Risk Sinyalleri') {
          AppRouter.openRiskSinyalleri(context);
          return;
        }

        if (module.title == 'Ana Panel') {
          AppRouter.openDijitalPazarAnaPaneli(context);
          return;
        }

        if (module.title == 'Rapor Merkezi') {
          AppRouter.openRaporMerkezi(context);
          return;
        }

        final message =
            '${module.title} modülü izleme profili tamamlandıktan sonra aktif edilecektir.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 245),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: module.isActive
                ? MarkaKalkanTheme.teal
                : const Color(0xFFE0E7EC),
          ),
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
              Container(
                height: 5,
                color: module.isActive
                    ? MarkaKalkanTheme.teal
                    : MarkaKalkanTheme.navy,
              ),
              Padding(
                padding: const EdgeInsets.all(24),
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
                      child: Icon(
                        module.icon,
                        color: MarkaKalkanTheme.teal,
                        size: 29,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      module.title,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 20,
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.statusText,
                            style: const TextStyle(
                              color: MarkaKalkanTheme.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          module.isActive
                              ? Icons.arrow_forward_rounded
                              : Icons.lock_clock_outlined,
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

class _MonitoringModule {
  final String title;
  final String description;
  final IconData icon;
  final String statusText;
  final bool isActive;

  const _MonitoringModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.statusText,
    required this.isActive,
  });
}
