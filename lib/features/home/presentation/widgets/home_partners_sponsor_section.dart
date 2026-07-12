import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';

class HomePartnersSponsorSection extends StatelessWidget {
  const HomePartnersSponsorSection({super.key});

  static const _partnerTypes = <_PartnerType>[
    _PartnerType(
      icon: Icons.account_balance_outlined,
      title: 'Hukuk ve Uyuşmazlık',
      description: 'Marka, fikri mülkiyet ve müdahale süreçleri için uzman ağ.',
    ),
    _PartnerType(
      icon: Icons.biotech_outlined,
      title: 'Laboratuvar ve Analiz',
      description: 'Ürün içeriği, teknik uygunluk ve delil doğrulama desteği.',
    ),
    _PartnerType(
      icon: Icons.local_shipping_outlined,
      title: 'Lojistik ve Tedarik',
      description: 'Sevkiyat, üretim ve tedarik zinciri görünürlüğü.',
    ),
    _PartnerType(
      icon: Icons.security_outlined,
      title: 'Siber Güvenlik',
      description: 'Dijital varlık, kimlik ve tehdit güvenliği iş birlikleri.',
    ),
    _PartnerType(
      icon: Icons.public_outlined,
      title: 'Kamu ve Sektör Ağı',
      description: 'Sektörel farkındalık, bildirim ve ortak savunma kanalları.',
    ),
    _PartnerType(
      icon: Icons.analytics_outlined,
      title: 'Veri ve Teknoloji',
      description: 'Doğrulama, izleme ve yapay zekâ altyapısı sağlayıcıları.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071923), Color(0xFF0B2834), Color(0xFF111B3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _SponsorBanner(
            onCorporateAccess: () => AppRouter.openBrandLogin(context),
          ),
          _PartnersArea(
            partnerTypes: _partnerTypes,
            onCorporateAccess: () => AppRouter.openBrandLogin(context),
          ),
          _CorporateClosing(
            onPrimaryAction: () => AppRouter.openBrandLogin(context),
            onSecondaryAction: () =>
                AppRouter.openCounterfeitTwinPublicRadar(context),
          ),
        ],
      ),
    );
  }
}

class _SponsorBanner extends StatelessWidget {
  const _SponsorBanner({required this.onCorporateAccess});

  final VoidCallback onCorporateAccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123D4A), Color(0xFF1A3154)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x556ECFC5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionPill(
                      icon: Icons.campaign_outlined,
                      text: 'SPONSORLU ALAN',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Marka güvenliği ekosisteminde görünür olun',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bu alan; marka koruma, doğrulama, hukuk, teknoloji, '
                      'laboratuvar ve tedarik güvenliği alanlarında faaliyet '
                      'gösteren kurumsal sponsorlar için ayrılmıştır.',
                      style: TextStyle(
                        color: Color(0xFFC8D8DE),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],
                );

                final action = FilledButton.icon(
                  onPressed: onCorporateAccess,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF0BD5B),
                    foregroundColor: const Color(0xFF17202A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 17,
                    ),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text(
                    'Kurumsal İş Birliği',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: 24),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 36),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnersArea extends StatelessWidget {
  const _PartnersArea({
    required this.partnerTypes,
    required this.onCorporateAccess,
  });

  final List<_PartnerType> partnerTypes;
  final VoidCallback onCorporateAccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 76),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionPill(
                icon: Icons.hub_outlined,
                text: 'İŞ ORTAKLIĞI AĞI',
              ),
              const SizedBox(height: 18),
              const Text(
                'Marka savunması tek kurumla değil, güçlü bir ağla büyür',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  'MarkaKalkan; doğrulama, hukuk, analiz, lojistik, siber '
                  'güvenlik ve sektör uzmanlığını ortak bir savunma zincirinde '
                  'buluşturacak şekilde tasarlanmıştır. Gerçek iş ortakları '
                  'onaylandıkça bu alanda adları ve logoları yayınlanacaktır.',
                  style: TextStyle(
                    color: Color(0xFFC7D6DD),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width < 680 ? 1 : (width < 1020 ? 2 : 3);
                  final itemWidth = (width - ((columns - 1) * 18)) / columns;

                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: partnerTypes
                        .map(
                          (partner) => SizedBox(
                            width: itemWidth,
                            child: _PartnerCard(partner: partner),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onCorporateAccess,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF7898A4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text(
                  'İş Ortağı Olun',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner});

  final _PartnerType partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x1F6ECFC5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(partner.icon, color: const Color(0xFF9BE0D8), size: 27),
          ),
          const SizedBox(height: 18),
          Text(
            partner.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            partner.description,
            style: const TextStyle(
              color: Color(0xFFB8CBD2),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorporateClosing extends StatelessWidget {
  const _CorporateClosing({
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF05131C),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 800;
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF9BE0D8),
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'MarkaKalkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Markanızı, üretiminizi, fikri varlıklarınızı ve dijital '
                    'itibarınızı aynı savunma zincirinde koruyun.',
                    style: TextStyle(
                      color: Color(0xFFB8CBD2),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              );

              final actions = Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onPrimaryAction,
                    icon: const Icon(Icons.business_outlined),
                    label: const Text('Marka Girişi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF7898A4)),
                    ),
                    icon: const Icon(Icons.radar_outlined),
                    label: const Text('Sahte İkiz Radarı'),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 28),
                    Align(alignment: Alignment.centerLeft, child: actions),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 40),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  const _SectionPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1A6ECFC5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x556ECFC5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFBCE7E3), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBCE7E3),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerType {
  const _PartnerType({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
