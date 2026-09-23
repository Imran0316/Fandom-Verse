import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = 28,
    this.tint = const Color(0xB30A0A10),
    this.borderColor,
    this.gradient,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color tint;
  final Gradient? gradient;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? Colors.white.withValues(alpha: 0.14);

    return Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: gradient == null ? tint : null,
            gradient: gradient,
          ),
          child: child,
        ),
      ),
    );
  }
}

class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({
    super.key,
    required this.child,
    this.radius = 999,
    this.blur = 30,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: radius,
      blur: blur,
      padding: padding,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.07),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.06),
          blurRadius: 0,
          offset: const Offset(0, 1),
        ),
      ],
      child: child,
    );
  }
}
