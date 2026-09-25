import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Text clamped to [maxLines] that shows a "See More" toggle — but only when
/// the content actually overflows. Tapping expands to the full text (and
/// back again with "See Less").
class ExpandableText extends StatefulWidget {
  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.style,
    this.toggleColor = AppColors.accent,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;
  final Color toggleColor;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  bool _overflows(BuildContext context, double maxWidth, TextStyle style) {
    if (!maxWidth.isFinite || maxWidth <= 0 || widget.text.isEmpty) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines > widget.maxLines;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = widget.style ?? DefaultTextStyle.of(context).style;
        final showToggle = _expanded || _overflows(context, constraints.maxWidth, style);
        final clamped = showToggle && !_expanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: clamped ? widget.maxLines : null,
              overflow: clamped ? TextOverflow.ellipsis : null,
            ),
            if (showToggle)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _expanded ? 'See Less' : 'See More',
                    style: TextStyle(
                      color: widget.toggleColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
