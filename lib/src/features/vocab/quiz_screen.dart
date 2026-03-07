import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedIndex;

  final _questions = const [
    _QuizQuestion(
      word: 'Beautiful',
      correct: 'Chiroyli',
      options: ['Chiroyli', 'Maktab', 'Kitob', 'Do\'st'],
    ),
    _QuizQuestion(
      word: 'School',
      correct: 'Maktab',
      options: ['Uy', 'Maktab', 'Ko\'cha', 'O\'qituvchi'],
    ),
  ];

  void _onSelect(int index) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedIndex = index;
      if (_questions[_currentIndex].options[index] ==
          _questions[_currentIndex].correct) {
        _score++;
      }
    });
  }

  void _next() {
    if (_currentIndex + 1 >= _questions.length) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quiz finished'),
          content: Text('Score: $_score / ${_questions.length}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];
    final progress = '${_currentIndex + 1} of ${_questions.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Mode'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose the correct meaning',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    progress,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.word,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(q.options.length, (i) {
                final option = q.options[i];
                final isSelected = _selectedIndex == i;
                Color borderColor = const Color(0xFFE5E7EB);
                Color fillColor = Colors.white;
                IconData? icon;
                Color? iconColor;

                if (_answered) {
                  if (option == q.correct) {
                    borderColor = const Color(0xFF22C55E);
                    fillColor = const Color(0xFFEFFDF4);
                    icon = Icons.check_circle;
                    iconColor = const Color(0xFF22C55E);
                  } else if (isSelected && option != q.correct) {
                    borderColor = const Color(0xFFEF4444);
                    fillColor = const Color(0xFFFFF1F2);
                    icon = Icons.cancel;
                    iconColor = const Color(0xFFEF4444);
                  }
                } else if (isSelected) {
                  borderColor = const Color(0xFF4C6FFF);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _onSelect(i),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (icon != null)
                            Icon(icon, color: iconColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _answered ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C6FFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
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

