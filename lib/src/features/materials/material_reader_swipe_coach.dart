import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kCoachViolet = Color(0xFF8840FE);

/// Non-blocking swipe hint overlay; auto-dismisses after [displayDuration].
class MaterialReaderSwipeCoach extends StatefulWidget {
  const MaterialReaderSwipeCoach({
    super.key,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 5),
  });

  final VoidCallback onDismiss;
  final Duration displayDuration;

  @override
  State<MaterialReaderSwipeCoach> createState() =>
      _MaterialReaderSwipeCoachState();
}

class _MaterialReaderSwipeCoachState extends State<MaterialReaderSwipeCoach>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _slide = Tween<double>(begin: -36, end: 36).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );
    _fade = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );
    Future<void>.delayed(widget.displayDuration, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _kCoachViolet.withValues(alpha: 0.06),
                        Colors.transparent,
                        Colors.transparent,
                        _kCoachViolet.withValues(alpha: 0.06),
                      ],
                      stops: const [0, 0.35, 0.65, 1],
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(_slide.value, 0),
                  child: child,
                ),
              ),
              Positioned(
                bottom: 48,
                left: 24,
                right: 24,
                child: Opacity(
                  opacity: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282A3A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Swipe left or right to turn pages',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: _SwipeCoachGlyph(),
      ),
    );
  }
}

class _SwipeCoachGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kCoachViolet.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: _kCoachViolet.withValues(alpha: 0.7),
            size: 28,
          ),
          Icon(
            Icons.swipe_rounded,
            color: _kCoachViolet,
            size: 36,
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _kCoachViolet.withValues(alpha: 0.7),
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Slightly softer page snap than the default [PageScrollPhysics].
class SmoothPageScrollPhysics extends PageScrollPhysics {
  const SmoothPageScrollPhysics({super.parent});

  @override
  SmoothPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.28,
        stiffness: 210,
        damping: 24,
      );
}
