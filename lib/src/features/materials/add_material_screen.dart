import 'dart:convert' show base64Encode;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../../util/material_file_reader.dart';
import '../billing/models/subscription_info.dart';
import '../billing/widgets/premium_paywall_dialog.dart';
import 'material_pdf_help_dialog.dart';
import 'material_text_review_screen.dart';

const Color _kViolet = Color(0xFF8840FE);

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
    required bool hasPdf,
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
  String? _fileName;
  String? _filePath;
  Uint8List? _fileBytes;
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
    final hasFile = (_fileBytes != null && _fileBytes!.isNotEmpty) ||
        (_filePath != null && _filePath!.isNotEmpty);
    widget.onFormChanged(
      hasPdf: hasFile,
      name: _nameController.text,
      type: _selectedType,
      level: _selectedLevel,
      uploading: _isUploading,
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
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

  void _clearFile() {
    setState(() {
      _fileName = null;
      _filePath = null;
      _fileBytes = null;
      _nameController.clear();
    });
    _notifyFormChanged();
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

  Future<void> _upload() async {
    if (_fileName == null) return;
    if (_nameController.text.trim().isEmpty) return;
    if (_selectedType == null || _selectedLevel == null) return;

    List<int> raw;
    if (_fileBytes != null && _fileBytes!.isNotEmpty) {
      raw = _fileBytes!;
    } else {
      final fromDisk = await readBytesFromPath(_filePath);
      if (fromDisk == null || fromDisk.isEmpty) {
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
      raw = fromDisk;
    }

    setState(() => _isUploading = true);
    _notifyFormChanged();

    try {
      // Server extracts text via Amazon Textract; user edits on review screen.
      final preview = await ApiClient.instance.postJson(
        '/materials/extract-preview',
        authenticated: true,
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

      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => MaterialTextReviewScreen(
            initialExtractedText: extracted,
            pageCount: pageCount,
            fileName: _fileName!,
            title: _nameController.text.trim(),
            materialType: _selectedType!,
            englishLevel: _selectedLevel!,
            subscription: widget.subscription,
            onUpgrade: widget.onUpgrade,
            onCreateCheckout: widget.onCreateCheckout,
          ),
        ),
      );

      if (!mounted) return;
      if (saved == true) widget.onUploadSuccess();
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
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PdfUploadZone(
              fileName: _fileName,
              onPickFile: _pickFile,
              onClear: _fileName != null ? _clearFile : null,
            ),
            const SizedBox(height: 20),
            _Label('Material Name *'),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., The Great Gatsby',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 4),
            _HelperText('Give your material a descriptive name'),
            const SizedBox(height: 16),
            _Label('Type *'),
            _FigmaSelectField<String>(
              value: _selectedType,
              hint: 'Select material type',
              items: _typeOptions,
              onChanged: (v) {
                setState(() => _selectedType = v);
                _notifyFormChanged();
              },
            ),
            const SizedBox(height: 4),
            _HelperText('Choose the type that best describes your material'),
            const SizedBox(height: 16),
            _Label('English Level *'),
            _FigmaSelectField<String>(
              value: _selectedLevel,
              hint: 'Select difficulty level',
              items: _levelOptions,
              onChanged: (v) {
                setState(() => _selectedLevel = v);
                _notifyFormChanged();
              },
            ),
            const SizedBox(height: 4),
            _HelperText(
                'Select based on CEFR English proficiency levels'),
            const SizedBox(height: 24),
            _AboutPdfButton(onTap: () => showPdfMaterialsHelpDialog(context)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFF6B7280),
      ),
    );
  }
}

class _PdfUploadZone extends StatelessWidget {
  const _PdfUploadZone({
    required this.fileName,
    required this.onPickFile,
    this.onClear,
  });

  final String? fileName;
  final VoidCallback onPickFile;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('PDF File *'),
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onPickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.upload_file_rounded,
                      size: 48,
                      color: _kViolet,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Click to select PDF file',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (fileName != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          fileName!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'PDF up to ~30 pages (~10 MB). Text is read with OCR (may take 1–2 min).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'Scans and digital PDFs both work—review and edit the extracted text before saving.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.35,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onClear != null && fileName != null)
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Select field matching Figma: white menu, rounded bottom corners,
/// selected option with yellowish-orange background and white text.
class _FigmaSelectField<T extends String> extends StatefulWidget {
  const _FigmaSelectField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final void Function(T?) onChanged;

  @override
  State<_FigmaSelectField<T>> createState() => _FigmaSelectFieldState<T>();
}

class _FigmaSelectFieldState<T extends String> extends State<_FigmaSelectField<T>> {
  final GlobalKey _triggerKey = GlobalKey();

  void _openMenu() async {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    const itemHeight = 48.0;
    final menuWidth = box.size.width;
    final menuHeight = widget.items.length * itemHeight;
    final top = offset.dy + box.size.height;
    final left = offset.dx;
    final right = left + menuWidth;
    final bottom = top + menuHeight;

    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(left, top, right, bottom),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      color: Colors.white,
      elevation: 2,
      items: widget.items.map((e) {
        final isSelected = widget.value == e;
        return PopupMenuItem<T>(
          value: e,
          height: itemHeight,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: menuWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      e,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _triggerKey,
      onTap: _openMenu,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value ?? widget.hint,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: widget.value != null
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontWeight:
                      widget.value != null ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPdfButton extends StatelessWidget {
  const _AboutPdfButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 20, color: _kViolet),
            const SizedBox(width: 10),
            Text(
              'About PDF Materials',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _kViolet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
