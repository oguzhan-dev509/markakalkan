import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_chain_presentation_labels.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_vault_page.dart';

class CaseEvidenceItemDetailPage extends StatefulWidget {
  const CaseEvidenceItemDetailPage({
    super.key,
    required this.evidenceRefId,
    this.repository,
  });
  final String evidenceRefId;
  final CaseEvidenceVaultRepository? repository;
  @override
  State<CaseEvidenceItemDetailPage> createState() =>
      _CaseEvidenceItemDetailPageState();
}

class _CaseEvidenceItemDetailPageState
    extends State<CaseEvidenceItemDetailPage> {
  late final CaseEvidenceVaultRepository repository =
      widget.repository ?? CallableCaseEvidenceVaultRepository();
  EvidenceItemDetail? detail;
  String? error;
  bool submitting = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await repository.loadDetail(widget.evidenceRefId);
      if (mounted) {
        setState(() {
          detail = value;
          error = null;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => error = e.code);
    } catch (_) {
      if (mounted) setState(() => error = 'generic');
    }
  }

  Future<void> _act(String type) async {
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(evidenceActionLabel(type)),
        content: TextField(
          key: const ValueKey('evidence-note'),
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'İşlem notu',
            helperText: 'En az 3 karakter girin.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Geri dön'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => submitting = true);
    try {
      final result = await repository.append(
        widget.evidenceRefId,
        type,
        controller.text.trim(),
        _requestId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'Bu işlem daha önce kaydedildi.'
                : 'Delil zinciri işlemi kaydedildi.',
          ),
        ),
      );
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'failed-precondition' =>
          'Bu işlem mevcut delil durumunda gerçekleştirilemiyor.',
        'permission-denied' => 'Bu işlem için yeterli yetkiniz bulunmuyor.',
        'not-found' => 'Delil kaydı artık bulunamıyor.',
        _ => 'Delil zinciri işlemi tamamlanamadı.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delil zinciri işlemi tamamlanamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
  }

  String _requestId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delil Ayrıntısı')),
    body: detail == null
        ? error == null
              ? const Center(
                  key: ValueKey('evidence-detail-loading'),
                  child: CircularProgressIndicator(),
                )
              : Center(
                  child: Text(
                    error == 'not-found'
                        ? 'Delil kaydı bulunamadı.'
                        : error == 'permission-denied'
                        ? 'Bu delili görüntüleme yetkiniz bulunmuyor.'
                        : 'Delil ayrıntısı yüklenemedi.',
                  ),
                )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                detail!.evidence.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${detail!.evidence.caseNumber} · ${detail!.evidence.caseTitle}',
              ),
              const SizedBox(height: 12),
              Text('Kaynak türü: ${evidenceTypeLabel(detail!.evidence.type)}'),
              Text('İnceleme: ${evidenceReviewLabel(detail!.evidence.review)}'),
              Text(
                'Teslim durumu: ${evidenceCustodyLabel(detail!.evidence.custody)}',
              ),
              Text(
                'Bütünlük: ${evidenceIntegrityLabel(detail!.evidence.integrity)}',
              ),
              Text('Zincir olay sayısı: ${detail!.evidence.count}'),
              const SizedBox(height: 20),
              const Text(
                'Delil Zinciri',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (detail!.events.isEmpty)
                const Text('Delil zinciri henüz başlatılmadı.')
              else
                ...detail!.events.map(
                  (event) => ListTile(
                    leading: CircleAvatar(child: Text('${event['sequence']}')),
                    title: Text(
                      evidenceEventLabel(event['eventType'] as String? ?? ''),
                    ),
                    subtitle: Text(
                      '${event['note']}\n${event['actorLabel']} · '
                      '${caseEvidenceDateTimeLabel(event['recordedAt'])}',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detail!.allowed
                    .map(
                      (action) => FilledButton(
                        onPressed: submitting ? null : () => _act(action),
                        child: Text(evidenceActionLabel(action)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
  );
}
