import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated splash shown on every cold app launch (~2.7s).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static const primary = Color(0xFF4C6FFF);
  static const secondary = Color(0xFF8E54E9);
  static const _logoAsset = 'assets/images/logo.png';

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
  late final Animation<double> _sparkleScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;
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

    _sparkleScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.22, 0.38, curve: Curves.elasticOut),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.30, 0.48, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.30, 0.48, curve: Curves.easeOutCubic),
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
                    const SizedBox(height: 28),
                    _buildTitle(),
                    const SizedBox(height: 8),
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
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: _glowOpacity.value * 0.55,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.35),
                    blurRadius: 40,
                    spreadRadius: 8,
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
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18 * pulseValue),
                      blurRadius: shadowBlur,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Image.asset(
                  SplashScreen._logoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.menu_book_rounded,
                    color: SplashScreen.primary,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Transform.scale(
              scale: _sparkleScale.value,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Opacity(
      opacity: _titleOpacity.value,
      child: Transform.translate(
        offset: Offset(0, _titleSlide.value),
        child: Text(
          'Donish',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Opacity(
      opacity: _taglineOpacity.value,
      child: Transform.translate(
        offset: Offset(0, _taglineSlide.value),
        child: Text(
          'Master Uzbek Through Reading',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.92),
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
