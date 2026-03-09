import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Figma quiz colors.
const Color _kBg = Color(0xFFF9FAFB);
const Color _kTextDark = Color(0xFF111827);
const Color _kTextMuted = Color(0xFF9CA3AF);
const Color _kProgressFill = Color(0xFF4C6FFF);
const Color _kProgressTrack = Color(0xFFE5E7EB);
const Color _kCardBg = Color(0xFFF0F8FF);
const Color _kCardBorder = Color(0xFFE5E7EB);
const Color _kTagBlue = Color(0xFF4C6FFF);
const Color _kCorrectBg = Color(0xFF059669);
const Color _kCorrectText = Color(0xFF059669);
const Color _kWrongBg = Color(0xFFFEE2E2);
const Color _kWrongText = Color(0xFFDC2626);
const Color _kFeedbackCorrectBg = Color(0xFFECFDF5);
const Color _kFeedbackWrongBg = Color(0xFFFEF2F2);

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _QuizTransitionPhase { idle, exiting, entering }

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedIndex;
  _QuizTransitionPhase _phase = _QuizTransitionPhase.idle;
  late AnimationController _transitionController;
  static const _transitionDuration = Duration(milliseconds: 280);

  static const List<_QuizQuestion> _questions = [
    _QuizQuestion(
      word: 'Chiroyli',
      correct: 'Beautiful',
      options: ['Happy', 'Beautiful', 'Fast', 'Strong'],
    ),
    _QuizQuestion(
      word: 'Maktab',
      correct: 'School',
      options: ['Hospital', 'School', 'Market', 'Home'],
    ),
    _QuizQuestion(
      word: 'Kitob',
      correct: 'Book',
      options: ['Pen', 'Book', 'Table', 'Door'],
    ),
    _QuizQuestion(
      word: 'Do\'st',
      correct: 'Friend',
      options: ['Enemy', 'Friend', 'Teacher', 'Student'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    )..addStatusListener(_onTransitionStatus);
  }

  @override
  void dispose() {
    _transitionController.removeStatusListener(_onTransitionStatus);
    _transitionController.dispose();
    super.dispose();
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    if (_phase == _QuizTransitionPhase.exiting) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedIndex = null;
        _phase = _QuizTransitionPhase.entering;
      });
      _transitionController.reset();
      _transitionController.forward();
    } else if (_phase == _QuizTransitionPhase.entering) {
      setState(() {
        _phase = _QuizTransitionPhase.idle;
      });
      _transitionController.reset();
    }
  }

  void _onSelect(int index) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedIndex = index;
      final q = _questions[_currentIndex];
      if (q.options[index] == q.correct) _score++;
    });
  }

  void _next() {
    if (_phase != _QuizTransitionPhase.idle) return;
    if (_currentIndex + 1 >= _questions.length) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quiz finished'),
          content: Text(
            'Score: $_score / ${_questions.length}',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _phase = _QuizTransitionPhase.exiting);
    _transitionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final n = _currentIndex + 1;
    final total = _questions.length;
    final q = _questions[_currentIndex];
    final isCorrect = _answered &&
        _selectedIndex != null &&
        q.options[_selectedIndex!] == q.correct;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Question $n of $total',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  'Score: $_score/$total',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: n / total,
                minHeight: 6,
                backgroundColor: _kProgressTrack,
                valueColor: const AlwaysStoppedAnimation<Color>(_kProgressFill),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: AnimatedBuilder(
            animation: _transitionController,
            builder: (context, _) {
              if (_phase == _QuizTransitionPhase.idle) {
                return _buildQuestionContent(
                  q: _questions[_currentIndex],
                  isCorrect: _answered &&
                      _selectedIndex != null &&
                      _questions[_currentIndex].options[_selectedIndex!] ==
                          _questions[_currentIndex].correct,
                );
              }
              if (_phase == _QuizTransitionPhase.exiting) {
                final exitAnim = CurvedAnimation(
                  parent: _transitionController,
                  curve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0).animate(exitAnim),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset.zero,
                      end: const Offset(-0.2, 0),
                    ).animate(exitAnim),
                    child: _buildQuestionContent(
                      q: _questions[_currentIndex],
                      isCorrect: isCorrect,
                    ),
                  ),
                );
              }
              final enterAnim = CurvedAnimation(
                parent: _transitionController,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(enterAnim),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(enterAnim),
                  child: _buildQuestionContent(
                    q: _questions[_currentIndex],
                    isCorrect: false,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionContent({
    required _QuizQuestion q,
    required bool isCorrect,
  }) {
    return Column(
      key: ValueKey<int>(_currentIndex),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionCard(word: q.word),
        const SizedBox(height: 24),
        ...List.generate(q.options.length, (i) {
          final option = q.options[i];
          final letter = String.fromCharCode(0x41 + i);
          final isSelected = _selectedIndex == i;
          final isCorrectOption = option == q.correct;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              letter: letter,
              label: option,
              state: _answered
                  ? (isCorrectOption
                      ? _OptionState.correct
                      : (isSelected
                          ? _OptionState.incorrect
                          : _OptionState.unselected))
                  : (isSelected
                      ? _OptionState.selected
                      : _OptionState.unselected),
              onTap: () => _onSelect(i),
            ),
          );
        }),
        if (_answered) ...[
          const SizedBox(height: 20),
          _FeedbackBar(
            isCorrect: isCorrect,
            correctAnswer: q.correct,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _phase == _QuizTransitionPhase.idle ? _next : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kProgressFill,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kTagBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'English – Uzbek',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kTextDark,
                height: 1.35,
              ),
              children: [
                const TextSpan(text: 'What is '),
                TextSpan(
                  text: '"$word"',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const TextSpan(text: ' in English?'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { unselected, selected, correct, incorrect }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color letterColor = _kTextMuted;
    Color textColor = _kTextDark;
    Widget? trailing;

    switch (state) {
      case _OptionState.unselected:
        break;
      case _OptionState.selected:
        letterColor = _kTextMuted;
        textColor = _kTextDark;
        break;
      case _OptionState.correct:
        bg = _kCorrectBg;
        letterColor = Colors.white;
        textColor = Colors.white;
        trailing = const Icon(
          Icons.check_circle_rounded,
          color: Colors.white,
          size: 22,
        );
        break;
      case _OptionState.incorrect:
        bg = _kWrongBg;
        letterColor = _kWrongText;
        textColor = _kTextMuted;
        trailing = Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: _kWrongText,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            color: Colors.white,
            size: 14,
          ),
        );
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state == _OptionState.correct || state == _OptionState.incorrect
            ? null
            : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: state == _OptionState.unselected ||
                      state == _OptionState.selected
                  ? _kCardBorder
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(
                '$letter.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: letterColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBar extends StatelessWidget {
  const _FeedbackBar({
    required this.isCorrect,
    required this.correctAnswer,
  });

  final bool isCorrect;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isCorrect ? _kFeedbackCorrectBg : _kFeedbackWrongBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 22,
            color: isCorrect ? _kCorrectText : _kWrongText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCorrect
                  ? 'Correct! Great job!'
                  : 'The correct answer is: $correctAnswer',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isCorrect ? _kCorrectText : _kWrongText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.word,
    required this.correct,
    required this.options,
  });

  final String word;
  final String correct;
  final List<String> options;
}
