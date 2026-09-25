import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../models/user_profile.dart';
import '../../services/content_service.dart';
import '../../services/taxonomy_service.dart';
import '../../services/user_service.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/fixed_pager.dart';
import '../../widgets/skeletons.dart';
import 'content_detail_screen.dart';
import 'explore_screen.dart';

/// Fan Home discovery surface. Every section comes from Firestore and only
/// renders when it has real data — drafts are never included.
class DiscoveryHome extends StatelessWidget {
  const DiscoveryHome({super.key});

  void _openContent(BuildContext context, ContentDoc content) {
    Navigator.pushNamed(
      context,
      AppRoutes.contentDetail,
      arguments: ContentDetailArgs(contentId: content.id),
    );
  }

  void _openExplore(BuildContext context, {String? fandomId, ContentType? type}) {
    Navigator.pushNamed(
      context,
      AppRoutes.explore,
      arguments: ExploreArgs(fandomId: fandomId, type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentDoc>>(
      stream: ContentService.instance.watchPublished(),
      builder: (context, contentSnap) {
        final published = contentSnap.data ?? const <ContentDoc>[];
        return StreamBuilder<List<FandomDoc>>(
          stream: TaxonomyService.instance.watchFandoms(),
          builder: (context, fandomSnap) {
            final fandoms = fandomSnap.data ?? const <FandomDoc>[];

            final featured = published.where((c) => c.isFeatured).toList();
            final trending = published.where((c) => c.isTrending).toList();
            final latest = published.take(8).toList();

            // Still loading the first payload.
            if (!contentSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    ContentRailSkeleton(),
                    SizedBox(height: 28),
                    ContentRailSkeleton(height: 150),
                  ],
                ),
              );
            }

            if (contentSnap.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ContentErrorState(
                  message:
                      'We couldn’t load discoveries right now. Pull the page again in a moment.',
                ),
              );
            }

            if (published.isEmpty && fandoms.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: ContentEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'No discoveries yet',
                  message: 'New fandom content will appear here soon.',
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (featured.isNotEmpty) ...[
                  FixedPager(
                    height: 348,
                    itemCount: featured.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FeaturedSpotlight(
                        content: featured[i],
                        onTap: () => _openContent(context, featured[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                if (fandoms.isNotEmpty) ...[
                  SectionHeading(
                    title: 'Trending Fandoms',
                    subtitle: 'The universes fans are exploring',
                    onExplore: () => _openExplore(context),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: fandoms.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final fandom = fandoms[i];
                        final count = published
                            .where((c) => c.fandomId == fandom.id)
                            .length;
                        return FandomRailCard(
                          fandom: fandom,
                          count: count,
                          onTap: () =>
                              _openExplore(context, fandomId: fandom.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                if (latest.isNotEmpty) ...[
                  SectionHeading(
                    title: 'Latest Discoveries',
                    subtitle: 'Freshly published for your fandoms',
                    onExplore: () => _openExplore(context),
                  ),
                  SizedBox(
                    height: 214,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: latest.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => ContentRailCard(
                        content: latest[i],
                        onTap: () => _openContent(context, latest[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                if (trending.isNotEmpty) ...[
                  SectionHeading(
                    title: 'Trending Now',
                    subtitle: 'Curated by the FandomVerse editors',
                    onExplore: () => _openExplore(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final c in trending.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ContentRow(
                              content: c,
                              onTap: () => _openContent(context, c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                _ExploreYourFandoms(
                  published: published,
                  fandoms: fandoms,
                  onOpen: (c) => _openContent(context, c),
                  onExplore: (fandomId) =>
                      _openExplore(context, fandomId: fandomId),
                ),
                _DeepDive(
                  published: published,
                  featuredIds: featured.map((c) => c.id).toSet(),
                  onOpen: (c) => _openContent(context, c),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ExploreYourFandoms extends StatelessWidget {
  const _ExploreYourFandoms({
    required this.published,
    required this.fandoms,
    required this.onOpen,
    required this.onExplore,
  });

  final List<ContentDoc> published;
  final List<FandomDoc> fandoms;
  final ValueChanged<ContentDoc> onOpen;
  final ValueChanged<String> onExplore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchCurrent(),
      builder: (context, snap) {
        final selected = snap.data?.selectedFandoms ?? const <String>[];
        if (selected.isEmpty || fandoms.isEmpty) {
          return const SizedBox.shrink();
        }
        final names = selected.map((s) => s.toLowerCase()).toSet();
        final matches = fandoms.where(
          (f) =>
              names.contains(f.name.toLowerCase()) ||
              names.any((n) => f.name.toLowerCase().contains(n)),
        );
        final matchIds = matches.map((f) => f.id).toSet();
        final items = published
            .where((c) => matchIds.contains(c.fandomId))
            .take(8)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: 'Explore Your Fandoms',
              subtitle: 'Picked from the interests you chose',
              onExplore: () => Navigator.pushNamed(context, AppRoutes.explore),
            ),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => ContentRailCard(
                  content: items[i],
                  onTap: () => onOpen(items[i]),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _DeepDive extends StatelessWidget {
  const _DeepDive({
    required this.published,
    required this.featuredIds,
    required this.onOpen,
  });

  final List<ContentDoc> published;
  final Set<String> featuredIds;
  final ValueChanged<ContentDoc> onOpen;

  @override
  Widget build(BuildContext context) {
    final candidates = published
        .where(
          (c) =>
              (c.type == ContentType.lore || c.type == ContentType.article) &&
              !featuredIds.contains(c.id),
        )
        .toList();
    if (candidates.isEmpty) return const SizedBox.shrink();

    final pick = candidates.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          title: 'Deep Dive',
          subtitle: 'One long read worth your time',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => onOpen(pick),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentCover(content: pick, aspectRatio: 16 / 9, radius: 20),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ContentTypePill(type: pick.type),
                    const SizedBox(width: 10),
                    Text(
                      pick.fandomName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  pick.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (pick.teaser.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    pick.teaser,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
