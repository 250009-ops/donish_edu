import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

const Color _kViolet = Color(0xFF4C6FFF);

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({
    super.key,
    required this.onFormChanged,
    required this.onUploadSuccess,
    required this.onRegisterUpload,
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

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  String? _fileName;
  String? _filePath;
  final _nameController = TextEditingController();
  String? _selectedType;
  String? _selectedLevel;
  bool _isUploading = false;

  static const List<String> _typeOptions = [
    'Article',
    'Book',
    'Short story',
    'Essay',
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
    widget.onFormChanged(
      hasPdf: _filePath != null,
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
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _fileName = file.name;
      _filePath = file.path;
    });
    if (_nameController.text.isEmpty) {
      _nameController.text =
          file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    }
    _notifyFormChanged();
  }

  Future<void> _upload() async {
    if (_fileName == null || _filePath == null) return;
    if (_nameController.text.trim().isEmpty) return;
    if (_selectedType == null || _selectedLevel == null) return;

    setState(() => _isUploading = true);
    _notifyFormChanged();

    try {
      await ApiClient.instance.postJson(
        '/materials',
        authenticated: true,
        body: {
          'title': _nameController.text.trim(),
          'file_path': _fileName,
          'page_count': null,
        },
      );

      if (!mounted) return;
      widget.onUploadSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _notifyFormChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _GradientHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PdfUploadZone(
                    fileName: _fileName,
                    onPickFile: _pickFile,
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
                  _HelperText(
                      'Give your material a descriptive name'),
                  const SizedBox(height: 16),
                  _Label('Type *'),
                  _DropdownField<String>(
                    value: _selectedType,
                    hint: 'Select material type',
                    items: _typeOptions,
                    onChanged: (v) {
                      setState(() => _selectedType = v);
                      _notifyFormChanged();
                    },
                  ),
                  const SizedBox(height: 4),
                  _HelperText(
                      'Choose the type that best describes your material'),
                  const SizedBox(height: 16),
                  _Label('English Level *'),
                  _DropdownField<String>(
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
                  _AboutPdfButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C6FFF), Color(0xFF8E54E9)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Material',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload PDF to your library.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.95),
              ),
            ),
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
  });

  final String? fileName;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('PDF File *'),
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
                  Text(
                    fileName!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Supports PDF files up to 50MB.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T extends String> extends StatelessWidget {
  const _DropdownField({
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 15,
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280)),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(
                      e,
                      style: GoogleFonts.inter(fontSize: 15),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AboutPdfButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 20, color: _kViolet),
            const SizedBox(width: 10),
            Text(
              'About PDF Material',
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
