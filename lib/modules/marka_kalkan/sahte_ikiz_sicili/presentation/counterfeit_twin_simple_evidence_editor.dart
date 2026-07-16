import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class CounterfeitTwinSimpleEvidencePayload {
  const CounterfeitTwinSimpleEvidencePayload({required this.imageUrls});

  final List<String> imageUrls;
}

class CounterfeitTwinSimpleEvidenceEditor extends StatefulWidget {
  const CounterfeitTwinSimpleEvidenceEditor({required this.enabled, super.key});

  final bool enabled;

  @override
  State<CounterfeitTwinSimpleEvidenceEditor> createState() =>
      CounterfeitTwinSimpleEvidenceEditorState();
}

class CounterfeitTwinSimpleEvidenceEditorState
    extends State<CounterfeitTwinSimpleEvidenceEditor> {
  static const int maxImages = 6;
  static const int maxImageBytes = 8 * 1024 * 1024;

  final List<_SelectedEvidenceImage> _images = <_SelectedEvidenceImage>[];

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
    if (!_committed) {
      unawaited(_deleteUploadedFiles());
    }
    super.dispose();
  }

  Future<CounterfeitTwinSimpleEvidencePayload> prepareForSubmit() async {
    if (_uploading) {
      throw StateError('Kanıt görselleri hâlen yükleniyor.');
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final imageUrls = await _uploadImages();
      return CounterfeitTwinSimpleEvidencePayload(
        imageUrls: List<String>.unmodifiable(imageUrls),
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

  Future<void> _pickImages() async {
    if (!widget.enabled || _uploading) return;
    if (_images.length >= maxImages) {
      setState(() => _error = 'En fazla $maxImages kanıt görseli eklenebilir.');
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
      if (_images.length >= maxImages) {
        error = 'En fazla $maxImages kanıt görseli eklenebilir.';
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
      if (_images.any((item) => item.sha256 == digest)) {
        error = '${file.name} daha önce eklendi.';
        continue;
      }

      _images.add(
        _SelectedEvidenceImage(
          name: file.name,
          extension: extension,
          bytes: bytes,
          sha256: digest,
          contentType: _contentType(extension),
        ),
      );
    }

    setState(() => _error = error.isEmpty ? null : error);
  }

  Future<List<String>> _uploadImages() async {
    if (_images.isEmpty) return const <String>[];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Kanıt görseli yüklemek için oturum açılmalıdır.');
    }

    final urls = <String>[];
    for (final image in _images) {
      if (image.downloadUrl != null) {
        urls.add(image.downloadUrl!);
        continue;
      }

      final fileName = '${image.sha256}.${image.extension}';
      final reference = FirebaseStorage.instance.ref(
        'counterfeit_twin_report_media/${user.uid}/'
        '$_sessionId/evidence/$fileName',
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
              'side': 'evidence',
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

    return urls;
  }

  Future<void> _removeImage(_SelectedEvidenceImage image) async {
    if (!widget.enabled || _uploading) return;
    setState(() => _images.remove(image));
    final path = image.storagePath;
    if (path == null) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // İptal veya kaldırma sırasında temizlik en iyi çabayla yapılır.
    }
  }

  Future<void> _deleteUploadedFiles() async {
    for (final path
        in _images.map((item) => item.storagePath).whereType<String>()) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (_) {
        // Diyalog kapatılırken temizlik en iyi çabayla yapılır.
      }
    }
  }

  String _message(Object error) {
    if (error is FirebaseException) {
      return error.message ?? 'Kanıt görselleri yüklenemedi.';
    }
    return error.toString().replaceFirst('Bad state: ', '');
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: MarkaKalkanTheme.teal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kanıt görseli ekleyin',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fotoğraf veya ekran görüntüsü ekleyebilirsiniz. '
                      'JPG, PNG ya da WEBP; görsel başına en fazla 8 MB.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5F6F78),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  widget.enabled && !_uploading && _images.length < maxImages
                  ? _pickImages
                  : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text('Kanıt görseli seç (${_images.length}/$maxImages)'),
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _images
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
                            onPressed: widget.enabled && !_uploading
                                ? () => _removeImage(image)
                                : null,
                            icon: const Icon(Icons.close, size: 17),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (_uploading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Kanıt görselleri güvenli alana yükleniyor...'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
  });

  final String name;
  final String extension;
  final Uint8List bytes;
  final String sha256;
  final String contentType;
  String? storagePath;
  String? downloadUrl;
}
