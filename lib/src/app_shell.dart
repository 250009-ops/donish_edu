import 'package:flutter/material.dart';

import 'features/materials/add_material_screen.dart';
import 'features/materials/materials_screen.dart';
import 'features/vocab/vocab_screen.dart';
import 'widgets/donish_top_bar.dart';

/// Amber gradient for default + button (Figma: #F59E0B).
const Color _kAmber = Color(0xFFF59E0B);

/// Violet/purplish used for upload state in bottom nav.
const Color _kViolet = Color(0xFF4C6FFF);

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.userId, this.onLogOut});

  /// Currently authenticated user's numeric ID (as string).
  final String userId;
  final VoidCallback? onLogOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<MaterialsScreenState> _materialsScreenKey = GlobalKey();
  final GlobalKey<VocabScreenState> _vocabScreenKey = GlobalKey();

  /// 0 = Materials, 1 = Add Material, 2 = Vocabulary
  int _currentIndex = 0;

  /// Recreate Add Material screen after successful upload so form resets.
  int _addScreenSeed = 0;

  /// Set by AddMaterialScreen when it mounts; used when user taps FAB to upload.
  VoidCallback? _addMaterialUpload;

  // Lifted add-material form state so it persists when switching tabs
  // and the center FAB can reflect upload readiness.
  bool _addHasPdf = false;
  String _addName = '';
  String? _addType;
  String? _addLevel;
  bool _addUploading = false;

  bool get _addFormComplete =>
      _addHasPdf &&
      _addName.trim().isNotEmpty &&
      _addType != null &&
      _addLevel != null;

  void _onAddFormChanged({
    required bool hasPdf,
    required String name,
    required String? type,
    required String? level,
    required bool uploading,
  }) {
    setState(() {
      _addHasPdf = hasPdf;
      _addName = name;
      _addType = type;
      _addLevel = level;
      _addUploading = uploading;
    });
  }

  void _onAddUploadSuccess() {
    setState(() {
      _currentIndex = 0;
      _addScreenSeed++;
      _addHasPdf = false;
      _addName = '';
      _addType = null;
      _addLevel = null;
      _addUploading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _materialsScreenKey.currentState?.reloadMaterials();
    });
  }

  void _onCenterButtonTap() {
    if (_currentIndex != 1) {
      setState(() => _currentIndex = 1);
      return;
    }
    if (_addFormComplete && !_addUploading) {
      _addMaterialUpload?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MaterialsScreen(
        key: _materialsScreenKey,
        userId: widget.userId,
      ),
      AddMaterialScreen(
        key: ValueKey('add_$_addScreenSeed'),
        onFormChanged: _onAddFormChanged,
        onUploadSuccess: _onAddUploadSuccess,
        onRegisterUpload: (cb) => _addMaterialUpload = cb,
      ),
      VocabScreen(key: _vocabScreenKey, userId: widget.userId),
    ];

    final isAddPage = _currentIndex == 1;

    // Smart center button: Default [+] amber | Upload (violet, 50% or 100%) | Spinner
    Widget centerButton;
    if (isAddPage && _addUploading) {
      centerButton = SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_kViolet),
            ),
          ),
        ),
      );
    } else if (isAddPage) {
      final enabled = _addFormComplete;
      centerButton = Material(
        color: _kViolet.withOpacity(enabled ? 1.0 : 0.5),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: enabled ? _onCenterButtonTap : null,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
          ),
        ),
      );
    } else {
      centerButton = FloatingActionButton(
        onPressed: _onCenterButtonTap,
        backgroundColor: _kAmber,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      );
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            DonishTopBar(
              userDisplayName: 'ID ${widget.userId}',
              onLogOut: widget.onLogOut,
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: keyboardVisible ? null : centerButton,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.menu_book_rounded,
                label: 'Materials',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              const SizedBox(width: 56),
              _NavItem(
                icon: Icons.style_rounded,
                label: 'Vocabulary',
                isActive: _currentIndex == 2,
                onTap: () {
                  final wasOnVocab = _currentIndex == 2;
                  setState(() => _currentIndex = 2);
                  if (!wasOnVocab) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _vocabScreenKey.currentState?.loadVocabulary();
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? const Color(0xFF4C6FFF) : const Color(0xFF9CA4B8);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
