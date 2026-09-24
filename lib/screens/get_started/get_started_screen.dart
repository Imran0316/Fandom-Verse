import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../auth/auth_form.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, this.openAuthInitially = false});

  final bool openAuthInitially;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with TickerProviderStateMixin {
  static const _ease = Cubic(0.22, 1, 0.36, 1);

  late final AnimationController _splashAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _formAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool _showAuth = false;
  bool _formMounted = false;
  AuthFormMode _mode = AuthFormMode.signUp;

  @override
  void initState() {
    super.initState();
    if (widget.openAuthInitially) {
      _splashAnim.value = 1;
      _showAuth = true;
      _formMounted = true;
      _formAnim.value = 1;
      return;
    }

    _splashAnim.forward().whenComplete(() {
      if (mounted) _openAuth();
    });
  }

  @override
  void dispose() {
    _splashAnim.dispose();
    _formAnim.dispose();
    super.dispose();
  }

  void _openAuth() {
    if (_showAuth) return;
    setState(() {
      _mode = AuthFormMode.signUp;
      _showAuth = true;
      _formMounted = true;
    });
    _formAnim.forward();
  }

  void _closeAuth() {
    setState(() => _showAuth = false);
    _formAnim.reverse().whenComplete(() {
      if (mounted && !_showAuth) {
        setState(() => _formMounted = false);
      }
    });
  }

  void _handleAuthSuccess(bool didSignUp) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      didSignUp ? AppRoutes.interests : AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showAuth,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeAuth();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _splashAnim,
                curve: const Interval(0, 0.28, curve: Curves.easeOut),
              ),
              child: AnimatedBuilder(
                animation: _splashAnim,
                builder: (context, _) =>
                    _NexoraBackdrop(particleProgress: _splashAnim.value),
              ),
            ),
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: _formAnim,
                    builder: (context, child) {
                      final progress = _ease.transform(_formAnim.value);
                      return IgnorePointer(
                        ignoring: _showAuth,
                        child: Opacity(
                          opacity: (1 - progress).clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Semantics(
                      button: true,
                      label: 'Continue to sign up',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_splashAnim.isCompleted) _openAuth();
                        },
                        child: Center(
                          child: _NexoraSplashHero(animation: _splashAnim),
                        ),
                      ),
                    ),
                  ),
                  if (_formMounted)
                    AnimatedBuilder(
                      animation: _formAnim,
                      builder: (context, child) {
                        final progress = _ease.transform(_formAnim.value);
                        return IgnorePointer(
                          ignoring: progress < 0.05,
                          child: Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 28 * (1 - progress)),
                              child: Transform.scale(
                                scale: 0.96 + 0.04 * progress,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: AuthForm(
                            initialMode: _mode,
                            onSuccess: _handleAuthSuccess,
                            onClose: _closeAuth,
                          ),
                        ),
                      ),
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

class _NexoraBackdrop extends StatelessWidget {
  const _NexoraBackdrop({required this.particleProgress});

  final double particleProgress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF080B1A)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.45, -0.7),
              radius: 1.15,
              colors: [Color(0xFF24234D), Color(0x00080B1A)],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.72, 0.5),
              radius: 0.92,
              colors: [Color(0x662E1D68), Color(0x00080B1A)],
            ),
          ),
        ),
        CustomPaint(
          painter: _ParticlePainter(particleProgress),
          child: const SizedBox.expand(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00080B1A), Color(0x22080B1A), Color(0x99080B1A)],
            ),
          ),
        ),
      ],
    );
  }
}

class _NexoraSplashHero extends StatelessWidget {
  const _NexoraSplashHero({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final backgroundFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.12, 0.48, curve: Curves.easeOutCubic),
    );
    final logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.12, 0.52, curve: Curves.easeOutCubic),
      ),
    );
    final titleFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.48, 0.72, curve: Curves.easeOut),
    );
    final taglineFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.67, 0.9, curve: Curves.easeOut),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 650;
        final logoSize = compact ? 132.0 : 160.0;
        final titleSize = compact ? 34.0 : 40.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: backgroundFade,
              child: ScaleTransition(
                scale: logoScale,
                child: _NexoraLogo(size: logoSize),
              ),
            ),
            SizedBox(height: compact ? 28 : 34),
            FadeTransition(
              opacity: titleFade,
              child: Text(
                'NEXORA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compact ? 7 : 8.5,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: taglineFade,
              child: const Text(
                'Your worlds. Your fandom. One place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB9B9D1),
                  fontSize: 15,
                  height: 1.45,
                  letterSpacing: 0.15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NexoraLogo extends StatelessWidget {
  const _NexoraLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF10142D).withValues(alpha: 0.78),
        border: Border.all(
          color: const Color(0xFF9E9AFF).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7164DB).withValues(alpha: 0.2),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(painter: _NexoraLogoPainter()),
    );
  }
}

class _NexoraLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.translate(center.dx, center.dy);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.011
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB1AAFF).withValues(alpha: 0.5);

    canvas.save();
    canvas.rotate(-0.48);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.84,
        height: size.height * 0.36,
      ),
      orbitPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.rotate(0.68);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.8,
        height: size.height * 0.32,
      ),
      orbitPaint,
    );
    canvas.restore();

    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFF4F3FF);

    final markGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF8077F2).withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final n = Path()
      ..moveTo(-size.width * 0.22, size.height * 0.23)
      ..lineTo(-size.width * 0.22, -size.height * 0.23)
      ..lineTo(size.width * 0.22, size.height * 0.23)
      ..lineTo(size.width * 0.22, -size.height * 0.23);

    canvas.drawPath(n, markGlow);
    canvas.drawPath(n, markPaint);

    final nodePaint = Paint()..color = const Color(0xFFD5D2FF);
    for (final point in [
      Offset(-size.width * 0.37, -size.height * 0.13),
      Offset(size.width * 0.34, size.height * 0.15),
      Offset(size.width * 0.08, -size.height * 0.37),
    ]) {
      canvas.drawCircle(point, size.width * 0.027, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NexoraLogoPainter oldDelegate) => false;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter(this.progress);

  final double progress;

  static const _particles = [
    Offset(0.12, 0.2),
    Offset(0.29, 0.72),
    Offset(0.43, 0.12),
    Offset(0.66, 0.25),
    Offset(0.84, 0.63),
    Offset(0.93, 0.18),
    Offset(0.08, 0.84),
    Offset(0.56, 0.88),
    Offset(0.74, 0.78),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _particles.length; index++) {
      final particle = _particles[index];
      final drift = math.sin((progress * math.pi * 2) + index) * 7;
      final offset = Offset(
        particle.dx * size.width + drift,
        particle.dy * size.height - drift,
      );
      final opacity = 0.17 + (math.sin(progress * math.pi + index) + 1) * 0.04;
      final paint = Paint()
        ..color = const Color(0xFFC1BCFF).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(offset, index.isEven ? 1.5 : 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
