import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../models/content_docs.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/fixed_pager.dart';
import '../../widgets/skeletons.dart';
import 'content_detail_screen.dart';
import 'explore_screen.dart';

/// Individual Home sections (Discovery, Trending Fandoms, Trending News,
/// Latest Discoveries). Each is self-contained so `_HomeTab` can compose the
/// full page order. Only renders real published content — drafts are never
/// included.

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

/// 1. Discovery — immersive editorial feature at the very top of Home.
class DiscoveryFeatureSection extends StatelessWidget {
  const DiscoveryFeatureSection({super.key, required this.stream});

  final Stream<List<ContentDoc>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentDoc>>(
      stream: stream,
      builder: (context, snap) {
        // Error first: an errored snapshot carries no data, so checking
        // `!hasData` alone made the error branch unreachable and a failed
        // stream sat on an endless skeleton with no message. Stale data from
        // a dropped connection still renders below instead of an error.
        if (snap.hasError && snap.data == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ContentErrorState(
              message:
                  'We couldn’t load discoveries right now. Pull the page again '
                  'in a moment.',
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ContentRailSkeleton(height: 320),
          );
        }

        final published = snap.data ?? const <ContentDoc>[];
        if (published.isEmpty) return const SizedBox.shrink();

        // Featured stories first; otherwise the newest story leads.
        final featured = published.where((c) => c.isFeatured).toList();
        final lead = featured.isNotEmpty
            ? featured
            : published.take(1).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixedPager(
              height: 348,
              itemCount: lead.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FeaturedSpotlight(
                  content: lead[i],
                  onTap: () => _openContent(context, lead[i]),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

/// 2. Trending Fandoms — horizontal visual rail ordered by content volume.
class TrendingFandomsSection extends StatelessWidget {
  const TrendingFandomsSection({
    super.key,
    required this.stream,
    required this.fandomStream,
  });

  final Stream<List<ContentDoc>> stream;
  final Stream<List<FandomDoc>> fandomStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FandomDoc>>(
      stream: fandomStream,
      builder: (context, fandomSnap) {
        final fandoms = fandomSnap.data ?? const <FandomDoc>[];
        if (!fandomSnap.hasData || fandoms.isEmpty) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<List<ContentDoc>>(
          stream: stream,
          builder: (context, contentSnap) {
            final published = contentSnap.data ?? const <ContentDoc>[];

            final counts = <String, int>{for (final f in fandoms) f.id: 0};
            for (final c in published) {
              counts[c.fandomId] = (counts[c.fandomId] ?? 0) + 1;
            }
            final ordered = [
              ...fandoms,
            ]..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    itemCount: ordered.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final fandom = ordered[i];
                      return FandomRailCard(
                        fandom: fandom,
                        count: counts[fandom.id],
                        onTap: () => _openExplore(context, fandomId: fandom.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }
}

/// 4. Trending News — editorial list of news + trending stories.
class TrendingNewsSection extends StatelessWidget {
  const TrendingNewsSection({super.key, required this.stream});

  final Stream<List<ContentDoc>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentDoc>>(
      stream: stream,
      builder: (context, snap) {
        final published = snap.data ?? const <ContentDoc>[];
        final news =
            published
                .where((c) => c.type == ContentType.news || c.isTrending)
                .toList()
              ..sort((a, b) {
                final aNews = a.type == ContentType.news ? 1 : 0;
                final bNews = b.type == ContentType.news ? 1 : 0;
                if (aNews != bNews) return bNews.compareTo(aNews);
                final da =
                    a.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
                final db =
                    b.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
                return db.compareTo(da);
              });
        final items = news.take(5).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: 'Trending News',
              subtitle: 'Editorial picks moving the fandoms',
              onExplore: () => _openExplore(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final c in items)
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
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/// 7. Latest Discoveries — visual content rail of the freshest stories.
class LatestDiscoveriesSection extends StatelessWidget {
  const LatestDiscoveriesSection({super.key, required this.stream});

  final Stream<List<ContentDoc>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentDoc>>(
      stream: stream,
      builder: (context, snap) {
        final latest = (snap.data ?? const <ContentDoc>[]).take(8).toList();
        if (latest.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
        );
      },
    );
  }
}
