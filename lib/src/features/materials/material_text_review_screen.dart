import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../billing/models/subscription_info.dart';
import '../billing/widgets/premium_paywall_dialog.dart';
import 'material_pdf_help_dialog.dart';

const Color _kViolet = Color(0xFF8840FE);

/// After extract-preview, user trims text here; final save uses [content_text] only.
class MaterialTextReviewScreen extends StatefulWidget {
  const MaterialTextReviewScreen({
    super.key,
    required this.initialExtractedText,
    required this.pageCount,
    required this.fileName,
    required this.title,
    required this.materialType,
    required this.englishLevel,
    this.reviewHint =
        'Last step: tap "Save to Materials" below so this upload appears on your Materials page.',
    this.subscription,
    this.onUpgrade,
    this.onCreateCheckout,
  });

  final String initialExtractedText;
  final int pageCount;
  final String fileName;
  final String title;
  final String materialType;
  final String englishLevel;
  final String reviewHint;
  final SubscriptionInfo? subscription;
  final VoidCallback? onUpgrade;
  final Future<String> Function()? onCreateCheckout;

  @override
  State<MaterialTextReviewScreen> createState() =>
      _MaterialTextReviewScreenState();
}

class _MaterialTextReviewScreenState extends State<MaterialTextReviewScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  Future<bool> _confirmDiscard() async {
    if (_saving) return false;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Discard this upload?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'If you go back now, this material will not be added to Materials.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard == true;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialExtractedText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add some text before saving, or cancel to go back.',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.instance.postJson(
        '/materials',
        authenticated: true,
        body: {
          'title': widget.title,
          'material_type': widget.materialType,
          'english_level': widget.englishLevel,
          'content_text': trimmed,
          if (widget.pageCount > 0) 'page_count': widget.pageCount,
          'file_name': widget.fileName,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'upgrade_required') {
        final checkout = widget.onCreateCheckout;
        if (checkout != null) {
          await showPremiumPaywallDialog(
            context,
            title: 'Upload limit reached',
            message: e.message,
            subscription: widget.subscription ?? SubscriptionInfo.freeDefaults(),
            onCreateCheckout: checkout,
          );
        } else {
          widget.onUpgrade?.call();
        }
        return;
      }
      showMaterialUploadError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          title: Text(
            'Review and save',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF111827),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: _kViolet),
              tooltip: 'Which PDFs work?',
              onPressed: () => showPdfMaterialsHelpDialog(context),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.reviewHint,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: widget.initialExtractedText.isEmpty
                        ? 'Type or paste English text here...'
                        : 'Extracted text...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.45,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ),
            SafeArea(
              minimum: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final shouldDiscard = await _confirmDiscard();
                              if (!mounted || !shouldDiscard) return;
                              Navigator.of(context).pop(false);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        foregroundColor: const Color(0xFF374151),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kViolet,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save to Materials',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                    ),
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
