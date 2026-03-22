import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'material_reader_screen.dart';

const Color _kViolet = Color(0xFF4C6FFF);

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
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String _selectedType = _typeOptions.first;
  String _selectedLevel = _levelOptions.first;
  String _searchQuery = '';

  List<MaterialSummary> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiClient.instance.getJson(
        '/materials',
        authenticated: true,
      );
      if (!mounted) return;
      final list = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(MaterialSummary.fromJson)
              .toList()
          : <MaterialSummary>[];
      setState(() {
        _all = list;
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
      setState(() => _all.removeWhere((m) => m.id == material.id));
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

  List<MaterialSummary> get _filteredMaterials {
    return _all.where((material) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty || material.title.toLowerCase().contains(query);

      final matchesType = _selectedType == _typeOptions.first ||
          material.materialType == _selectedType;

      final matchesLevel = _selectedLevel == _levelOptions.first ||
          material.englishLevel == _selectedLevel;

      return matchesSearch && matchesType && matchesLevel;
    }).toList();
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
            onTypeChanged: (v) => setState(() => _selectedType = v!),
            onLevelChanged: (v) => setState(() => _selectedLevel = v!),
            onSearchChanged: (value) => setState(() => _searchQuery = value),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _kViolet,
        ),
      );
    }
    if (_error != null) {
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
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final items = _filteredMaterials;
    if (items.isEmpty && _all.isEmpty) {
      return _EmptyMaterialsState();
    }
    if (items.isEmpty) {
      return Center(
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
      );
    }
    return RefreshIndicator(
      color: _kViolet,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final material = items[index];
          return _MaterialCard(
            material: material,
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
          'Upload a short PDF (up to about 10 pages) to start reading in English. '
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
          color: const Color(0xFF4C6FFF),
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
    required this.onDelete,
  });

  final MaterialSummary material;
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
                                      color: const Color(0xFF4C6FFF),
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
