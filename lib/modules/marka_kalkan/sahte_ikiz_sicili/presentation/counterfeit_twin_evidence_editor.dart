import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import 'counterfeit_twin_comparison_codec.dart';

class CounterfeitTwinEvidencePayload {
  const CounterfeitTwinEvidencePayload({
    required this.rows,
    required this.originalImageUrls,
    required this.suspectedImageUrls,
    required this.originalSourceUrls,
    required this.suspectedSourceUrls,
    required this.originalPrice,
    required this.suspectedPrice,
    required this.currency,
    required this.priceObservedAt,
    required this.originalImageSource,
    required this.suspectedImageSource,
  });

  final List<CounterfeitTwinComparisonRow> rows;
  final List<String> originalImageUrls;
  final List<String> suspectedImageUrls;
  final List<String> originalSourceUrls;
  final List<String> suspectedSourceUrls;
  final double? originalPrice;
  final double? suspectedPrice;
  final String currency;
  final String priceObservedAt;
  final String originalImageSource;
  final String suspectedImageSource;
}

class CounterfeitTwinEvidenceEditor extends StatefulWidget {
  const CounterfeitTwinEvidenceEditor({required this.enabled, super.key});

  final bool enabled;

  @override
  State<CounterfeitTwinEvidenceEditor> createState() =>
      CounterfeitTwinEvidenceEditorState();
}

class CounterfeitTwinEvidenceEditorState
    extends State<CounterfeitTwinEvidenceEditor> {
  static const int maxImagesPerSide = 4;
  static const int maxImageBytes = 8 * 1024 * 1024;
  static const int maxComparisonRows = 8;

  final List<_ComparisonRowControllers> _rows = <_ComparisonRowControllers>[
    _ComparisonRowControllers(),
  ];
  final List<_SelectedEvidenceImage> _originalImages =
      <_SelectedEvidenceImage>[];
  final List<_SelectedEvidenceImage> _suspectedImages =
      <_SelectedEvidenceImage>[];

  final _originalPrice = TextEditingController();
  final _suspectedPrice = TextEditingController();
  final _originalPriceSource = TextEditingController();
  final _suspectedPriceSource = TextEditingController();
  final _originalImageSource = TextEditingController();
  final _suspectedImageSource = TextEditingController();

  String _currency = 'TRY';
  DateTime? _priceObservedAt;
  String? _error;
  bool _uploading = false;
  bool _committed = false;
  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final prefix = uid.length > 8 ? uid.substring(0, 8) : uid;
    _sessionId = '${DateTime.now().microsecondsSinceEpoch}_$prefix';
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    for (final controller in <TextEditingController>[
      _originalPrice,
      _suspectedPrice,
      _originalPriceSource,
      _suspectedPriceSource,
      _originalImageSource,
      _suspectedImageSource,
    ]) {
      controller.dispose();
    }
    if (!_committed) {
      unawaited(_deleteUploadedFiles());
    }
    super.dispose();
  }

  Future<CounterfeitTwinEvidencePayload> prepareForSubmit() async {
    if (_uploading) {
      throw StateError('Görseller hâlen yükleniyor.');
    }

    final rows = <CounterfeitTwinComparisonRow>[];
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final checkpoint = row.checkpoint.text.trim();
      final original = row.original.text.trim();
      final suspected = row.suspected.text.trim();
      final anyValue =
          checkpoint.isNotEmpty || original.isNotEmpty || suspected.isNotEmpty;

      if (!anyValue) continue;
      if (checkpoint.isEmpty || original.isEmpty || suspected.isEmpty) {
        final message =
            '${index + 1}. karşılaştırma satırındaki üç alan da doldurulmalıdır.';
        setState(() => _error = message);
        throw StateError(message);
      }

      rows.add(
        CounterfeitTwinComparisonRow(
          checkpoint: checkpoint,
          originalValue: original,
          suspectedValue: suspected,
        ),
      );
    }

    final originalPrice = _amount(_originalPrice.text, 'Gerçek fiyat');
    final suspectedPrice = _amount(
      _suspectedPrice.text,
      'Sahte / şüpheli fiyat',
    );
    final originalPriceSource = _url(
      _originalPriceSource.text,
      'Gerçek fiyat kaynağı',
    );
    final suspectedPriceSource = _url(
      _suspectedPriceSource.text,
      'Şüpheli fiyat kaynağı',
    );

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final originalImageUrls = await _upload(_originalImages, 'original');
      final suspectedImageUrls = await _upload(_suspectedImages, 'suspected');

      return CounterfeitTwinEvidencePayload(
        rows: List<CounterfeitTwinComparisonRow>.unmodifiable(rows),
        originalImageUrls: originalImageUrls,
        suspectedImageUrls: suspectedImageUrls,
        originalSourceUrls: originalPriceSource.isEmpty
            ? const <String>[]
            : <String>[originalPriceSource],
        suspectedSourceUrls: suspectedPriceSource.isEmpty
            ? const <String>[]
            : <String>[suspectedPriceSource],
        originalPrice: originalPrice,
        suspectedPrice: suspectedPrice,
        currency: _currency,
        priceObservedAt: _dateText(_priceObservedAt),
        originalImageSource: _originalImageSource.text.trim(),
        suspectedImageSource: _suspectedImageSource.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void markCommitted() {
    _committed = true;
  }

  Future<void> _pickImages({
    required List<_SelectedEvidenceImage> target,
    required String side,
  }) async {
    if (!widget.enabled || _uploading) return;
    if (target.length >= maxImagesPerSide) {
      setState(
        () => _error =
            'Her taraf için en fazla $maxImagesPerSide görsel eklenebilir.',
      );
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;

    var error = '';
    for (final file in result.files) {
      if (target.length >= maxImagesPerSide) {
        error = 'Her taraf için en fazla $maxImagesPerSide görsel eklenebilir.';
        break;
      }

      final bytes = file.bytes;
      final extension = (file.extension ?? '').toLowerCase();
      if (bytes == null || bytes.isEmpty) {
        error = '${file.name} okunamadı.';
        continue;
      }
      if (bytes.length > maxImageBytes) {
        error = '${file.name} 8 MB sınırını aşıyor.';
        continue;
      }
      if (!const <String>['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        error = '${file.name} desteklenen bir görsel türü değil.';
        continue;
      }

      final digest = sha256.convert(bytes).toString();
      final duplicate = <_SelectedEvidenceImage>[
        ..._originalImages,
        ..._suspectedImages,
      ].any((item) => item.sha256 == digest);
      if (duplicate) {
        error = '${file.name} daha önce eklendi.';
        continue;
      }

      target.add(
        _SelectedEvidenceImage(
          name: file.name,
          extension: extension,
          bytes: bytes,
          sha256: digest,
          contentType: _contentType(extension),
          side: side,
        ),
      );
    }

    setState(() => _error = error.isEmpty ? null : error);
  }

  Future<List<String>> _upload(
    List<_SelectedEvidenceImage> images,
    String side,
  ) async {
    if (images.isEmpty) return const <String>[];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Görsel yüklemek için oturum açılmalıdır.');
    }

    final urls = <String>[];
    for (final image in images) {
      if (image.downloadUrl != null) {
        urls.add(image.downloadUrl!);
        continue;
      }

      final fileName = '${image.sha256}.${image.extension}';
      final reference = FirebaseStorage.instance.ref(
        'counterfeit_twin_report_media/${user.uid}/'
        '$_sessionId/$side/$fileName',
      );
      image.storagePath = reference.fullPath;

      try {
        image.downloadUrl = await reference.getDownloadURL();
      } catch (_) {
        await reference.putData(
          image.bytes,
          SettableMetadata(
            contentType: image.contentType,
            customMetadata: <String, String>{
              'ownerUid': user.uid,
              'sessionId': _sessionId,
              'side': side,
              'originalFileName': image.name,
              'sha256': image.sha256,
              'hashAlgorithm': 'SHA-256',
            },
          ),
        );
        image.downloadUrl = await reference.getDownloadURL();
      }

      urls.add(image.downloadUrl!);
    }

    return List<String>.unmodifiable(urls);
  }

  Future<void> _removeImage(
    List<_SelectedEvidenceImage> target,
    _SelectedEvidenceImage image,
  ) async {
    if (!widget.enabled || _uploading) return;
    setState(() => target.remove(image));
    final path = image.storagePath;
    if (path == null) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // Best-effort cleanup; Storage rules and session isolation remain active.
    }
  }

  Future<void> _deleteUploadedFiles() async {
    final paths = <String?>{
      ..._originalImages.map((item) => item.storagePath),
      ..._suspectedImages.map((item) => item.storagePath),
    }.whereType<String>();

    for (final path in paths) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (_) {
        // Cleanup is intentionally best effort on dialog cancellation.
      }
    }
  }

  void _addRow() {
    if (!widget.enabled || _rows.length >= maxComparisonRows) return;
    setState(() => _rows.add(_ComparisonRowControllers()));
  }

  void _removeRow(int index) {
    if (!widget.enabled || _rows.length == 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _selectDate() async {
    if (!widget.enabled) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: _priceObservedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null || !mounted) return;
    setState(() => _priceObservedAt = selected);
  }

  double? _amount(String raw, String label) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value < 0) {
      throw StateError('$label geçerli ve sıfırdan büyük bir tutar olmalıdır.');
    }
    return value;
  }

  String _url(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !<String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw StateError('$label geçerli bir http/https bağlantısı olmalıdır.');
    }
    return value;
  }

  String _message(Object error) {
    if (error is FirebaseException) {
      return error.message ?? 'Görseller yüklenemedi.';
    }
    return error.toString().replaceFirst('Bad state: ', '');
  }

  String _dateText(DateTime? value) {
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EvidenceHeading(
          icon: Icons.compare_arrows_outlined,
          title: 'Yapılandırılmış gerçek–sahte karşılaştırması',
          subtitle:
              'Kontrol noktalarını satır satır girin. Boş bırakılan satırlar '
              'bildirime eklenmez.',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _rows.length; index++) ...[
          _ComparisonRowEditor(
            index: index,
            controllers: _rows[index],
            enabled: widget.enabled && !_uploading,
            removable: _rows.length > 1,
            onRemove: () => _removeRow(index),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed:
                widget.enabled &&
                    !_uploading &&
                    _rows.length < maxComparisonRows
                ? _addRow
                : null,
            icon: const Icon(Icons.add),
            label: Text(
              'Karşılaştırma satırı ekle '
              '(${_rows.length}/$maxComparisonRows)',
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _EvidenceHeading(
          icon: Icons.photo_library_outlined,
          title: 'Görsel deliller',
          subtitle:
              'Görseller isteğe bağlıdır. Gerçek ve şüpheli görselleri ayrı '
              'yükleyebilirsiniz. JPG, PNG veya WEBP; görsel başına en fazla '
              '8 MB.',
        ),
        const SizedBox(height: 12),
        _ImagePickerCard(
          title: 'Gerçek ürün görselleri',
          images: _originalImages,
          enabled: widget.enabled && !_uploading,
          onPick: () => _pickImages(target: _originalImages, side: 'original'),
          onRemove: (image) => _removeImage(_originalImages, image),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _originalImageSource,
          enabled: widget.enabled && !_uploading,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Gerçek görsel kaynağı / atfı',
            hintText: 'Örn. marka sahibi kataloğu, ürün ambalajı, resmî site',
          ),
        ),
        const SizedBox(height: 12),
        _ImagePickerCard(
          title: 'Sahte / şüpheli ürün görselleri',
          images: _suspectedImages,
          enabled: widget.enabled && !_uploading,
          onPick: () =>
              _pickImages(target: _suspectedImages, side: 'suspected'),
          onRemove: (image) => _removeImage(_suspectedImages, image),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _suspectedImageSource,
          enabled: widget.enabled && !_uploading,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Şüpheli görsel kaynağı / atfı',
            hintText: 'Örn. pazaryeri ilanı, mağaza sayfası, saha fotoğrafı',
          ),
        ),
        const SizedBox(height: 22),
        const _EvidenceHeading(
          icon: Icons.price_check_outlined,
          title: 'Fiyat karşılaştırması',
          subtitle:
              'Fiyatlar isteğe bağlıdır. Girildiğinde kaynak bağlantısı ve '
              'tespit tarihiyle birlikte saklanır.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final original = TextFormField(
              controller: _originalPrice,
              enabled: widget.enabled && !_uploading,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Gerçek fiyat'),
            );
            final suspected = TextFormField(
              controller: _suspectedPrice,
              enabled: widget.enabled && !_uploading,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Sahte / şüpheli fiyat',
              ),
            );
            final currency = DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Para birimi'),
              items: const <String>['TRY', 'USD', 'EUR', 'GBP']
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.enabled && !_uploading
                  ? (value) => setState(() => _currency = value ?? _currency)
                  : null,
            );

            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  original,
                  const SizedBox(height: 12),
                  suspected,
                  const SizedBox(height: 12),
                  currency,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: original),
                const SizedBox(width: 12),
                Expanded(child: suspected),
                const SizedBox(width: 12),
                Expanded(child: currency),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _originalPriceSource,
          enabled: widget.enabled && !_uploading,
          maxLength: 1200,
          decoration: const InputDecoration(
            labelText: 'Gerçek fiyat kaynağı URL',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _suspectedPriceSource,
          enabled: widget.enabled && !_uploading,
          maxLength: 1200,
          decoration: const InputDecoration(
            labelText: 'Şüpheli fiyat kaynağı URL',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.enabled && !_uploading ? _selectDate : null,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _priceObservedAt == null
                  ? 'Fiyat tespit tarihi seç'
                  : 'Fiyat tespit tarihi: ${_dateText(_priceObservedAt)}',
            ),
          ),
        ),
        if (_uploading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Görsel deliller güvenli alana yükleniyor...'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ComparisonRowControllers {
  final checkpoint = TextEditingController();
  final original = TextEditingController();
  final suspected = TextEditingController();

  void dispose() {
    checkpoint.dispose();
    original.dispose();
    suspected.dispose();
  }
}

class _ComparisonRowEditor extends StatelessWidget {
  const _ComparisonRowEditor({
    required this.index,
    required this.controllers,
    required this.enabled,
    required this.removable,
    required this.onRemove,
  });

  final int index;
  final _ComparisonRowControllers controllers;
  final bool enabled;
  final bool removable;
  final VoidCallback onRemove;

  String? _validator(String? value, String label) {
    final all = <String>[
      controllers.checkpoint.text.trim(),
      controllers.original.text.trim(),
      controllers.suspected.text.trim(),
    ];
    if (all.every((item) => item.isEmpty)) return null;
    if ((value ?? '').trim().isEmpty) return '$label zorunludur.';
    if ((value ?? '').trim().length > 300) {
      return '$label en fazla 300 karakter olabilir.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Karşılaştırma ${index + 1}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (removable)
                IconButton(
                  tooltip: 'Satırı kaldır',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers.checkpoint,
            enabled: enabled,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Kontrol noktası'),
            validator: (value) => _validator(value, 'Kontrol noktası'),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final original = TextFormField(
                controller: controllers.original,
                enabled: enabled,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Gerçek ürün / varlık',
                ),
                validator: (value) => _validator(value, 'Gerçek ürün / varlık'),
              );
              final suspected = TextFormField(
                controller: controllers.suspected,
                enabled: enabled,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Sahte / doğrulanmamış ürün',
                ),
                validator: (value) =>
                    _validator(value, 'Sahte / doğrulanmamış ürün'),
              );

              if (constraints.maxWidth < 650) {
                return Column(
                  children: [original, const SizedBox(height: 10), suspected],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: original),
                  const SizedBox(width: 10),
                  Expanded(child: suspected),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectedEvidenceImage {
  _SelectedEvidenceImage({
    required this.name,
    required this.extension,
    required this.bytes,
    required this.sha256,
    required this.contentType,
    required this.side,
  });

  final String name;
  final String extension;
  final Uint8List bytes;
  final String sha256;
  final String contentType;
  final String side;
  String? storagePath;
  String? downloadUrl;
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.title,
    required this.images,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final List<_SelectedEvidenceImage> images;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<_SelectedEvidenceImage> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${images.length}/'
                  '${CounterfeitTwinEvidenceEditorState.maxImagesPerSide})',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    enabled &&
                        images.length <
                            CounterfeitTwinEvidenceEditorState.maxImagesPerSide
                    ? onPick
                    : null,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Görsel seç'),
              ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: images
                  .map(
                    (image) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            image.bytes,
                            width: 118,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton.filledTonal(
                            tooltip: 'Görseli kaldır',
                            visualDensity: VisualDensity.compact,
                            onPressed: enabled ? () => onRemove(image) : null,
                            icon: const Icon(Icons.close, size: 17),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceHeading extends StatelessWidget {
  const _EvidenceHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E4E2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MarkaKalkanTheme.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF5F6F78), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
