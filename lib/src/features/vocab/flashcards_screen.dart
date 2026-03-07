import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  int _currentIndex = 0;
  bool _showBack = false;

  final _cards = const [
    _FlashcardData(
      front: 'Beautiful',
      back: 'Chiroyli',
      context: 'She lives in a beautiful city.',
    ),
    _FlashcardData(
      front: 'School',
      back: 'Maktab',
      context: 'Students go to school every morning.',
    ),
  ];

  void _nextCard(bool known) {
    setState(() {
      _showBack = false;
      _currentIndex = (_currentIndex + 1) % _cards.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_currentIndex];
    final progressLabel = '${_currentIndex + 1} of ${_cards.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  progressLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showBack = !_showBack;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4C6FFF),
                          Color(0xFF8E54E9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _showBack ? card.back : card.front,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!_showBack)
                            Text(
                              card.context,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _nextCard(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Don\'t know'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _nextCard(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Know'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashcardData {
  const _FlashcardData({
    required this.front,
    required this.back,
    required this.context,
  });

  final String front;
  final String back;
  final String context;
}

