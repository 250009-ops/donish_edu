import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'material_reader_screen.dart';

const Color _kFilterHighlight = Color(0xFFF59E0B);

const List<String> _typeOptions = [
  'All Types',
  'Articles',
  'Stories',
  'Books',
];
const List<String> _levelOptions = [
  'All Levels',
  'Beginner',
  'Intermediate',
  'Advanced',
];

typedef ReadingMaterial = ({String title, String level, String type});

const List<ReadingMaterial> _materials = [
  (title: 'Tech Innovations 2026', level: 'Intermediate', type: 'Article'),
  (title: 'Climate Change Today', level: 'Advanced', type: 'Article'),
  (title: 'Space Exploration', level: 'Advanced', type: 'Article'),
  (title: 'Healthy Living Tips', level: 'Beginner', type: 'Article'),
  (title: 'The Lost Key', level: 'Beginner', type: 'Short Story'),
  (title: 'The Garden Mystery', level: 'Beginner', type: 'Short Story'),
  (title: 'Midnight Adventure', level: 'Intermediate', type: 'Short Story'),
  (title: 'The Digital Age', level: 'Advanced', type: 'Book'),
];

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String _selectedType = _typeOptions.first;
  String _selectedLevel = _levelOptions.first;

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
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _materials.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final material = _materials[index];
                return _MaterialCard(material: material);
              },
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
  });

  final String selectedType;
  final String selectedLevel;
  final void Function(String?) onTypeChanged;
  final void Function(String?) onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
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

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material});

  final ReadingMaterial material;

  Color _levelColor(String level) {
    switch (level) {
      case 'Beginner':
        return const Color(0xFF16A34A);
      case 'Intermediate':
        return const Color(0xFFF97316);
      case 'Advanced':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color _levelBackground(String level) {
    switch (level) {
      case 'Beginner':
        return const Color(0xFFE5F9ED);
      case 'Intermediate':
        return const Color(0xFFFFF4E5);
      case 'Advanced':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MaterialReaderScreen(
              materialTitle: material.title,
            ),
          ),
        );
      },
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          color: _levelBackground(material.level),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          material.level,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _levelColor(material.level),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0EAFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          material.type,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4C6FFF),
                          ),
                        ),
                      ),
                    ],
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

