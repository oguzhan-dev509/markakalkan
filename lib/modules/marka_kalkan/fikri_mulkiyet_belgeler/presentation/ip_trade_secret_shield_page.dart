import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import 'ip_trade_secret_access_disclosure_page.dart';
import 'ip_trade_secret_incident_page.dart';
import 'ip_trade_secret_inventory_page.dart';
import 'ip_trade_secret_protection_control_page.dart';

class IpTradeSecretShieldPage extends StatelessWidget {
  const IpTradeSecretShieldPage({super.key});

  static const _metrics = <_Metric>[
    _Metric('Korunan sır', '12', '8 aktif, 4 kritik'),
    _Metric('Bileşen', '46', '11 yüksek hassasiyet'),
    _Metric('Yetkili erişim', '19', '3 gözden geçirme bekliyor'),
    _Metric('Açık aksiyon', '7', '2 kritik müdahale'),
  ];

  static const _capabilities = <_Capability>[
    _Capability(
      'Formül ve Bileşen Envanteri',
      'Sır bileşenlerini, kritik oranları ve bağımlılıkları yönetin.',
      Icons.science_outlined,
    ),
    _Capability(
      'Erişim ve İfşa Sicili',
      'Kim, ne zaman, hangi kapsamda erişti veya sır paylaştı.',
      Icons.admin_panel_settings_outlined,
    ),
    _Capability(
      'Olay ve İhlal Yönetimi',
      'Şüpheli erişim, sızıntı ve kötüye kullanım olaylarını kaydedin.',
      Icons.security_outlined,
    ),
    _Capability(
      'Koruma Kontrolleri',
      'Fiziksel, dijital, sözleşmesel ve operasyonel önlemleri izleyin.',
      Icons.verified_user_outlined,
    ),
    _Capability(
      'Düzeltici Aksiyonlar',
      'Risk azaltma adımlarını sorumlu, tarih ve kanıtla takip edin.',
      Icons.build_circle_outlined,
    ),
    _Capability(
      'Yönetim Kararları',
      'Kritik ticari sır kararlarını kalıcı yönetim siciline bağlayın.',
      Icons.account_balance_outlined,
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
          'Formül ve Ticari Sır Kalkanı',
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
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 22),
                const _ScoreGrid(),
                const SizedBox(height: 22),
                _MetricGrid(items: _metrics),
                const SizedBox(height: 22),
                const _RiskAndActionGrid(),
                const SizedBox(height: 22),
                _CapabilityGrid(
                  items: _capabilities,
                  onOpenInventory: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const IpTradeSecretInventoryPage(),
                      ),
                    );
                  },
                  onOpenAccessDisclosure: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const IpTradeSecretAccessDisclosurePage(),
                      ),
                    );
                  },
                  onOpenIncident: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const IpTradeSecretIncidentPage(),
                      ),
                    );
                  },
                  onOpenProtectionControl: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const IpTradeSecretProtectionControlPage(),
                      ),
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

class _Header extends StatelessWidget {
  const _Header();

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;

          final score = Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Column(
              children: [
                Text(
                  '74',
                  style: TextStyle(
                    color: MarkaKalkanTheme.teal,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dayanıklılık\nEndeksi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          final content = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Fikri varlığınızın savunma durumu tek merkezde',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Formülleri, ticari sırları, erişimleri, ifşaları, olayları '
                've yönetim kararlarını kalıcı bir savunma sicilinde yönetin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E5EA),
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
                children: const [
                  _Badge('Demo veri'),
                  _Badge('Firestore yazımı kapalı'),
                  _Badge('Üretim mimarisi'),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              children: [score, const SizedBox(height: 22), content],
            );
          }

          return Row(
            children: [
              score,
              const SizedBox(width: 24),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid();

  @override
  Widget build(BuildContext context) {
    const cards = [
      _ScoreCard(
        'Risk Skoru',
        68,
        'Yüksek dikkat',
        Icons.warning_amber_rounded,
      ),
      _ScoreCard('Koruma Skoru', 81, 'Güçlü kontrol', Icons.shield_outlined),
      _ScoreCard(
        'Savunulabilirlik',
        73,
        'Kanıt güçleniyor',
        Icons.gavel_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 3;
        const spacing = 16.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard(this.title, this.value, this.caption, this.icon);

  final String title;
  final int value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          _IconBox(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value / 100',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  caption,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 4;
        const spacing = 16.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFF687580),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: const TextStyle(
                            color: Color(0xFF687580),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RiskAndActionGrid extends StatelessWidget {
  const _RiskAndActionGrid();

  @override
  Widget build(BuildContext context) {
    const risks = [
      'Fason üretici erişimi yeniden doğrulanmalı',
      'Tedarikçi gizlilik eki eksik',
      'Erişim günlüğü kapsamı yetersiz',
    ];

    const actions = [
      'Kritik erişimleri 48 saat içinde gözden geçir',
      'Formül bölümlendirmesini güçlendir',
      'Savunulabilirlik dosyasını tamamla',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;

        const riskPanel = _ListPanel(
          title: 'Kritik Açıklar',
          icon: Icons.crisis_alert_outlined,
          items: risks,
        );

        const actionPanel = _ListPanel(
          title: 'Öncelikli Müdahaleler',
          icon: Icons.task_alt_outlined,
          items: actions,
        );

        if (narrow) {
          return const Column(
            children: [riskPanel, SizedBox(height: 16), actionPanel],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: riskPanel),
            SizedBox(width: 16),
            Expanded(child: actionPanel),
          ],
        );
      },
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MarkaKalkanTheme.teal),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD74B4B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({
    required this.items,
    required this.onOpenInventory,
    required this.onOpenAccessDisclosure,
    required this.onOpenIncident,
    required this.onOpenProtectionControl,
  });

  final List<_Capability> items;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenAccessDisclosure;
  final VoidCallback onOpenIncident;
  final VoidCallback onOpenProtectionControl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 3;

        const spacing = 16.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: item.title == 'Formül ve Bileşen Envanteri'
                        ? onOpenInventory
                        : item.title == 'Erişim ve İfşa Sicili'
                        ? onOpenAccessDisclosure
                        : item.title == 'Olay ve İhlal Yönetimi'
                        ? onOpenIncident
                        : item.title == 'Koruma Kontrolleri'
                        ? onOpenProtectionControl
                        : null,
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IconBox(item.icon),
                          const SizedBox(height: 14),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: Color(0xFF687580),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                item.title == 'Formül ve Bileşen Envanteri'
                                    ? 'Envanteri Aç'
                                    : 'Ayrıntıları Aç',
                                style: const TextStyle(
                                  color: MarkaKalkanTheme.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: MarkaKalkanTheme.blue,
                                size: 19,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: MarkaKalkanTheme.teal, size: 30),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
      child: child,
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.detail);

  final String title;
  final String value;
  final String detail;
}

class _Capability {
  const _Capability(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}
