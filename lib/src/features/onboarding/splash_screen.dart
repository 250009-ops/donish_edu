import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_branding.dart';

/// Animated splash shown on every cold app launch (~2.7s).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static const primary = AppBranding.primary;
  static const secondary = AppBranding.primaryLight;
  static const _logoAsset = AppBranding.logoAsset;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _totalMs = 2700;
  static const _exitStartMs = 2200;

  late final AnimationController _timeline;
  late final AnimationController _pulse;
  late final AnimationController _orbDrift;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _taglineSlide;
  late final Animation<double> _dotsOpacity;
  late final Animation<double> _exitOpacity;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _timeline = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _orbDrift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
    ]).animate(CurvedAnimation(
      parent: _timeline,
      curve: const Interval(0, 0.35, curve: Curves.linear),
    ));

    _logoRotation = Tween<double>(begin: -math.pi, end: 0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _glowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.11, 0.25, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.44, 0.60, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.44, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _dotsOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.56, 0.70, curve: Curves.easeOut),
      ),
    );

    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: Interval(
          _exitStartMs / _totalMs,
          1.0,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _timeline.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _pulse.repeat(reverse: true);
    });

    _timeline.forward();
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _pulse.stop();
    _orbDrift.stop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _timeline.dispose();
    _pulse.dispose();
    _orbDrift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: AnimatedBuilder(
        animation: Listenable.merge([_timeline, _pulse, _orbDrift]),
        builder: (context, child) {
          return Opacity(
            opacity: _exitOpacity.value.clamp(0.0, 1.0),
            child: child,
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SplashScreen.primary,
                SplashScreen.secondary,
                SplashScreen.primary,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AmbientOrbs(drift: _orbDrift.value),
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoCluster(),
                    const SizedBox(height: 24),
                    _buildTagline(),
                    const SizedBox(height: 40),
                    _buildLoadingDots(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoCluster() {
    final pulseValue = 0.85 + (_pulse.value * 0.15);
    final shadowBlur = 24.0 + (_pulse.value * 16);

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: _glowOpacity.value * 0.5,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.28),
                    blurRadius: 48,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: _logoScale.value,
            child: Transform.rotate(
              angle: _logoRotation.value,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22 * pulseValue),
                      blurRadius: shadowBlur,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: ColoredBox(
                    color: SplashScreen.primary,
                    child: Image.asset(
                      SplashScreen._logoAsset,
                      width: 148,
                      height: 148,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          AppBranding.displayName,
                          style: AppBranding.wordmark(
                            fontSize: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return Opacity(
      opacity: _taglineOpacity.value,
      child: Transform.translate(
        offset: Offset(0, _taglineSlide.value),
        child: Text(
          AppBranding.tagline,
          style: AppBranding.wordmark(
            fontSize: 15,
            color: Colors.white.withOpacity(0.92),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Opacity(
      opacity: _dotsOpacity.value,
      child: _LoadingDots(pulse: _pulse.value),
    );
  }
}

class _AmbientOrbs extends StatelessWidget {
  const _AmbientOrbs({required this.drift});

  final double drift;

  @override
  Widget build(BuildContext context) {
    final sin = math.sin(drift * math.pi * 2);
    final cos = math.cos(drift * math.pi * 2);

    return Stack(
      children: [
        Positioned(
          top: 80 + sin * 24,
          left: -40 + cos * 16,
          child: _orb(180, Colors.white.withOpacity(0.12)),
        ),
        Positioned(
          bottom: 120 - sin * 20,
          right: -60 - cos * 12,
          child: _orb(220, Colors.white.withOpacity(0.10)),
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final phase = (pulse + index * 0.2) % 1.0;
        final scale = 0.65 + (phase < 0.5 ? phase : 1 - phase) * 0.7;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        );
      }),
    );
  }
}
