import 'dart:math';

import 'package:flutter/material.dart';

class AmbientParticles extends StatefulWidget {
  const AmbientParticles({super.key});

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  static const List<_Ember> _embers = [
    _Ember(x: 0.06, phase: 0.02, size: 2.6, speed: 1.0, kind: 0),
    _Ember(x: 0.14, phase: 0.40, size: 1.6, speed: 0.7, kind: 1),
    _Ember(x: 0.22, phase: 0.75, size: 3.4, speed: 1.1, kind: 0),
    _Ember(x: 0.30, phase: 0.18, size: 1.4, speed: 0.8, kind: 2),
    _Ember(x: 0.38, phase: 0.55, size: 2.2, speed: 1.2, kind: 0),
    _Ember(x: 0.46, phase: 0.90, size: 1.8, speed: 0.65, kind: 1),
    _Ember(x: 0.54, phase: 0.30, size: 3.0, speed: 1.0, kind: 0),
    _Ember(x: 0.62, phase: 0.62, size: 1.5, speed: 0.9, kind: 2),
    _Ember(x: 0.70, phase: 0.08, size: 2.4, speed: 1.15, kind: 0),
    _Ember(x: 0.78, phase: 0.48, size: 1.7, speed: 0.75, kind: 1),
    _Ember(x: 0.86, phase: 0.82, size: 3.2, speed: 1.05, kind: 0),
    _Ember(x: 0.94, phase: 0.25, size: 1.5, speed: 0.85, kind: 2),
    _Ember(x: 0.10, phase: 0.66, size: 2.0, speed: 1.25, kind: 0),
    _Ember(x: 0.34, phase: 0.12, size: 2.8, speed: 0.95, kind: 1),
    _Ember(x: 0.50, phase: 0.70, size: 1.3, speed: 1.1, kind: 2),
    _Ember(x: 0.66, phase: 0.35, size: 2.5, speed: 0.7, kind: 0),
    _Ember(x: 0.82, phase: 0.58, size: 1.9, speed: 1.2, kind: 1),
    _Ember(x: 0.90, phase: 0.95, size: 2.1, speed: 0.8, kind: 0),
    _Ember(x: 0.18, phase: 0.28, size: 3.6, speed: 1.0, kind: 0),
    _Ember(x: 0.42, phase: 0.88, size: 1.4, speed: 1.3, kind: 2),
    _Ember(x: 0.58, phase: 0.15, size: 2.7, speed: 0.9, kind: 0),
    _Ember(x: 0.74, phase: 0.50, size: 1.6, speed: 1.15, kind: 1),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EmberPainter(_controller.value, _embers),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Ember {
  const _Ember({
    required this.x,
    required this.phase,
    required this.size,
    required this.speed,
    required this.kind,
  });

  final double x;
  final double phase;
  final double size;
  final double speed;
  final int kind;
}

class _EmberPainter extends CustomPainter {
  const _EmberPainter(this.t, this.embers);

  final double t;
  final List<_Ember> embers;

  static const _palette = [
    Color(0xFFFF2A1A),
    Color(0xFFFF6B35),
    Color(0xFFFFC9C9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final progress = (t * e.speed + e.phase) % 1.0;
      final y = size.height * (1.05 - progress * 1.15);
      final sway = sin((progress + e.phase) * 2 * pi) * 18;
      final x = size.width * e.x + sway;
      final fade = sin(progress * pi);
      final alpha = (fade * 0.85).clamp(0.0, 1.0);
      final color = _palette[e.kind % _palette.length];

      final glow = Paint()
        ..color = color.withValues(alpha: alpha * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), e.size * 2.2, glow);

      final core = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(Offset(x, y), e.size, core);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter oldDelegate) => oldDelegate.t != t;
}
