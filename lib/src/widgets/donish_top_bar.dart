import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/config/app_branding.dart';
import '../features/billing/models/subscription_info.dart';

/// Persistent top bar: Gotcha wordmark + profile icon.
class DonishTopBar extends StatefulWidget {
  const DonishTopBar({
    super.key,
    this.userDisplayName,
    this.subscription,
    this.onLogOut,
    this.onUpgrade,
    this.onRevokeOtherDevices,
  });

  final String? userDisplayName;
  final SubscriptionInfo? subscription;
  final VoidCallback? onLogOut;
  final VoidCallback? onUpgrade;
  final Future<void> Function()? onRevokeOtherDevices;

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
        subscription: widget.subscription,
        onLogOut: () {
          dismiss();
          widget.onLogOut?.call();
        },
        onUpgrade: () {
          dismiss();
          widget.onUpgrade?.call();
        },
        onRevokeOtherDevices: widget.onRevokeOtherDevices,
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

const double _kProfileCardWidth = 272;
const double _kProfileCardRadius = 12;

class _ProfileCardOverlay extends StatefulWidget {
  const _ProfileCardOverlay({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.displayName,
    required this.onLogOut,
    required this.onUpgrade,
    required this.onDismiss,
    this.subscription,
    this.onRevokeOtherDevices,
  });

  final Offset anchorTopLeft;
  final Size anchorSize;
  final String displayName;
  final SubscriptionInfo? subscription;
  final VoidCallback onLogOut;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;
  final Future<void> Function()? onRevokeOtherDevices;

  @override
  State<_ProfileCardOverlay> createState() => _ProfileCardOverlayState();
}

class _ProfileCardOverlayState extends State<_ProfileCardOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _revoking = false;

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

  Future<void> _revokeOthers() async {
    final action = widget.onRevokeOtherDevices;
    if (action == null || _revoking) return;
    setState(() => _revoking = true);
    try {
      await action();
      if (mounted) _dismiss();
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    double left = widget.anchorTopLeft.dx + widget.anchorSize.width - _kProfileCardWidth;
    left = left.clamp(12.0, screenSize.width - _kProfileCardWidth - 12);
    final top = widget.anchorTopLeft.dy + widget.anchorSize.height + 8;
    final sub = widget.subscription;
    final isPremium = sub?.isPremium == true;
    final billingEnabled = sub?.billingEnabled == true;

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
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              size: 22,
                              color: Color(0xFF9CA3AF),
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
                      if (sub != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (billingEnabled) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPremium
                                        ? const Color(0xFFFFF7ED)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    isPremium ? 'Premium plan' : 'Free plan',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isPremium
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isPremium
                                      ? '${_formatUzs(sub.priceUzs)} / month'
                                      : '${sub.usage.materialsCount}/${sub.limits.freeMaxMaterials} PDF · ${sub.usage.translateTotal}/${sub.limits.freeMaxTranslateTotal} taps',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              Text(
                                'Up to ${sub.limits.maxDevices} devices · personal use',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (billingEnabled && !isPremium)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: FilledButton(
                              onPressed: widget.onUpgrade,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppBranding.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                'Upgrade to Premium',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (sub.usage.devicesCount > 1 &&
                            widget.onRevokeOtherDevices != null)
                          _menuAction(
                            icon: Icons.phonelink_erase_rounded,
                            label: _revoking ? 'Freeing devices…' : 'Free other devices',
                            color: const Color(0xFF374151),
                            onTap: _revoking ? null : _revokeOthers,
                          ),
                      ],
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      _menuAction(
                        icon: Icons.logout_rounded,
                        label: 'Log out',
                        color: const Color(0xFFDC2626),
                        onTap: widget.onLogOut,
                        bottomRadius: true,
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

  Widget _menuAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool bottomRadius = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: bottomRadius
            ? const BorderRadius.vertical(bottom: Radius.circular(_kProfileCardRadius))
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUzs(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} UZS';
  }
}
