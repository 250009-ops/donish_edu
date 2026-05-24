import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/word_normalizer.dart';
import '../vocab/data/vocab_repository.dart';
import '../vocab/data/word_lexicon_store.dart';
import '../../core/network/api_client.dart';

const Color _kTextPrimary = Color(0xFF111827);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kViolet = Color(0xFF4C6FFF);
const Color _kTappedFill = Color(0xFFEDE9FE);

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
    required this.userId,
  });

  final String materialId;
  final String initialTitle;
  final String userId;

  @override
  State<MaterialReaderScreen> createState() => _MaterialReaderScreenState();
}

class _MaterialReaderScreenState extends State<MaterialReaderScreen> {
  bool _loading = true;
  String? _error;
  String _title = '';
  List<String> _paragraphs = [];
  final _repo = VocabRepository(ApiClient.instance);
  Map<String, WordLexiconEntry> _lexicon = {};

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _load();
    _syncLexicon();
  }

  Future<void> _syncLexicon() async {
    await WordLexiconStore.instance.setActiveUser(widget.userId);
    final local = await WordLexiconStore.instance.allForUser();
    if (mounted) setState(() => _lexicon = local);
    try {
      final remote = await _repo.fetchLexicon();
      await WordLexiconStore.instance.replaceAllFromServer(
        remote
            .map(
              (w) => {
                'word': w.word,
                'translation_base_uz': w.translationBaseUz,
                'saved_for_practice': w.savedForPractice,
              },
            )
            .toList(),
      );
      final merged = await WordLexiconStore.instance.allForUser();
      if (mounted) setState(() => _lexicon = merged);
    } catch (_) {
      // Offline: keep local cache.
    }
  }

  void _onLexiconUpdated(WordLexiconEntry entry) {
    setState(() {
      _lexicon = Map<String, WordLexiconEntry>.from(_lexicon)
        ..[entry.word] = entry;
    });
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
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewPadding.bottom > mq.padding.bottom
        ? mq.viewPadding.bottom
        : mq.padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + bottomInset),
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
            'Purple words are already known. Tap any word for Uzbek meaning.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _TappableText(
            paragraphs: _paragraphs,
            lexicon: _lexicon,
            materialId: widget.materialId,
            vocabRepository: _repo,
            onLexiconUpdated: _onLexiconUpdated,
          ),
        ],
      ),
    );
  }
}

class _TappableText extends StatefulWidget {
  const _TappableText({
    required this.paragraphs,
    required this.lexicon,
    required this.materialId,
    required this.vocabRepository,
    required this.onLexiconUpdated,
  });

  final List<String> paragraphs;
  final Map<String, WordLexiconEntry> lexicon;
  final String materialId;
  final VocabRepository vocabRepository;
  final void Function(WordLexiconEntry entry) onLexiconUpdated;

  @override
  State<_TappableText> createState() => _TappableTextState();
}

class _TappableTextState extends State<_TappableText> {
  final Map<String, Map<String, String>> _sessionTranslationsByWord = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _ParagraphBlock(
            text: widget.paragraphs[i],
            lexicon: widget.lexicon,
            onWordTap: (word, position) =>
                _onWordTap(context, word, widget.paragraphs[i], position),
          ),
        ],
      ],
    );
  }

  void _onWordTap(BuildContext context, String word, String contextSentence,
      Offset tapGlobalPosition) {
    final normalized = normalizeTappedWord(word);
    final lexEntry = widget.lexicon[normalized];
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
        sessionByWord: _sessionTranslationsByWord,
        lexiconEntry: lexEntry,
        materialId: widget.materialId,
        vocabRepository: widget.vocabRepository,
        onLexiconUpdated: widget.onLexiconUpdated,
        onDismiss: dismiss,
      ),
    );
    overlay.insert(entry);
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    required this.text,
    required this.lexicon,
    required this.onWordTap,
  });

  final String text;
  final Map<String, WordLexiconEntry> lexicon;
  final void Function(String word, Offset globalPosition) onWordTap;

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: words.map((w) {
        final normalized = normalizeTappedWord(w);
        final entry = lexicon[normalized];
        final saved = entry?.savedForPractice ?? false;
        final tapped = entry != null;
        return GestureDetector(
          onTapDown: (details) => onWordTap(w, details.globalPosition),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              color: saved
                  ? _kViolet
                  : tapped
                      ? _kTappedFill
                      : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$w ',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: saved
                    ? Colors.white
                    : tapped
                        ? _kViolet
                        : _kTextPrimary,
              ),
            ),
          ),
        );
      }).toList(),
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
    required this.sessionByWord,
    required this.lexiconEntry,
    required this.materialId,
    required this.vocabRepository,
    required this.onLexiconUpdated,
    required this.onDismiss,
  });

  final String word;
  final String contextSentence;
  final Offset tapPosition;
  final Map<String, Map<String, String>> sessionByWord;
  final WordLexiconEntry? lexiconEntry;
  final String materialId;
  final VocabRepository vocabRepository;
  final void Function(WordLexiconEntry entry) onLexiconUpdated;
  final VoidCallback onDismiss;

  @override
  State<_InstantMeaningOverlay> createState() => _InstantMeaningOverlayState();
}

class _InstantMeaningOverlayState extends State<_InstantMeaningOverlay> {
  String? _translationContext;
  String? _translationBase;
  bool _isLoading = true;
  String? _error;
  bool _fromCache = false;
  bool _savedForPractice = false;

  final GlobalKey _measureKey = GlobalKey();
  double? _measuredTotalHeight;

  String get _normalizedWord => normalizeTappedWord(widget.word);

  bool get _hasSavableTranslation {
    final v = _translationBase?.trim() ?? '';
    return v.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _savedForPractice = widget.lexiconEntry?.savedForPractice ?? false;
    _fetchTranslation();
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _measureKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final h = box.size.height;
      if (_measuredTotalHeight == null || (h - _measuredTotalHeight!).abs() > 0.5) {
        setState(() => _measuredTotalHeight = h);
      }
    });
  }

  Future<void> _applyLexiconHit(WordLexiconEntry entry) async {
    setState(() {
      _translationBase = entry.translationBaseUz;
      _translationContext = null;
      _fromCache = true;
      _savedForPractice = entry.savedForPractice;
      _isLoading = false;
      _error = null;
    });
    widget.sessionByWord[_normalizedWord] = {
      'context': '',
      'base': entry.translationBaseUz,
      'from_cache': 'true',
    };
    _scheduleMeasure();
  }

  Future<void> _fetchTranslation() async {
    final word = _normalizedWord;
    if (word.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Could not detect a valid word.';
      });
      _scheduleMeasure();
      return;
    }

    final sessionKey = _normalizedWord;
    final sessionCached = widget.sessionByWord[sessionKey];
    if (sessionCached != null) {
      final fromCache = sessionCached['from_cache'] == 'true';
      setState(() {
        _translationContext =
            fromCache ? null : sessionCached['context'];
        _translationBase = sessionCached['base'];
        _fromCache = fromCache;
        _isLoading = false;
        _error = null;
      });
      _scheduleMeasure();
      return;
    }

    final local = await WordLexiconStore.instance.lookup(word);
    if (local != null && mounted) {
      await _applyLexiconHit(local);
      _refreshFromNetwork(word, silent: true);
      return;
    }

    if (widget.lexiconEntry != null) {
      await _applyLexiconHit(widget.lexiconEntry!);
      _refreshFromNetwork(word, silent: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _refreshFromNetwork(word, silent: false);
  }

  Future<void> _refreshFromNetwork(String word, {required bool silent}) async {
    try {
      final json = await widget.vocabRepository.translateWord(
        word: word,
        contextSentence: widget.contextSentence,
        materialId: widget.materialId,
      );
      if (!mounted) return;
      final fromCache = json['from_cache'] == true;
      final context =
          (json['translation_context_uz'] ?? json['translation_uz']) as String?;
      final base = json['translation_base_uz'] as String?;
      final contextStr = fromCache ? '' : (context?.trim() ?? '');
      final baseStr = base?.trim() ?? '';
      final saved = json['saved_for_practice'] == true;

      if (baseStr.isNotEmpty) {
        await WordLexiconStore.instance.upsert(
          word: word,
          translationBaseUz: baseStr,
          savedForPractice: saved,
        );
        widget.onLexiconUpdated(
          WordLexiconEntry(
            word: word,
            translationBaseUz: baseStr,
            savedForPractice: saved,
          ),
        );
      }

      widget.sessionByWord[word] = {
        'context': contextStr,
        'base': baseStr,
        'from_cache': fromCache ? 'true' : 'false',
      };

      if (!silent || !fromCache) {
        setState(() {
          _translationContext =
              contextStr.isEmpty ? null : contextStr;
          _translationBase = baseStr.isEmpty ? null : baseStr;
          _fromCache = fromCache;
          _savedForPractice = saved;
          _isLoading = false;
        });
        _scheduleMeasure();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        _scheduleMeasure();
      }
    }
  }

  Future<void> _saveToVocab() async {
    final toSave = _translationBase?.trim();
    if (toSave == null || toSave.isEmpty) return;
    try {
      await widget.vocabRepository.saveForPractice(
        word: _normalizedWord.isNotEmpty ? _normalizedWord : widget.word,
        translationUz: toSave,
        contextSentence: widget.contextSentence,
        materialId: widget.materialId,
      );
      await WordLexiconStore.instance.upsert(
        word: _normalizedWord,
        translationBaseUz: toSave,
        savedForPractice: true,
      );
      final entry = WordLexiconEntry(
        word: _normalizedWord,
        translationBaseUz: toSave,
        savedForPractice: true,
      );
      widget.onLexiconUpdated(entry);
      if (!mounted) return;
      setState(() => _savedForPractice = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Vocabulary Bank')),
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
    final padding = MediaQuery.paddingOf(context);
    final viewSize = MediaQuery.sizeOf(context);
    const cardWidth = 300.0;
    const cardPadding = 16.0;
    const tailHeight = 10.0;
    const edgeMargin = 12.0;
    const gap = 8.0;
    const tailHalfBase = 8.0;

    final tap = widget.tapPosition;
    final left = (tap.dx - cardWidth / 2).clamp(
      edgeMargin,
      viewSize.width - cardWidth - edgeMargin,
    );

    final tipLocalX =
        (tap.dx - left).clamp(tailHalfBase + 2, cardWidth - tailHalfBase - 2);

    final totalH = _measuredTotalHeight ?? 200.0;
    final need = totalH + gap;

    final spaceAbove = tap.dy - padding.top - edgeMargin;
    final spaceBelow =
        viewSize.height - tap.dy - padding.bottom - edgeMargin;

    final bool placeAbove;
    if (spaceAbove >= need && spaceBelow >= need) {
      placeAbove = true;
    } else if (spaceAbove >= need) {
      placeAbove = true;
    } else if (spaceBelow >= need) {
      placeAbove = false;
    } else {
      placeAbove = spaceAbove >= spaceBelow;
    }

    double top;
    if (placeAbove) {
      top = tap.dy - gap - totalH;
      final minTop = padding.top + edgeMargin;
      final maxTop = viewSize.height - padding.bottom - edgeMargin - totalH;
      top = top.clamp(minTop, maxTop);
    } else {
      top = tap.dy + gap;
      final minTop = padding.top + edgeMargin;
      final maxTop = viewSize.height - padding.bottom - edgeMargin - totalH;
      top = top.clamp(minTop, maxTop);
    }

    final tailBar = SizedBox(
      width: cardWidth,
      height: tailHeight,
      child: CustomPaint(
        painter: placeAbove
            ? _TailPainterDown(color: _kPopoverBg, tipX: tipLocalX)
            : _TailPainterUp(color: _kPopoverBg, tipX: tipLocalX),
      ),
    );

    final showContext = !_fromCache &&
        (_translationContext?.trim().isNotEmpty ?? false);

    final card = Container(
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
            _normalizedWord.isNotEmpty ? _normalizedWord : widget.word,
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
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: showContext ? 72 : 120),
              child: SingleChildScrollView(
                child: Text(
                  (_translationBase?.trim().isNotEmpty ?? false)
                      ? _translationBase!.trim()
                      : '—',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (showContext) ...[
            const SizedBox(height: 12),
            Text(
              'Contextual translation',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kPopoverLabel,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 88),
              child: SingleChildScrollView(
                child: Text(
                  _translationContext!.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          if (!_savedForPractice) ...[
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
                    _hasSavableTranslation && !_isLoading ? _saveToVocab : null,
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
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

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
              key: _measureKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: placeAbove ? [card, tailBar] : [tailBar, card],
            ),
          ),
        ),
      ],
    );
  }
}

class _TailPainterDown extends CustomPainter {
  _TailPainterDown({required this.color, required this.tipX});

  final Color color;
  final double tipX;

  @override
  void paint(Canvas canvas, Size size) {
    final tx = tipX.clamp(4.0, size.width - 4.0);
    const half = 8.0;
    final path = Path()
      ..moveTo(tx - half, 0)
      ..lineTo(tx + half, 0)
      ..lineTo(tx, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainterDown oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tipX != tipX;
}

class _TailPainterUp extends CustomPainter {
  _TailPainterUp({required this.color, required this.tipX});

  final Color color;
  final double tipX;

  @override
  void paint(Canvas canvas, Size size) {
    final tx = tipX.clamp(4.0, size.width - 4.0);
    const half = 8.0;
    final path = Path()
      ..moveTo(tx, 0)
      ..lineTo(tx - half, size.height)
      ..lineTo(tx + half, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainterUp oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tipX != tipX;
}
