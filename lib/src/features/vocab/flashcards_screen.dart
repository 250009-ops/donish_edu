import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'data/vocab_repository.dart';

const Color _kBg = Color(0xFFF9FAFB);
const Color _kTextDark = Color(0xFF111827);
const Color _kTextMuted = Color(0xFF9CA3AF);
const Color _kProgressFill = Color(0xFF4C6FFF);
const Color _kProgressTrack = Color(0xFFE5E7EB);
const Color _kTagBlue = Color(0xFF4C6FFF);
const Color _kHardOrange = Color(0xFFF59E0B);
const Color _kEasyGreen = Color(0xFF22C55E);
const Color _kNavButtonBg = Color(0xFFE5E7EB);

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({
    super.key,
    required this.entries,
    this.vocabRepository,
  });

  final List<VocabEntry> entries;
  final VocabRepository? vocabRepository;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  int _currentIndex = 0;
  bool _showBack = false;
  int _slideDirection = 1; // 1 = next (from right), -1 = prev

  late final List<_FlashcardData> _cards;
  late final VocabRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.vocabRepository ?? VocabRepository(ApiClient.instance);
    _cards = widget.entries
        .map(
          (e) => _FlashcardData(
            vocabId: e.id,
            front: e.word,
            back: e.translationUz,
          ),
        )
        .toList();
  }

  int get _total => _cards.length;

  void _reportFlashcardPractice(String action) {
    if (_total == 0) return;
    final id = _cards[_currentIndex].vocabId;
    _repo
        .recordPractice(vocabId: id, action: action)
        .catchError((Object _) {});
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    setState(() {
      _slideDirection = -1;
      _currentIndex--;
      _showBack = false;
    });
  }

  void _goNext() {
    if (_currentIndex >= _total - 1) return;
    setState(() {
      _slideDirection = 1;
      _currentIndex++;
      _showBack = false;
    });
  }

  void _markHard() {
    _reportFlashcardPractice('flashcard_hard');
    setState(() {
      _slideDirection = 1;
      _showBack = false;
      if (_currentIndex < _total - 1) {
        _currentIndex++;
      }
    });
  }

  void _markEasy() {
    _reportFlashcardPractice('flashcard_easy');
    setState(() {
      _slideDirection = 1;
      _showBack = false;
      if (_currentIndex < _total - 1) {
        _currentIndex++;
      }
    });
  }

  void _refresh() {
    setState(() {
      _slideDirection = 1;
      _currentIndex = 0;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: _kTextDark,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Flashcards',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: _kTextDark,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No words saved today. Add words from a material first.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: _kTextMuted,
              ),
            ),
          ),
        ),
      );
    }

    final card = _cards[_currentIndex];
    final n = _currentIndex + 1;
    final progress = _total > 0 ? n / _total : 0.0;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: _kTextDark,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Card $n of $_total',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _kProgressTrack,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_kProgressFill),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: _kTextDark,
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final offsetAnim = Tween<Offset>(
                      begin: Offset(_slideDirection * 0.2, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnim,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentIndex),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showBack = !_showBack);
                      },
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! < -100) {
                          _markHard();
                        } else if (details.primaryVelocity! > 100) {
                          _markEasy();
                        }
                      },
                      child: _FlipFlashcard(
                        card: card,
                        showBack: _showBack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavButton(
                        icon: Icons.chevron_left_rounded,
                        onPressed: _currentIndex > 0 ? _goPrev : null,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            label: 'Hard',
                            color: _kHardOrange,
                            onPressed: _markHard,
                          ),
                          const SizedBox(width: 12),
                          _ActionButton(
                            label: 'Easy',
                            color: _kEasyGreen,
                            onPressed: _markEasy,
                          ),
                        ],
                      ),
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        onPressed:
                            _currentIndex < _total - 1 ? _goNext : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Swipe gestures: ← Hard | Easy →',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _kTextMuted,
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

/// Wraps flashcard in a 3D flip animation when toggling front/back.
class _FlipFlashcard extends StatefulWidget {
  const _FlipFlashcard({
    required this.card,
    required this.showBack,
  });

  final _FlashcardData card;
  final bool showBack;

  @override
  State<_FlipFlashcard> createState() => _FlipFlashcardState();
}

class _FlipFlashcardState extends State<_FlipFlashcard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (widget.showBack) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_FlipFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack != widget.showBack) {
      if (widget.showBack) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final angle = _animation.value * 3.14159;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _FlashcardFace(
                card: widget.card,
                isFront: true,
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(3.14159),
                child: _FlashcardFace(
                  card: widget.card,
                  isFront: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One face of the flashcard (front = word, back = translation).
class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({
    required this.card,
    required this.isFront,
  });

  final _FlashcardData card;
  final bool isFront;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kTagBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'English',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFront ? card.front : card.back,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 16),
          Icon(
            Icons.volume_up_rounded,
            size: 28,
            color: _kTagBlue,
          ),
          const SizedBox(height: 12),
          Text(
            isFront ? 'Tap to reveal translation' : card.front,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _kTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kNavButtonBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 28,
            color: onPressed != null ? _kTextDark : _kTextMuted,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashcardData {
  const _FlashcardData({
    required this.vocabId,
    required this.front,
    required this.back,
  });

  final String vocabId;
  final String front;
  final String back;
}
