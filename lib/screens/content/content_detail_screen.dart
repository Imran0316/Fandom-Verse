import 'package:flutter/material.dart';

import '../../core/auth_gate.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/bookmark_service.dart';
import '../../services/content_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/article_video.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/glass_button.dart';
import 'content_deep_dive.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/skeletons.dart';

class ContentDetailArgs {
  const ContentDetailArgs({required this.contentId, this.preview = false});

  final String contentId;
  final bool preview;
}

class ContentDetailScreen extends StatelessWidget {
  const ContentDetailScreen({
    super.key,
    required this.args,
    this.contentStream,
  });

  final ContentDetailArgs args;

  /// Test seam: defaults to the live content stream.
  final Stream<ContentDoc?>? contentStream;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<ContentDoc?>(
            stream: contentStream ??
                ContentService.instance.watchById(args.contentId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const _DetailSkeleton();
              }
              if (snap.hasError) {
                return _DetailError(
                  preview: args.preview,
                  message:
                      'This discovery isn’t available right now. It may have been unpublished.',
                );
              }
              final content = snap.data;
              if (content == null) {
                return _DetailError(
                  preview: args.preview,
                  message: args.preview
                      ? 'This content could not be loaded for preview.'
                      : 'This discovery may have been removed by the curators.',
                );
              }
              return _DetailBody(content: content, preview: args.preview);
            },
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.content, required this.preview});

  final ContentDoc content;
  final bool preview;

  void _openRelated(BuildContext context, ContentDoc related) {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.contentDetail,
      arguments: ContentDetailArgs(contentId: related.id, preview: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = content.videoUrl?.trim();
    return CustomScrollView(
      // BouncingScrollPhysics + a stretching SliverAppBar trigger an Android
      // overscroll bug that snaps the scroll position back to the top when
      // the user drags past either end of the page.
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: preview ? 240 : 280,
          pinned: true,
          stretch: false,
          backgroundColor: AppColors.backgroundDeep,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: LiquidGlass(
                radius: 999,
                blur: 18,
                padding: const EdgeInsets.all(8),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                ContentCover(
                  content: content,
                  aspectRatio: 1,
                  radius: 0,
                  iconSize: 52,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        AppColors.backgroundDeep,
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview) ...[
                  const _PreviewBanner(),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    ContentTypePill(type: content.type),
                    if (content.fandomName.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          content.fandomName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                if (content.summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    content.summary,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _MetaRow(content: content),
                const SizedBox(height: 20),
                const Divider(color: Color(0x1FFFFFFF), height: 1),
                const SizedBox(height: 22),
                if (videoUrl != null && videoUrl.isNotEmpty) ...[
                  ArticleVideo(url: videoUrl, posterUrl: content.coverImageUrl),
                  const SizedBox(height: 24),
                ],
                _ContentBody(content: content),
                if (content.tags.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in content.tags) _TagChip(label: tag),
                    ],
                  ),
                ],
                if (!preview) ...[
                  const SizedBox(height: 30),
                  _BookmarkButton(contentId: content.id),
                  const SizedBox(height: 34),
                  ContentDeepDive(content: content),
                ],
                const SizedBox(height: 34),
                _RelatedSection(
                  content: content,
                  onOpen: (c) => _openRelated(context, c),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, size: 17, color: Color(0xFFF59E0B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Preview — this is how fans see it once published.',
              style: TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.content});

  final ContentDoc content;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _MetaItem(
          icon: Icons.calendar_today_rounded,
          label: contentDateLabel(content.displayDate),
        ),
        if (content.categoryName.isNotEmpty)
          _MetaItem(
            icon: Icons.local_offer_rounded,
            label: content.categoryName,
          ),
        _MetaItem(
          icon: Icons.schedule_rounded,
          label: '${content.readingMinutes} min read',
        ),
        if (content.isTrending)
          const _MetaItem(icon: Icons.trending_up_rounded, label: 'Trending'),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.content});

  final ContentDoc content;

  @override
  Widget build(BuildContext context) {
    if (content.type.usesQuestion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.question.trim().isNotEmpty) ...[
            const Text(
              'QUESTION',
              style: _eyebrowStyle,
            ),
            const SizedBox(height: 8),
            Text(
              content.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (content.answer.trim().isNotEmpty) ...[
            const Text('ANSWER', style: _eyebrowStyle),
            const SizedBox(height: 8),
            LiquidGlass(
              radius: 16,
              blur: 18,
              padding: const EdgeInsets.all(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              child: Text(
                content.answer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (content.explanation.trim().isNotEmpty) ...[
            const Text('WHY IT MATTERS', style: _eyebrowStyle),
            const SizedBox(height: 8),
            Text(
              content.explanation,
              style: const TextStyle(
                color: Color(0xFFCFCFD6),
                fontSize: 15,
                height: 1.65,
              ),
            ),
          ],
        ],
      );
    }

    final paragraphs = content.body
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (paragraphs.isEmpty)
          const Text(
            'Full story coming soon.',
            style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
          )
        else
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                p.trim(),
                style: const TextStyle(
                  color: Color(0xFFD6D6DD),
                  fontSize: 15.5,
                  height: 1.7,
                ),
              ),
            ),
      ],
    );
  }
}

const _eyebrowStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
);

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({required this.contentId});

  final String contentId;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _busy = false;

  late final _savedIds = StreamCache<Set<String>>(
    () => BookmarkService.instance.watchMyContentIds(),
  );

  Future<void> _toggle() async {
    if (_busy) return;
    if (!requireSignIn(context, reason: 'Sign in to save discoveries.')) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await BookmarkService.instance.toggle(widget.contentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xE616161F),
            content: Text(
              saved ? 'Saved to your library' : 'Removed from saved',
            ),
          ),
        );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xE616161F),
            content: Text(e.message),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xE616161F),
            content: Text('Could not update your saved library. Try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _savedIds(),
      builder: (context, snap) {
        final saved = snap.data?.contains(widget.contentId) ?? false;
        return GlassButton(
          label: saved ? 'Saved' : 'Save for later',
          icon: saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_add_outlined,
          isLoading: _busy,
          variant: saved ? GlassButtonVariant.outline : GlassButtonVariant.primary,
          onPressed: _toggle,
        );
      },
    );
  }
}

class _RelatedSection extends StatefulWidget {
  const _RelatedSection({required this.content, required this.onOpen});

  final ContentDoc content;
  final ValueChanged<ContentDoc> onOpen;

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  late final _published = StreamCache<List<ContentDoc>>(
    () => ContentService.instance.watchPublished(),
  );

  List<ContentDoc> _related(List<ContentDoc> all) {
    final content = widget.content;
    final tags = content.tags.map((t) => t.toLowerCase()).toSet();
    final scored = <(int, ContentDoc)>[];
    for (final other in all) {
      if (other.id == content.id) continue;
      var score = 0;
      if (other.fandomId.isNotEmpty && other.fandomId == content.fandomId) {
        score += 3;
      }
      if (other.categoryId.isNotEmpty &&
          other.categoryId == content.categoryId) {
        score += 2;
      }
      score += other.tags
          .where((t) => tags.contains(t.toLowerCase()))
          .length;
      if (score > 0) scored.add((score, other));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.take(6).map((e) => e.$2).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentDoc>>(
      stream: _published(),
      builder: (context, snap) {
        final related = _related(snap.data ?? const []);
        if (related.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              title: 'Continue Exploring',
              subtitle: 'More from this universe',
            ),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const ClampingScrollPhysics(),
                itemCount: related.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => ContentRailCard(
                  content: related[i],
                  width: 176,
                  onTap: () => widget.onOpen(related[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.preview, required this.message});

  final bool preview;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: ContentEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Discovery unavailable',
        message: message,
        action: () => Navigator.of(context).maybePop(),
        actionLabel: preview ? 'Back to management' : 'Back',
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: const [
        SizedBox(height: 8),
        SkeletonBox(height: 240, radius: 22),
        SizedBox(height: 20),
        SkeletonBox(height: 14, width: 120),
        SizedBox(height: 14),
        SkeletonBox(height: 26),
        SizedBox(height: 10),
        SkeletonBox(height: 26, width: 220),
        SizedBox(height: 22),
        SkeletonBox(height: 13),
        SizedBox(height: 10),
        SkeletonBox(height: 13),
        SizedBox(height: 10),
        SkeletonBox(height: 13, width: 260),
      ],
    );
  }
}
