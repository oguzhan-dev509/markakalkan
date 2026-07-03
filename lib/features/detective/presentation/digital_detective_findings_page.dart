import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class DigitalDetectiveFindingsPage extends StatelessWidget {
  const DigitalDetectiveFindingsPage({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.brandName,
    required this.productName,
  });

  final String taskId;
  final String taskName;
  final String brandName;
  final String productName;

  CollectionReference<Map<String, dynamic>> get _findingsCollection {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Dijital Dedektif bulgularını görüntülemek için giriş yapılmalıdır.',
      );
    }

    return FirebaseFirestore.instance
        .collection('brands')
        .doc(user.uid)
        .collection('digitalDetectiveTasks')
        .doc(taskId)
        .collection('findings');
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList();
  }

  String _violationLabel(String violationId) {
    return switch (violationId) {
      'counterfeit_product' => 'Sahte ürün şüphesi',
      'fake_certificate' => 'Sahte sertifika',
      'fake_label' => 'Sahte etiket',
      'parallel_import_gray_market' => 'Paralel ithalat / gri pazar',
      'unauthorized_seller' => 'Yetkisiz satıcı',
      'brand_misuse' => 'Markanın izinsiz kullanımı',
      'logo_misuse' => 'Logo veya görsel kimlik ihlali',
      'domain_abuse' => 'Alan adı ihlali',
      'fake_website' => 'Sahte internet sitesi',
      'misleading_advertising' => 'Yanıltıcı reklam',
      _ => violationId,
    };
  }

  String _riskLabel(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'high' || 'yüksek' => 'Yüksek',
      'medium' || 'orta' => 'Orta',
      'low' || 'düşük' => 'Düşük',
      'standard' || 'standart' => 'Standart',
      _ => 'İnceleniyor',
    };
  }

  String _reviewStatusLabel(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'pending' || 'bekliyor' => 'Uzman incelemesi bekliyor',
      'in_review' || 'reviewing' => 'Uzman tarafından inceleniyor',
      'confirmed' || 'approved' => 'İhlal doğrulandı',
      'rejected' || 'dismissed' => 'İhlal olarak değerlendirilmedi',
      _ => 'Uzman incelemesi bekliyor',
    };
  }

  String _archiveStatusLabel(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'pending' || 'queued' => 'Arşivleme bekliyor',
      'capturing' || 'processing' => 'Delil yakalanıyor',
      'archived' || 'completed' => 'Arşivlendi',
      'failed' => 'Arşivleme başarısız',
      'not_required' => 'Arşivleme gerekmiyor',
      _ => 'Henüz arşivlenmedi',
    };
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      final text = value.trim();

      final turkishDatePattern = RegExp(
        r'^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$',
      );

      final match = turkishDatePattern.firstMatch(text);

      if (match != null) {
        date = DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6) ?? '0'),
        );
      } else {
        date = DateTime.tryParse(text);
      }
    }

    if (date == null) {
      return 'Tarih bekleniyor';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} · $hour:$minute';
  }

  String _priceText(Map<String, dynamic> data) {
    final price = data['price'];
    final currency = data['currency']?.toString() ?? '';

    if (price is num) {
      return '${price.toStringAsFixed(2)} $currency'.trim();
    }

    return 'Fiyat belirtilmedi';
  }

  Future<void> _openSourceUrl(BuildContext context, dynamic value) async {
    final sourceUrl = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(sourceUrl);

    final isValidWebUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    if (!isValidWebUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir kaynak bağlantısı bulunamadı.'),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak bağlantısı açılamadı.')),
      );
    }
  }

  Future<void> _openEvidenceImage(BuildContext context, dynamic value) async {
    final screenshotUrl = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(screenshotUrl);

    final isValidWebUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    if (!isValidWebUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delil görüntüsü henüz oluşturulmadı.')),
      );
      return;
    }

    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delil görüntüsü açılamadı.')),
      );
    }
  }

  void _showFindingDetails(
    BuildContext context,
    String findingId,
    Map<String, dynamic> data,
  ) {
    final violations = _stringList(data['violationIds']);
    final fieldRecommended = data['fieldRecommended'] == true;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          data['productTitle']?.toString().trim().isNotEmpty == true
              ? data['productTitle'].toString()
              : 'Dijital Bulgu',
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FindingDetailRow(label: 'Bulgu No', value: findingId),
                _FindingDetailRow(
                  label: 'Kaynak platform',
                  value: data['sourcePlatform']?.toString() ?? '-',
                ),
                _FindingSourceLink(
                  sourceUrl: data['sourceUrl']?.toString() ?? '',
                  onOpen: () => _openSourceUrl(context, data['sourceUrl']),
                ),
                _FindingDetailRow(
                  label: 'Yakalanan sayfa başlığı',
                  value: data['pageTitle']?.toString() ?? 'Henüz yakalanmadı',
                ),
                _FindingDetailRow(
                  label: 'Delil yakalama tarihi',
                  value: _formatDate(data['capturedAt']),
                ),
                _FindingDetailRow(
                  label: 'Arşivlenme durumu',
                  value: _archiveStatusLabel(data['archiveStatus']),
                ),
                _FindingEvidenceLink(
                  screenshotUrl: data['screenshotUrl']?.toString() ?? '',
                  onOpen: () =>
                      _openEvidenceImage(context, data['screenshotUrl']),
                ),
                _FindingDetailRow(
                  label: 'İçerik bütünlük parmak izi',
                  value:
                      data['contentHash']?.toString() ?? 'Henüz oluşturulmadı',
                ),
                _FindingDetailRow(
                  label: 'Satıcı',
                  value: data['sellerName']?.toString() ?? '-',
                ),
                _FindingDetailRow(
                  label: 'Ürün başlığı',
                  value: data['productTitle']?.toString() ?? '-',
                ),
                _FindingDetailRow(label: 'Fiyat', value: _priceText(data)),
                _FindingDetailRow(
                  label: 'Konum',
                  value: [data['city']?.toString(), data['country']?.toString()]
                      .whereType<String>()
                      .where((item) => item.isNotEmpty)
                      .join(', '),
                ),
                _FindingDetailRow(
                  label: 'İhlal türleri',
                  value: violations.isEmpty
                      ? '-'
                      : violations.map(_violationLabel).join(', '),
                ),
                _FindingDetailRow(
                  label: 'Risk seviyesi',
                  value: _riskLabel(data['riskLevel']),
                ),
                _FindingDetailRow(
                  label: 'Yapay zekâ değerlendirmesi',
                  value: data['aiAssessment']?.toString() ?? '-',
                ),
                _FindingDetailRow(
                  label: 'Uzman inceleme durumu',
                  value: _reviewStatusLabel(data['reviewStatus']),
                ),
                _FindingDetailRow(
                  label: 'Saha incelemesi',
                  value: fieldRecommended ? 'Önerildi' : 'Önerilmedi',
                ),
                _FindingDetailRow(
                  label: 'Tespit tarihi',
                  value: _formatDate(data['detectedAt']),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Dijital Bulgular',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _findingsCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FindingsMessage(
              icon: Icons.error_outline,
              title: 'Bulgular yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final findings = [...?snapshot.data?.docs];

          findings.sort((a, b) {
            final aDate = a.data()['detectedAt'];
            final bDate = b.data()['detectedAt'];

            final aMilliseconds = aDate is Timestamp
                ? aDate.millisecondsSinceEpoch
                : 0;
            final bMilliseconds = bDate is Timestamp
                ? bDate.millisecondsSinceEpoch
                : 0;

            return bMilliseconds.compareTo(aMilliseconds);
          });

          if (findings.isEmpty) {
            return _FindingsMessage(
              icon: Icons.manage_search_outlined,
              title: 'Henüz bulgu oluşturulmadı',
              description:
                  'Bu görev için henüz bulgu oluşturulmadı. Dijital tarama '
                  'başladığında sonuçlar burada görüntülenecektir.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FindingsHeader(
                      taskName: taskName,
                      brandName: brandName,
                      productName: productName,
                      findingCount: findings.length,
                    ),
                    const SizedBox(height: 22),
                    ...findings.map((document) {
                      final data = document.data();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FindingCard(
                          data: data,
                          detectedAt: _formatDate(data['detectedAt']),
                          priceText: _priceText(data),
                          violations: _stringList(data['violationIds']),
                          onOpen: () =>
                              _showFindingDetails(context, document.id, data),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FindingsHeader extends StatelessWidget {
  const _FindingsHeader({
    required this.taskName,
    required this.brandName,
    required this.productName,
    required this.findingCount,
  });

  final String taskName;
  final String brandName;
  final String productName;
  final int findingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fact_check_outlined,
            color: MarkaKalkanTheme.teal,
            size: 42,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$brandName · $productName\n'
                  '$findingCount dijital bulgu kayıtlı.',
                  style: const TextStyle(
                    color: Color(0xFFD9E5EA),
                    height: 1.45,
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

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.data,
    required this.detectedAt,
    required this.priceText,
    required this.violations,
    required this.onOpen,
  });

  final Map<String, dynamic> data;
  final String detectedAt;
  final String priceText;
  final List<String> violations;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final fieldRecommended = data['fieldRecommended'] == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.public_outlined,
                      color: MarkaKalkanTheme.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['productTitle']?.toString() ??
                              'İsimsiz dijital bulgu',
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${data['sourcePlatform'] ?? 'Kaynak belirtilmedi'} · '
                          '${data['sellerName'] ?? 'Satıcı belirtilmedi'}',
                          style: const TextStyle(color: Color(0xFF687580)),
                        ),
                      ],
                    ),
                  ),
                  _RiskBadge(
                    riskLevel: data['riskLevel']?.toString() ?? 'unknown',
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FindingChip(icon: Icons.payments_outlined, label: priceText),
                  _FindingChip(
                    icon: Icons.flag_outlined,
                    label:
                        [data['city']?.toString(), data['country']?.toString()]
                            .whereType<String>()
                            .where((item) => item.isNotEmpty)
                            .join(', '),
                  ),
                  _FindingChip(
                    icon: Icons.warning_amber_rounded,
                    label: violations.isEmpty
                        ? 'İhlal türü bekleniyor'
                        : '${violations.length} ihlal göstergesi',
                  ),
                  if (fieldRecommended)
                    const _FindingChip(
                      icon: Icons.location_searching_outlined,
                      label: 'Saha incelemesi önerildi',
                    ),
                ],
              ),
              const SizedBox(height: 17),
              const Divider(height: 1),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detectedAt,
                      style: const TextStyle(
                        color: Color(0xFF7A8790),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Bulgu Ayrıntısı'),
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

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.riskLevel});

  final String riskLevel;

  String get label {
    return switch (riskLevel.toLowerCase()) {
      'high' || 'yüksek' => 'Yüksek Risk',
      'medium' || 'orta' => 'Orta Risk',
      'low' || 'düşük' => 'Düşük Risk',
      _ => 'İnceleniyor',
    };
  }

  Color get backgroundColor {
    return switch (riskLevel.toLowerCase()) {
      'high' || 'yüksek' => const Color(0xFFFDECEC),
      'medium' || 'orta' => const Color(0xFFFFF4D8),
      'low' || 'düşük' => const Color(0xFFE8F6F4),
      _ => const Color(0xFFF0F2F4),
    };
  }

  Color get textColor {
    return switch (riskLevel.toLowerCase()) {
      'high' || 'yüksek' => const Color(0xFFB42318),
      'medium' || 'orta' => const Color(0xFF8A6110),
      'low' || 'düşük' => MarkaKalkanTheme.teal,
      _ => const Color(0xFF687580),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FindingChip extends StatelessWidget {
  const _FindingChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim().isEmpty ? 'Belirtilmedi' : label;

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: MarkaKalkanTheme.blue),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              displayLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingEvidenceLink extends StatelessWidget {
  const _FindingEvidenceLink({
    required this.screenshotUrl,
    required this.onOpen,
  });

  final String screenshotUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(screenshotUrl.trim());
    final hasValidUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delil görüntüsü',
            style: TextStyle(
              color: Color(0xFF7A8790),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          if (hasValidUrl)
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Delil Görüntüsünü Aç'),
            )
          else
            const Text(
              'Henüz delil görüntüsü oluşturulmadı',
              style: TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _FindingSourceLink extends StatelessWidget {
  const _FindingSourceLink({required this.sourceUrl, required this.onOpen});

  final String sourceUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(sourceUrl.trim());
    final hasValidUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kaynak bağlantısı',
            style: TextStyle(
              color: Color(0xFF7A8790),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          if (hasValidUrl)
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Kaynağı Aç'),
            )
          else
            const Text(
              'Bağlantı bulunamadı',
              style: TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _FindingDetailRow extends StatelessWidget {
  const _FindingDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8790),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            displayValue,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingsMessage extends StatelessWidget {
  const _FindingsMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 58, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
