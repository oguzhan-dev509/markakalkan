import 'package:flutter/material.dart';
import 'package:markakalkan/features/sponsor_content/data/sponsor_content_service.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

const Key publicLiteSponsorFooterSectionKey = Key(
  'publicLiteSponsorFooterSection',
);
const Key publicLiteSponsorStripKey = Key('publicLiteSponsorStrip');
const Key publicLiteSponsorInquiryButtonKey = Key(
  'publicLiteSponsorInquiryButton',
);
const Key publicLitePartnersButtonKey = Key('publicLitePartnersButton');

typedef PublicSponsorLoader = Future<List<SponsorContentEntry>> Function();

class PublicLiteSponsorFooterSection extends StatefulWidget {
  const PublicLiteSponsorFooterSection({super.key, this.loadSponsors});

  final PublicSponsorLoader? loadSponsors;

  @override
  State<PublicLiteSponsorFooterSection> createState() =>
      _PublicLiteSponsorFooterSectionState();
}

class _PublicLiteSponsorFooterSectionState
    extends State<PublicLiteSponsorFooterSection> {
  static const _sponsorSlots = <_SponsorSlot>[
    _SponsorSlot(
      icon: Icons.memory_outlined,
      category: 'Teknoloji',
      categoryCode: 'technology',
    ),
    _SponsorSlot(
      icon: Icons.gavel_outlined,
      category: 'Hukuk ve IP',
      categoryCode: 'legal_ip',
    ),
    _SponsorSlot(
      icon: Icons.storefront_outlined,
      category: 'E-ticaret',
      categoryCode: 'ecommerce',
    ),
    _SponsorSlot(
      icon: Icons.hub_outlined,
      category: 'Telekom',
      categoryCode: 'telecom',
    ),
    _SponsorSlot(
      icon: Icons.local_shipping_outlined,
      category: 'Lojistik',
      categoryCode: 'logistics',
    ),
    _SponsorSlot(
      icon: Icons.add_business_outlined,
      category: 'Kurumsal',
      categoryCode: 'corporate',
    ),
  ];

  SponsorContentService? _service;
  List<SponsorContentEntry> _entries = const <SponsorContentEntry>[];

  SponsorContentService get _resolvedService =>
      _service ??= SponsorContentService();

  PublicSponsorLoader get _loader =>
      widget.loadSponsors ?? _resolvedService.listPublic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _loader();
      if (!mounted) return;
      setState(() {
        _entries = [...entries]
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = const <SponsorContentEntry>[];
      });
    }
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: publicLiteSponsorFooterSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SponsorPanel(
          entries: _entries,
          fallbackSlots: _sponsorSlots,
          onPartnersPressed: () => _showComingSoon(
            context,
            'Onaylı iş ortakları dizini hazırlanıyor.',
          ),
          onInquiryPressed: () => _showComingSoon(
            context,
            'Sponsorluk ve iş ortaklığı başvuru kanalı hazırlanıyor.',
          ),
        ),
        const SizedBox(height: 22),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 22),
        const _PublicFooter(),
      ],
    );
  }
}

class _SponsorPanel extends StatelessWidget {
  const _SponsorPanel({
    required this.entries,
    required this.fallbackSlots,
    required this.onPartnersPressed,
    required this.onInquiryPressed,
  });

  final List<SponsorContentEntry> entries;
  final List<_SponsorSlot> fallbackSlots;
  final VoidCallback onPartnersPressed;
  final VoidCallback onInquiryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: publicLiteSponsorStripKey,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Yeni sponsor alanı',
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'İş Ortaklarımız / Sponsorlarımız',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Markanızı korumak için güç birliği yapıyoruz',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              'Stratejik iş ortaklarımız ve sponsorlarımız, MarkaKalkan’ın '
              'daha güçlü ve etkili olmasını destekler. Yalnızca doğrulanmış '
              'iş birlikleri burada marka adı ve logosuyla yayımlanır.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SponsorContentArea(entries: entries, fallbackSlots: fallbackSlots),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: publicLitePartnersButtonKey,
                onPressed: onPartnersPressed,
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('Tüm iş ortaklarımızı görüntüle'),
              ),
              TextButton.icon(
                key: publicLiteSponsorInquiryButtonKey,
                onPressed: onInquiryPressed,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Siz de burada yer almak ister misiniz?'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SponsorContentArea extends StatelessWidget {
  const _SponsorContentArea({
    required this.entries,
    required this.fallbackSlots,
  });

  final List<SponsorContentEntry> entries;
  final List<_SponsorSlot> fallbackSlots;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _FallbackSponsorGrid(slots: fallbackSlots);
    }

    final media = MediaQuery.maybeOf(context);
    final reducedMotion =
        media?.disableAnimations == true || media?.accessibleNavigation == true;
    final shouldAnimate = entries.length >= 3 && !reducedMotion;

    if (!shouldAnimate) {
      return _StaticDynamicSponsorGrid(entries: entries);
    }

    return _SponsorRail(entries: entries);
  }
}

class _FallbackSponsorGrid extends StatelessWidget {
  const _FallbackSponsorGrid({required this.slots});

  final List<_SponsorSlot> slots;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1040
            ? 6
            : width >= 760
            ? 3
            : width >= 500
            ? 2
            : 1;
        const gap = 14.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < slots.length; index++)
              SizedBox(
                width: cardWidth,
                child: _SponsorSlotCard(
                  key: Key('publicLiteSponsorSlot$index'),
                  slot: slots[index],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StaticDynamicSponsorGrid extends StatelessWidget {
  const _StaticDynamicSponsorGrid({required this.entries});

  final List<SponsorContentEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 560
            ? 2
            : 1;
        const gap = 14.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (var index = 0; index < entries.length; index++)
              SizedBox(
                width: cardWidth,
                child: _DynamicSponsorCard(
                  key: Key('publicLiteDynamicSponsorStatic$index'),
                  entry: entries[index],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SponsorRail extends StatefulWidget {
  const _SponsorRail({required this.entries});

  final List<SponsorContentEntry> entries;

  @override
  State<_SponsorRail> createState() => _SponsorRailState();
}

class _SponsorRailState extends State<_SponsorRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _paused = false;

  Duration get _period =>
      Duration(seconds: (widget.entries.length * 9).clamp(32, 90).toInt());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void didUpdateWidget(covariant _SponsorRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _controller.duration = _period;
      if (!_paused) {
        _controller.repeat();
      }
    }
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _controller.stop(canceled: false);
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900 ? 220.0 : 190.0;
        const gap = 14.0;
        final groupWidth = widget.entries.length * (cardWidth + gap);

        Widget buildGroup(int groupIndex) {
          return SizedBox(
            width: groupWidth,
            child: Row(
              children: [
                for (var index = 0; index < widget.entries.length; index++) ...[
                  SizedBox(
                    width: cardWidth,
                    child: _DynamicSponsorCard(
                      key: Key(
                        'publicLiteDynamicSponsor-'
                        '${widget.entries[index].id}-$groupIndex',
                      ),
                      entry: widget.entries[index],
                    ),
                  ),
                  const SizedBox(width: gap),
                ],
              ],
            ),
          );
        }

        return Semantics(
          container: true,
          label: 'Sponsorlar ve iş ortakları hareketli listesi',
          child: MouseRegion(
            onEnter: (_) => _pause(),
            onExit: (_) => _resume(),
            child: Focus(
              onFocusChange: (focused) {
                if (focused) {
                  _pause();
                } else {
                  _resume();
                }
              },
              child: SizedBox(
                key: const Key('publicLiteSponsorRail'),
                height: 126,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: SizedBox(
                      width: groupWidth * 2,
                      height: 126,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(-_controller.value * groupWidth, 0),
                            child: child,
                          );
                        },
                        child: Row(children: [buildGroup(0), buildGroup(1)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DynamicSponsorCard extends StatelessWidget {
  const _DynamicSponsorCard({super.key, required this.entry});

  final SponsorContentEntry entry;

  Widget _fallbackLogo(Color color) {
    return Icon(Icons.handshake_outlined, size: 32, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLogo = entry.logoUrl.trim().isNotEmpty;
    final accent = _sponsorAccentFor(entry.categoryCode);

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.background, colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.border.withValues(alpha: 0.82),
          width: 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.border.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 42,
            width: 116,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: hasLogo
                  ? Image.network(
                      entry.logoUrl,
                      fit: BoxFit.contain,
                      semanticLabel: entry.logoAlt.trim().isEmpty
                          ? '${entry.displayName} logosu'
                          : entry.logoAlt,
                      errorBuilder: (context, error, stackTrace) =>
                          _fallbackLogo(accent.foreground),
                    )
                  : _fallbackLogo(accent.foreground),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFF102A43),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.categoryLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorSlotCard extends StatelessWidget {
  const _SponsorSlotCard({super.key, required this.slot});

  final _SponsorSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _sponsorAccentFor(slot.categoryCode);

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.background, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.border.withValues(alpha: 0.78),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.border.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slot.icon, color: accent.foreground, size: 29),
          const SizedBox(height: 10),
          Text(
            slot.category,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFF102A43),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sponsor alanı',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  static const _platform = <String>[
    'Sahte İkiz Radarı',
    'Yaratım Öncelik Sicili',
    'Risk tarama hizmeti',
    'Tüm modüller',
  ];

  static const _resources = <String>[
    'Resmî kurumlar',
    'Kılavuzlar',
    'Sık sorulan sorular',
    'Blog',
  ];

  static const _company = <String>[
    'Hakkımızda',
    'İletişim',
    'Kariyer',
    'Basın odası',
  ];

  static const _legal = <String>[
    'Kullanım koşulları',
    'Gizlilik politikası',
    'Çerez politikası',
    'KVKK Aydınlatma Metni',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;

            final brand = _BrandFooterBlock(
              textColor: colorScheme.onSurfaceVariant,
            );
            final links = Wrap(
              spacing: 34,
              runSpacing: 24,
              children: const [
                _FooterColumn(title: 'Platform', items: _platform),
                _FooterColumn(title: 'Kaynaklar', items: _resources),
                _FooterColumn(title: 'Şirket', items: _company),
                _FooterColumn(title: 'Yasal', items: _legal),
              ],
            );
            const security = _SecurityPostureCard();

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  brand,
                  const SizedBox(height: 26),
                  links,
                  const SizedBox(height: 26),
                  security,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 230, child: brand),
                const SizedBox(width: 30),
                Expanded(child: links),
                const SizedBox(width: 26),
                const SizedBox(width: 230, child: _SecurityPostureCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 13),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Text(
              '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_outlined, size: 17),
                    SizedBox(width: 7),
                    Text('Türkçe'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandFooterBlock extends StatelessWidget {
  const _BrandFooterBlock({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(Icons.shield_outlined, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'MarkaKalkan',
                  maxLines: 1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Markanızı korumak, sahtecilikle mücadele etmek ve dijital '
          'dünyada güvenliğinizi güçlendirmek için tasarlandı.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Text(
              item,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SecurityPostureCard extends StatelessWidget {
  const _SecurityPostureCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Güvenlik ve gizlilik yaklaşımı',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          const _SecurityRow(
            icon: Icons.lock_outline,
            title: 'Güvenli tasarım',
            subtitle: 'Erişim ve veri minimizasyonu',
          ),
          const SizedBox(height: 12),
          const _SecurityRow(
            icon: Icons.policy_outlined,
            title: 'Gizlilik ilkeleri',
            subtitle: 'KVKK ve GDPR odaklı yaklaşım',
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SponsorAccent {
  const _SponsorAccent({
    required this.border,
    required this.background,
    required this.foreground,
  });

  final Color border;
  final Color background;
  final Color foreground;
}

_SponsorAccent _sponsorAccentFor(String categoryCode) {
  return switch (categoryCode) {
    'technology' => const _SponsorAccent(
      border: Color(0xFFF0B90B),
      background: Color(0xFFFFFBEC),
      foreground: Color(0xFFB78300),
    ),
    'legal_ip' => const _SponsorAccent(
      border: Color(0xFF66C9E8),
      background: Color(0xFFF0FAFD),
      foreground: Color(0xFF16789B),
    ),
    'ecommerce' => const _SponsorAccent(
      border: Color(0xFFFF8B5C),
      background: Color(0xFFFFF3EE),
      foreground: Color(0xFFD35420),
    ),
    'telecom' => const _SponsorAccent(
      border: Color(0xFF4FD1D9),
      background: Color(0xFFF0FBFC),
      foreground: Color(0xFF137F86),
    ),
    'logistics' => const _SponsorAccent(
      border: Color(0xFF78C96F),
      background: Color(0xFFF3FBF2),
      foreground: Color(0xFF3C8A35),
    ),
    'corporate' => const _SponsorAccent(
      border: Color(0xFFB48AFF),
      background: Color(0xFFF8F3FF),
      foreground: Color(0xFF7650B8),
    ),
    _ => const _SponsorAccent(
      border: Color(0xFF7EA5FF),
      background: Color(0xFFF3F7FF),
      foreground: Color(0xFF315FAE),
    ),
  };
}

class _SponsorSlot {
  const _SponsorSlot({
    required this.icon,
    required this.category,
    required this.categoryCode,
  });

  final IconData icon;
  final String category;
  final String categoryCode;
}
