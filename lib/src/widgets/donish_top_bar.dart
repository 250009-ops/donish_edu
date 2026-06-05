import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/config/app_branding.dart';

/// Persistent top bar: Gotcha wordmark + profile icon.
/// Tapping profile shows a pop-up card (user name + Log out) with transition.
class DonishTopBar extends StatefulWidget {
  const DonishTopBar({
    super.key,
    this.userDisplayName,
    this.onLogOut,
  });

  /// Display name in the profile card (e.g. "Javohir Abdullayev"). If null, shows "User".
  final String? userDisplayName;

  /// Called when the user taps "Log out" in the profile card.
  final VoidCallback? onLogOut;

  @override
  State<DonishTopBar> createState() => _DonishTopBarState();
}

class _DonishTopBarState extends State<DonishTopBar> {
  final GlobalKey _profileKey = GlobalKey();

  void _onProfileTap() {
    final box = _profileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    void dismiss() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) => _ProfileCardOverlay(
        anchorTopLeft: offset,
        anchorSize: size,
        displayName: widget.userDisplayName ?? 'User',
        onLogOut: () {
          dismiss();
          widget.onLogOut?.call();
        },
        onDismiss: dismiss,
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppBranding.primary, AppBranding.primaryLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Text(
            AppBranding.displayName,
            style: AppBranding.wordmark(
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            key: _profileKey,
            icon: const Icon(Icons.person_outline_rounded),
            color: Colors.white,
            onPressed: _onProfileTap,
          ),
        ],
      ),
    );
  }

}

const double _kProfileCardWidth = 240;
const double _kProfileCardRadius = 12;

/// Overlay that shows the profile card with enter/exit transition.
class _ProfileCardOverlay extends StatefulWidget {
  const _ProfileCardOverlay({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.displayName,
    required this.onLogOut,
    required this.onDismiss,
  });

  final Offset anchorTopLeft;
  final Size anchorSize;
  final String displayName;
  final VoidCallback onLogOut;
  final VoidCallback onDismiss;

  @override
  State<_ProfileCardOverlay> createState() => _ProfileCardOverlayState();
}

class _ProfileCardOverlayState extends State<_ProfileCardOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    double left = widget.anchorTopLeft.dx + widget.anchorSize.width - _kProfileCardWidth;
    left = left.clamp(12.0, screenSize.width - _kProfileCardWidth - 12);
    final top = widget.anchorTopLeft.dy + widget.anchorSize.height + 8;

    return Stack(
      children: [
        GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: _kProfileCardWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_kProfileCardRadius),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 22,
                              color: const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: const Color(0xFFE5E7EB),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onLogOut();
                          },
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(_kProfileCardRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 20,
                                  color: const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Log out',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
