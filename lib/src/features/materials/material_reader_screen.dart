import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

const Color _kTextPrimary = Color(0xFF111827);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kViolet = Color(0xFF4C6FFF);

List<String> paragraphsFromExtractedText(String content) {
  final t = content.trim();
  if (t.isEmpty) return [];
  var blocks = t
      .split(RegExp(r'\n\s*\n'))
      .map((s) => s.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
      .where((s) => s.isNotEmpty)
      .toList();
  if (blocks.isEmpty) {
    return [t.replaceAll(RegExp(r'\s+'), ' ')];
  }
  if (blocks.length == 1 && blocks.first.length > 6000) {
    final lines = blocks.first
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.length > 1) return lines;
  }
  return blocks;
}

class MaterialReaderScreen extends StatefulWidget {
  const MaterialReaderScreen({
    super.key,
    required this.materialId,
    required this.initialTitle,
  });

  final String materialId;
  final String initialTitle;

  @override
  State<MaterialReaderScreen> createState() => _MaterialReaderScreenState();
}

class _MaterialReaderScreenState extends State<MaterialReaderScreen> {
  bool _loading = true;
  String? _error;
  String _title = '';
  List<String> _paragraphs = [];

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final decoded = await ApiClient.instance.getJson(
        '/materials/${Uri.encodeComponent(widget.materialId)}',
        authenticated: true,
      );
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Invalid material response.');
      }
      final json = decoded;
      if (!mounted) return;
      final title = json['title'] as String? ?? widget.initialTitle;
      final raw = json['content_text'] as String? ?? '';
      final paras = paragraphsFromExtractedText(raw);
      if (paras.isEmpty) {
        setState(() {
          _title = title;
          _error = 'This material has no readable text.';
          _paragraphs = [];
          _loading = false;
        });
        return;
      }
      setState(() {
        _title = title;
        _paragraphs = paras;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: _kTextPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: _kTextPrimary,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kViolet),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap any word to see its translation',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _TappableText(paragraphs: _paragraphs),
        ],
      ),
    );
  }
}

class _TappableText extends StatelessWidget {
  const _TappableText({required this.paragraphs});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _ParagraphBlock(
            text: paragraphs[i],
            onWordTap: (word, position) =>
                _onWordTap(context, word, paragraphs[i], position),
          ),
        ],
      ],
    );
  }

  void _onWordTap(BuildContext context, String word, String contextSentence,
      Offset tapGlobalPosition) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    void dismiss() {
      entry.remove();
    }
    entry = OverlayEntry(
      builder: (ctx) => _InstantMeaningOverlay(
        word: word,
        contextSentence: contextSentence,
        tapPosition: tapGlobalPosition,
        onDismiss: dismiss,
      ),
    );
    overlay.insert(entry);
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    required this.text,
    required this.onWordTap,
  });

  final String text;
  final void Function(String word, Offset globalPosition) onWordTap;

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: words
          .map(
            (w) => GestureDetector(
              onTapDown: (details) => onWordTap(w, details.globalPosition),
              child: Text(
                '$w ',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: _kTextPrimary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

const Color _kPopoverBg = Color(0xFF282A3A);
const Color _kPopoverLabel = Color(0xFF9CA3AF);
const Color _kPopoverButton = Color(0xFF6F42C1);

class _InstantMeaningOverlay extends StatefulWidget {
  const _InstantMeaningOverlay({
    required this.word,
    required this.contextSentence,
    required this.tapPosition,
    required this.onDismiss,
  });

  final String word;
  final String contextSentence;
  final Offset tapPosition;
  final VoidCallback onDismiss;

  @override
  State<_InstantMeaningOverlay> createState() => _InstantMeaningOverlayState();
}

class _InstantMeaningOverlayState extends State<_InstantMeaningOverlay> {
  String? _translation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();
  }

  Future<void> _fetchTranslation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.postJson(
        '/translate',
        body: {
          'word': widget.word,
          'context_sentence': widget.contextSentence,
        },
        authenticated: true,
      );
      if (!mounted) return;
      setState(() {
        _translation = json['translation_uz'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToVocab() async {
    if (_translation == null) return;
    try {
      await ApiClient.instance.postJson(
        '/vocab',
        authenticated: true,
        body: {
          'word': widget.word,
          'translation_uz': _translation,
          'context_sentence': widget.contextSentence,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Vocabulary Bank'),
        ),
      );
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    const cardWidth = 280.0;
    const cardPadding = 16.0;
    const tailHeight = 10.0;
    const tailWidth = 16.0;

    double left = widget.tapPosition.dx - cardWidth / 2;
    left = left.clamp(12.0, screenSize.width - cardWidth - 12);
    const cardHeight = 200.0;
    double top = widget.tapPosition.dy - cardHeight - tailHeight - 8;
    top = top.clamp(12.0, screenSize.height - cardHeight - tailHeight - 24);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: _kPopoverBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Word',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kPopoverLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.word,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Translation',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kPopoverLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_isLoading)
                        SizedBox(
                          height: 20,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_kPopoverLabel),
                              ),
                            ),
                          ),
                        )
                      else if (_error != null)
                        Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.red.shade300,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          _translation ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: _kPopoverLabel.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed:
                              _translation != null && !_isLoading
                                  ? _saveToVocab
                                  : null,
                          icon: const Icon(
                            Icons.bookmark_add_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Save to Vocabulary',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: _kPopoverButton,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: CustomPaint(
                    size: const Size(tailWidth, tailHeight),
                    painter: _TailPainter(color: _kPopoverBg),
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

class _TailPainter extends CustomPainter {
  _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
