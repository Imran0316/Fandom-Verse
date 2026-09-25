import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/content_docs.dart';
import 'liquid_glass.dart';

/* --------------------------------- Helpers -------------------------------- */

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String contentDateLabel(DateTime? date) {
  if (date == null) return 'Unpublished';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/* -------------------------------- Surfaces -------------------------------- */

/// Cover image with amber-free placeholder + graceful error handling.
class ContentCover extends StatelessWidget {
  const ContentCover({
    super.key,
    required this.content,
    this.aspectRatio = 16 / 9,
    this.radius = 18,
    this.iconSize = 30,
  });

  final ContentDoc content;
  final double aspectRatio;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = content.coverImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: (url == null || url.isEmpty)
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _fallback(loading: true);
                },
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback({bool loading = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241016), Color(0xFF14141D)],
        ),
      ),
      child: Center(
        child: Icon(
          content.type.icon,
          color: Colors.white.withValues(alpha: loading ? 0.18 : 0.32),
          size: iconSize,
        ),
      ),
    );
  }
}

class ContentTypePill extends StatelessWidget {
  const ContentTypePill({super.key, required this.type, this.compact = false});

  final ContentType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFF9F0A12)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: compact ? 10 : 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            type.label.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ContentStatus status;

  @override
  Widget build(BuildContext context) {
    final published = status.isPublished;
    final color = published ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class FlagChip extends StatelessWidget {
  const FlagChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------- Section UI ------------------------------- */

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.onExplore,
    this.exploreLabel = 'Explore all',
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onExplore;
  final String exploreLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onExplore != null)
            TextButton(
              onPressed: onExplore,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exploreLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 15),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Premium, reusable empty state.
class ContentEmptyState extends StatelessWidget {
  const ContentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlass(
              radius: 26,
              blur: 22,
              padding: const EdgeInsets.all(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: action,
                child: LiquidGlassPill(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly, exception-free error state.
class ContentErrorState extends StatelessWidget {
  const ContentErrorState({super.key, this.onRetry, this.message});

  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ContentEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load discoveries',
      message:
          message ??
          'Check your connection and try again. Your fandoms will be waiting.',
      action: onRetry,
      actionLabel: onRetry == null ? null : 'Try again',
    );
  }
}

/* ------------------------------ Featured hero ----------------------------- */

/// Large editorial spotlight for featured content.
class FeaturedSpotlight extends StatelessWidget {
  const FeaturedSpotlight({
    super.key,
    required this.content,
    required this.onTap,
  });

  final ContentDoc content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              ContentCover(
                content: content,
                aspectRatio: 4 / 3,
                radius: 0,
                iconSize: 46,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.25, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ContentTypePill(type: content.type),
                        if (content.fandomName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              content.fandomName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (content.teaser.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        content.teaser,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Read Discovery',
                                style: TextStyle(
                                  color: Color(0xFF0A0A0F),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 15,
                                color: Color(0xFF0A0A0F),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------------- Rails ---------------------------------- */

/// Cover-first card used in horizontal discovery rails.
class ContentRailCard extends StatelessWidget {
  const ContentRailCard({
    super.key,
    required this.content,
    required this.onTap,
    this.width = 200,
  });

  final ContentDoc content;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ContentCover(content: content, radius: 18),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ContentTypePill(type: content.type, compact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              [
                if (content.fandomName.isNotEmpty) content.fandomName,
                if (content.categoryName.isNotEmpty) content.categoryName,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FandomRailCard extends StatelessWidget {
  const FandomRailCard({
    super.key,
    required this.fandom,
    required this.onTap,
    this.count,
  });

  final FandomDoc fandom;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = fandom.color;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.55),
                  color.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (fandom.coverImageUrl?.isNotEmpty == true)
                  Image.network(
                    fandom.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                if (fandom.coverImageUrl?.isNotEmpty == true)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Icon(fandom.icon, color: Colors.white, size: 22),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fandom.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count == null
                            ? 'Discover'
                            : '$count ${count == 1 ? 'discovery' : 'discoveries'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------- List row variations -------------------------- */

/// Dispatches to a type-specific row so the content type reads at a glance.
class ContentRow extends StatelessWidget {
  const ContentRow({
    super.key,
    required this.content,
    required this.onTap,
    this.trailing,
  });

  final ContentDoc content;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    switch (content.type) {
      case ContentType.news:
        return _NewsRow(content: content, onTap: onTap, trailing: trailing);
      case ContentType.trivia:
        return _TriviaRow(content: content, onTap: onTap, trailing: trailing);
      case ContentType.article:
      case ContentType.lore:
        return _EditorialRow(
          content: content,
          onTap: onTap,
          trailing: trailing,
        );
    }
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: child,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final text = parts.where((p) => p.isNotEmpty).join(' · ');
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EditorialRow extends StatelessWidget {
  const _EditorialRow({
    required this.content,
    required this.onTap,
    this.trailing,
  });

  final ContentDoc content;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: ContentCover(content: content, aspectRatio: 1, radius: 14),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${content.type.label.toUpperCase()}'
                  '${content.categoryName.isEmpty ? '' : ' · ${content.categoryName.toUpperCase()}'}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaLine(
                  parts: [
                    content.fandomName,
                    contentDateLabel(content.displayDate),
                    '${content.readingMinutes} min read',
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.content, required this.onTap, this.trailing});

  final ContentDoc content;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: ContentCover(content: content, aspectRatio: 1, radius: 12),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.newspaper_rounded,
                      size: 12,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'NEWS${content.fandomName.isEmpty ? '' : ' · ${content.fandomName.toUpperCase()}'}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaLine(
                  parts: [
                    contentDateLabel(content.displayDate),
                    if (content.tags.isNotEmpty) '#${content.tags.first}',
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _TriviaRow extends StatelessWidget {
  const _TriviaRow({required this.content, required this.onTap, this.trailing});

  final ContentDoc content;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE50914).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFE50914).withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.quiz_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'TRIVIA${content.fandomName.isEmpty ? '' : ' · ${content.fandomName.toUpperCase()}'}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (content.question.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“${content.question}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _MetaLine(
                    parts: [
                      contentDateLabel(content.displayDate),
                      'Tap to reveal',
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}
