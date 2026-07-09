import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/app/router.dart';

class BrandDashboardPage extends StatelessWidget {
  const BrandDashboardPage({super.key});

  static const List<_DashboardModule> _modules = [
    _DashboardModule(
      title: 'Ürünler',
      description:
          'Markanıza ait ürün modellerini oluşturun ve ürün bilgilerini yönetin.',
      icon: Icons.inventory_2_outlined,
      statusText: 'Ürün kataloğu',
    ),
    _DashboardModule(
      title: 'Üretim Partileri',
      description:
          'Üretim, ithalat, fason üretim ve sevk partilerini kayıt altına alın.',
      icon: Icons.factory_outlined,
      statusText: 'Parti yönetimi',
    ),
    _DashboardModule(
      title: 'Tekil Kodlar',
      description:
          'Her fiziksel ürün için benzersiz kodlar oluşturun ve durumlarını izleyin.',
      icon: Icons.qr_code_2_outlined,
      statusText: 'Kod merkezi',
    ),
    _DashboardModule(
      title: 'Şüpheli Taramalar',
      description:
          'Aynı kodun farklı cihaz ve bölgelerdeki olağan dışı kullanımını inceleyin.',
      icon: Icons.warning_amber_rounded,
      statusText: 'Risk takibi',
    ),
    _DashboardModule(
      title: 'Vaka Dosyaları',
      description:
          'Sahtecilik bildirimlerini, fotoğrafları, faturaları ve satıcı kayıtlarını yönetin.',
      icon: Icons.folder_copy_outlined,
      statusText: 'İnceleme dosyaları',
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
          'Ürün Kimliği ve İzlenebilirlik',
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
                _DashboardHeader(email: user?.email),
                const SizedBox(height: 26),
                const Text(
                  'İzlenebilirlik Merkezleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ürün, üretim partisi, tekil kod ve yaşam döngüsü kayıtlarınızı tek merkezden yönetin.',
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
                              child: _DashboardModuleCard(module: module),
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

class _DashboardHeader extends StatelessWidget {
  final String? email;

  const _DashboardHeader({required this.email});

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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF254D60),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shield_outlined,
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
                'Ürün Kimliği ve İzlenebilirlik',
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
                'Ürünlerinizi, üretim partilerinizi, tekil kodlarınızı ve '
                'şüpheli hareketleri buradan yönetin.',
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

class _DashboardModuleCard extends StatelessWidget {
  final _DashboardModule module;

  const _DashboardModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (module.title == 'Ürünler') {
          AppRouter.openProducts(context);
          return;
        }

        if (module.title == 'Üretim Partileri') {
          AppRouter.openProductionBatches(context);
          return;
        }

        if (module.title == 'Tekil Kodlar') {
          AppRouter.openProductCodes(context);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${module.title} modülü bir sonraki aşamada aktif edilecektir.',
            ),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 245),
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
              Container(height: 5, color: MarkaKalkanTheme.navy),
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

class _DashboardModule {
  final String title;
  final String description;
  final IconData icon;
  final String statusText;

  const _DashboardModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.statusText,
  });
}
