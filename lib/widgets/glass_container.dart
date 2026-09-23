import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 24,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color = const Color(0x59000000),
    this.gradient,
    this.borderColor = const Color(0x2EFFFFFF),
    this.borderWidth = 1,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final double blur;
  final BorderRadius borderRadius;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
