import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidSegmentedControl extends StatefulWidget {
  const LiquidSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  State<LiquidSegmentedControl> createState() =>
      _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _thumbPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  int _lastIndex = 0;

  @override
  void didUpdateWidget(LiquidSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _lastIndex = oldWidget.selectedIndex;
      _thumbPulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _thumbPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.labels.length;
    if (count == 0) return const SizedBox.shrink();

    const spring = Cubic(0.34, 1.4, 0.44, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final segmentWidth = trackWidth / count;
        final thumbWidth = segmentWidth - 8;
        final thumbLeft = 4.0 + (widget.selectedIndex * segmentWidth);

        return Container(
          height: 48,
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x2EFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: spring,
                    left: thumbLeft,
                    top: 4,
                    bottom: 4,
                    width: thumbWidth,
                    child: AnimatedBuilder(
                      animation: _thumbPulse,
                      builder: (context, child) {
                        final t = _thumbPulse.value;
                        final bounce =
                            1 + 0.04 * (1 - Curves.easeOutBack.transform(t));
                        final dir = widget.selectedIndex - _lastIndex;
                        final shift =
                            6.0 * dir * (1 - Curves.easeOut.transform(t));
                        return Transform.translate(
                          offset: Offset(shift, 0),
                          child: Transform.scale(
                            scale: bounce,
                            child: child,
                          ),
                        );
                      },
                      child: _LiquidThumb(),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: List.generate(count, (i) {
                        final selected = i == widget.selectedIndex;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onIndexChanged(i),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                ),
                                child: Text(widget.labels[i]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiquidThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4D4D), Color(0xFFC1121F), Color(0xFF7F1D1D)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
