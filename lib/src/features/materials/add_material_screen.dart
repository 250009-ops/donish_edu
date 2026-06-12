import 'dart:convert' show base64Encode;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../util/material_file_reader.dart';
import '../billing/models/subscription_info.dart';
import '../billing/widgets/premium_paywall_dialog.dart';
import 'material_pdf_help_dialog.dart';
import 'material_photo_capture.dart';
import 'material_text_review_screen.dart';

const Color _kViolet = Color(0xFF8840FE);

enum MaterialInputSource { pdf, photo, write }

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({
    super.key,
    required this.onFormChanged,
    required this.onUploadSuccess,
    required this.onRegisterUpload,
    this.subscription,
    this.onUpgrade,
    this.onCreateCheckout,
  });

  final void Function({
    required bool hasContent,
    required String name,
    required String? type,
    required String? level,
    required bool uploading,
  }) onFormChanged;

  final VoidCallback onUploadSuccess;

  final void Function(VoidCallback upload) onRegisterUpload;
  final SubscriptionInfo? subscription;
  final VoidCallback? onUpgrade;
  final Future<String> Function()? onCreateCheckout;

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  MaterialInputSource _source = MaterialInputSource.pdf;

  String? _fileName;
  String? _filePath;
  Uint8List? _fileBytes;

  final List<Uint8List> _photoPages = [];

  final _nameController = TextEditingController();
  String? _selectedType;
  String? _selectedLevel;
  bool _isUploading = false;

  static const List<String> _typeOptions = [
    'Article',
    'Short Story',
    'Book',
    'Document',
    'Other',
  ];

  static const List<String> _levelOptions = [
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
    'C2',
  ];

  bool get _isSourceReady {
    switch (_source) {
      case MaterialInputSource.pdf:
        return (_fileBytes != null && _fileBytes!.isNotEmpty) ||
            (_filePath != null && _filePath!.isNotEmpty);
      case MaterialInputSource.photo:
        return _photoPages.isNotEmpty;
      case MaterialInputSource.write:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.onRegisterUpload(_upload);
    _nameController.addListener(_notifyFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFormChanged());
  }

  @override
  void dispose() {
    _nameController.removeListener(_notifyFormChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _notifyFormChanged() {
    widget.onFormChanged(
      hasContent: _isSourceReady,
      name: _nameController.text,
      type: _selectedType,
      level: _selectedLevel,
      uploading: _isUploading,
    );
  }

  void _setSource(MaterialInputSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _fileName = null;
      _filePath = null;
      _fileBytes = null;
      _photoPages.clear();
      if (source == MaterialInputSource.write) {
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = '';
        }
      } else {
        _nameController.clear();
      }
      _selectedType = null;
      _selectedLevel = null;
    });
    _notifyFormChanged();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final nameFromFile =
        file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    setState(() {
      _fileName = file.name;
      _filePath = file.path;
      _fileBytes = file.bytes != null && file.bytes!.isNotEmpty
          ? Uint8List.fromList(file.bytes!)
          : null;
      _nameController.text = nameFromFile;
    });
    _notifyFormChanged();
  }

  void _clearPdf() {
    setState(() {
      _fileName = null;
      _filePath = null;
      _fileBytes = null;
      _nameController.clear();
      _selectedType = null;
      _selectedLevel = null;
    });
    _notifyFormChanged();
  }

  Future<void> _addPhotoPage(ImageSource source) async {
    if (_photoPages.length >= kMaxPhotoPages) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $kMaxPhotoPages pages per material.'),
        ),
      );
      return;
    }

    final bytes = await captureAndCropPage(context, source: source);
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _photoPages.add(bytes);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = 'Photo material';
      }
    });
    _notifyFormChanged();
  }

  void _removePhotoPage(int index) {
    setState(() {
      _photoPages.removeAt(index);
      if (_photoPages.isEmpty) {
        _nameController.clear();
        _selectedType = null;
        _selectedLevel = null;
      }
    });
    _notifyFormChanged();
  }

  void _clearPhotos() {
    setState(() {
      _photoPages.clear();
      _nameController.clear();
      _selectedType = null;
      _selectedLevel = null;
    });
    _notifyFormChanged();
  }

  Future<List<int>?> _loadPdfBytes() async {
    final fromDisk = await readBytesFromPath(_filePath);
    if (fromDisk != null && fromDisk.isNotEmpty) return fromDisk;
    if (_fileBytes != null && _fileBytes!.isNotEmpty) return _fileBytes!;
    return null;
  }

  Future<void> _showUpgradePaywall(String message) async {
    final checkout = widget.onCreateCheckout;
    if (checkout == null) {
      widget.onUpgrade?.call();
      return;
    }
    await showPremiumPaywallDialog(
      context,
      title: 'Upload limit reached',
      message: message,
      subscription: widget.subscription ?? SubscriptionInfo.freeDefaults(),
      onCreateCheckout: checkout,
    );
  }

  Future<bool> _openReviewScreen({
    required String extracted,
    required int pageCount,
    required String fileName,
    required String reviewHint,
  }) async {
    if (!mounted) return false;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MaterialTextReviewScreen(
          initialExtractedText: extracted,
          pageCount: pageCount,
          fileName: fileName,
          title: _nameController.text.trim(),
          materialType: _selectedType!,
          englishLevel: _selectedLevel!,
          reviewHint: reviewHint,
          subscription: widget.subscription,
          onUpgrade: widget.onUpgrade,
          onCreateCheckout: widget.onCreateCheckout,
        ),
      ),
    );
    return saved == true;
  }

  Future<void> _upload() async {
    if (_nameController.text.trim().isEmpty) return;
    if (_selectedType == null || _selectedLevel == null) return;
    if (!_isSourceReady) return;

    setState(() => _isUploading = true);
    _notifyFormChanged();

    try {
      if (_source == MaterialInputSource.write) {
        final saved = await _openReviewScreen(
          extracted: '',
          pageCount: 0,
          fileName: 'manual.txt',
          reviewHint:
              'Write or paste your English text below, then tap Save to Materials.',
        );
        if (!mounted) return;
        if (saved) widget.onUploadSuccess();
        return;
      }

      if (_source == MaterialInputSource.photo) {
        final imagesB64 = _photoPages
            .map((b) => base64Encode(b))
            .toList(growable: false);

        final preview = await ApiClient.instance.postJson(
          '/materials/extract-preview',
          authenticated: true,
          timeout: const Duration(minutes: 5),
          body: {'images_base64': imagesB64},
        );

        final extracted = preview['extracted_text'];
        if (extracted is! String || extracted.isEmpty) {
          if (!mounted) return;
          showMaterialUploadError(
            context,
            const ApiException('No text returned from the server.'),
          );
          return;
        }

        final pcRaw = preview['page_count'];
        final pageCount = pcRaw is int
            ? pcRaw
            : (pcRaw is num ? pcRaw.toInt() : _photoPages.length);

        final saved = await _openReviewScreen(
          extracted: extracted,
          pageCount: pageCount,
          fileName: 'photos_${_photoPages.length}_pages.jpg',
          reviewHint:
              'Check the extracted text from your photos, edit if needed, then save.',
        );
        if (!mounted) return;
        if (saved) widget.onUploadSuccess();
        return;
      }

      // PDF
      if (_fileName == null) return;
      final raw = await _loadPdfBytes();
      if (raw == null || raw.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read this PDF. Try choosing the file again.',
            ),
          ),
        );
        return;
      }

      final preview = await ApiClient.instance.postJson(
        '/materials/extract-preview',
        authenticated: true,
        timeout: const Duration(minutes: 5),
        body: {
          'pdf_base64': base64Encode(Uint8List.fromList(raw)),
          'file_name': _fileName!,
        },
      );

      final extracted = preview['extracted_text'];
      if (extracted is! String || extracted.isEmpty) {
        if (!mounted) return;
        showMaterialUploadError(
          context,
          const ApiException('No text returned from the server.'),
        );
        return;
      }

      final pcRaw = preview['page_count'];
      final pageCount = pcRaw is int
          ? pcRaw
          : (pcRaw is num ? pcRaw.toInt() : 0);

      final saved = await _openReviewScreen(
        extracted: extracted,
        pageCount: pageCount,
        fileName: _fileName!,
        reviewHint:
            'Last step: tap Save to Materials below so this upload appears on your Materials page.',
      );
      if (!mounted) return;
      if (saved) widget.onUploadSuccess();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'upgrade_required') {
        await _showUpgradePaywall(e.message);
        return;
      }
      showMaterialUploadError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _notifyFormChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        MediaQuery.viewPaddingOf(context).bottom + 80;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SourceSelector(
              selected: _source,
              onChanged: _setSource,
            ),
            const SizedBox(height: 12),
            _SourceContentCard(
              source: _source,
              fileName: _fileName,
              photoPages: _photoPages,
              onPickPdf: _pickFile,
              onClearPdf: _fileName != null ? _clearPdf : null,
              onTakePhoto: () => _addPhotoPage(ImageSource.camera),
              onPickGallery: () => _addPhotoPage(ImageSource.gallery),
              onRemovePhoto: _removePhotoPage,
              onClearPhotos: _photoPages.isNotEmpty ? _clearPhotos : null,
              onHelp: () => showMaterialSourcesHelpDialog(context),
            ),
            const SizedBox(height: 16),
            _DetailsCard(
              enabled: _isSourceReady,
              lockMessage: _source == MaterialInputSource.photo
                  ? 'Add at least one photo'
                  : 'Choose a PDF first',
              showLock: _source != MaterialInputSource.write,
              nameController: _nameController,
              selectedType: _selectedType,
              selectedLevel: _selectedLevel,
              typeOptions: _typeOptions,
              levelOptions: _levelOptions,
              onTypeChanged: (v) {
                setState(() => _selectedType = v);
                _notifyFormChanged();
              },
              onLevelChanged: (v) {
                setState(() => _selectedLevel = v);
                _notifyFormChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source selector ─────────────────────────────────────────────────────────

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({
    required this.selected,
    required this.onChanged,
  });

  final MaterialInputSource selected;
  final ValueChanged<MaterialInputSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceChip(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            selected: selected == MaterialInputSource.pdf,
            onTap: () => onChanged(MaterialInputSource.pdf),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SourceChip(
            icon: Icons.photo_camera_rounded,
            label: 'Photo',
            selected: selected == MaterialInputSource.photo,
            onTap: () => onChanged(MaterialInputSource.photo),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SourceChip(
            icon: Icons.edit_note_rounded,
            label: 'Write',
            selected: selected == MaterialInputSource.write,
            onTap: () => onChanged(MaterialInputSource.write),
          ),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kViolet : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kViolet : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dynamic source content card ─────────────────────────────────────────────

class _SourceContentCard extends StatelessWidget {
  const _SourceContentCard({
    required this.source,
    required this.fileName,
    required this.photoPages,
    required this.onPickPdf,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onRemovePhoto,
    required this.onHelp,
    this.onClearPdf,
    this.onClearPhotos,
  });

  final MaterialInputSource source;
  final String? fileName;
  final List<Uint8List> photoPages;
  final VoidCallback onPickPdf;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final void Function(int index) onRemovePhoto;
  final VoidCallback onHelp;
  final VoidCallback? onClearPdf;
  final VoidCallback? onClearPhotos;

  @override
  Widget build(BuildContext context) {
    switch (source) {
      case MaterialInputSource.pdf:
        return _PdfUploadCard(
          fileName: fileName,
          onPickFile: onPickPdf,
          onClear: onClearPdf,
          onHelp: onHelp,
        );
      case MaterialInputSource.photo:
        return _PhotoUploadCard(
          photoPages: photoPages,
          onTakePhoto: onTakePhoto,
          onPickGallery: onPickGallery,
          onRemovePhoto: onRemovePhoto,
          onClear: onClearPhotos,
          onHelp: onHelp,
        );
      case MaterialInputSource.write:
        return _WriteSourceCard(onHelp: onHelp);
    }
  }
}

class _PdfUploadCard extends StatelessWidget {
  const _PdfUploadCard({
    required this.fileName,
    required this.onPickFile,
    required this.onHelp,
    this.onClear,
  });

  final String? fileName;
  final VoidCallback onPickFile;
  final VoidCallback onHelp;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;

    return _ContentCardShell(
      hasContent: hasFile,
      onClear: onClear,
      onHelp: onHelp,
      child: InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              _IconTile(
                icon: hasFile
                    ? Icons.picture_as_pdf_rounded
                    : Icons.upload_file_rounded,
                active: hasFile,
              ),
              const SizedBox(height: 14),
              if (hasFile) ...[
                _StatusPill(label: fileName!),
                const SizedBox(height: 8),
                Text(
                  'Tap to change file',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ] else ...[
                Text(
                  'Choose PDF',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Digital or scanned',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LimitChip(icon: Icons.layers_outlined, label: '30 pg'),
                  SizedBox(width: 8),
                  _LimitChip(icon: Icons.sd_storage_outlined, label: '30 MB'),
                  SizedBox(width: 8),
                  _LimitChip(icon: Icons.timer_outlined, label: '~2 min'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoUploadCard extends StatelessWidget {
  const _PhotoUploadCard({
    required this.photoPages,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onRemovePhoto,
    required this.onHelp,
    this.onClear,
  });

  final List<Uint8List> photoPages;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final void Function(int index) onRemovePhoto;
  final VoidCallback onHelp;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasPages = photoPages.isNotEmpty;

    return _ContentCardShell(
      hasContent: hasPages,
      onClear: onClear,
      onHelp: onHelp,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            _IconTile(
              icon: hasPages
                  ? Icons.photo_library_rounded
                  : Icons.photo_camera_rounded,
              active: hasPages,
            ),
            const SizedBox(height: 14),
            Text(
              hasPages ? '${photoPages.length} page${photoPages.length == 1 ? '' : 's'}' : 'Take or import',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasPages ? 'Crop each page for best OCR' : 'Camera or gallery, then crop',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            if (hasPages) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoPages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            photoPages[index],
                            width: 56,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: _CircleIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => onRemovePhoto(index),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_camera_rounded,
                    label: 'Camera',
                    onTap: onTakePhoto,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: onPickGallery,
                    outlined: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LimitChip(icon: Icons.layers_outlined, label: '30 pg'),
                SizedBox(width: 8),
                _LimitChip(icon: Icons.crop_rounded, label: 'Crop'),
                SizedBox(width: 8),
                _LimitChip(icon: Icons.timer_outlined, label: '~1 min/pg'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteSourceCard extends StatelessWidget {
  const _WriteSourceCard({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return _ContentCardShell(
      hasContent: true,
      onHelp: onHelp,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            const _IconTile(
              icon: Icons.edit_note_rounded,
              active: true,
            ),
            const SizedBox(height: 14),
            Text(
              'Write or paste',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add title & level below, then tap upload to edit text',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LimitChip(icon: Icons.edit_outlined, label: 'Type'),
                SizedBox(width: 8),
                _LimitChip(icon: Icons.content_paste_rounded, label: 'Paste'),
                SizedBox(width: 8),
                _LimitChip(icon: Icons.check_circle_outline, label: 'Review'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCardShell extends StatelessWidget {
  const _ContentCardShell({
    required this.hasContent,
    required this.onHelp,
    required this.child,
    this.onClear,
  });

  final bool hasContent;
  final VoidCallback onHelp;
  final VoidCallback? onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasContent
                ? _kViolet.withOpacity(0.35)
                : const Color(0xFFE5E7EB),
            width: hasContent ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            child,
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onClear != null)
                    _CircleIconButton(
                      icon: Icons.close_rounded,
                      onTap: onClear!,
                    ),
                  if (onClear != null) const SizedBox(width: 4),
                  _CircleIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: onHelp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: active
            ? _kViolet.withOpacity(0.12)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        size: 36,
        color: active ? _kViolet : const Color(0xFF9CA3AF),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: _kViolet,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4C1D95),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.white : _kViolet,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: outlined
                ? Border.all(color: const Color(0xFFE5E7EB))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: outlined ? _kViolet : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: outlined ? _kViolet : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

// ── Visual metadata for type chips ──────────────────────────────────────────

class _TypeMeta {
  const _TypeMeta(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _typeMeta = <String, _TypeMeta>{
  'Article': _TypeMeta('Article', Icons.article_outlined),
  'Short Story': _TypeMeta('Story', Icons.auto_stories_outlined),
  'Book': _TypeMeta('Book', Icons.menu_book_outlined),
  'Document': _TypeMeta('Doc', Icons.description_outlined),
  'Other': _TypeMeta('Other', Icons.more_horiz_rounded),
};

Color _levelColor(String level) {
  switch (level) {
    case 'A1':
      return const Color(0xFF10B981);
    case 'A2':
      return const Color(0xFF34D399);
    case 'B1':
      return const Color(0xFFF59E0B);
    case 'B2':
      return const Color(0xFFF97316);
    case 'C1':
      return const Color(0xFFEF4444);
    case 'C2':
      return const Color(0xFF8840FE);
    default:
      return const Color(0xFF9CA3AF);
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.enabled,
    required this.lockMessage,
    required this.showLock,
    required this.nameController,
    required this.selectedType,
    required this.selectedLevel,
    required this.typeOptions,
    required this.levelOptions,
    required this.onTypeChanged,
    required this.onLevelChanged,
  });

  final bool enabled;
  final String lockMessage;
  final bool showLock;
  final TextEditingController nameController;
  final String? selectedType;
  final String? selectedLevel;
  final List<String> typeOptions;
  final List<String> levelOptions;
  final void Function(String) onTypeChanged;
  final void Function(String) onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!enabled && showLock)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lockMessage,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            _SectionHeader(icon: Icons.edit_note_rounded, title: 'Title'),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: enabled ? 'The Great Gatsby' : '—',
                prefixIcon: Icon(
                  Icons.title_rounded,
                  color: enabled
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFD1D5DB),
                  size: 22,
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.category_outlined, title: 'Type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: typeOptions.map((type) {
                final meta = _typeMeta[type]!;
                final selected = selectedType == type;
                return _TypeChip(
                  label: meta.label,
                  icon: meta.icon,
                  selected: selected,
                  enabled: enabled,
                  onTap: enabled ? () => onTypeChanged(type) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.school_outlined, title: 'CEFR Level'),
            const SizedBox(height: 10),
            Row(
              children: levelOptions.map((level) {
                final selected = selectedLevel == level;
                final color = _levelColor(level);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: level != levelOptions.last ? 6 : 0,
                    ),
                    child: _LevelChip(
                      level: level,
                      color: color,
                      selected: selected,
                      enabled: enabled,
                      onTap: enabled ? () => onLevelChanged(level) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kViolet),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && selected;
    return Material(
      color: active ? _kViolet : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? Colors.white
                    : (enabled
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFD1D5DB)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : (enabled
                          ? const Color(0xFF374151)
                          : const Color(0xFFD1D5DB)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.color,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String level;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && selected;
    final idleColor = enabled ? color : const Color(0xFFD1D5DB);
    return Material(
      color: active ? color : idleColor.withValues(alpha: enabled ? 0.1 : 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: active
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : null,
          child: Text(
            level,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : idleColor,
            ),
          ),
        ),
      ),
    );
  }
}
