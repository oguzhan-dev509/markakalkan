import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/markakalkan_theme.dart';
import '../constants/ip_enums.dart';
import '../models/ip_document_model.dart';
import '../repositories/firebase_ip_document_storage.dart';
import '../repositories/ip_document_repository.dart';
import '../services/ip_document_file_registration_service.dart';
import '../services/ip_document_upload_service.dart';
import '../services/ip_document_vault_service.dart';

class IpDocumentVaultPage extends StatefulWidget {
  const IpDocumentVaultPage({super.key});

  @override
  State<IpDocumentVaultPage> createState() => _IpDocumentVaultPageState();
}

class _IpDocumentVaultPageState extends State<IpDocumentVaultPage> {
  static const int _maximumFileSizeBytes = 25 * 1024 * 1024;

  static const List<String> _allowedExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'txt',
    'csv',
    'zip',
    'docx',
    'xlsx',
    'pptx',
    'odt',
    'ods',
    'odp',
  ];

  static const Map<String, String> _mimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'zip': 'application/zip',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'odt': 'application/vnd.oasis.opendocument.text',
    'ods': 'application/vnd.oasis.opendocument.spreadsheet',
    'odp': 'application/vnd.oasis.opendocument.presentation',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _documentCodeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  IpDocumentType _documentType = IpDocumentType.registrationCertificate;
  IpConfidentialityLevel _confidentiality = IpConfidentialityLevel.confidential;
  IpAccessLevel _accessLevel = IpAccessLevel.controlledView;
  IpRiskLevel _riskLevel = IpRiskLevel.medium;

  Uint8List? _selectedBytes;
  String? _selectedFileName;
  String? _selectedMimeType;
  int _selectedFileSizeBytes = 0;

  bool _isSelecting = false;
  bool _isUploading = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  IpDocumentRepository? get _repository {
    final user = _user;

    if (user == null) {
      return null;
    }

    return IpDocumentRepository.instance(tenantId: user.uid);
  }

  IpDocumentFileRegistrationService? get _registrationService {
    final user = _user;
    final repository = _repository;

    if (user == null || repository == null) {
      return null;
    }

    final vaultService = IpDocumentVaultService(
      repository: repository,
      tenantId: user.uid,
    );

    return IpDocumentFileRegistrationService(
      uploadService: IpDocumentUploadService(
        storage: FirebaseIpDocumentStorage(),
      ),
      recordWriter: IpDocumentVaultRecordWriter(vaultService: vaultService),
    );
  }

  @override
  void dispose() {
    _documentCodeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    if (_isSelecting || _isUploading) {
      return;
    }

    setState(() {
      _isSelecting = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      final extension = file.extension?.trim().toLowerCase();

      if (bytes == null || bytes.isEmpty) {
        throw StateError('Seçilen dosyanın içeriği okunamadı.');
      }

      if (bytes.lengthInBytes > _maximumFileSizeBytes) {
        throw StateError('Belge dosyası 25 MB sınırını aşamaz.');
      }

      if (extension == null || !_mimeTypes.containsKey(extension)) {
        throw StateError(
          'Seçilen dosya türü Belge Kasası tarafından desteklenmiyor.',
        );
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _selectedMimeType = _mimeTypes[extension];
        _selectedFileSizeBytes = bytes.lengthInBytes;
      });
    } catch (error) {
      if (mounted) {
        _showMessage(_errorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (_isUploading) {
      return;
    }

    final user = _user;
    final registrationService = _registrationService;
    final bytes = _selectedBytes;
    final fileName = _selectedFileName;
    final mimeType = _selectedMimeType;

    if (user == null || registrationService == null) {
      _showMessage(
        'Belge yüklemek için marka hesabıyla giriş yapılmalıdır.',
        isError: true,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (bytes == null || fileName == null || mimeType == null) {
      _showMessage('Önce yüklenecek belge dosyasını seçin.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final documentId =
          'ipdoc_${DateTime.now().toUtc().microsecondsSinceEpoch}';

      final draft = IpDocumentModel(
        id: documentId,
        tenantId: user.uid,
        brandId: user.uid,
        documentCode: _documentCodeController.text.trim(),
        title: _titleController.text.trim(),
        description: _nullableText(_descriptionController.text),
        documentType: _documentType,
        status: IpDocumentStatus.uploaded,
        confidentialityLevel: _confidentiality,
        accessLevel: _accessLevel,
        integrityStatus: IpEvidenceIntegrityStatus.notAssessed,
        riskLevel: _riskLevel,
        createdAt: DateTime.now().toUtc(),
        createdBy: user.uid,
        metadata: const <String, dynamic>{
          'registrationSource': 'ip_document_vault_ui',
        },
      );

      await registrationService.uploadAndCreate(
        draft: draft,
        bytes: bytes,
        originalFileName: fileName,
        mimeType: mimeType,
        uploadedBy: user.uid,
      );

      if (!mounted) {
        return;
      }

      _resetForm();

      _showMessage(
        'Belge güvenli kasaya yüklendi ve SHA-256 parmak izi oluşturuldu.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(_errorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _documentCodeController.clear();
    _titleController.clear();
    _descriptionController.clear();

    setState(() {
      _documentType = IpDocumentType.registrationCertificate;
      _confidentiality = IpConfidentialityLevel.confidential;
      _accessLevel = IpAccessLevel.controlledView;
      _riskLevel = IpRiskLevel.medium;
      _selectedBytes = null;
      _selectedFileName = null;
      _selectedMimeType = null;
      _selectedFileSizeBytes = 0;
    });
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedBytes = null;
      _selectedFileName = null;
      _selectedMimeType = null;
      _selectedFileSizeBytes = 0;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB42318) : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final repository = _repository;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Fikri Mülkiyet ve Belgeler',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: user == null || repository == null
          ? const _MessagePanel(
              icon: Icons.lock_person_outlined,
              title: 'Oturum gerekli',
              message: 'Belge Kasası için marka hesabıyla giriş yapmalısınız.',
            )
          : StreamBuilder<List<IpDocumentModel>>(
              stream: repository.watchAll(limit: 200),
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _VaultHeader(
                            documentCount: snapshot.data?.length ?? 0,
                          ),
                          const SizedBox(height: 24),
                          _buildUploadCard(),
                          const SizedBox(height: 24),
                          _buildDocumentList(snapshot),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Yeni Belge Yükle',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dosya türü ve boyutu doğrulanır; SHA-256 parmak izi '
              'oluşturulur ve fiziksel dosya Firestore kaydıyla bağlanır.',
              style: TextStyle(color: Color(0xFF687580), height: 1.5),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;

                final codeField = TextFormField(
                  controller: _documentCodeController,
                  enabled: !_isUploading,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Belge kodu',
                    hintText: 'Örn. MARKA-TR-2026-001',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredValidator,
                );

                final titleField = TextFormField(
                  controller: _titleController,
                  enabled: !_isUploading,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Belge başlığı',
                    hintText: 'Örn. Marka Tescil Belgesi',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredValidator,
                );

                if (narrow) {
                  return Column(
                    children: [
                      codeField,
                      const SizedBox(height: 14),
                      titleField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: codeField),
                    const SizedBox(width: 16),
                    Expanded(child: titleField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              enabled: !_isUploading,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth < 760
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 14) / 2;

                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _dropdown<IpDocumentType>(
                        label: 'Belge türü',
                        value: _documentType,
                        values: IpDocumentType.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) {
                          setState(() {
                            _documentType = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _dropdown<IpConfidentialityLevel>(
                        label: 'Gizlilik seviyesi',
                        value: _confidentiality,
                        values: IpConfidentialityLevel.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) {
                          setState(() {
                            _confidentiality = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _dropdown<IpAccessLevel>(
                        label: 'Erişim seviyesi',
                        value: _accessLevel,
                        values: IpAccessLevel.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) {
                          setState(() {
                            _accessLevel = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _dropdown<IpRiskLevel>(
                        label: 'Risk seviyesi',
                        value: _riskLevel,
                        values: IpRiskLevel.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) {
                          setState(() {
                            _riskLevel = value;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _SelectedFilePanel(
              fileName: _selectedFileName,
              mimeType: _selectedMimeType,
              fileSizeBytes: _selectedFileSizeBytes,
              isSelecting: _isSelecting,
              isUploading: _isUploading,
              onSelect: _selectFile,
              onRemove: _removeSelectedFile,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isUploading ? null : _uploadDocument,
              icon: _isUploading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _isUploading
                    ? 'Belge güvenli kasaya yükleniyor...'
                    : 'Belgeyi Güvenli Kasaya Yükle',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MarkaKalkanTheme.teal,
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentList(AsyncSnapshot<List<IpDocumentModel>> snapshot) {
    if (snapshot.hasError) {
      return _MessagePanel(
        icon: Icons.error_outline,
        title: 'Belge listesi yüklenemedi',
        message: _errorMessage(snapshot.error!),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _MessagePanel(
        icon: Icons.hourglass_top_rounded,
        title: 'Belge Kasası yükleniyor',
        message: 'Güvenli belge kayıtları getiriliyor.',
        showProgress: true,
      );
    }

    final documents = snapshot.data ?? const <IpDocumentModel>[];

    if (documents.isEmpty) {
      return const _MessagePanel(
        icon: Icons.inventory_2_outlined,
        title: 'Belge Kasası henüz boş',
        message: 'İlk fikri mülkiyet belgenizi yukarıdan yükleyin.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kasa Belgeleri (${documents.length})',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...documents.map(_documentTile),
        ],
      ),
    );
  }

  Widget _documentTile(IpDocumentModel document) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${document.documentCode} • ${document.documentType.label}',
            style: const TextStyle(
              color: Color(0xFF687580),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocumentBadge(
                label: document.status.label,
                icon: Icons.cloud_done_outlined,
              ),
              _DocumentBadge(
                label: document.integrityStatus.label,
                icon: Icons.fingerprint,
              ),
              _DocumentBadge(
                label: document.confidentialityLevel.label,
                icon: Icons.lock_outline,
              ),
              _DocumentBadge(
                label: _formatBytes(document.fileSizeBytes),
                icon: Icons.insert_drive_file_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isUploading
          ? null
          : (selected) {
              if (selected != null) {
                onChanged(selected);
              }
            },
    );
  }

  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }

    return null;
  }

  static String? _nullableText(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? error.toString();
    }

    return error.toString();
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0E7EC)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({required this.documentCount});

  final int documentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belge Kasası',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tescil, sözleşme, teknik dosya ve kanıt kayıtları '
            'SHA-256 parmak iziyle korunur.',
            style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            '$documentCount güvenli belge kaydı',
            style: const TextStyle(
              color: MarkaKalkanTheme.teal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFilePanel extends StatelessWidget {
  const _SelectedFilePanel({
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.isSelecting,
    required this.isUploading,
    required this.onSelect,
    required this.onRemove,
  });

  final String? fileName;
  final String? mimeType;
  final int fileSizeBytes;
  final bool isSelecting;
  final bool isUploading;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (fileName == null) {
      return OutlinedButton.icon(
        onPressed: isSelecting || isUploading ? null : onSelect,
        icon: isSelecting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file),
        label: Text(
          isSelecting
              ? 'Dosya seçiliyor...'
              : 'Belge Dosyası Seç — En fazla 25 MB',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: MarkaKalkanTheme.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$mimeType • '
                  '${_IpDocumentVaultPageState._formatBytes(fileSizeBytes)}',
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isUploading ? null : onRemove,
            tooltip: 'Dosyayı kaldır',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _DocumentBadge extends StatelessWidget {
  const _DocumentBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MarkaKalkanTheme.blue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: MarkaKalkanTheme.blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 760),
        decoration: _IpDocumentVaultPageState._cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MarkaKalkanTheme.teal, size: 42),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687580), height: 1.5),
            ),
            if (showProgress) ...[
              const SizedBox(height: 17),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
