import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../models/supply_facility_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';
import 'supply_facility_create_dialog.dart';
import 'supply_facility_detail_edit_dialog.dart';

class SupplyFacilityRegistryPage extends StatelessWidget {
  const SupplyFacilityRegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutPage();
    }

    final repository = SupplyFacilityRepository.instance(tenantId: user.uid);
    final partnerRepository = SupplyPartnerRepository.instance(
      tenantId: user.uid,
    );

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Tesis, Depo ve Üretim Noktası Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            final created = await showSupplyFacilityCreateDialog(
              context: context,
              user: user,
              facilityRepository: repository,
              partnerRepository: partnerRepository,
            );

            if (created && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tesis taslak kaydı oluşturuldu.'),
                ),
              );
            }
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Partner listesi yüklenemedi: $error')),
              );
            }
          }
        },
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text(
          'Yeni Tesis',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<SupplyFacilityModel>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Tesis sicili yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final facilities = snapshot.data ?? const <SupplyFacilityModel>[];

          if (facilities.isEmpty) {
            return const _RegistryMessage(
              icon: Icons.factory_outlined,
              title: 'Henüz tesis kaydı yok',
              description:
                  'İlk fabrika, üretim hattı, depo veya şüpheli üretim noktası '
                  'kaydı oluşturulduğunda kapasite, vardiya, yetki ve risk '
                  'bilgileri burada görüntülenecek.',
            );
          }

          final activeFacilities = facilities
              .where((item) => !item.isArchived)
              .toList(growable: false);

          final archivedCount = facilities.length - activeFacilities.length;

          final highRisk = activeFacilities
              .where((item) => item.isHighRisk)
              .length;

          final unauthorized = activeFacilities
              .where((item) => item.isUnauthorizedOrSuspicious)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          label: 'Aktif tesis',
                          value: '${activeFacilities.length}',
                        ),
                        _MetricCard(
                          label: 'Arşivlenen',
                          value: '$archivedCount',
                        ),
                        _MetricCard(
                          label: 'Yüksek / kritik risk',
                          value: '$highRisk',
                        ),
                        _MetricCard(
                          label: 'Yetkisiz / şüpheli',
                          value: '$unauthorized',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...activeFacilities.map(
                      (facility) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _FacilityCard(
                          facility: facility,
                          user: user,
                          facilityRepository: repository,
                          partnerRepository: partnerRepository,
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

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({
    required this.facility,
    required this.user,
    required this.facilityRepository,
    required this.partnerRepository,
  });

  final SupplyFacilityModel facility;
  final User user;
  final SupplyFacilityRepository facilityRepository;
  final SupplyPartnerRepository partnerRepository;

  @override
  Widget build(BuildContext context) {
    final riskColor = facility.isHighRisk
        ? const Color(0xFFB42318)
        : const Color(0xFF16866F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          try {
            final updated = await showSupplyFacilityDetailEditDialog(
              context: context,
              user: user,
              facility: facility,
              facilityRepository: facilityRepository,
              partnerRepository: partnerRepository,
            );

            if (updated && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tesis kaydı güncellendi.')),
              );
            }
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tesis detayı açılamadı: $error')),
              );
            }
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
                child: const Icon(Icons.factory_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${facility.facilityCode} · '
                      '${facility.facilityType.label}'
                      '${facility.city == null ? '' : ' · ${facility.city}'}',
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
                        _Badge(label: facility.status.label),
                        _Badge(label: facility.authorizationStatus.label),
                        _Badge(
                          label: 'Risk: ${facility.riskLevel.label}',
                          foreground: riskColor,
                        ),
                        if (facility.monthlyCapacity != null)
                          _Badge(
                            label:
                                'Kapasite: ${facility.monthlyCapacity} '
                                '${facility.capacityUnit ?? ''}',
                          ),
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
  const _SignedOutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(title: const Text('Tesis, Depo ve Üretim Noktası Sicili')),
      body: const _RegistryMessage(
        icon: Icons.lock_outline,
        title: 'Oturum gerekli',
        description: 'Bu sicili görüntülemek için marka hesabıyla giriş yapın.',
      ),
    );
  }
}
