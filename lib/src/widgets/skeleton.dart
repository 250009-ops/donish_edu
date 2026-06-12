import 'package:flutter/material.dart';

/// Provides a shared shimmer [animation] value to descendant [SkeletonBox] widgets.
class SkeletonScope extends InheritedWidget {
  const SkeletonScope({
    super.key,
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SkeletonScope>();
    assert(scope != null, 'SkeletonBox must be inside SkeletonScope');
    return scope!.animation;
  }

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) =>
      oldWidget.animation != animation;
}

/// Wraps skeleton layouts with a single shimmer animation ticker.
class SkeletonScopeHost extends StatefulWidget {
  const SkeletonScopeHost({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonScopeHost> createState() => _SkeletonScopeHostState();
}

class _SkeletonScopeHostState extends State<SkeletonScopeHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

/// Base shimmer placeholder used across loading skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SkeletonScope.of(context),
      builder: (context, child) {
        final t = SkeletonScope.of(context).value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF9FAFB),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton layout matching [VocabScreen] while vocabulary loads.
class VocabScreenSkeleton extends StatelessWidget {
  const VocabScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SkeletonScopeHost(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _StatsCardSkeleton(),
              const SizedBox(height: 16),
              const SkeletonBox(
                height: 48,
                borderRadius: 999,
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(height: 56, borderRadius: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(height: 56, borderRadius: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SkeletonBox(width: 100, height: 16, borderRadius: 6),
              const SizedBox(height: 12),
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                const _WordCardSkeleton(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCardSkeleton extends StatelessWidget {
  const _StatsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFD1D5DB),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 110, height: 18, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 13, borderRadius: 6),
                SizedBox(height: 16),
                SkeletonBox(width: 48, height: 26, borderRadius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 72, height: 13, borderRadius: 6),
                SizedBox(height: 12),
                SkeletonBox(height: 8, borderRadius: 999),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 88, height: 11, borderRadius: 4),
                    SkeletonBox(width: 80, height: 11, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          SkeletonBox(width: 72, height: 72, borderRadius: 999),
        ],
      ),
    );
  }
}

class _WordCardSkeleton extends StatelessWidget {
  const _WordCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 15, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 13, borderRadius: 6),
                  ],
                ),
              ),
              SkeletonBox(width: 52, height: 24, borderRadius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 36, height: 36, borderRadius: 999),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 6, borderRadius: 999),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonBox(width: 32, height: 11, borderRadius: 4),
          ),
        ],
      ),
    );
  }
}

/// Skeleton list for [MaterialsScreen] initial / filter reload.
class MaterialsListSkeleton extends StatelessWidget {
  const MaterialsListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonScopeHost(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _MaterialCardSkeleton(),
      ),
    );
  }
}

class _MaterialCardSkeleton extends StatelessWidget {
  const _MaterialCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 44, height: 44, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 15, borderRadius: 6)),
                    SizedBox(width: 8),
                    SkeletonBox(width: 72, height: 11, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 22, borderRadius: 999),
                    SizedBox(width: 8),
                    SkeletonBox(width: 72, height: 22, borderRadius: 999),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 24, height: 24, borderRadius: 6),
        ],
      ),
    );
  }
}
