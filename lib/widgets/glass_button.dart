import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'liquid_glass.dart';

enum GlassButtonVariant { primary, outline, sleek }

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? height;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == GlassButtonVariant.primary;
    final isSleek = widget.variant == GlassButtonVariant.sleek;
    final height = widget.height ?? (isSleek ? 52 : 58);

    final label = Text(
      widget.label,
      style: TextStyle(
        color: Colors.white,
        fontSize: isSleek ? 16 : (isPrimary ? 17 : 15.5),
        fontWeight: isSleek ? FontWeight.w600 : FontWeight.w800,
        letterSpacing: isSleek ? -0.1 : 0.4,
      ),
    );

    final child = isPrimary ? _PrimaryButtonContent(label: label, isLoading: widget.isLoading, icon: widget.icon) : Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 19, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: label),
          ),
        ],
      ],
    );

    final Widget surface;
    if (isPrimary) {
      surface = child;
    } else if (isSleek) {
      surface = LiquidGlass(
        radius: 999,
        blur: 16,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: child,
      );
    } else {
      surface = GlassContainer(
        blur: 20,
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.3),
        child: child,
      );
    }

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: _pressed ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: _enabled ? 1 : (isSleek ? 0.45 : 0.55),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: surface,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButtonContent extends StatelessWidget {
  const _PrimaryButtonContent({
    required this.label,
    required this.isLoading,
    this.icon,
  });

  final Text label;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5C4D), Color(0xFFC1121F), Color(0xFF7F1D1D)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF7F1D1D).withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Specular sheen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.32),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Soft top-left glow
          Positioned(
            top: -30,
            left: -20,
            child: Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: label,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
