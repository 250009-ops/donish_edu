import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../billing/models/subscription_info.dart';
import 'data/materials_cache_store.dart';
import 'material_reader_screen.dart';

const Color _kViolet = Color(0xFF8840FE);

const List<String> _typeOptions = [
  'All Types',
  'Article',
  'Short Story',
  'Book',
  'Document',
  'Other',
];

const List<String> _levelOptions = [
  'All Levels',
  'A1',
  'A2',
  'B1',
  'B2',
  'C1',
  'C2',
];

class MaterialSummary {
  const MaterialSummary({
    required this.id,
    required this.title,
    required this.materialType,
    required this.englishLevel,
    this.pageCount,
    this.createdAt,
  });

  final String id;
  final String title;
  final String materialType;
  final String englishLevel;
  final int? pageCount;
  /// Server `created_at` (upload time), UTC from API; shown in local time in the list.
  final DateTime? createdAt;

  factory MaterialSummary.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String && raw.isNotEmpty) {
      created = DateTime.tryParse(raw);
    }

    return MaterialSummary(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      materialType: json['material_type'] as String? ?? 'Other',
      englishLevel: json['english_level'] as String? ?? 'B1',
      pageCount: json['page_count'] as int?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'material_type': materialType,
        'english_level': englishLevel,
        if (pageCount != null) 'page_count': pageCount,
        if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      };
}

/// Compact local date + 24h time for list cards (e.g. `Oct 24, 14:30`).
String _formatMaterialListTimestamp(DateTime? utc) {
  if (utc == null) return '';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final l = utc.toLocal();
  final mon = months[l.month - 1];
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '$mon ${l.day}, $hh:$mm';
}

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({
    super.key,
    required this.userId,
    this.subscription,
    this.onUpgrade,
  });

  final String userId;
  final SubscriptionInfo? subscription;
  final VoidCallback? onUpgrade;

  @override
  MaterialsScreenState createState() => MaterialsScreenState();
}

class MaterialsScreenState extends State<MaterialsScreen> {
  static const int _pageSize = 40;

  String _selectedType = _typeOptions.first;
  String _selectedLevel = _levelOptions.first;
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<MaterialSummary> _items = [];
  int _nextOffset = 0;
  bool _hasMore = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _loadMoreInProgress = false;
  String? _error;

  /// Refetch from the first page (e.g. after upload). Keeps existing list visible.
  Future<void> reloadMaterials() => _fetchMaterials(reset: true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initFromCacheThenFetch();
  }

  Future<void> _initFromCacheThenFetch() async {
    await MaterialsCacheStore.instance.setActiveUser(widget.userId);
    await _hydrateFromCache();
    if (!mounted) return;
    _fetchMaterials(reset: true);
  }

  Future<void> _hydrateFromCache() async {
    final cached = await MaterialsCacheStore.instance.loadFeed(
      type: _selectedType,
      level: _selectedLevel,
      searchQuery: _searchQuery,
    );
    if (cached == null || !mounted) return;
    final items = cached.itemMaps.map(MaterialSummary.fromJson).toList();
    setState(() {
      _items = items;
      _hasMore = cached.hasMore;
      _nextOffset = cached.nextOffset;
      _error = null;
    });
  }

  Future<void> _persistFeedCache() async {
    await MaterialsCacheStore.instance.saveFeed(
      type: _selectedType,
      level: _selectedLevel,
      searchQuery: _searchQuery,
      itemMaps: _items.map((m) => m.toJson()).toList(),
      hasMore: _hasMore,
      nextOffset: _nextOffset,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedType != _typeOptions.first ||
      _selectedLevel != _levelOptions.first ||
      _searchQuery.trim().isNotEmpty;

  void _onScroll() {
    if (!mounted) return;
    if (_loadMoreInProgress ||
        _loadingMore ||
        !_hasMore ||
        _refreshing ||
        _error != null) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 360) {
      _fetchMaterials(reset: false);
    }
  }

  void _reloadFromFilters() {
    _searchDebounce?.cancel();
    _hydrateFromCache().then((_) {
      if (mounted) _fetchMaterials(reset: true);
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _hydrateFromCache().then((_) {
        if (mounted) _fetchMaterials(reset: true);
      });
    });
  }

  Future<void> _fetchMaterials({bool reset = false}) async {
    if (reset) {
      _loadMoreInProgress = false;
      setState(() {
        _refreshing = true;
        _error = null;
        _hasMore = false;
        _nextOffset = 0;
        _loadingMore = false;
      });
    } else {
      if (_loadMoreInProgress || !_hasMore || _refreshing || _error != null) {
        return;
      }
      _loadMoreInProgress = true;
      setState(() => _loadingMore = true);
    }

    final offset = reset ? 0 : _nextOffset;
    final params = <String, String>{
      'limit': '$_pageSize',
      'offset': '$offset',
    };
    final q = _searchQuery.trim();
    if (q.isNotEmpty) {
      params['q'] = q;
    }
    if (_selectedType != _typeOptions.first) {
      params['material_type'] = _selectedType;
    }
    if (_selectedLevel != _levelOptions.first) {
      params['english_level'] = _selectedLevel;
    }

    try {
      final raw = await ApiClient.instance.getJson(
        '/materials',
        authenticated: true,
        queryParameters: params,
      );
      if (!mounted) return;

      if (raw is! Map<String, dynamic>) {
        setState(() {
          _error = 'Unexpected response from server.';
          _refreshing = false;
          _loadingMore = false;
          _loadMoreInProgress = false;
        });
        return;
      }

      final batch = (raw['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MaterialSummary.fromJson)
              .toList() ??
          <MaterialSummary>[];
      final hasMore = raw['has_more'] == true;

      setState(() {
        if (reset) {
          _items = batch;
        } else {
          _items = [..._items, ...batch];
        }
        _hasMore = hasMore;
        _nextOffset = reset ? batch.length : _nextOffset + batch.length;
        _refreshing = false;
        _loadingMore = false;
        _loadMoreInProgress = false;
      });
      await _persistFeedCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreInProgress = false;
        _refreshing = false;
        if (reset) {
          if (_items.isEmpty) {
            _error = e.toString();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not refresh: $e',
                  style: GoogleFonts.inter(),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      });
      if (!reset && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load more: $e',
              style: GoogleFonts.inter(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteMaterial(
    BuildContext context,
    MaterialSummary material,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete material?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '“${material.title}” will be removed from your list. '
          'Words you already saved stay in vocabulary.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ApiClient.instance.deleteJson(
        '/materials/${material.id}',
        authenticated: true,
      );
      if (!mounted) return;
      setState(() => _items.removeWhere((m) => m.id == material.id));
      await _persistFeedCache();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Removed “${material.title}”',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _SearchAndFilters(
            selectedType: _selectedType,
            selectedLevel: _selectedLevel,
            onTypeChanged: (v) {
              setState(() => _selectedType = v!);
              _reloadFromFilters();
            },
            onLevelChanged: (v) {
              setState(() => _selectedLevel = v!);
              _reloadFromFilters();
            },
            onSearchChanged: _onSearchChanged,
          ),
          if (widget.subscription != null &&
              widget.subscription!.billingEnabled &&
              widget.subscription!.isFree)
            _FreePlanBanner(
              subscription: widget.subscription!,
              onUpgrade: widget.onUpgrade,
            ),
          if (_refreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: _kViolet,
              backgroundColor: Color(0xFFE5E7EB),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _fetchMaterials(reset: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && !_hasActiveFilters) {
      return _EmptyMaterialsState();
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        color: _kViolet,
        onRefresh: () => _fetchMaterials(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.25,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No materials match your filters.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final footer = _loadingMore ? 1 : 0;
    return RefreshIndicator(
      color: _kViolet,
      onRefresh: () => _fetchMaterials(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length + footer,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _kViolet,
                  ),
                ),
              ),
            );
          }
          final material = _items[index];
          return _MaterialCard(
            material: material,
            userId: widget.userId,
            onDelete: () => _confirmAndDeleteMaterial(context, material),
          );
        },
      ),
    );
  }
}

class _EmptyMaterialsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 44,
              color: _kViolet,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your reading shelf is empty',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Upload a PDF (up to about 30 pages) to start reading in English. '
          'Tap any word while you read to see an Uzbek translation and save words to your vocabulary.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: _kViolet.withOpacity(0.9), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'How to add your first material',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StepRow(number: '1', text: 'Tap the + button below.'),
              _StepRow(number: '2', text: 'Choose a PDF, name it, and pick type & level.'),
              _StepRow(number: '3', text: 'Tap the cloud upload button to send it to your account.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search bar and Type/Level filter buttons with dropdowns (Figma).
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.selectedType,
    required this.selectedLevel,
    required this.onTypeChanged,
    required this.onLevelChanged,
    required this.onSearchChanged,
  });

  final String selectedType;
  final String selectedLevel;
  final void Function(String?) onTypeChanged;
  final void Function(String?) onLevelChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search materials...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MaterialsFilterDropdown(
                label: 'Type',
                icon: Icons.tune_rounded,
                options: _typeOptions,
                value: selectedType,
                onChanged: onTypeChanged,
              ),
              const SizedBox(width: 8),
              _MaterialsFilterDropdown(
                label: 'Level',
                icon: Icons.filter_alt_outlined,
                options: _levelOptions,
                value: selectedLevel,
                onChanged: onLevelChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filter button that opens a Figma-style dropdown: white panel, shadow;
/// "All X" selected = bullet + black text; specific option selected = orange pill + white text.
class _MaterialsFilterDropdown extends StatefulWidget {
  const _MaterialsFilterDropdown({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<String> options;
  final String value;
  final void Function(String?) onChanged;

  @override
  State<_MaterialsFilterDropdown> createState() =>
      _MaterialsFilterDropdownState();
}

class _MaterialsFilterDropdownState extends State<_MaterialsFilterDropdown> {
  final GlobalKey _triggerKey = GlobalKey();

  void _openMenu() async {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    const itemHeight = 44.0;
    final menuWidth = 200.0;
    final menuHeight = widget.options.length * itemHeight;
    final top = offset.dy + box.size.height + 4;
    final left = offset.dx;
    final right = left + menuWidth;
    final bottom = top + menuHeight;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(left, top, right, bottom),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.12),
      items: widget.options.map((option) {
        final isSelected = widget.value == option;
        return PopupMenuItem<String>(
          value: option,
          height: itemHeight,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: menuWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _triggerKey,
      onTap: _openMenu,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF8840FE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

Color _levelAccentColor(String level) {
  switch (level) {
    case 'A1':
    case 'A2':
      return const Color(0xFF16A34A);
    case 'B1':
    case 'B2':
      return const Color(0xFFF97316);
    case 'C1':
    case 'C2':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF4B5563);
  }
}

Color _levelAccentBackground(String level) {
  switch (level) {
    case 'A1':
    case 'A2':
      return const Color(0xFFE5F9ED);
    case 'B1':
    case 'B2':
      return const Color(0xFFFFF4E5);
    case 'C1':
    case 'C2':
      return const Color(0xFFFEE2E2);
    default:
      return const Color(0xFFE5E7EB);
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.userId,
    required this.onDelete,
  });

  final MaterialSummary material;
  final String userId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final level = material.englishLevel;
    final lc = _levelAccentColor(level);
    final lb = _levelAccentBackground(level);
    final uploadedLabel = _formatMaterialListTimestamp(material.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MaterialReaderScreen(
                      materialId: material.id,
                      initialTitle: material.title,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF1F2),
                        border: Border.all(
                          color: const Color(0xFFFB7185),
                          width: 1.6,
                        ),
                      ),
                      child: const Icon(
                        Icons.insert_drive_file_rounded,
                        size: 20,
                        color: Color(0xFFFB7185),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lb,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  level,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: lc,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0EAFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    material.materialType,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8840FE),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (uploadedLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              uploadedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete material',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFF9CA3AF),
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _FreePlanBanner extends StatelessWidget {
  const _FreePlanBanner({
    required this.subscription,
    this.onUpgrade,
  });

  final SubscriptionInfo subscription;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final used = subscription.usage.materialsCount;
    final max = subscription.limits.freeMaxMaterials;
    return Material(
      color: const Color(0xFFF5F3FF),
      child: InkWell(
        onTap: onUpgrade,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: _kViolet, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$used of $max free PDF${max == 1 ? '' : 's'} · ${subscription.translateRemainingOnFree} word taps left',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4C1D95),
                  ),
                ),
              ),
              if (onUpgrade != null)
                Text(
                  'Upgrade',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kViolet,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
