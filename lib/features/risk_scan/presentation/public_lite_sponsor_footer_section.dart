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
    final media = MediaQuery.maybeOf(context);
    final reducedMotion =
        media?.disableAnimations == true || media?.accessibleNavigation == true;

    if (entries.isEmpty) {
      final shouldAnimateFallback = fallbackSlots.length >= 3 && !reducedMotion;
      if (!shouldAnimateFallback) {
        return _FallbackSponsorGrid(slots: fallbackSlots);
      }
      return _FallbackSponsorRail(slots: fallbackSlots);
    }

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

class _FallbackSponsorRail extends StatefulWidget {
  const _FallbackSponsorRail({required this.slots});

  final List<_SponsorSlot> slots;

  @override
  State<_FallbackSponsorRail> createState() => _FallbackSponsorRailState();
}

class _FallbackSponsorRailState extends State<_FallbackSponsorRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _paused = false;

  Duration get _period =>
      Duration(seconds: (widget.slots.length * 9).clamp(32, 90).toInt());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void didUpdateWidget(covariant _FallbackSponsorRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots.length != widget.slots.length) {
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
        const railHeight = 132.0;
        final groupWidth = widget.slots.length * (cardWidth + gap);

        Widget buildGroup(int groupIndex) {
          return SizedBox(
            width: groupWidth,
            child: Row(
              children: [
                for (var index = 0; index < widget.slots.length; index++) ...[
                  SizedBox(
                    width: cardWidth,
                    child: _SponsorSlotCard(
                      key: Key('publicLiteFallbackSponsor-$index-$groupIndex'),
                      slot: widget.slots[index],
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
          label: 'Sponsor alanları hareketli listesi',
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
                key: const Key('publicLiteFallbackSponsorRail'),
                height: railHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: SizedBox(
                      width: groupWidth * 2,
                      height: railHeight,
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
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

  static const _navy = Color(0xFF102A43);
  static const _navyDeep = Color(0xFF0B1F33);
  static const _accent = Color(0xFF2F80ED);
  static const _muted = Color(0xFFB9C7D5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'MarkaKalkan yasal bağlantıları',
      child: Container(
        key: const Key('publicLiteCompactLegalFooter'),
        decoration: const BoxDecoration(
          color: _navyDeep,
          border: Border(
            top: BorderSide(
              color: _accent,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              final brand = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MarkaKalkan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              );

              final legal = Wrap(
                spacing: 9,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const [
                  _CompactLegalLabel('Kullanım koşulları'),
                  _CompactLegalDot(),
                  _CompactLegalLabel('Gizlilik politikası'),
                  _CompactLegalDot(),
                  _CompactLegalLabel('Çerez politikası'),
                  _CompactLegalDot(),
                  _CompactLegalLabel('KVKK Aydınlatma Metni'),
                ],
              );

              final language = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.language_outlined,
                      color: _muted,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Türkçe',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand,
                    const SizedBox(height: 16),
                    legal,
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        language,
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      brand,
                      const Spacer(),
                      language,
                    ],
                  ),
                  const SizedBox(height: 17),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: legal),
                      const SizedBox(width: 24),
                      Text(
                        '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompactLegalLabel extends StatelessWidget {
  const _CompactLegalLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.88),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CompactLegalDot extends StatelessWidget {
  const _CompactLegalDot();

  @override
  Widget build(BuildContext context) {
    return Text(
      '•',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.32),
        fontSize: 11,
      ),
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
