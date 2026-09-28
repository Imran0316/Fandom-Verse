import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_catalog.dart';
import '../../models/catalog_docs.dart';
import '../../models/community_docs.dart';
import '../../models/post_docs.dart';
import '../../models/reel_docs.dart';
import '../../services/community_service.dart';
import '../../services/event_service.dart';
import '../../services/post_service.dart';
import '../../services/reel_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';
import '../reels/reels_tab.dart' show formatCount;

/// The Trending tab (nav index 1): a live mix of hot fan posts, community
/// reels, rising communities and upcoming events — ranked client-side so no
/// composite Firestore indexes are required.
///
/// All streams are injectable for tests; onOpenReels jumps to the Reels tab.
class TrendingTab extends StatefulWidget {
  const TrendingTab({
    super.key,
    this.onOpenReels,
    this.postsStream,
    this.reelsStream,
    this.communitiesStream,
    this.eventsStream,
  });

  final VoidCallback? onOpenReels;
  final Stream<List<PostDoc>>? postsStream;
  final Stream<List<ReelDoc>>? reelsStream;
  final Stream<List<CommunityDoc>>? communitiesStream;
  final Stream<List<FandomEventDoc>>? eventsStream;

  @override
  State<TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<TrendingTab> {
  late final _posts = StreamCache<List<PostDoc>>(
    () => widget.postsStream ?? PostService.instance.watchFeed(limit: 40),
  );
  late final _reels = StreamCache<List<ReelDoc>>(
    () => widget.reelsStream ?? ReelService.instance.watchLatest(limit: 12),
  );
  late final _communities = StreamCache<List<CommunityDoc>>(
    () => widget.communitiesStream ?? CommunityService.instance.watchAll(),
  );
  late final _events = StreamCache<List<FandomEventDoc>>(
    () => widget.eventsStream ?? EventService.instance.watchUpcoming(),
  );

  static int _heat(PostDoc p) => p.likeCount + p.commentCount * 2;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        _header(),
        _hotPosts(),
        _reelsRail(),
        _risingCommunities(),
        _eventsSection(),
        _quietFallback(),
      ],
    );
  }

  /* --------------------------------- Header -------------------------------- */

  Widget _header() {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5C4D), Color(0xFF7F1D1D)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trending Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'What the verse is buzzing about — updated live',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ------------------------------ Hot posts ------------------------------- */

  Widget _hotPosts() {
    return StreamBuilder<List<PostDoc>>(
      stream: _posts(),
      builder: (context, snap) {
        if (!snap.hasData) return const _SectionSkeleton(height: 118);
        final posts = [...?snap.data]..sort((a, b) => _heat(b).compareTo(_heat(a)));
        final top = posts.take(5).toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: 'Fan posts on fire',
              icon: Icons.whatshot_rounded,
              actionLabel: 'See all',
              onAction: () => Navigator.pushNamed(context, AppRoutes.feed),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < top.length; i++)
                    FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                      child: _HotPostCard(
                        rank: i + 1,
                        post: top[i],
                        heat: _heat(top[i]),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.feed),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /* ------------------------------ Reels rail ------------------------------ */

  Widget _reelsRail() {
    return StreamBuilder<List<ReelDoc>>(
      stream: _reels(),
      builder: (context, snap) {
        if (!snap.hasData) return const _SectionSkeleton(height: 210);
        final reels = (snap.data ?? const <ReelDoc>[])
            .where((r) => r.videoUrl.isNotEmpty)
            .take(8)
            .toList();
        if (reels.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: 'Reels on fire',
              icon: Icons.play_circle_rounded,
              actionLabel: 'Watch',
              onAction: widget.onOpenReels ?? () {},
            ),
            SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: _ReelMiniCard(
                    reel: reels[i],
                    onTap: widget.onOpenReels ?? () {},
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /* -------------------------- Rising communities -------------------------- */

  Widget _risingCommunities() {
    return StreamBuilder<List<CommunityDoc>>(
      stream: _communities(),
      builder: (context, snap) {
        if (!snap.hasData) return const _SectionSkeleton(height: 132);
        final communities = [...?snap.data]
          ..sort((a, b) => b.memberCount.compareTo(a.memberCount));
        final top = communities.take(6).toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: 'Rising communities',
              icon: Icons.trending_up_rounded,
              actionLabel: 'Browse',
              onAction: () =>
                  Navigator.pushNamed(context, AppRoutes.communities),
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: _RisingCommunityCard(
                    rank: i + 1,
                    community: top[i],
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.communityDetail,
                      arguments: top[i].id,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /* -------------------------------- Events --------------------------------- */

  Widget _eventsSection() {
    return StreamBuilder<List<FandomEventDoc>>(
      stream: _events(),
      builder: (context, snap) {
        if (!snap.hasData) return const _SectionSkeleton(height: 84);
        final events = (snap.data ?? const <FandomEventDoc>[]).take(4).toList();
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: 'Events on the horizon',
              icon: Icons.event_rounded,
              actionLabel: 'All events',
              onAction: () => Navigator.pushNamed(context, AppRoutes.events),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++)
                    FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                      child: _EventTrendRow(
                        event: events[i],
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.eventDetail,
                          arguments: events[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /* ----------------------------- Quiet fallback --------------------------- */

  /// Renders only when every live stream has reported an empty list — keeps
  /// the tab lively before the first post/reel exists.
  Widget _quietFallback() {
    return StreamBuilder<List<PostDoc>>(
      stream: _posts(),
      builder: (context, s1) {
        return StreamBuilder<List<ReelDoc>>(
          stream: _reels(),
          builder: (context, s2) {
            return StreamBuilder<List<CommunityDoc>>(
              stream: _communities(),
              builder: (context, s3) {
                return StreamBuilder<List<FandomEventDoc>>(
                  stream: _events(),
                  builder: (context, s4) {
                    bool quiet(AsyncSnapshot<Object?> s) =>
                        s.hasData && (s.data as List?)?.isEmpty == true;
                    if (!(quiet(s1) && quiet(s2) && quiet(s3) && quiet(s4))) {
                      return const SizedBox.shrink();
                    }
                    return _QuietVerseCard(
                      onOpenFeed: () =>
                          Navigator.pushNamed(context, AppRoutes.feed),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/* --------------------------------- Pieces -------------------------------- */

class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(
              '$actionLabel ›',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotPostCard extends StatelessWidget {
  const _HotPostCard({
    required this.rank,
    required this.post,
    required this.heat,
    required this.onTap,
  });

  final int rank;
  final PostDoc post;
  final int heat;
  final VoidCallback onTap;

  Color get _medal {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFD97706);
      default:
        return Colors.white.withValues(alpha: 0.30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = post.body.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: LiquidGlass(
          radius: 18,
          blur: 0,
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderColor: rank <= 3
              ? _medal.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.10),
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _medal.withValues(alpha: 0.18),
                  border: Border.all(color: _medal, width: 1.4),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: _medal,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body.isEmpty ? 'Community buzz' : body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            post.authorName.isEmpty ? 'Fan' : post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (post.communityName != null &&
                            post.communityName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppColors.accent.withValues(alpha: 0.16),
                            ),
                            child: Text(
                              post.communityName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: Color(0xFFF97316),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$heat heat',
                          style: const TextStyle(
                            color: Color(0xFFF97316),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
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

class _ReelMiniCard extends StatelessWidget {
  const _ReelMiniCard({required this.reel, required this.onTap});

  final ReelDoc reel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = const [
      Color(0xFF9F1239),
      Color(0xFF1E3A5F),
      Color(0xFF064E3B),
      Color(0xFF7C3AED),
    ];
    final color = palette[reel.id.hashCode.abs() % palette.length];

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.35)],
                  ),
                ),
              ),
              if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
                Image.network(
                  reel.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xE6000000)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white70,
                  size: 34,
                ),
              ),
              Positioned(
                left: 9,
                right: 9,
                bottom: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.accent,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(reel.likeCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reel.caption.isEmpty ? 'Community reel' : reel.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
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

class _RisingCommunityCard extends StatelessWidget {
  const _RisingCommunityCard({
    required this.rank,
    required this.community,
    required this.onTap,
  });

  final int rank;
  final CommunityDoc community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 168,
        child: LiquidGlass(
          radius: 18,
          blur: 0,
          gradient: LinearGradient(
            colors: [
              community.color.withValues(alpha: 0.34),
              community.color.withValues(alpha: 0.10),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.16),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.25),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      community.icon,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                community.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 13,
                    color: Color(0xFF4ADE80),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${formatCount(community.memberCount)} followers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTrendRow extends StatelessWidget {
  const _EventTrendRow({required this.event, required this.onTap});

  final FandomEventDoc event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = event.dateLabel.split(' ');
    final month = parts.isNotEmpty ? parts.first : '';
    final day = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: LiquidGlass(
          radius: 16,
          blur: 0,
          gradient: LinearGradient(
            colors: [
              event.color.withValues(alpha: 0.26),
              event.color.withValues(alpha: 0.07),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.12),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Colors.black.withValues(alpha: 0.30),
                  border: Border.all(color: Colors.white24),
                ),
                child: day.isEmpty
                    ? Icon(event.icon, color: event.color, size: 20)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            month.toUpperCase(),
                            style: TextStyle(
                              color: event.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            day,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 15,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietVerseCard extends StatelessWidget {
  const _QuietVerseCard({required this.onOpenFeed});

  final VoidCallback onOpenFeed;

  @override
  Widget build(BuildContext context) {
    final items = MockCatalog.recommended.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidGlass(
            radius: 22,
            blur: 0,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C4D), Color(0xFF7F1D1D)],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The verse is warming up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nothing is trending yet — drop the first post and '
                            'heat things up.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final item in items)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.colors,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.emoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.tag,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: 'Open the fan feed',
            variant: GlassButtonVariant.outline,
            height: 48,
            icon: Icons.article_rounded,
            onPressed: onOpenFeed,
          ),
        ],
      ),
    );
  }
}
