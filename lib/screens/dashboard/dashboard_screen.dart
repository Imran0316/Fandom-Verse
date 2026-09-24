import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_catalog.dart';
import '../../models/catalog_docs.dart';
import '../../models/community_docs.dart';
import '../../models/post_docs.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/community_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../widgets/liquid_floating_nav.dart';
import '../../widgets/liquid_glass.dart';
import '../communities/post_card.dart';
import '../reels/reels_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _onSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
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
                  children: const [
                    _HomeTab(),
                    _TrendingTab(),
                    _SearchTab(),
                    ReelsTab(),
                    _ProfileTab(),
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
  final PageController _heroController = PageController(viewportFraction: 0.74);
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    _heroController.addListener(() {
      final page = _heroController.page?.round() ?? 0;
      if (page != _heroPage && mounted) {
        setState(() => _heroPage = page);
      }
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xE616161F),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        const SizedBox(height: 10),
        _topBar(),
        const SizedBox(height: 18),
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _heroController,
            itemCount: MockCatalog.trending.length,
            itemBuilder: (context, index) {
              final item = MockCatalog.trending[index];
              final isCurrent = _heroPage == index;
              return AnimatedScale(
                scale: isCurrent ? 1 : 0.9,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: _HeroCard(item: item),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _PageDots(count: MockCatalog.trending.length, index: _heroPage),
        const SizedBox(height: 28),
        StreamBuilder<List<FandomCategoryDoc>>(
          stream: CatalogService.instance.watchCategories(),
          builder: (context, snap) {
            final cats = snap.data ?? const <FandomCategoryDoc>[];
            if (cats.isEmpty) {
              return _CategoryGrid(
                onTap: (cat) => _toast('Browsing ${cat.label}'),
              );
            }
            return _CategoryGridDoc(
              categories: cats,
              onTap: (cat) => _toast('Browsing ${cat.name}'),
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Communities',
          onSeeAll: () => Navigator.pushNamed(context, AppRoutes.communities),
        ),
        StreamBuilder<List<CommunityDoc>>(
          stream: CommunityService.instance.watchAll(),
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
            final preview = communities.take(4).toList();
            return SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: preview.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final c = preview[i];
                  return _MiniCommunityCard(
                    community: c,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.communityDetail,
                      arguments: c.id,
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Fan Feed',
          onSeeAll: () => Navigator.pushNamed(context, AppRoutes.feed),
        ),
        StreamBuilder<List<PostDoc>>(
          stream: PostService.instance.watchFeed(limit: 5),
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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(post: posts[i]),
                    ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.feed),
                    child: const Text(
                      'Open full feed',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Recommended For You',
          onSeeAll: () => _toast('See all recommendations'),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: MockCatalog.recommended.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final t = MockCatalog.recommended[i];
              return _PosterCard(
                item: t,
                width: 134,
                onTap: () => _toast(t.title),
              );
            },
          ),
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Upcoming Events',
          onSeeAll: () => _toast('Full event calendar'),
        ),
        StreamBuilder<List<FandomEventDoc>>(
          stream: CatalogService.instance.watchEvents(),
          builder: (context, snap) {
            final events = snap.data ?? const <FandomEventDoc>[];
            if (events.isEmpty) {
              return SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: MockCatalog.events.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) =>
                      _EventCard(event: MockCatalog.events[i]),
                ),
              );
            }
            return SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) =>
                    _EventCardDoc(event: events[i]),
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Merch Spotlight',
          onSeeAll: () => _toast('Official merchandise store'),
        ),
        StreamBuilder<List<MerchProductDoc>>(
          stream: CatalogService.instance.watchMerch(),
          builder: (context, snap) {
            final merch = snap.data ?? const <MerchProductDoc>[];
            if (merch.isEmpty) {
              return SizedBox(
                height: 186,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: MockCatalog.merch.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) =>
                      _MerchCard(item: MockCatalog.merch[i]),
                ),
              );
            }
            return SizedBox(
              height: 186,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: merch.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) =>
                    _MerchCardDoc(item: merch[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _topBar() {
    final name = AuthService.instance.greetingName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, ${name.isEmpty ? 'Fan' : name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your fandoms are heating up',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: LiquidGlass(
              radius: 16,
              blur: 20,
              padding: const EdgeInsets.all(10),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.white24,
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.item});

  final TrendingFandom item;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (widget.item.videoId ?? '').isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.item.videoId ?? '',
        autoPlay: true,
        params: const YoutubePlayerParams(
          mute: true,
          loop: true,
          showControls: false,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = kIsWeb
        ? Image.network(
            widget.item.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.item.colors,
                ),
              ),
              child: Center(
                child: Text(
                  widget.item.emoji,
                  style: const TextStyle(fontSize: 68),
                ),
              ),
            ),
          )
        : _controller == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.item.colors,
              ),
            ),
            child: Center(
              child: Text(
                widget.item.emoji,
                style: const TextStyle(fontSize: 68),
              ),
            ),
          )
        : YoutubePlayer(controller: _controller!, aspectRatio: 0.74);

    return LiquidGlass(
      radius: 24,
      blur: 0.01,
      borderColor: Colors.white.withValues(alpha: 0.1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            media,
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: LiquidGlass(
                radius: 18,
                blur: 24,
                tint: const Color(0x66000000),
                borderColor: Colors.white.withValues(alpha: 0.12),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.item.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.onTap});

  final ValueChanged<FandomCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 40;
        final cross = (width / 130).floor().clamp(3, 3);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: MockCatalog.categories.length,
            itemBuilder: (context, i) {
              final cat = MockCatalog.categories[i];
              return _CategoryTile(category: cat, onTap: () => onTap(cat));
            },
          ),
        );
      },
    );
  }
}

class _CategoryGridDoc extends StatelessWidget {
  const _CategoryGridDoc({
    required this.categories,
    required this.onTap,
  });

  final List<FandomCategoryDoc> categories;
  final ValueChanged<FandomCategoryDoc> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...categories.take(5),
      if (categories.length > 5)
        FandomCategoryDoc(
          id: '__all__',
          name: 'See all',
          iconName: 'grid',
          colorName: 'gray',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 40;
        final cross = (width / 130).floor().clamp(3, 3);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final cat = items[i];
              return _CategoryDocTile(
                category: cat,
                onTap: () => onTap(cat),
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryDocTile extends StatelessWidget {
  const _CategoryDocTile({required this.category, required this.onTap});

  final FandomCategoryDoc category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 20,
        blur: 24,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.25),
                  ],
                ),
              ),
              child: Icon(category.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCardDoc extends StatelessWidget {
  const _EventCardDoc({required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    final base = event.color;
    return LiquidGlass(
      radius: 20,
      blur: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(alpha: 0.55),
          base.withValues(alpha: 0.9),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: SizedBox(
        width: 224,
        child: Stack(
          children: [
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
    );
  }
}

class _MerchCardDoc extends StatelessWidget {
  const _MerchCardDoc({required this.item});

  final MerchProductDoc item;

  @override
  Widget build(BuildContext context) {
    final color = item.color;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.product,
        arguments: item,
      ),
      child: LiquidGlass(
      radius: 20,
      blur: 24,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.16),
      child: SizedBox(
        width: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.7),
                      color.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: item.imageUrl?.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        )
                      : Text(item.emoji, style: const TextStyle(fontSize: 40)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final FandomCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 20,
        blur: 24,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            category.color.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    category.color.withValues(alpha: 0.55),
                    category.color.withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(category.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
          LiquidGlass(
            radius: 999,
            blur: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            child: GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final MediaTitle item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 18,
        blur: 18,
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
                  child: Text(item.emoji, style: const TextStyle(fontSize: 40)),
                ),
              ),
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

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final FandomEvent event;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 20,
      blur: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          event.colors.first.withValues(alpha: 0.55),
          event.colors.last.withValues(alpha: 0.9),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: SizedBox(
        width: 224,
        child: Stack(
          children: [
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
                      event.date,
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
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.confirmation_number_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchCard extends StatelessWidget {
  const _MerchCard({required this.item});

  final MerchItem item;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 20,
      blur: 24,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.16),
      child: SizedBox(
        width: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: item.colors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: Text(item.emoji, style: const TextStyle(fontSize: 40)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.price,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 18,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------- TRENDING -------------------------------- */

class _TrendingTab extends StatelessWidget {
  const _TrendingTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      ...MockCatalog.recommended,
      ...MockCatalog.trending.map(
        (t) => MediaTitle(
          title: t.title,
          tag: t.category,
          colors: t.colors,
          emoji: t.emoji,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'Trending Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'What the verse is buzzing about this week',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 360 ? 2 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.7,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _PosterCard(
                  item: items[i],
                  width: double.infinity,
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(items[i].title)),
                    ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* --------------------------------- SEARCH --------------------------------- */

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  String _query = '';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      ...MockCatalog.recommended,
      ...MockCatalog.trending.map(
        (t) => MediaTitle(
          title: t.title,
          tag: t.category,
          colors: t.colors,
          emoji: t.emoji,
        ),
      ),
    ];
    final results = all.where((m) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return m.title.toLowerCase().contains(q) ||
          m.tag.toLowerCase().contains(q);
    }).toList();

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
            blur: 20,
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v.trim()),
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
            physics: const BouncingScrollPhysics(),
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
        Expanded(
          child: results.isEmpty
              ? const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  subtitle: 'Try another fandom keyword.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _PosterCard(
                    item: results[i],
                    width: double.infinity,
                    onTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(results[i].title)),
                      ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MiniCommunityCard extends StatelessWidget {
  const _MiniCommunityCard({required this.community, required this.onTap});

  final CommunityDoc community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              community.color.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  community.color,
                  community.color.withValues(alpha: 0.55),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(community.icon, color: Colors.white, size: 18),
            ),
            const Spacer(),
            Text(
              community.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${community.memberCount} members',
              style: TextStyle(
                color: community.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlass(
              radius: 24,
              blur: 20,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------- PROFILE -------------------------------- */

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchCurrent(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.name.isNotEmpty == true
            ? profile!.name
            : AuthService.instance.greetingName;
        final role = profile?.role ?? UserRole.fan;

        return ListView(
          physics: const BouncingScrollPhysics(),
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
                              color:
                                  AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: profile?.avatarUrl?.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(27),
                                child: Image.network(
                                  profile!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
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
                        : (user?.email ?? 'Local session'),
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
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.seller),
              ),
              const SizedBox(height: 12),
            ],
            if (role == UserRole.admin)
              FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: _ProfileTile(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin Console',
                  trailing: const _MiniBadge(text: 'Admin'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
                ),
              ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _ProfileTile(
                icon: Icons.person_outline_rounded,
                label: 'My profile',
                onTap: () {
                  final uid = AuthService.instance.currentUser?.uid;
                  if (uid == null || uid.isEmpty) {
                    _toast(context, 'Sign in to view your profile');
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: uid,
                  );
                },
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _ProfileTile(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () async {
                  final uid = AuthService.instance.currentUser?.uid;
                  if (uid == null) {
                    _toast(context, 'Sign in to edit your profile');
                    return;
                  }
                  final current = profile ??
                      await UserService.instance.fetch(uid);
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
              delay: const Duration(milliseconds: 120),
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
              delay: const Duration(milliseconds: 150),
              child: _ProfileTile(
                icon: Icons.shopping_cart_outlined,
                label: 'Cart',
                onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 165),
              child: _ProfileTile(
                icon: Icons.receipt_long_outlined,
                label: 'My orders',
                onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: _ProfileTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 210),
              child: _ProfileTile(
                icon: Icons.smart_toy_outlined,
                label: 'AI Fan Helper',
                trailing: const _MiniBadge(text: 'AI'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.aiHelper),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: _ProfileTile(
                icon: Icons.mail_outline_rounded,
                label: 'Contact Us',
                onTap: () => Navigator.pushNamed(context, AppRoutes.contact),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 270),
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
                          blur: 18,
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.getStarted,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _confirmAndSignOut,
      child: Opacity(
        opacity: _busy ? 0.7 : 1,
        child: LiquidGlass(
          radius: 16,
          blur: 20,
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
                const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.white,
                ),
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
        blur: 26,
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
      children: [
        for (final f in fandoms) _InterestChip(label: f),
      ],
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
          blur: 22,
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
