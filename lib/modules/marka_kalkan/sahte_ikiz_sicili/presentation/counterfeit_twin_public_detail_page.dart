import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/models/counterfeit_twin_public_contract.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_comparison_codec.dart';
import 'package:url_launcher/url_launcher.dart';

class CounterfeitTwinPublicDetailPage extends StatefulWidget {
  const CounterfeitTwinPublicDetailPage({
    required this.slug,
    this.initialDetail,
    super.key,
  });

  final String slug;
  final CounterfeitTwinPublicDetail? initialDetail;

  @override
  State<CounterfeitTwinPublicDetailPage> createState() =>
      _CounterfeitTwinPublicDetailPageState();
}

class _CounterfeitTwinPublicDetailPageState
    extends State<CounterfeitTwinPublicDetailPage> {
  late final CounterfeitTwinPublicDetailService _service;
  CounterfeitTwinPublicDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = CounterfeitTwinPublicDetailService();
    _detail = widget.initialDetail;
    _isLoading = widget.initialDetail == null;
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _service.getBySlug(widget.slug);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'not-found'
            ? 'Bu kamu kaydı bulunamadı veya artık yayımlanmıyor.'
            : error.message ?? 'Kamu kaydı yüklenemedi.';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kamu kaydı şu anda yüklenemiyor.';
        _isLoading = false;
      });
    }
  }

  String _publicUrl(CounterfeitTwinPublicDetail detail) {
    final path = detail.canonicalPath.isNotEmpty
        ? detail.canonicalPath
        : '/sahte-ikiz/${detail.slug}';
    if (Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
      return Uri.base.resolve(path).toString();
    }
    return 'https://markakalkan-app.web.app$path';
  }

  Future<void> _launch(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım bağlantısı açılamadı.')),
      );
    }
  }

  Future<void> _share(CounterfeitTwinPublicDetail detail, String channel) {
    final url = _publicUrl(detail);
    final title = detail.shareTitle.isEmpty
        ? 'Doğrulanmış Sahte İkiz Kaydı'
        : detail.shareTitle;
    final uri = switch (channel) {
      'whatsapp' => Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent('$title\n$url')}',
      ),
      'x' => Uri.parse(
        'https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent(title)}'
        '&url=${Uri.encodeComponent(url)}',
      ),
      'facebook' => Uri.parse(
        'https://www.facebook.com/sharer/sharer.php'
        '?u=${Uri.encodeComponent(url)}',
      ),
      'linkedin' => Uri.parse(
        'https://www.linkedin.com/sharing/share-offsite/'
        '?url=${Uri.encodeComponent(url)}',
      ),
      'telegram' => Uri.parse(
        'https://t.me/share/url'
        '?url=${Uri.encodeComponent(url)}'
        '&text=${Uri.encodeComponent(title)}',
      ),
      _ => Uri.parse(url),
    };
    return _launch(uri);
  }

  Future<void> _copyLink(CounterfeitTwinPublicDetail detail) async {
    await Clipboard.setData(ClipboardData(text: _publicUrl(detail)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kamu kayıt bağlantısı kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(title: const Text('Doğrulanmış Sahte İkiz Kaydı')),
      body: _isLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? _DetailError(
              message: _error ?? 'Kamu kaydı bulunamadı.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Hero(detail: detail),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _VerificationStrip(detail: detail),
                            if (detail.publicSummary.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _SectionCard(
                                title: 'Kamuya açık doğrulama özeti',
                                icon: Icons.fact_check_outlined,
                                child: Text(
                                  detail.publicSummary,
                                  style: const TextStyle(
                                    height: 1.6,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                            if (_hasCoreProductInformation(detail)) ...[
                              const SizedBox(height: 18),
                              _CoreProductInformationSection(detail: detail),
                            ],
                            const SizedBox(height: 18),
                            _ComparisonSection(detail: detail),
                            if (_hasExtendedEvidence(detail)) ...[
                              const SizedBox(height: 18),
                              _PublicEvidenceSection(detail: detail),
                            ],
                            if (detail.incidentTypes.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _SectionCard(
                                title: 'Tespit edilen olay türleri',
                                icon: Icons.warning_amber_rounded,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: detail.incidentTypes
                                      .map(
                                        (item) => Chip(
                                          label: Text(_incidentLabel(item)),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ],
                            if (detail
                                .decodedComparison
                                .legacyNotes
                                .isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _SectionCard(
                                title: 'Belirlenen farklar',
                                icon: Icons.difference_outlined,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: detail.decodedComparison.legacyNotes
                                      .map(
                                        (note) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline,
                                                size: 19,
                                                color: MarkaKalkanTheme.teal,
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  note,
                                                  style: const TextStyle(
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ],
                            if (detail.financialImpact.hasMonetaryLoss) ...[
                              const SizedBox(height: 18),
                              _FinancialImpactCard(detail: detail),
                            ],
                            const SizedBox(height: 18),
                            _ShareSection(
                              detail: detail,
                              onShare: (channel) => _share(detail, channel),
                              onCopy: () => _copyLink(detail),
                            ),
                            const SizedBox(height: 18),
                            const _PublicNotice(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF1C5260)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Wrap(
                spacing: 9,
                runSpacing: 9,
                alignment: WrapAlignment.center,
                children: [
                  _HeroChip(
                    icon: _categoryIcon(detail.publicCategory),
                    text: _categoryLabel(detail.publicCategory),
                  ),
                  if (detail.publicRecordCode.isNotEmpty)
                    _HeroChip(
                      icon: Icons.numbers_outlined,
                      text: detail.publicRecordCode,
                    ),
                  const _HeroChip(
                    icon: Icons.verified_outlined,
                    text: 'Delille doğrulandı',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                detail.title.isNotEmpty ? detail.title : detail.comparisonLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Gerçeği doğrula, sahte ikizi görünür kıl.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBCE7E3),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail.publishedAt != null) ...[
                const SizedBox(height: 13),
                Text(
                  'Yayımlanma: ${_dateLabel(detail.publishedAt!)}',
                  style: const TextStyle(color: Color(0xFFD9E5EA)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationStrip extends StatelessWidget {
  const _VerificationStrip({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9BD8CD)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: MarkaKalkanTheme.teal,
            size: 30,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              detail.publicRecordCode.isEmpty
                  ? 'Bu kayıt MarkaKalkan inceleme sürecinden geçirilmiştir.'
                  : '${detail.publicRecordCode} numaralı kayıt MarkaKalkan '
                        'inceleme sürecinden geçirilmiştir.',
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasCoreProductInformation(CounterfeitTwinPublicDetail detail) {
  return detail.usagePurpose.isNotEmpty ||
      detail.technicalIdentity.isNotEmpty ||
      detail.counterfeitRisk.isNotEmpty;
}

class _CoreProductInformationSection extends StatelessWidget {
  const _CoreProductInformationSection({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ürün amacı, teknik kimlik ve risk',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.usagePurpose.isNotEmpty)
            _CoreInformationRow(
              label: 'Ne için kullanılır?',
              value: detail.usagePurpose,
            ),
          if (detail.technicalIdentity.isNotEmpty)
            _CoreInformationRow(
              label: 'Ayırt edici teknik bilgi / ürün kimliği',
              value: detail.technicalIdentity,
            ),
          if (detail.counterfeitRisk.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF5C26B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFB54708),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sahte olduğunda doğabilecek risk',
                          style: TextStyle(
                            color: Color(0xFF7A2E0E),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail.counterfeitRisk,
                          style: const TextStyle(height: 1.55),
                        ),
                      ],
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

class _CoreInformationRow extends StatelessWidget {
  const _CoreInformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(height: 1.55)),
        ],
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: detail.comparisonLabel.isNotEmpty
          ? detail.comparisonLabel
          : 'Gerçek – Sahte İkiz Karşılaştırması',
      icon: Icons.compare_arrows_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final original = _EntityPanel(
            label: 'GERÇEK',
            name: detail.originalDisplayName,
            brandName: detail.originalBrandName,
            productName: detail.originalProductName,
            country: detail.originalCountry,
            imageUrls: detail.originalImageUrls,
            sourceUrls: detail.originalUrls,
            priceText: _authorizedPrice(detail),
            background: const Color(0xFFEAF7F4),
            accent: const Color(0xFF167D71),
          );
          final suspected = _EntityPanel(
            label: 'SAHTE / ŞÜPHELİ İKİZ',
            name: detail.suspectedDisplayName,
            brandName: detail.suspectedBrandName,
            productName: detail.suspectedProductName,
            country: detail.claimedOriginCountry.isNotEmpty
                ? detail.claimedOriginCountry
                : detail.allegedSupplyCountry,
            imageUrls: detail.suspectedImageUrls,
            sourceUrls: detail.suspectedUrls,
            priceText: detail.suspectedPrice == null
                ? ''
                : '${detail.suspectedPrice!.toStringAsFixed(2)} '
                      '${detail.currency}',
            background: const Color(0xFFFFF4E8),
            accent: const Color(0xFFC56A13),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                original,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Icon(Icons.swap_vert_rounded, size: 32),
                ),
                suspected,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: original),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 180, 18, 0),
                child: Icon(Icons.compare_arrows_rounded, size: 34),
              ),
              Expanded(child: suspected),
            ],
          );
        },
      ),
    );
  }
}

class _EntityPanel extends StatelessWidget {
  const _EntityPanel({
    required this.label,
    required this.name,
    required this.brandName,
    required this.productName,
    required this.country,
    required this.imageUrls,
    required this.sourceUrls,
    required this.priceText,
    required this.background,
    required this.accent,
  });

  final String label;
  final String name;
  final String brandName;
  final String productName;
  final String country;
  final List<String> imageUrls;
  final List<String> sourceUrls;
  final String priceText;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _MainImage(url: imageUrls.isEmpty ? '' : imageUrls.first),
          if (imageUrls.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.skip(1).take(5).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _Thumbnail(url: imageUrls[index + 1]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            name.isEmpty ? 'Ad bilgisi yayımlanmadı' : name,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (brandName.isNotEmpty && brandName != name)
            _InfoLine(label: 'Marka', value: brandName),
          if (productName.isNotEmpty && productName != name)
            _InfoLine(label: 'Ürün', value: productName),
          if (country.isNotEmpty)
            _InfoLine(label: 'Ülke / menşe', value: country),
          if (priceText.isNotEmpty) _InfoLine(label: 'Fiyat', value: priceText),
          if (sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openSource(context, sourceUrls.first),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Yayımlanan kaynağı aç'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak bağlantısı geçersiz.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak bağlantısı açılamadı.')),
      );
    }
  }
}

class _MainImage extends StatelessWidget {
  const _MainImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.white.withValues(alpha: 0.8),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 52, color: Color(0xFF98A2B3)),
          SizedBox(height: 8),
          Text(
            'Görsel yayımlanmadı',
            style: TextStyle(color: Color(0xFF667085)),
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 62,
          height: 62,
          color: Colors.white,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: Color(0xFF475467), height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _PublicEvidenceSection extends StatelessWidget {
  const _PublicEvidenceSection({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    if (!_hasExtendedEvidence(detail)) {
      return const SizedBox.shrink();
    }

    final decoded = detail.decodedComparison;
    final originalPrice =
        detail.authorizedPriceMin ?? detail.authorizedPriceMax;
    final suspectedPrice = detail.suspectedPrice;
    final priceComparison = _priceComparisonText(detail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (decoded.rows.isNotEmpty)
          _SectionCard(
            title: 'Gerçek–Sahte Karşılaştırma Tablosu',
            icon: Icons.table_chart_outlined,
            child: _PublicComparisonTable(rows: decoded.rows),
          ),
        if (decoded.rows.isNotEmpty) const SizedBox(height: 18),
        _SectionCard(
          title: 'Fiyat ve görsel doğrulama bilgileri',
          icon: Icons.price_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PublicEvidenceRow(
                label: 'Gerçek fiyat',
                value: originalPrice == null
                    ? ''
                    : '${originalPrice.toStringAsFixed(2)} ${detail.currency}',
              ),
              _PublicEvidenceRow(
                label: 'Sahte / şüpheli fiyat',
                value: suspectedPrice == null
                    ? ''
                    : '${suspectedPrice.toStringAsFixed(2)} ${detail.currency}',
              ),
              _PublicEvidenceRow(label: 'Fiyat farkı', value: priceComparison),
              _PublicEvidenceRow(
                label: 'Fiyat tespit tarihi',
                value: decoded.priceObservedAt,
              ),
              _PublicEvidenceRow(
                label: 'Gerçek görsel kaynağı / atfı',
                value: decoded.originalImageSource,
              ),
              _PublicEvidenceRow(
                label: 'Şüpheli görsel kaynağı / atfı',
                value: decoded.suspectedImageSource,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicComparisonTable extends StatelessWidget {
  const _PublicComparisonTable({required this.rows});

  final List<CounterfeitTwinComparisonRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            row.checkpoint,
                            style: const TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _PublicEvidenceRow(
                            label: 'Gerçek ürün / varlık',
                            value: row.originalValue,
                          ),
                          _PublicEvidenceRow(
                            label: 'Sahte / doğrulanmamış ürün',
                            value: row.suspectedValue,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F7)),
            columns: const [
              DataColumn(label: Text('Kontrol noktası')),
              DataColumn(label: Text('Gerçek ürün / varlık')),
              DataColumn(label: Text('Sahte / doğrulanmamış ürün')),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text(
                            row.checkpoint,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(width: 290, child: Text(row.originalValue)),
                      ),
                      DataCell(
                        SizedBox(width: 290, child: Text(row.suspectedValue)),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class _PublicEvidenceRow extends StatelessWidget {
  const _PublicEvidenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w800,
            ),
          );
          final valueWidget = SelectableText(
            value,
            style: const TextStyle(color: Color(0xFF344054), height: 1.45),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 210, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

bool _hasExtendedEvidence(CounterfeitTwinPublicDetail detail) {
  final decoded = detail.decodedComparison;
  return decoded.rows.isNotEmpty ||
      decoded.priceObservedAt.isNotEmpty ||
      decoded.originalImageSource.isNotEmpty ||
      decoded.suspectedImageSource.isNotEmpty ||
      detail.authorizedPriceMin != null ||
      detail.authorizedPriceMax != null ||
      detail.suspectedPrice != null;
}

String _priceComparisonText(CounterfeitTwinPublicDetail detail) {
  final original = detail.authorizedPriceMin ?? detail.authorizedPriceMax;
  final suspected = detail.suspectedPrice;

  if (original == null || suspected == null) return '';

  final difference = suspected - original;
  final absoluteDifference = difference.abs();

  if (difference == 0) {
    return 'Fiyatlar aynı seviyede.';
  }

  final direction = difference < 0 ? 'daha düşük' : 'daha yüksek';

  if (original <= 0) {
    return '${absoluteDifference.toStringAsFixed(2)} ${detail.currency} '
        '$direction';
  }

  final percentage = (absoluteDifference / original) * 100;
  return '${absoluteDifference.toStringAsFixed(2)} ${detail.currency} '
      '$direction (%${percentage.toStringAsFixed(1)})';
}

class _FinancialImpactCard extends StatelessWidget {
  const _FinancialImpactCard({required this.detail});

  final CounterfeitTwinPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    final amount = detail.financialImpact.lossAmount;
    final text = amount == null
        ? 'Bu vaka için maddi kayıp bildirilmiştir.'
        : 'Bildirilen maddi kayıp: ${amount.toStringAsFixed(2)} '
              '${detail.financialImpact.currency}';
    return _SectionCard(
      title: 'Kamuya açık finansal etki özeti',
      icon: Icons.account_balance_wallet_outlined,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFB42318),
            height: 1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ShareSection extends StatelessWidget {
  const _ShareSection({
    required this.detail,
    required this.onShare,
    required this.onCopy,
  });

  final CounterfeitTwinPublicDetail detail;
  final ValueChanged<String> onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final buttons = <(String, String, IconData)>[
      ('whatsapp', 'WhatsApp', Icons.chat_outlined),
      ('x', 'X', Icons.alternate_email),
      ('facebook', 'Facebook', Icons.facebook_outlined),
      ('linkedin', 'LinkedIn', Icons.business_center_outlined),
      ('telegram', 'Telegram', Icons.send_outlined),
    ];
    return _SectionCard(
      title: 'Bu doğrulanmış kaydı paylaş',
      icon: Icons.ios_share_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            detail.shareDescription.isEmpty
                ? 'Gerçeği doğrula, sahte ikizi görünür kıl.'
                : detail.shareDescription,
            style: const TextStyle(color: Color(0xFF475467), height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...buttons.map(
                (item) => OutlinedButton.icon(
                  onPressed: () => onShare(item.$1),
                  icon: Icon(item.$3),
                  label: Text(item.$2),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.link_outlined),
                label: const Text('Bağlantıyı kopyala'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: MarkaKalkanTheme.teal),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            child,
          ],
        ),
      ),
    );
  }
}

class _PublicNotice extends StatelessWidget {
  const _PublicNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Bu sayfa kamuya açık bir MarkaKalkan doğrulama kaydıdır. '
        'Yalnız inceleme sonucunda yayımlanmasına karar verilen bilgiler '
        'gösterilir. Kişisel ve hassas bilgiler kamuya açılmaz.',
        style: TextStyle(color: Color(0xFF475467), height: 1.55),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 64,
                color: Color(0xFFB42318),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _authorizedPrice(CounterfeitTwinPublicDetail detail) {
  final min = detail.authorizedPriceMin;
  final max = detail.authorizedPriceMax;
  if (min == null && max == null) return '';
  if (min != null && max != null) {
    return '${min.toStringAsFixed(2)} – ${max.toStringAsFixed(2)} '
        '${detail.currency}';
  }
  return '${(min ?? max)!.toStringAsFixed(2)} ${detail.currency}';
}

String _categoryLabel(CounterfeitTwinPublicCategory category) {
  return switch (category) {
    CounterfeitTwinPublicCategory.physical => 'Fiziksel Sahte İkiz',
    CounterfeitTwinPublicCategory.digital => 'Dijital Sahte İkiz',
    CounterfeitTwinPublicCategory.aiRobot => 'Yapay Zekâ ve Robot Sahte İkizi',
  };
}

IconData _categoryIcon(CounterfeitTwinPublicCategory category) {
  return switch (category) {
    CounterfeitTwinPublicCategory.physical => Icons.inventory_2_outlined,
    CounterfeitTwinPublicCategory.digital => Icons.language_outlined,
    CounterfeitTwinPublicCategory.aiRobot => Icons.smart_toy_outlined,
  };
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

String _incidentLabel(String value) {
  const labels = <String, String>{
    'product_imitation': 'Ürün taklidi',
    'brand_impersonation': 'Marka kimliği taklidi',
    'platform_impersonation': 'Platform kimliği taklidi',
    'website_clone': 'Web sitesi klonu',
    'mobile_app_impersonation': 'Mobil uygulama taklidi',
    'interface_clone': 'Arayüz klonu',
    'fake_checkout': 'Sahte ödeme adımı',
    'fake_payment_page': 'Sahte ödeme sayfası',
    'fake_subscription': 'Sahte abonelik',
    'fake_reservation': 'Sahte rezervasyon',
    'fake_financial_service': 'Sahte finansal hizmet',
    'fake_investment_service': 'Sahte yatırım hizmeti',
    'fake_customer_support': 'Sahte müşteri desteği',
    'credential_phishing': 'Kimlik bilgisi avı',
    'payment_diversion': 'Ödeme yönlendirme',
    'iban_diversion': 'IBAN yönlendirme',
    'merchant_identity_deception': 'İşyeri kimliği yanıltması',
    'unauthorized_card_charge': 'Yetkisiz kart işlemi',
    'personal_data_harvesting': 'Kişisel veri toplama',
    'counterfeit_robot_hardware': 'Sahte robot donanımı',
    'robot_identity_clone': 'Robot kimliği klonu',
    'serial_number_clone': 'Seri numarası klonu',
    'device_certificate_clone': 'Cihaz sertifikası klonu',
    'control_software_clone': 'Kontrol yazılımı klonu',
    'firmware_clone': 'Firmware klonu',
    'fake_robot_certification': 'Sahte robot sertifikası',
    'teleoperation_channel_impersonation': 'Uzaktan kontrol kanalı taklidi',
    'robot_fleet_impersonation': 'Robot filosu kimliği taklidi',
    'ai_agent_impersonation': 'Yapay zekâ ajanı taklidi',
    'voice_persona_clone': 'Ses / persona klonu',
    'fake_robot_service_network': 'Sahte robot servis ağı',
    'other': 'Diğer',
  };
  return labels[value] ?? value;
}
