import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

/// App-wide page routes with smooth glass-style transitions.
abstract final class AppTransitions {
  static const _curve = Curves.easeOutCubic;
  static const _dur = Duration(milliseconds: 380);

  static Route<T> fadeSlide<T>(Widget page, {RouteSettings? settings}) {
    return PageTransition<T>(
      child: page,
      type: PageTransitionType.fade,
      duration: _dur,
      curve: _curve,
      settings: settings,
    );
  }

  static Route<T> rightToLeft<T>(Widget page, {RouteSettings? settings}) {
    return PageTransition<T>(
      child: page,
      type: PageTransitionType.rightToLeft,
      duration: _dur,
      curve: _curve,
      settings: settings,
    );
  }

  static Route<T> scaleFade<T>(Widget page, {RouteSettings? settings}) {
    return PageTransition<T>(
      child: page,
      type: PageTransitionType.scale,
      alignment: Alignment.center,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      settings: settings,
    );
  }

  static Route<T> bottomUp<T>(Widget page, {RouteSettings? settings}) {
    return PageTransition<T>(
      child: page,
      type: PageTransitionType.bottomToTop,
      duration: const Duration(milliseconds: 400),
      curve: _curve,
      settings: settings,
    );
  }
}

/// Staggered fade-in for list / form children.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Simple pulse used when Lottie asset is unavailable.
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    this.size = 72,
    this.color = const Color(0xFFE50914),
  });

  final double size;
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size * (0.85 + 0.15 * t),
          height: widget.size * (0.85 + 0.15 * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.2 + 0.25 * t),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 * t),
                blurRadius: 28 * t + 8,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: widget.color,
            size: widget.size * 0.4,
          ),
        );
      },
    );
  }
}
