import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

const Color _kTextPrimary = Color(0xFF111827);
const Color _kTextSecondary = Color(0xFF6B7280);

class MaterialReaderScreen extends StatelessWidget {
  const MaterialReaderScreen({
    super.key,
    required this.materialTitle,
  });

  final String materialTitle;

  @override
  Widget build(BuildContext context) {
    const sampleParagraphs = [
      'Climate change is one of the most pressing global challenges.',
      'When you tap on an unknown word, Donish will show you its natural '
          'Uzbek translation.',
    ];

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
          materialTitle,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: _kTextPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              materialTitle,
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
            _TappableText(paragraphs: sampleParagraphs),
          ],
        ),
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
    final words = text.split(' ');
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

/// Figma: dark popover above the word with tail, "Word" / "Translation" labels, Save button.
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

/// Draws a small downward-pointing triangle tail at bottom center of popover.
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

