import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/local_date.dart';
import '../../core/network/api_client.dart';
import '../auth/data/auth_session_store.dart';
import 'data/vocab_cache_store.dart';
import 'data/vocab_repository.dart';
import 'data/word_lexicon_store.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';
import 'widgets/vocab_day_calendar.dart';

class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key, required this.userId});

  final String userId;

  @override
  VocabScreenState createState() => VocabScreenState();
}

typedef VocabWord = ({
  String english,
  String uzbek,
  String tag,
  double progress,
  bool saved,
});

class VocabScreenState extends State<VocabScreen> with WidgetsBindingObserver {
  late final VocabRepository _repo = VocabRepository(ApiClient.instance);

  bool _refreshing = false;
  String? _loadError;
  List<VocabEntry> _entries = [];
  String _searchQuery = '';
  Set<String> _datesWithWords = {};
  DateTime? _memberSince;
  DateTime _selectedDate = localDateOnly(DateTime.now());
  DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _calendarExpanded = true;

  DateTime get _today => localDateOnly(DateTime.now());

  DateTime get _minSelectableDay => _memberSince ?? _today;

  DateTime get _maxSelectableDay => _today;

  DateTime _clampSelection(DateTime day) =>
      clampLocalDay(day, _minSelectableDay, _maxSelectableDay);

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
    _bootstrap().then((_) async {
      await _hydrateFromCache();
      if (!mounted) return;
      _loadVocabulary();
    });
  }

  Future<void> _bootstrap() async {
    await WordLexiconStore.instance.setActiveUser(widget.userId);
    await VocabCacheStore.instance.setActiveUser(widget.userId);
    final memberIso = await AuthSessionStore().readMemberSinceIso();
    _memberSince = memberSinceFromIso(memberIso);
    _selectedDate = _clampSelection(_selectedDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  Future<void> _hydrateFromCache() async {
    final snap = await VocabCacheStore.instance.loadUiSnapshot();
    if (snap == null || !mounted) return;
    final selected = _clampSelection(snap.selectedDate);
    setState(() {
      _datesWithWords = snap.datesWithWords;
      _selectedDate = selected;
      _visibleMonth = DateTime(selected.year, selected.month, 1);
      _entries = snap.entries;
      _loadError = null;
    });
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

  Future<void> loadVocabulary() => _loadVocabulary();

  Future<void> _syncLexicon() async {
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
    } catch (_) {}
  }

  Future<void> _loadVocabulary() async {
    setState(() {
      _refreshing = true;
      _loadError = null;
    });
    try {
      Set<String> datesSet = {};
      try {
        final daysPayload = await _repo.listDaysWithWords();
        datesSet = daysPayload.dates.toSet();
        if (daysPayload.memberSinceIso != null) {
          await AuthSessionStore()
              .saveMemberSinceIso(daysPayload.memberSinceIso);
          _memberSince = memberSinceFromIso(daysPayload.memberSinceIso);
        }
      } catch (e) {
        if (_entries.isEmpty) {
          _loadError = e.toString();
        }
      }

      try {
        await _syncLexicon();
      } catch (_) {}

      final selected = _clampSelection(_selectedDate);

      List<VocabEntry> list = [];
      try {
        list = await _repo.listForLocalDate(selected);
        if (_loadError != null && list.isNotEmpty) {
          _loadError = null;
        }
      } catch (e) {
        if (_entries.isEmpty) {
          _loadError = e.toString();
        }
      }

      if (!mounted) return;
      setState(() {
        _datesWithWords = datesSet;
        _selectedDate = selected;
        _visibleMonth = DateTime(selected.year, selected.month, 1);
        _entries = list;
        _refreshing = false;
      });
      await VocabCacheStore.instance.saveUiSnapshot(
        datesWithWords: datesSet,
        selectedDate: selected,
        entries: list,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        if (_entries.isEmpty) {
          _loadError = e.toString();
        }
      });
    }
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    final day = _clampSelection(date);
    if (isBeforeLocalDay(day, _minSelectableDay) ||
        isAfterLocalDay(day, _maxSelectableDay)) {
      return;
    }
    final cached = await VocabCacheStore.instance.loadEntriesForDate(day);
    if (!mounted) return;
    setState(() {
      _selectedDate = day;
      _loadError = null;
      if (cached != null) _entries = cached;
      _refreshing = true;
    });
    try {
      final list = await _repo.listForLocalDate(day);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _refreshing = false;
      });
      await VocabCacheStore.instance.saveEntriesForDate(day, list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
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
        saved: e.savedForPractice,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadVocabulary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xFF8840FE),
                    backgroundColor: Color(0xFFE5E7EB),
                  ),
                ),
              _StatsCard(
                totalWords: _totalWords,
                masteredCount: _masteredCount,
                learningCount: _learningCount,
                masteryPercent: _masteryPercent,
                dateLabel: formatLocalDateLabel(_selectedDate),
              ),
              if (_loadError != null && _entries.isEmpty) ...[
                const SizedBox(height: 12),
                _VocabErrorBanner(
                  message: _loadError!,
                  onRetry: _loadVocabulary,
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(
                  () => _calendarExpanded = !_calendarExpanded,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Study calendar',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _calendarExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ),
              if (_calendarExpanded) ...[
                const SizedBox(height: 8),
                VocabDayCalendar(
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  datesWithWords: _datesWithWords,
                  minSelectableDate: _minSelectableDay,
                  maxSelectableDate: _maxSelectableDay,
                  onMonthChanged: (m) => setState(() => _visibleMonth = m),
                  onDateSelected: (d) => _loadEntriesForDate(d),
                ),
              ],
              const SizedBox(height: 16),
              _SearchBar(
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 16),
              _PracticeRow(
                entries: List<VocabEntry>.from(_entries),
                vocabRepository: _repo,
                selectedDateLabel: formatLocalDateLabel(_selectedDate),
                onReturnFromPractice: _loadVocabulary,
              ),
              const SizedBox(height: 20),
              _WordsSection(
                words: _filteredWords,
                selectedDateLabel: formatLocalDateLabel(_selectedDate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocabErrorBanner extends StatelessWidget {
  const _VocabErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
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
    required this.dateLabel,
  });

  final int totalWords;
  final int masteredCount;
  final int learningCount;
  final double masteryPercent;
  final String dateLabel;

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
          colors: [Color(0xFF8840FE), Color(0xFF9B5FFF)],
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
                  dateLabel,
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
                  'Words this day',
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
                        child: Container(color: Colors.white),
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
    required this.selectedDateLabel,
    required this.onReturnFromPractice,
  });

  final List<VocabEntry> entries;
  final VocabRepository vocabRepository;
  final String selectedDateLabel;
  final Future<void> Function() onReturnFromPractice;

  @override
  Widget build(BuildContext context) {
    final disabled = entries.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice · $selectedDateLabel',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PracticeCard(
                label: 'Flashcards',
                icon: Icons.loop,
                disabled: disabled,
                onTap: disabled
                    ? null
                    : () {
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
                disabled: disabled,
                onTap: disabled
                    ? null
                    : () {
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
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final isPrimary = label == 'Flashcards';
    final colors = disabled
        ? [const Color(0xFFD1D5DB), const Color(0xFFE5E7EB)]
        : isPrimary
            ? const [Color(0xFF8840FE), Color(0xFF9B5FFF)]
            : const [Color(0xFF9B5FFF), Color(0xFFB98CFF)];

    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: InkWell(
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
      ),
    );
  }
}

class _WordsSection extends StatelessWidget {
  const _WordsSection({
    required this.words,
    required this.selectedDateLabel,
  });

  final List<VocabWord> words;
  final String selectedDateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Words · $selectedDateLabel',
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
                'No words for this day. Read a material and tap words to build your list.',
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
                saved: w.saved,
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
    required this.saved,
  });

  final String english;
  final String uzbek;
  final String tag;
  final double progress;
  final bool saved;

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
                  color: saved
                      ? const Color(0xFF8840FE)
                      : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: saved ? Colors.white : const Color(0xFF8840FE),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded),
                color: const Color(0xFF8840FE),
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
