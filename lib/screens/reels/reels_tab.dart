import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_catalog.dart';
import '../../widgets/liquid_glass.dart';

/// Vertical short-video feed (index 3 in the bottom nav).
class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key});

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> {
  final PageController _controller = PageController();
  int _index = 0;

  static final _reels = <_ReelItem>[
    for (final t in MockCatalog.trending)
      _ReelItem(
        title: t.title,
        caption: 'Fan cut · ${t.category}',
        colors: t.colors,
        emoji: t.emoji,
        videoId: t.videoId,
      ),
    const _ReelItem(
      title: 'Cosplay Spotlight',
      caption: 'Weekly builds from the verse',
      colors: [Color(0xFF9F1239), Color(0xFF1A0508)],
      emoji: '🎭',
      videoId: null,
    ),
    const _ReelItem(
      title: 'Merch Unbox',
      caption: 'Drop day energy',
      colors: [Color(0xFF7C3AED), Color(0xFF0F061C)],
      emoji: '📦',
      videoId: null,
    ),
    const _ReelItem(
      title: 'Arena Clips',
      caption: 'Clutch rounds only',
      colors: [Color(0xFF064E3B), Color(0xFF031510)],
      emoji: '🎮',
      videoId: 'UE6UtfwmWu4',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: _reels.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _ReelPage(
            reel: _reels[i],
            active: i == _index,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Reels',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.primary.withValues(alpha: 0.35),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Text(
                    'LIVE FEED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right-side action rail
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _RailBtn(
                icon: Icons.favorite_border_rounded,
                label: '${24 + _index * 7}k',
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _RailBtn(
                icon: Icons.mode_comment_outlined,
                label: '${120 + _index * 13}',
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _RailBtn(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {},
              ),
            ],
          ),
        ),
        // Progress dots
        Positioned(
          left: 0,
          right: 0,
          bottom: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_reels.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppColors.accent : Colors.white38,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReelItem {
  const _ReelItem({
    required this.title,
    required this.caption,
    required this.colors,
    required this.emoji,
    this.videoId,
  });

  final String title;
  final String caption;
  final List<Color> colors;
  final String emoji;
  final String? videoId;
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({required this.reel, required this.active});

  final _ReelItem reel;
  final bool active;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  YoutubePlayerController? _yt;

  @override
  void initState() {
    super.initState();
    final id = widget.reel.videoId;
    // YouTube iframe embeds on web are flaky/slow — show poster art instead.
    if (!kIsWeb && id != null && id.isNotEmpty) {
      _yt = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: widget.active,
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
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _yt?.playVideo();
    } else if (!widget.active && old.active) {
      _yt?.pauseVideo();
    }
  }

  @override
  void dispose() {
    _yt?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;

    Widget media;
    if (_yt != null) {
      media = YoutubePlayer(
        controller: _yt!,
        aspectRatio: 9 / 16,
        builder: (context, player, _) => Center(child: player),
      );
    } else {
      media = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: reel.colors,
          ),
        ),
        child: Center(
          child: Text(reel.emoji, style: const TextStyle(fontSize: 88)),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        // Bottom gradient + meta
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x55000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xE6000000),
              ],
              stops: [0.0, 0.25, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 140,
          child: LiquidGlass(
            radius: 16,
            blur: 18,
            padding: const EdgeInsets.all(14),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reel.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reel.caption,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
