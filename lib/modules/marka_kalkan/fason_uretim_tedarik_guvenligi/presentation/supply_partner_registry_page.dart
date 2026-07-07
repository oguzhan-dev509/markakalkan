import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../models/supply_partner_model.dart';
import '../repositories/supply_partner_repository.dart';
import 'supply_partner_create_dialog.dart';
import 'supply_partner_detail_edit_dialog.dart';

class SupplyPartnerRegistryPage extends StatelessWidget {
  const SupplyPartnerRegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutPage(title: 'Fason Üretici ve Tedarikçi Sicili');
    }

    final repository = SupplyPartnerRepository.instance(tenantId: user.uid);

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Fason Üretici ve Tedarikçi Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showSupplyPartnerCreateDialog(
            context: context,
            user: user,
            repository: repository,
          );

          if (created && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Partner taslak kaydı oluşturuldu.'),
              ),
            );
          }
        },
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text(
          'Yeni Partner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<SupplyPartnerModel>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Partner sicili yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final partners = snapshot.data ?? const <SupplyPartnerModel>[];

          if (partners.isEmpty) {
            return const _RegistryMessage(
              icon: Icons.handshake_outlined,
              title: 'Henüz partner kaydı yok',
              description:
                  'İlk fason üretici veya tedarikçi kaydı oluşturulduğunda '
                  'doğrulama, risk ve güven durumu burada görüntülenecek.',
            );
          }

          final activePartners = partners
              .where((item) => !item.isArchived)
              .toList(growable: false);

          final archivedCount = partners.length - activePartners.length;

          final highRisk = activePartners
              .where((item) => item.isHighRisk)
              .length;

          final verified = activePartners
              .where((item) => item.verificationStatus.name == 'verified')
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      active: activePartners.length,
                      archived: archivedCount,
                      verified: verified,
                      highRisk: highRisk,
                    ),
                    const SizedBox(height: 18),
                    ...activePartners.map(
                      (partner) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PartnerCard(
                          partner: partner,
                          user: user,
                          repository: repository,
                        ),
                      ),
                    ),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.active,
    required this.archived,
    required this.verified,
    required this.highRisk,
  });

  final int active;
  final int archived;
  final int verified;
  final int highRisk;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Aktif partner', value: '$active'),
        _MetricCard(label: 'Arşivlenen', value: '$archived'),
        _MetricCard(label: 'Doğrulandı', value: '$verified'),
        _MetricCard(label: 'Yüksek / kritik risk', value: '$highRisk'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.user,
    required this.repository,
  });

  final SupplyPartnerModel partner;
  final User user;
  final SupplyPartnerRepository repository;

  @override
  Widget build(BuildContext context) {
    final riskColor = partner.isHighRisk
        ? const Color(0xFFB42318)
        : const Color(0xFF16866F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final updated = await showSupplyPartnerDetailEditDialog(
            context: context,
            user: user,
            partner: partner,
            repository: repository,
          );

          if (updated && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Partner kaydı güncellendi.')),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE8F6F4),
                foregroundColor: MarkaKalkanTheme.teal,
                child: const Icon(Icons.business_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.legalName,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${partner.partnerCode} · '
                      '${partner.roles.map((item) => item.label).join(', ')}',
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: partner.status.label),
                        _Badge(label: partner.verificationStatus.label),
                        _Badge(
                          label: 'Risk: ${partner.riskLevel.label}',
                          foreground: riskColor,
                        ),
                        _Badge(label: 'Güven: ${partner.trustScore}/100'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.edit_outlined, color: MarkaKalkanTheme.teal),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.foreground = const Color(0xFF4D6470),
  });

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RegistryMessage extends StatelessWidget {
  const _RegistryMessage({
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
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

class _SignedOutPage extends StatelessWidget {
  const _SignedOutPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(title: Text(title)),
      body: const _RegistryMessage(
        icon: Icons.lock_outline,
        title: 'Oturum gerekli',
        description: 'Bu sicili görüntülemek için marka hesabıyla giriş yapın.',
      ),
    );
  }
}
