import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Horizontal pager with page dots, sized to a fixed height.
class FixedPager extends StatefulWidget {
  const FixedPager({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.viewportFraction = 0.92,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double viewportFraction;

  @override
  State<FixedPager> createState() => _FixedPagerState();
}

class _FixedPagerState extends State<FixedPager> {
  late final PageController _controller = PageController(
    viewportFraction: widget.viewportFraction,
  );
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final page = _controller.page?.round() ?? 0;
      if (page != _page && mounted) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.itemCount,
              padEnds: true,
              itemBuilder: (context, index) {
                final active = index == _page;
                return AnimatedScale(
                  scale: active ? 1 : 0.94,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: widget.itemBuilder(context, index),
                );
              },
            ),
          ),
          if (widget.itemCount > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.itemCount, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
