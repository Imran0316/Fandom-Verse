import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_catalog.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/liquid_floating_nav.dart';
import '../../widgets/liquid_glass.dart';

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
                      colors: [
                        Color(0x55E50914),
                        Colors.transparent,
                      ],
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
                    _LibraryTab(),
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
  final PageController _heroController =
      PageController(viewportFraction: 0.74);
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
                  child: _HeroCard(
                    item: item,
                    showPlay: isCurrent,
                    onTap: () =>
                        _toast('${item.title} — trailer coming soon'),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _PageDots(count: MockCatalog.trending.length, index: _heroPage),
        const SizedBox(height: 28),
        _CategoryGrid(onTap: (cat) {
          _toast(cat.label == 'See all'
              ? 'All fandom categories'
              : 'Browsing ${cat.label}');
        }),
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
        SizedBox(
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
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Merch Spotlight',
          onSeeAll: () => _toast('Official merchandise store'),
        ),
        SizedBox(
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
          LiquidGlass(
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.item,
    required this.showPlay,
    required this.onTap,
  });

  final TrendingFandom item;
  final bool showPlay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 24,
        blur: showPlay ? 4 : 0.01,
        borderColor: showPlay
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: showPlay
                ? AppColors.primary.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.5),
            blurRadius: showPlay ? 40 : 28,
            offset: const Offset(0, 16),
          ),
        ],
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
                child: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 68),
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
                        item.category,
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
                      item.title,
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
            if (showPlay)
              const Center(child: _PlayButton()),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white.withValues(alpha: 0.82),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Color(0xFF111111),
        size: 42,
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
              return _CategoryTile(
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
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
                  child:
                      Text(item.emoji, style: const TextStyle(fontSize: 40)),
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
                  child:
                      Text(item.emoji, style: const TextStyle(fontSize: 40)),
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
                  onTap: () {},
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
                    color: selected ? null : Colors.white.withValues(alpha: 0.07),
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _PosterCard(
                    item: results[i],
                    width: double.infinity,
                    onTap: () {},
                  ),
                ),
        ),
      ],
    );
  }
}

/* --------------------------------- LIBRARY -------------------------------- */

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      children: [
        const Text(
          'Library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bookmarks, wishlists & offline saves',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Row(
          children: const [
            Expanded(
              child: _LibraryStat(
                value: '12',
                label: 'Bookmarks',
                icon: Icons.bookmark_rounded,
                color: Color(0xFFE11D48),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _LibraryStat(
                value: '6',
                label: 'Wishlist',
                icon: Icons.favorite_rounded,
                color: Color(0xFFA855F7),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _LibraryStat(
                value: '4',
                label: 'Offline',
                icon: Icons.download_rounded,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Saved for later',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ...MockCatalog.recommended.take(3).map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LibraryRow(item: t),
              ),
            ),
        const SizedBox(height: 8),
        const _EmptyState(
          icon: Icons.folder_open_rounded,
          title: 'Wishlist is empty',
          subtitle: 'Tap the heart on merch to save items here.',
        ),
      ],
    );
  }
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 18,
      blur: 22,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.06),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
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

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.item});

  final MediaTitle item;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 16,
      blur: 22,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: item.colors),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child:
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.tag,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.bookmark_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ],
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
                  Container(
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
                    child: Center(
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
                  const SizedBox(height: 14),
                  Row(
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
                  const SizedBox(height: 4),
                  Text(
                    profile?.shopName != null &&
                            profile!.shopName!.isNotEmpty
                        ? profile.shopName!
                        : (user?.email ?? 'Local session'),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _InterestChip(label: 'Anime'),
                      _InterestChip(label: 'Gaming'),
                      _InterestChip(label: 'K-Pop'),
                      _InterestChip(label: 'Comics'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            if (role == UserRole.fan) ...[
              _SellerUpgradeCard(
                onUpgrade: () => _showSellerSheet(context),
              ),
              const SizedBox(height: 14),
            ] else if (role == UserRole.seller) ...[
              _ProfileTile(
                icon: Icons.storefront_rounded,
                label: 'Seller dashboard',
                trailing: const _MiniBadge(text: 'Seller'),
                onTap: () => _toast(context, 'Seller dashboard — coming next'),
              ),
              const SizedBox(height: 12),
            ],
            if (role == UserRole.admin)
              _ProfileTile(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Admin Console',
                trailing: const _MiniBadge(text: 'Admin'),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.admin),
              ),
            _ProfileTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit profile',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.favorite_outline_rounded,
              label: 'My fandom interests',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.smart_toy_outlined,
              label: 'AI Fan Helper',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.mail_outline_rounded,
              label: 'Contact Us',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.info_outline_rounded,
              label: 'About Us',
              onTap: () {},
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                                  await UserService.instance
                                      .upgradeToSeller(
                                    uid: uid,
                                    shopName: controller.text,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop(true);
                                  }
                                } catch (e) {
                                  setSheetState(() => loading = false);
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                        child: LiquidGlass(
                          radius: 16,
                          blur: 18,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC1121F),
                              Color(0xFF7F1D1D),
                            ],
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
                        onPressed:
                            loading ? null : () => Navigator.pop(sheetContext, false),
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
      _toast(context, 'You’re a seller now — open Seller dashboard to list items.');
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.shopName});

  final UserRole role;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    final (label, colors) = switch (role) {
      UserRole.admin => (
          'Admin',
          [Color(0xFFC1121F), Color(0xFF7F1D1D)],
        ),
      UserRole.seller => (
          'Seller',
          [Color(0xFF7C3AED), Color(0xFF4C1D95)],
        ),
      UserRole.fan => (
          'Fan',
          [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.08)],
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
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
          colors: [
            Color(0x597C3AED),
            Color(0x33C1121F),
            Color(0x1AFFFFFF),
          ],
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
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
