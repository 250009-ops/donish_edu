import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'data/vocab_repository.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';

class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});

  @override
  VocabScreenState createState() => VocabScreenState();
}

typedef VocabWord = ({String english, String uzbek, String tag, double progress});

class VocabScreenState extends State<VocabScreen> with WidgetsBindingObserver {
  final _repo = VocabRepository(ApiClient.instance);

  bool _loading = true;
  String? _loadError;
  List<VocabEntry> _entries = [];
  String _searchQuery = '';

  int get _totalWords => _entries.length;

  int get _masteredCount =>
      _entries.where((e) => e.flashcardMastered).length;

  int get _learningCount => _totalWords - _masteredCount;

  double get _masteryPercent =>
      _totalWords == 0 ? 0.0 : _masteredCount / _totalWords;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVocabulary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadVocabulary();
    }
  }

  /// Public so [AppShell] can refresh when the user opens the Vocabulary tab.
  Future<void> loadVocabulary() => _loadVocabulary();

  Future<void> _loadVocabulary() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await _repo.listForLocalDay(DateTime.now());
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_entries.isEmpty) {
          _loadError = e.toString();
        }
      });
    }
  }

  List<VocabWord> get _filteredWords {
    Iterable<VocabWord> words = _entries.map(
      (e) => (
        english: e.word,
        uzbek: e.translationUz,
        tag: e.displayTag,
        progress: e.progress,
      ),
    );

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      words = words.where(
        (w) =>
            w.english.toLowerCase().contains(query) ||
            w.uzbek.toLowerCase().contains(query),
      );
    }

    return words.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _entries.isEmpty && _loadError == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_loadError != null && _entries.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loadVocabulary,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadVocabulary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _StatsCard(
                totalWords: _totalWords,
                masteredCount: _masteredCount,
                learningCount: _learningCount,
                masteryPercent: _masteryPercent,
              ),
              const SizedBox(height: 16),
              _SearchBar(
                onChanged: (value) =>
                    setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 16),
              _PracticeRow(
                entries: List<VocabEntry>.from(_entries),
                vocabRepository: _repo,
                onReturnFromPractice: _loadVocabulary,
              ),
              const SizedBox(height: 20),
              _WordsSection(words: _filteredWords),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.totalWords,
    required this.masteredCount,
    required this.learningCount,
    required this.masteryPercent,
  });

  final int totalWords;
  final int masteredCount;
  final int learningCount;
  final double masteryPercent;

  @override
  Widget build(BuildContext context) {
    final barValue = totalWords == 0 ? 0.0 : masteryPercent;
    final pctLabel = totalWords == 0
        ? '0%'
        : '${(masteryPercent * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF4C6FFF), Color(0xFF8E54E9)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vocabulary',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'English \u2192 Uzbek',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$totalWords',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Words',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 8,
                    color: Colors.white.withOpacity(0.25),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: barValue.clamp(0.0, 1.0),
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$masteredCount mastered',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '$learningCount learning',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: totalWords == 0 ? 0 : barValue.clamp(0.0, 1.0),
                    strokeWidth: 7,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.25),
                  ),
                ),
                Text(
                  pctLabel,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search words...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.entries,
    required this.vocabRepository,
    required this.onReturnFromPractice,
  });

  final List<VocabEntry> entries;
  final VocabRepository vocabRepository;
  final Future<void> Function() onReturnFromPractice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PracticeCard(
            label: 'Flashcards',
            icon: Icons.loop,
            onTap: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (_) => FlashcardsScreen(
                    entries: entries,
                    vocabRepository: vocabRepository,
                  ),
                ),
              )
                  .then((_) => onReturnFromPractice());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PracticeCard(
            label: 'Quiz Mode',
            icon: Icons.star,
            onTap: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    entries: entries,
                    vocabRepository: vocabRepository,
                  ),
                ),
              )
                  .then((_) => onReturnFromPractice());
            },
          ),
        ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = label == 'Flashcards';
    final colors = isPrimary
        ? const [Color(0xFF4C6FFF), Color(0xFF8E54E9)]
        : const [Color(0xFF8E54E9), Color(0xFFB46BFF)];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: colors),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordsSection extends StatelessWidget {
  const _WordsSection({required this.words});

  final List<VocabWord> words;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Words',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        if (words.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No words saved today. Tap a word in a material to add some.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          )
        else
          ...words.asMap().entries.map((e) {
            final i = e.key;
            final w = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < words.length - 1 ? 12 : 0),
              child: _WordCard(
                english: w.english,
                uzbek: w.uzbek,
                tag: w.tag,
                progress: w.progress,
              ),
            );
          }),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.english,
    required this.uzbek,
    required this.tag,
    required this.progress,
  });

  final String english;
  final String uzbek;
  final String tag;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      english,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uzbek,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded),
                color: const Color(0xFF4C6FFF),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: const Color(0xFFE5E7EB),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

