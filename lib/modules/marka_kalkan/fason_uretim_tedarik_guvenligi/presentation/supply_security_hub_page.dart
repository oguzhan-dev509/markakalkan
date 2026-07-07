import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import 'supply_facility_registry_page.dart';
import 'supply_partner_registry_page.dart';

class SupplySecurityHubPage extends StatelessWidget {
  const SupplySecurityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Fason Üretim ve Tedarik Güvenliği',
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
                const _HeroPanel(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 760
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 18) / 2;

                    return Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _RegistryCard(
                            icon: Icons.handshake_outlined,
                            title: 'Fason Üretici ve Tedarikçi Sicili',
                            description:
                                'Üretici, fason üretici, hammadde ve ambalaj '
                                'tedarikçisi, lojistik, depo ve laboratuvar '
                                'partnerlerini doğrulama ve risk durumlarıyla yönetin.',
                            badges: const [
                              'Partner kimliği',
                              'Doğrulama',
                              'Risk ve güven',
                            ],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const SupplyPartnerRegistryPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _RegistryCard(
                            icon: Icons.factory_outlined,
                            title: 'Tesis, Depo ve Üretim Noktası Sicili',
                            description:
                                'Fabrika, üretim hattı, depo, paketleme, etiket, '
                                'laboratuvar ve şüpheli üretim noktalarını kapasite, '
                                'vardiya, denetim ve yetki bilgileriyle izleyin.',
                            badges: const [
                              'Tesis bağlantısı',
                              'Kapasite ve vardiya',
                              'Şüpheli nokta',
                            ],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const SupplyFacilityRegistryPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _DoctrinePanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroIcon(),
          SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Üretim emrinden tedarik zincirine kadar savunma',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Sahte ürün riskini yalnız satış noktasında değil; yetkili '
                  'üretim, tesis, kapasite, vardiya, sevkiyat ve alt yüklenici '
                  'ilişkilerinin başladığı yerde kontrol edin.',
                  style: TextStyle(
                    color: Color(0xFFD7E5EB),
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF254D60),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.account_tree_outlined,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}

class _RegistryCard extends StatelessWidget {
  const _RegistryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badges,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> badges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: MarkaKalkanTheme.teal, size: 31),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF687580),
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges
                    .map(
                      (badge) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F9),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Color(0xFF4D6470),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Text(
                    'Sicili Aç',
                    style: TextStyle(
                      color: MarkaKalkanTheme.blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: MarkaKalkanTheme.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctrinePanel extends StatelessWidget {
  const _DoctrinePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D9A9)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.policy_outlined, color: Color(0xFF9B6A10)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Temel ilke: Sahte ürünle mücadele satış noktasında değil, '
              'üretim emri ve tedarik zincirinin başladığı yerde kurulmalıdır.',
              style: TextStyle(
                color: Color(0xFF5B461D),
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
