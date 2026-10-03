import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/pkr_format.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../models/content_docs.dart';
import '../../models/community_docs.dart';
import '../../models/notification_docs.dart';
import '../../models/post_docs.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/content_service.dart';
import '../../services/community_service.dart';
import '../../services/explore_prompt_service.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../services/taxonomy_service.dart';
import '../../services/user_service.dart';
import '../../widgets/auth_popup.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_floating_nav.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/content_widgets.dart';
import '../communities/post_card.dart';
import '../content/content_detail_screen.dart';
import '../content/discovery_sections.dart';
import '../reels/reels_tab.dart';
import 'trending_tab.dart';

String _normalizeFandomKey(String? value) => (value ?? '').trim().toLowerCase();

List<ContentDoc> buildRecommendedContentForUser(
  UserProfile? profile,
  List<ContentDoc> published,
) {
  final items = published
      .where((item) => item.isPublished && item.title.trim().isNotEmpty)
      .toList();

  if (items.isEmpty) return const <ContentDoc>[];

  final selected = (profile?.selectedFandoms ?? const <String>[])
      .map(_normalizeFandomKey)
      .where((value) => value.isNotEmpty)
      .toSet();

  List<ContentDoc> ranked;
  if (selected.isNotEmpty) {
    final matches = items.where((item) {
      final keys = <String>{
        _normalizeFandomKey(item.fandomName),
        _normalizeFandomKey(item.fandomId),
      };
      return keys.any(
        (key) =>
            key.isNotEmpty &&
            selected.any(
              (interest) =>
                  key == interest ||
                  key.contains(interest) ||
                  interest.contains(key),
            ),
      );
    }).toList();
    ranked = matches.isNotEmpty ? matches : items;
  } else {
    ranked = items;
  }

  ranked.sort((a, b) {
    final scoreA =
        (a.isFeatured ? 8 : 0) +
        (a.isTrending ? 6 : 0) +
        (a.publishedAt != null ? 4 : 0);
    final scoreB =
        (b.isFeatured ? 8 : 0) +
        (b.isTrending ? 6 : 0) +
        (b.publishedAt != null ? 4 : 0);

    if (scoreA != scoreB) return scoreB.compareTo(scoreA);
    final dateA = a.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });

  return ranked.take(6).toList();
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final Set<int> _builtTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    // If Firebase finishes initializing after this screen (and its cached
    // tab streams) were built, rebuild so every tab re-subscribes with live
    // Firestore streams instead of the empty not-ready fallbacks.
    AuthService.readyListenable.addListener(_onFirebaseReadyChanged);
    // Start the explore prompt timer for signed-out users.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ExplorePromptService.setContext(context);
        ExplorePromptService.instance.start();
      }
    });
  }

  @override
  void dispose() {
    AuthService.readyListenable.removeListener(_onFirebaseReadyChanged);
    ExplorePromptService.clearContext();
    super.dispose();
  }

  void _onFirebaseReadyChanged() {
    if (mounted) setState(() {});
  }

  void _onSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _builtTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stack(
            children: [
              // Ambient red wash
              const Positioned(
                top: -120,
                left: -40,
                right: -40,
                height: 340,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1,
                      colors: [Color(0x55E50914), Colors.transparent],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: _currentIndex,
                  // Deliberately non-const: a const child is canonicalized,
                  // so Element.updateChild skips it on parent rebuilds and
                  // the tab would keep the streams of its first build
                  // forever. Fresh instances let a readiness flip (or a
                  // tab switch) re-run each tab's build and re-subscribe.
                  // Unvisited slots stay as placeholders so tab indexes
                  // never shift.
                  children: [
                    if (_builtTabs.contains(0))
                      _HomeTab()
                    else
                      const SizedBox.shrink(),
                    if (_builtTabs.contains(1))
                      TrendingTab(onOpenReels: () => _onSelected(3))
                    else
                      const SizedBox.shrink(),
                    if (_builtTabs.contains(2))
                      _SearchTab()
                    else
                      const SizedBox.shrink(),
                    if (_builtTabs.contains(3))
                      ReelsTab(active: _currentIndex == 3)
                    else
                      const SizedBox.shrink(),
                    if (_builtTabs.contains(4))
                      _ProfileTab()
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LiquidFloatingNav(
                  selectedIndex: _currentIndex,
                  onSelected: _onSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------- HOME ---------------------------------- */

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _communities = StreamCache<List<CommunityDoc>>(
    () => CommunityService.instance.watchAll(),
  );
  final _profile = StreamCache<UserProfile?>(
    () => UserService.instance.watchCurrent(),
  );
  final _published = StreamCache<List<ContentDoc>>(
    () => ContentService.instance.watchPublished(limit: 18),
  );
  final _fandoms = StreamCache<List<FandomDoc>>(
    () => TaxonomyService.instance.watchFandoms(),
  );
  final _feed = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchFeed(limit: 3),
  );
  final _notifications = StreamCache<List<NotificationDoc>>(
    () => NotificationService.instance.watch(),
  );
  final _events = StreamCache<List<FandomEventDoc>>(
    () => CatalogService.instance.watchUpcomingEvents(),
  );
  final _merch = StreamCache<List<MerchProductDoc>>(
    () => CatalogService.instance.watchMerch(),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('home_feed'),
      // BouncingScrollPhysics triggers an Android overscroll bug that snaps
      // the list back to the top when dragged past the end — use clamping.
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        const SizedBox(height: 10),
        _topBar(),
        const SizedBox(height: 20),
        DiscoveryFeatureSection(stream: _published()),
        TrendingFandomsSection(stream: _published(), fandomStream: _fandoms()),
        _SectionHeader(
          title: 'Communities',
          subtitle: 'Find your people across the fandoms',
          onSeeAll: () => Navigator.pushNamed(context, AppRoutes.communities),
        ),
        StreamBuilder<List<CommunityDoc>>(
          stream: _communities(),
          builder: (context, snap) {
            final communities = snap.data ?? const <CommunityDoc>[];
            if (communities.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CommunityPromoCard(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.communities),
                ),
              );
            }
            final preview = communities.take(10).toList();
            return SizedBox(
              height: 122,
              child: ListView.separated(
                key: const PageStorageKey<String>('home_communities_rail'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const ClampingScrollPhysics(),
                itemCount: preview.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _CompactCommunityCard(
                  community: preview[i],
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.communityDetail,
                    arguments: preview[i].id,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        TrendingNewsSection(stream: _published()),
        const SizedBox(height: 14),
        StreamBuilder<UserProfile?>(
          stream: _profile(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            return StreamBuilder<List<ContentDoc>>(
              stream: _published(),
              builder: (context, snap) {
                final published = snap.data ?? const <ContentDoc>[];
                final recommendations = buildRecommendedContentForUser(
                  profile,
                  published,
                );
                if (recommendations.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Recommended For You',
                      subtitle: 'Stories picked from your fandoms',
                      onSeeAll: () =>
                          Navigator.pushNamed(context, AppRoutes.explore),
                    ),
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        key: const PageStorageKey<String>(
                          'home_recommended_rail',
                        ),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const ClampingScrollPhysics(),
                        itemCount: recommendations.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, i) {
                          final item = recommendations[i];
                          return ContentRailCard(
                            content: item,
                            width: 200,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.contentDetail,
                              arguments: ContentDetailArgs(contentId: item.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Fan Feed',
          subtitle: 'Fresh posts from fans and communities',
          onSeeAll: () => Navigator.pushNamed(context, AppRoutes.feed),
        ),
        StreamBuilder<List<PostDoc>>(
          stream: _feed(),
          builder: (context, snap) {
            final posts = (snap.data ?? const <PostDoc>[]).take(3).toList();
            if (posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FeedPromoCard(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.feed),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < posts.length; i++)
                    Padding(
                      key: ValueKey(posts[i].id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(post: posts[i]),
                    ),
                  GlassButton(
                    label: 'Discover more posts',
                    variant: GlassButtonVariant.outline,
                    height: 50,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.feed),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        LatestDiscoveriesSection(stream: _published()),
        const SizedBox(height: 34),
        StreamBuilder<List<FandomEventDoc>>(
          stream: _events(),
          builder: (context, snap) {
            final events = (snap.data ?? const <FandomEventDoc>[])
                .take(6)
                .toList();
            if (events.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Upcoming Events',
                  subtitle: 'Gatherings and moments from the fandom community',
                  onSeeAll: () =>
                      Navigator.pushNamed(context, AppRoutes.events),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    key: const PageStorageKey<String>('home_events_rail'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const ClampingScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) =>
                        _EventCardDoc(event: events[i]),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 34),
        StreamBuilder<List<MerchProductDoc>>(
          stream: _merch(),
          builder: (context, snap) {
            final merch = (snap.data ?? const <MerchProductDoc>[])
                .take(8)
                .toList();
            if (merch.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Merch Spotlight',
                  subtitle: 'Fan-made finds from community sellers',
                  onSeeAll: () =>
                      Navigator.pushNamed(context, AppRoutes.merchExplore),
                ),
                SizedBox(
                  height: 244,
                  child: ListView.separated(
                    key: const PageStorageKey<String>('home_merch_rail'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const ClampingScrollPhysics(),
                    itemCount: merch.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => _MerchCardDoc(item: merch[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Image.asset(
              'lib/assets/images/fanVerseLogoF.png',
              height: 40,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Row(
            children: [
              _TopBarAction(
                icon: Icons.auto_awesome_rounded,
                onTap: () => Navigator.pushNamed(context, AppRoutes.fanHelper),
              ),
              const SizedBox(width: 8),
              _TopBarAction(
                icon: Icons.travel_explore_rounded,
                onTap: () => Navigator.pushNamed(context, AppRoutes.explore),
              ),
              const SizedBox(width: 8),
              _TopBarAction(
                icon: Icons.bookmark_border_rounded,
                onTap: () => Navigator.pushNamed(context, AppRoutes.saved),
              ),
              const SizedBox(width: 8),
              StreamBuilder<List<NotificationDoc>>(
                stream: _notifications(),
                builder: (context, snap) {
                  final unread = (snap.data ?? const <NotificationDoc>[])
                      .where((n) => !n.read)
                      .length;
                  return _TopBarAction(
                    icon: Icons.notifications_none_rounded,
                    badge: unread,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LiquidGlass(
            radius: 16,
            blur: 0,
            padding: const EdgeInsets.all(10),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC1121F),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.backgroundDeep,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// _CategoryGrid removed (unused). Kept file smaller and warnings clean.

// _CategoryGridDoc removed (unused). Kept file smaller and warnings clean.

// _CategoryDocTile removed (unused).

class _EventCardDoc extends StatelessWidget {
  const _EventCardDoc({required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    final base = event.color;
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.eventDetail, arguments: event),
      child: LiquidGlass(
        radius: 20,
        blur: 0,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withValues(alpha: 0.55), base.withValues(alpha: 0.9)],
        ),
        borderColor: Colors.white.withValues(alpha: 0.18),
        child: SizedBox(
          width: 224,
          child: Stack(
            children: [
              if (event.coverImageUrl?.isNotEmpty == true)
                Positioned.fill(
                  child: CachedImage(
                    url: event.coverImageUrl,
                    memCacheWidth: 448,
                    memCacheHeight: 300,
                  ),
                ),
              if (event.coverImageUrl?.isNotEmpty == true)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -8,
                top: -8,
                child: Icon(
                  event.icon,
                  size: 88,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiquidGlass(
                      radius: 999,
                      blur: 12,
                      tint: Colors.white.withValues(alpha: 0.14),
                      borderColor: Colors.white.withValues(alpha: 0.25),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        event.dateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
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

class _MerchCardDoc extends StatelessWidget {
  const _MerchCardDoc({required this.item});

  final MerchProductDoc item;

  @override
  Widget build(BuildContext context) {
    final hasRating = item.reviewCount > 0;
    final stock = item.stock;
    final lowStock = stock != null && stock > 0 && stock <= 10;
    final out = stock != null && stock <= 0;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.product, arguments: item),
      child: SizedBox(
        width: 162,
        child: LiquidGlass(
          radius: 24,
          blur: 0,
          padding: const EdgeInsets.all(7),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.13),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 224,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(
                          color: Color(0x0DFFFFFF),
                          child: Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white24,
                              size: 38,
                            ),
                          ),
                        ),
                        if (item.imageUrl?.isNotEmpty == true)
                          CachedImage(
                            url: item.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                            child: const SizedBox(height: 54),
                          ),
                        ),
                        if (hasRating)
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                color: Colors.black.withValues(alpha: 0.55),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFD166),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (out || lowStock)
                          Positioned(
                            top: 9,
                            left: 9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                color: Colors.black.withValues(alpha: 0.55),
                                border: Border.all(
                                  color:
                                      (out
                                              ? const Color(0xFFFF6B6B)
                                              : const Color(0xFFFFD166))
                                          .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                out ? 'Sold out' : 'Only $stock left',
                                style: TextStyle(
                                  color: out
                                      ? const Color(0xFFFF6B6B)
                                      : const Color(0xFFFFD166),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatPkrPrice(item.priceLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.subtitle,
  });

  final String title;
  final VoidCallback onSeeAll;
  final String? subtitle;

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
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore all',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.item, required this.width});

  final _SearchHit item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: LiquidGlass(
        radius: 18,
        blur: 0,
        borderColor: Colors.white.withValues(alpha: 0.16),
        boxShadow: [
          BoxShadow(
            color: item.colors.first.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: item.colors,
                  ),
                ),
                child: Center(
                  child: item.emoji?.isNotEmpty == true
                      ? Text(item.emoji!, style: const TextStyle(fontSize: 40))
                      : Icon(
                          item.icon ?? Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                ),
              ),
              if (item.imageUrl?.trim().isNotEmpty == true)
                item.isCircular
                    ? Center(
                        child: Container(
                          width: 92,
                          height: 92,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: CachedImage(url: item.imageUrl),
                        ),
                      )
                    : CachedImage(url: item.imageUrl),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------- TRENDING -------------------------------- */

/* --------------------------------- SEARCH --------------------------------- */

/// One search result. Rendered by [_PosterCard]; [onTap] is the route the
/// tile opens — every hit points at a real document (detail screens for live
/// hits, the feed/community for posts).
class _SearchHit {
  const _SearchHit({
    required this.title,
    required this.tag,
    required this.colors,
    required this.onTap,
    this.emoji,
    this.icon,
    this.imageUrl,
    this.isCircular = false,
  });

  final String title;
  final String tag;
  final List<Color> colors;
  final String? emoji;
  final IconData? icon;

  /// Real artwork (cover / product photo / post image) shown over the
  /// gradient fallback so search reads like a visual discovery feed.
  final String? imageUrl;

  /// Render [imageUrl] as a centered circular avatar instead of a full-bleed
  /// cover (square community profile images).
  final bool isCircular;
  final VoidCallback onTap;
}

/// A titled group of hits (Content, Communities, Events, Merch, Posts).
class _SearchSection {
  const _SearchSection({required this.title, required this.hits});

  final String title;
  final List<_SearchHit> hits;
}

/// Case-insensitive `contains` over every searchable field of a source doc.
bool _hitsQuery(String query, List<String> fields) =>
    fields.any((value) => value.toLowerCase().contains(query));

/// `null` while a source is still connecting (so the tab can show a spinner),
/// the last event otherwise — an errored source degrades to an empty list
/// instead of spinning forever.
List<T>? _sourceData<T>(AsyncSnapshot<List<T>> snapshot) =>
    snapshot.data ?? (snapshot.hasError ? <T>[] : null);

/// Poster gradients per content type — mirrors the browse poster palette.
List<Color> _contentColors(ContentType type) => switch (type) {
  ContentType.article => const [Color(0xFF1D4ED8), Color(0xFF030B1F)],
  ContentType.news => const [Color(0xFFBE123C), Color(0xFF18040A)],
  ContentType.trivia => const [Color(0xFFB45309), Color(0xFF1A0E03)],
  ContentType.lore => const [Color(0xFF7C3AED), Color(0xFF0F061C)],
};

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _queryDebounce;

  /// Live sources for the query. They are State-level [StreamCache]s so each
  /// source is subscribed once per tab — never re-created by a keystroke.
  final _searchContent = StreamCache<List<ContentDoc>>(
    () => ContentService.instance.watchPublished(limit: 60),
  );
  final _searchCommunities = StreamCache<List<CommunityDoc>>(
    () => CommunityService.instance.watchAll(),
  );
  final _searchEvents = StreamCache<List<FandomEventDoc>>(
    () => CatalogService.instance.watchUpcomingEvents(),
  );
  final _searchMerch = StreamCache<List<MerchProductDoc>>(
    () => CatalogService.instance.watchMerch(),
  );
  final _searchPosts = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchFeed(limit: 40),
  );

  /// Ceiling per section so a broad query can't build hundreds of tiles.
  static const int _maxHitsPerSection = 12;

  /// Tighter ceilings for the empty-query browse so the discovery feed stays
  /// scannable instead of dumping every source on the screen.
  static const int _maxBrowsePerSection = 6;
  static const int _maxBrowsePosts = 4;

  static const _filters = [
    'All',
    'Anime',
    'Gaming',
    'Movies',
    'Comics',
    'K-Pop',
    'Sci-Fi',
    'Events',
    'Merch',
  ];
  int _filter = 0;

  String get _filterLabel => _filters[_filter];

  /// `Events` / `Merch` chips isolate their own section; every other chip is
  /// a category that must be matched against each doc's fields.
  bool get _isCategoryFilter =>
      _filter != 0 && _filterLabel != 'Events' && _filterLabel != 'Merch';

  /// The section group a chip isolates (`events` / `merch`), or `null` when
  /// every group is visible.
  String? get _isolatedGroup {
    switch (_filterLabel) {
      case 'Events':
        return 'events';
      case 'Merch':
        return 'merch';
      default:
        return null;
    }
  }

  bool _groupVisible(String group) {
    final isolated = _isolatedGroup;
    return isolated == null || isolated == group;
  }

  /// Case-insensitive `contains` of the active chip label over [fields], with
  /// a hyphen/punctuation-insensitive fallback so `K-Pop` also matches `Kpop`
  /// and `Sci-Fi` matches `Sci Fi`. Sources with no plausible category field
  /// simply never match, which hides them under a category chip.
  bool _matchesFilter(List<String> fields) {
    if (!_isCategoryFilter) return true;
    final needle = _filterLabel.toLowerCase();
    final compactNeedle = _compactFilterKey(_filterLabel);
    for (final field in fields) {
      final value = field.toLowerCase();
      if (value.contains(needle)) return true;
      if (compactNeedle.isNotEmpty &&
          _compactFilterKey(value).contains(compactNeedle)) {
        return true;
      }
    }
    return false;
  }

  static String _compactFilterKey(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  @override
  void dispose() {
    _queryDebounce?.cancel();
    ExplorePromptService.instance.stop();
    ExplorePromptService.clearContext();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LiquidGlass(
            radius: 16,
            blur: 0,
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: Colors.white),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                hintText: 'Idols, lore, events, merch...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _queryDebounce?.cancel();
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const ClampingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final selected = _filter == i;
              return GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                          )
                        : null,
                    color: selected
                        ? null
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    _filters[i],
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: query.isEmpty ? _browse() : _liveResults(query)),
      ],
    );
  }

  /// Live browse shown before the user types: the exact same cached sources
  /// as [_liveResults], just sectioned for discovery instead of matched
  /// against a query. An empty query matches everything, so the section
  /// builder keeps its browse titles and tighter caps.
  Widget _browse() => _liveResults('');

  /// One [StreamBuilder] per cached source; each layer hands its slice to
  /// the next and the innermost layer groups the hits into sections.
  Widget _liveResults(String query) {
    return StreamBuilder<List<ContentDoc>>(
      stream: _searchContent(),
      builder: (context, snapshot) =>
          _withCommunities(query, content: _sourceData(snapshot)),
    );
  }

  Widget _withCommunities(String query, {List<ContentDoc>? content}) {
    return StreamBuilder<List<CommunityDoc>>(
      stream: _searchCommunities(),
      builder: (context, snapshot) => _withEvents(
        query,
        content: content,
        communities: _sourceData(snapshot),
      ),
    );
  }

  Widget _withEvents(
    String query, {
    List<ContentDoc>? content,
    List<CommunityDoc>? communities,
  }) {
    return StreamBuilder<List<FandomEventDoc>>(
      stream: _searchEvents(),
      builder: (context, snapshot) => _withMerch(
        query,
        content: content,
        communities: communities,
        events: _sourceData(snapshot),
      ),
    );
  }

  Widget _withMerch(
    String query, {
    List<ContentDoc>? content,
    List<CommunityDoc>? communities,
    List<FandomEventDoc>? events,
  }) {
    return StreamBuilder<List<MerchProductDoc>>(
      stream: _searchMerch(),
      builder: (context, snapshot) => _withPosts(
        query,
        content: content,
        communities: communities,
        events: events,
        merch: _sourceData(snapshot),
      ),
    );
  }

  Widget _withPosts(
    String query, {
    List<ContentDoc>? content,
    List<CommunityDoc>? communities,
    List<FandomEventDoc>? events,
    List<MerchProductDoc>? merch,
  }) {
    return StreamBuilder<List<PostDoc>>(
      stream: _searchPosts(),
      builder: (context, snapshot) => _buildResults(
        query,
        content: content,
        communities: communities,
        events: events,
        merch: merch,
        posts: _sourceData(snapshot),
      ),
    );
  }

  Widget _buildResults(
    String query, {
    required List<ContentDoc>? content,
    required List<CommunityDoc>? communities,
    required List<FandomEventDoc>? events,
    required List<MerchProductDoc>? merch,
    required List<PostDoc>? posts,
  }) {
    final sections = _sections(
      query,
      content: content,
      communities: communities,
      events: events,
      merch: merch,
      posts: posts,
    );

    if (sections.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
        physics: const ClampingScrollPhysics(),
        itemCount: sections.length,
        itemBuilder: (context, index) =>
            _SearchSectionView(section: sections[index]),
      );
    }

    final connecting =
        content == null ||
        communities == null ||
        events == null ||
        merch == null ||
        posts == null;
    if (connecting) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (query.isEmpty) {
      final filtered = _isCategoryFilter || _isolatedGroup != null;
      return ContentEmptyState(
        icon: filtered ? Icons.filter_alt_off_rounded : Icons.auto_awesome,
        title: filtered
            ? 'Nothing under “$_filterLabel” yet'
            : 'Nothing in the verse yet',
        message: filtered
            ? 'No live picks match this chip right now. Try another one, '
                  'or tap All to see everything.'
            : 'Fresh stories, communities, events and merch show up here '
                  'the moment they drop.',
      );
    }

    return ContentEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matches',
      message:
          'Nothing in the verse matches “$_query”. Try a fandom, a story, '
          'an event or some merch.',
    );
  }

  /// Groups the live slices into sections. An empty [query] means "browse":
  /// sections then carry discovery titles and tighter caps, but both modes
  /// run the same field matching plus the active chip filter.
  List<_SearchSection> _sections(
    String query, {
    required List<ContentDoc>? content,
    required List<CommunityDoc>? communities,
    required List<FandomEventDoc>? events,
    required List<MerchProductDoc>? merch,
    required List<PostDoc>? posts,
  }) {
    final browse = query.isEmpty;
    final cap = browse ? _maxBrowsePerSection : _maxHitsPerSection;
    final sections = <_SearchSection>[];

    if (_groupVisible('content')) {
      final contentHits = <_SearchHit>[];
      for (final item in content ?? const <ContentDoc>[]) {
        if (item.title.trim().isEmpty) continue;
        final fields = [
          item.title,
          item.summary,
          item.fandomName,
          item.categoryName,
          item.tags.join(' '),
        ];
        if (!_hitsQuery(query, fields)) continue;
        if (!_matchesFilter(fields)) continue;

        var tag = item.type.label;
        if (item.categoryName.trim().isNotEmpty) tag = item.categoryName;
        if (item.fandomName.trim().isNotEmpty) tag = item.fandomName;

        contentHits.add(
          _SearchHit(
            title: item.title,
            tag: tag,
            colors: _contentColors(item.type),
            icon: item.type.icon,
            imageUrl: item.coverImageUrl,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.contentDetail,
              arguments: ContentDetailArgs(contentId: item.id),
            ),
          ),
        );
        if (contentHits.length >= cap) break;
      }
      if (contentHits.isNotEmpty) {
        sections.add(
          _SearchSection(
            title: browse ? 'Fresh discoveries' : 'Content',
            hits: contentHits,
          ),
        );
      }
    }

    if (_groupVisible('communities')) {
      final source = communities ?? const <CommunityDoc>[];
      // Browse leads with the biggest rooms; typed queries keep source order.
      final ordered = browse
          ? ([...source]
              ..sort((a, b) => b.memberCount.compareTo(a.memberCount)))
          : source;

      final communityHits = <_SearchHit>[];
      for (final item in ordered) {
        if (item.name.trim().isEmpty) continue;
        final fields = [item.name, item.description];
        if (!_hitsQuery(query, fields)) continue;
        if (!_matchesFilter(fields)) continue;

        communityHits.add(
          _SearchHit(
            title: item.name,
            tag:
                '${item.memberCount} '
                '${item.memberCount == 1 ? 'member' : 'members'}',
            colors: [item.color, item.color.withValues(alpha: 0.22)],
            icon: item.icon,
            imageUrl: item.profileImageUrl ?? item.coverImageUrl,
            isCircular: true,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.communityDetail,
              arguments: item.id,
            ),
          ),
        );
        if (communityHits.length >= cap) break;
      }
      if (communityHits.isNotEmpty) {
        sections.add(
          _SearchSection(
            title: browse ? 'Popular communities' : 'Communities',
            hits: communityHits,
          ),
        );
      }
    }

    if (_groupVisible('events')) {
      final eventHits = <_SearchHit>[];
      for (final item in events ?? const <FandomEventDoc>[]) {
        if (item.title.trim().isEmpty) continue;
        final fields = [
          item.title,
          item.description,
          item.city,
          item.eventType,
        ];
        if (!_hitsQuery(query, fields)) continue;
        if (!_matchesFilter(fields)) continue;

        var tag = item.dateLabel;
        if (tag.trim().isEmpty) tag = item.city;
        if (tag.trim().isEmpty) tag = item.eventType;

        eventHits.add(
          _SearchHit(
            title: item.title,
            tag: tag,
            colors: [item.color, item.color.withValues(alpha: 0.22)],
            icon: item.icon,
            imageUrl: item.coverImageUrl,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.eventDetail,
              arguments: item,
            ),
          ),
        );
        if (eventHits.length >= cap) break;
      }
      if (eventHits.isNotEmpty) {
        sections.add(
          _SearchSection(
            title: browse ? 'Upcoming events' : 'Events',
            hits: eventHits,
          ),
        );
      }
    }

    if (_groupVisible('merch')) {
      final merchHits = <_SearchHit>[];
      for (final item in merch ?? const <MerchProductDoc>[]) {
        if (item.name.trim().isEmpty) continue;
        final fields = [item.name, item.description, item.sellerName];
        if (!_hitsQuery(query, fields)) continue;
        if (!_matchesFilter(fields)) continue;

        merchHits.add(
          _SearchHit(
            title: item.name,
            tag: formatPkrPrice(item.priceLabel),
            colors: [item.color, item.color.withValues(alpha: 0.22)],
            emoji: item.emoji,
            imageUrl: item.imageUrl,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.product,
              arguments: item,
            ),
          ),
        );
        if (merchHits.length >= cap) break;
      }
      if (merchHits.isNotEmpty) {
        sections.add(
          _SearchSection(
            title: browse ? 'Fan merch' : 'Merch',
            hits: merchHits,
          ),
        );
      }
    }

    if (_groupVisible('posts')) {
      final postHits = <_SearchHit>[];
      final postCap = browse ? _maxBrowsePosts : _maxHitsPerSection;
      for (final item in posts ?? const <PostDoc>[]) {
        if (item.body.trim().isEmpty) continue;
        final fields = [item.body, item.authorName, item.communityName ?? ''];
        if (!_hitsQuery(query, fields)) continue;
        if (!_matchesFilter(fields)) continue;

        var tag = 'Fan post';
        if (item.communityName?.trim().isNotEmpty ?? false) {
          tag = item.communityName!;
        }
        if (item.authorName.trim().isNotEmpty) tag = item.authorName;

        final communityId = item.communityId ?? '';
        postHits.add(
          _SearchHit(
            title: _postTitle(item),
            tag: tag,
            colors: const [Color(0xFFA855F7), Color(0xFF1E0B33)],
            icon: Icons.forum_rounded,
            imageUrl: item.imageUrl,
            onTap: () {
              if (communityId.isEmpty) {
                Navigator.pushNamed(context, AppRoutes.feed);
              } else {
                Navigator.pushNamed(
                  context,
                  AppRoutes.communityDetail,
                  arguments: communityId,
                );
              }
            },
          ),
        );
        if (postHits.length >= postCap) break;
      }
      if (postHits.isNotEmpty) {
        sections.add(
          _SearchSection(
            title: browse ? 'Latest posts' : 'Posts',
            hits: postHits,
          ),
        );
      }
    }

    return sections;
  }

  static String _postTitle(PostDoc post) {
    final line = post.body.trim().split('\n').first.trim();
    if (line.length <= 64) return line;
    return '${line.substring(0, 64).trimRight()}…';
  }
}

/// Section header + the poster grid for one group of hits. Sections only
/// ever contain matches, so an empty group is never rendered.
class _SearchSectionView extends StatelessWidget {
  const _SearchSectionView({required this.section});

  final _SearchSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          child: Row(
            children: [
              Text(
                section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  '${section.hits.length}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.7,
          ),
          itemCount: section.hits.length,
          itemBuilder: (context, index) =>
              _PosterCard(item: section.hits[index], width: double.infinity),
        ),
      ],
    );
  }
}

class _CompactCommunityCard extends StatelessWidget {
  const _CompactCommunityCard({required this.community, required this.onTap});

  final CommunityDoc community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: LiquidGlass(
          radius: 20,
          blur: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          gradient: LinearGradient(
            colors: [
              community.color.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderColor: community.color.withValues(alpha: 0.35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      community.color,
                      community.color.withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: community.color.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    community.profileImageUrl?.isNotEmpty == true ||
                        community.coverImageUrl?.isNotEmpty == true
                    ? CachedImage(
                        url: community.profileImageUrl?.isNotEmpty == true
                            ? community.profileImageUrl
                            : community.coverImageUrl,
                      )
                    : Icon(community.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                community.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${community.memberCount} '
                '${community.memberCount == 1 ? 'member' : 'members'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPromoCard extends StatelessWidget {
  const _CommunityPromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Row(
          children: [
            Icon(Icons.diversity_3_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start a community',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gather your fandom — create or join a crew.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _FeedPromoCard extends StatelessWidget {
  const _FeedPromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFA855F7).withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFFA855F7), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feed is warming up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Post hot takes and see what the verse is saying.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------- PROFILE -------------------------------- */

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white54,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in to view your profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access your profile, fandom interests, saved discoveries and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 24),
            GlassButton(
              label: 'Sign In',
              variant: GlassButtonVariant.sleek,
              icon: Icons.login_rounded,
              onPressed: () => showAuthPopup(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _user = StreamCache<UserProfile?>(
    () => UserService.instance.watchCurrent(),
  );

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      return const _SignInPrompt();
    }

    return StreamBuilder<UserProfile?>(
      stream: _user(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.name.isNotEmpty == true
            ? profile!.name
            : AuthService.instance.greetingName;
        final role = profile?.role ?? UserRole.fan;

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: profile?.uid.isNotEmpty == true
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.userProfile,
                            arguments: profile!.uid,
                          )
                        : null,
                    child: Hero(
                      tag: 'avatar-${profile?.uid ?? 'self'}',
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: profile?.avatarUrl?.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(27),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name.characters.first
                                                  .toUpperCase()
                                            : 'F',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    CachedImage(url: profile!.avatarUrl),
                                  ],
                                ),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name.characters.first.toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: profile?.uid.isNotEmpty == true
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.userProfile,
                            arguments: profile!.uid,
                          )
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _RoleBadge(role: role, shopName: profile?.shopName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.shopName != null && profile!.shopName!.isNotEmpty
                        ? profile.shopName!
                        : (user.email ?? 'Local session'),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.interestsEditor,
                      arguments: profile?.selectedFandoms ?? const <String>[],
                    ),
                    child: _FandomChips(profile: profile),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            if (role == UserRole.fan) ...[
              _SellerUpgradeCard(onUpgrade: () => _showSellerSheet(context)),
              const SizedBox(height: 14),
            ] else if (role == UserRole.seller || profile?.isAdmin == true) ...[
              _ProfileTile(
                icon: Icons.storefront_rounded,
                label: 'Seller dashboard',
                trailing: _MiniBadge(
                  text: profile?.isAdmin == true ? 'Admin' : 'Seller',
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.seller),
              ),
              const SizedBox(height: 12),
            ],
            if (role == UserRole.admin)
              FadeSlideIn(
                child: _ProfileTile(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin Console',
                  trailing: const _MiniBadge(text: 'Admin'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
                ),
              ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.person_outline_rounded,
                label: 'My profile',
                onTap: () async {
                  final uid = AuthService.instance.currentUser?.uid;
                  if (uid == null || uid.isEmpty) {
                    await showAuthPopup(context);
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: uid,
                  );
                },
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () async {
                  final uid = AuthService.instance.currentUser?.uid;
                  if (uid == null) {
                    await showAuthPopup(context);
                    return;
                  }
                  if (!context.mounted) return;
                  final current =
                      profile ?? await UserService.instance.fetch(uid);
                  if (!context.mounted) return;
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.editProfile,
                    arguments: current,
                  );
                },
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.favorite_outline_rounded,
                label: 'My fandom interests',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.interestsEditor,
                  arguments: profile?.selectedFandoms ?? const <String>[],
                ),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.auto_awesome_rounded,
                label: 'Fan Helper AI',
                trailing: const _MiniBadge(text: 'AI'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.fanHelper),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.bookmark_border_rounded,
                label: 'Saved discoveries',
                onTap: () => Navigator.pushNamed(context, AppRoutes.saved),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.travel_explore_rounded,
                label: 'Explore fandoms',
                onTap: () => Navigator.pushNamed(context, AppRoutes.explore),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.shopping_cart_outlined,
                label: 'Cart',
                onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.receipt_long_outlined,
                label: 'My orders',
                onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.mail_outline_rounded,
                label: 'Contact Us',
                onTap: () => Navigator.pushNamed(context, AppRoutes.contact),
              ),
            ),
            FadeSlideIn(
              child: _ProfileTile(
                icon: Icons.info_outline_rounded,
                label: 'About Us',
                onTap: () => Navigator.pushNamed(context, AppRoutes.about),
              ),
            ),
            const SizedBox(height: 20),
            _SignOutButton(),
          ],
        );
      },
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Fiverr-style self-serve upgrade — no admin approval.
  static Future<void> _showSellerSheet(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var loading = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                decoration: BoxDecoration(
                  color: const Color(0xF2101018),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Become a Seller',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Open your shop in one tap — list apparel, collectibles and fan merch. No approval wait.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: controller,
                        enabled: !loading,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: AppColors.accent,
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return 'Shop name must be at least 3 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Shop name',
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          prefixIcon: const Icon(Icons.storefront_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: loading
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                setSheetState(() => loading = true);
                                try {
                                  final uid =
                                      AuthService.instance.currentUser?.uid;
                                  if (uid == null) {
                                    throw StateError('Not signed in.');
                                  }
                                  await UserService.instance.upgradeToSeller(
                                    uid: uid,
                                    shopName: controller.text,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop(true);
                                  }
                                } catch (e) {
                                  setSheetState(() => loading = false);
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                        child: LiquidGlass(
                          radius: 16,
                          blur: 0,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                          ),
                          borderColor: Colors.white.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Upgrade to Seller',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => Navigator.pop(sheetContext, false),
                        child: const Text(
                          'Not now',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      _toast(
        context,
        'You’re a seller now — open Seller dashboard to list items.',
      );
    }
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _busy = false;

  Future<void> _confirmAndSignOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF2101018),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You can sign back in anytime with your email or Google account.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign out',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Still leave the session — a stuck Google SDK must not lock the user in.
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.getStarted, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _confirmAndSignOut,
      child: Opacity(
        opacity: _busy ? 0.7 : 1,
        child: LiquidGlass(
          radius: 16,
          blur: 0,
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.35),
              AppColors.primaryDark.withValues(alpha: 0.2),
            ],
          ),
          borderColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _busy ? 'Signing out…' : 'Sign Out',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.shopName});

  final UserRole role;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    final (label, colors) = switch (role) {
      UserRole.admin => ('Admin', [Color(0xFFC1121F), Color(0xFF7F1D1D)]),
      UserRole.seller => ('Seller', [Color(0xFF7C3AED), Color(0xFF4C1D95)]),
      UserRole.fan => (
        'Fan',
        [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.08),
        ],
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SellerUpgradeCard extends StatelessWidget {
  const _SellerUpgradeCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpgrade,
      child: LiquidGlass(
        radius: 20,
        blur: 0,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x597C3AED), Color(0x33C1121F), Color(0x1AFFFFFF)],
        ),
        borderColor: Colors.white.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become a Seller',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'List merch, reach fans — upgrade in one tap',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

class _FandomChips extends StatelessWidget {
  const _FandomChips({this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final fandoms = profile?.selectedFandoms ?? const <String>[];
    if (fandoms.isEmpty) {
      return const Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _InterestChip(label: 'Anime'),
          _InterestChip(label: 'Gaming'),
          _InterestChip(label: 'K-Pop'),
          _InterestChip(label: 'Comics'),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [for (final f in fandoms) _InterestChip(label: f)],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 999,
      blur: 14,
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.3),
          AppColors.primary.withValues(alpha: 0.12),
        ],
      ),
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: LiquidGlass(
          radius: 16,
          blur: 0,
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
