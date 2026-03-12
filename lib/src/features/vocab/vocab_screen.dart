import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flashcards_screen.dart';
import 'quiz_screen.dart';

const List<String> _wordFormOptions = [
  'All',
  'Noun',
  'Verb',
  'Adjective',
  'Adverb',
  'Pronoun',
];

const Color _kFilterHighlight = Color(0xFFF59E0B);

class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});

  @override
  State<VocabScreen> createState() => _VocabScreenState();
}

typedef VocabWord = ({String english, String uzbek, String tag, double progress});

class _VocabScreenState extends State<VocabScreen> {
  String _wordFormFilter = _wordFormOptions.first;
  String _searchQuery = '';

  static const List<VocabWord> _allWords = [
    (english: 'Beautiful', uzbek: 'Chiroyli', tag: 'Adjective', progress: 0.85),
    (english: 'School', uzbek: 'Maktab', tag: 'Noun', progress: 1.0),
    (english: 'Book', uzbek: 'Kitob', tag: 'Noun', progress: 0.9),
    (english: 'Run', uzbek: 'Yugurmoq', tag: 'Verb', progress: 0.6),
    (english: 'Quickly', uzbek: 'Tez', tag: 'Adverb', progress: 0.75),
    (english: 'He', uzbek: 'U', tag: 'Pronoun', progress: 1.0),
    (english: 'Happy', uzbek: 'Baxtli', tag: 'Adjective', progress: 0.8),
    (english: 'Read', uzbek: 'O\'qimoq', tag: 'Verb', progress: 0.7),
  ];

  List<VocabWord> get _filteredWords {
    Iterable<VocabWord> words = _allWords;

    if (_wordFormFilter != _wordFormOptions.first) {
      words = words.where((w) => w.tag == _wordFormFilter);
    }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _StatsCard(),
            const SizedBox(height: 16),
            _SearchBar(
              onChanged: (value) =>
                  setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            const _PracticeRow(),
            const SizedBox(height: 20),
            _WordsSection(
              wordFormFilter: _wordFormFilter,
              onFilterChanged: (v) => setState(() => _wordFormFilter = v!),
              words: _filteredWords,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
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
                  '542',
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
                        widthFactor: 0.7,
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
                      '387 mastered',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '155 learning',
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
                    value: 0.71,
                    strokeWidth: 7,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.25),
                  ),
                ),
                Text(
                  '71%',
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
  const _PracticeRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PracticeCard(
            label: 'Flashcards',
            icon: Icons.loop,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FlashcardsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PracticeCard(
            label: 'Quiz Mode',
            icon: Icons.star,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QuizScreen(),
                ),
              );
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
  const _WordsSection({
    required this.wordFormFilter,
    required this.onFilterChanged,
    required this.words,
  });

  final String wordFormFilter;
  final void Function(String?) onFilterChanged;
  final List<VocabWord> words;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Words',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            _FilterButton(
              currentValue: wordFormFilter,
              options: _wordFormOptions,
              onChanged: onFilterChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (words.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No words in this category',
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

/// Filter button with dropdown: white card, checkmark for selected, orange for hover (per image).
/// Dropdown overlay for vocab filter: white card, checkmark for selected, orange for hover.
class _VocabFilterOverlay extends StatefulWidget {
  const _VocabFilterOverlay({
    required this.left,
    required this.top,
    required this.menuWidth,
    required this.itemHeight,
    required this.options,
    required this.currentValue,
    required this.onSelected,
    required this.onDismiss,
  });

  final double left;
  final double top;
  final double menuWidth;
  final double itemHeight;
  final List<String> options;
  final String currentValue;
  final void Function(String) onSelected;
  final VoidCallback onDismiss;

  @override
  State<_VocabFilterOverlay> createState() => _VocabFilterOverlayState();
}

class _VocabFilterOverlayState extends State<_VocabFilterOverlay> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widget.menuWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.options.length, (i) {
                  final option = widget.options[i];
                  final isSelected = widget.currentValue == option;
                  final isHovered = _hoveredIndex == i;
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = i),
                    onExit: (_) => setState(() => _hoveredIndex = -1),
                    child: Material(
                      color: isHovered ? _kFilterHighlight : Colors.transparent,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(i == 0 ? 12 : 0),
                        bottom: Radius.circular(
                            i == widget.options.length - 1 ? 12 : 0),
                      ),
                      child: InkWell(
                        onTap: () => widget.onSelected(option),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(i == 0 ? 12 : 0),
                          bottom: Radius.circular(
                              i == widget.options.length - 1 ? 12 : 0),
                        ),
                        child: SizedBox(
                          height: widget.itemHeight,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: isHovered
                                              ? Colors.white
                                              : const Color(0xFF111827),
                                        )
                                      : null,
                                ),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isHovered
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatefulWidget {
  const _FilterButton({
    required this.currentValue,
    required this.options,
    required this.onChanged,
  });

  final String currentValue;
  final List<String> options;
  final void Function(String?) onChanged;

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  final GlobalKey _key = GlobalKey();

  void _openMenu() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    const itemHeight = 44.0;
    const menuWidth = 180.0;
    final top = offset.dy + box.size.height + 4;
    final left = offset.dx + box.size.width - menuWidth;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final clampedLeft = left.clamp(12.0, screenWidth - menuWidth - 12);

    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _VocabFilterOverlay(
        left: clampedLeft,
        top: top,
        menuWidth: menuWidth,
        itemHeight: itemHeight,
        options: widget.options,
        currentValue: widget.currentValue,
        onSelected: (v) => Navigator.of(ctx).pop(v),
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );

    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _key,
        onTap: _openMenu,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
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

