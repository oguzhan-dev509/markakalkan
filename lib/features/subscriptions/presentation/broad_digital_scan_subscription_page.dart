import 'dart:math';

import 'package:flutter/material.dart';
import 'package:markakalkan/features/subscriptions/data/subscription_request_repository.dart';
import 'package:markakalkan/features/subscriptions/domain/subscription_request_models.dart';

const Key broadDigitalScanSubscriptionSubmitButtonKey = Key(
  'broadDigitalScanSubscriptionSubmitButton',
);
const Key broadDigitalScanSubscriptionSuccessKey = Key(
  'broadDigitalScanSubscriptionSuccess',
);
const Key broadDigitalScanSubscriptionErrorKey = Key(
  'broadDigitalScanSubscriptionError',
);

final class BroadDigitalScanSubscriptionPage extends StatefulWidget {
  const BroadDigitalScanSubscriptionPage({
    super.key,
    required this.source,
    this.repository,
    this.requestIdFactory,
  });

  static const String routeName = '/subscriptions/broad-digital-scan-request';

  final BroadDigitalScanSubscriptionSource source;
  final SubscriptionServiceRequestRepository? repository;
  final String Function()? requestIdFactory;

  @override
  State<BroadDigitalScanSubscriptionPage> createState() =>
      _BroadDigitalScanSubscriptionPageState();
}

final class _BroadDigitalScanSubscriptionPageState
    extends State<BroadDigitalScanSubscriptionPage> {
  late final SubscriptionServiceRequestRepository _repository;
  late final String Function() _requestIdFactory;

  bool _submitting = false;
  SubscriptionServiceRequestResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableSubscriptionServiceRequestRepository();
    _requestIdFactory = widget.requestIdFactory ?? _newUuidV4;
  }

  Future<void> _submit() async {
    if (_submitting || _result != null) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.create(
        CreateSubscriptionServiceRequestCommand(
          requestId: _requestIdFactory(),
          source: widget.source,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } on SubscriptionServiceRequestFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Abonelik talebi oluşturulamadı.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik ve Hizmetler')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.radar_outlined,
                            size: 44,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Geniş Kapsamlı Tarama Aboneliği',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Daha fazla dijital kanalı taramak ve ayrıntılı '
                            'rapor almak için abonelik talebinizi oluşturun.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          _SourceRow(
                            label: 'Marka',
                            value: widget.source.brandName,
                          ),
                          const SizedBox(height: 10),
                          _SourceRow(
                            label: 'Resmî internet adresi',
                            value: widget.source.officialWebsiteUrl,
                          ),
                          const SizedBox(height: 24),
                          if (result == null)
                            FilledButton.icon(
                              key: broadDigitalScanSubscriptionSubmitButtonKey,
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(
                                _submitting
                                    ? 'Talep oluşturuluyor...'
                                    : 'Abonelik Talebi Oluştur',
                              ),
                            ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              key: broadDigitalScanSubscriptionErrorKey,
                              liveRegion: true,
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      key: broadDigitalScanSubscriptionSuccessKey,
                      color: colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.task_alt_outlined, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Talebiniz alındı',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Geniş kapsamlı tarama aboneliği talebiniz '
                              'güvenli biçimde kaydedildi.',
                            ),
                            const SizedBox(height: 10),
                            Text('Talep no: ${result.resultId}'),
                            if (result.idempotentReplay)
                              const Text(
                                'Mevcut talebiniz güvenli biçimde geri '
                                'getirildi.',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
