import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_catalog.dart';
import '../../models/reel_docs.dart';
import '../../services/auth_service.dart';
import '../../services/reel_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/liquid_glass.dart';
import 'reel_comments_sheet.dart';

/// Vertical short-video feed (index 3 in the bottom nav).
///
/// Plays community reels from Firestore (Cloudinary-hosted MP4s). When the
/// database has no reels yet, a Spotlight lineup from [MockCatalog] keeps the
/// feed alive alongside a "post the first reel" call to action.
///
/// [reelsStream] is a test seam.
class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key, this.reelsStream});

  final Stream<List<ReelDoc>>? reelsStream;

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> {
  final PageController _controller = PageController();
  int _index = 0;

  late final StreamCache<List<ReelDoc>> _reels = StreamCache<List<ReelDoc>>(
    () => widget.reelsStream ?? ReelService.instance.watchLatest(),
  );

  /// Curated posters shown until the community posts its first reel.
  static List<ReelDoc> get _spotlight => [
        for (var i = 0; i < MockCatalog.trending.length; i++)
          ReelDoc(
            id: 'spotlight-$i',
            authorUid: 'system',
            authorName: 'FandomVerse Spotlight',
            caption: '${MockCatalog.trending[i].title} · '
                '${MockCatalog.trending[i].category}',
            videoUrl: '',
            thumbnailUrl: MockCatalog.trending[i].thumbnailUrl,
            communityName: MockCatalog.trending[i].category,
          ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    if (AuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sign in to post a reel.')),
        );
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.createReel);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(ReelDoc reel) async {
    final link = reel.videoUrl.isNotEmpty
        ? reel.videoUrl
        : 'https://fandomverse.app';
    await Clipboard.setData(ClipboardData(text: link));
    _snack('Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReelDoc>>(
      stream: _reels(),
      builder: (context, snap) {
        final real = snap.data ?? const <ReelDoc>[];
        final isLive = real.isNotEmpty;
        final items = isLive ? real : _spotlight;
        final current = items[_index.clamp(0, items.length - 1)];

        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _ReelPage(
                key: ValueKey(items[i].id),
                reel: items[i],
                active: i == _index,
                onOpenCommunity: items[i].communityId == null
                    ? null
                    : () => Navigator.pushNamed(
                          context,
                          AppRoutes.communityDetail,
                          arguments: items[i].communityId,
                        ),
              ),
            ),
            // Header
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
                      child: Text(
                        isLive ? 'COMMUNITY' : 'LIVE FEED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openCreate,
                      child: const LiquidGlassPill(
                        radius: 999,
                        blur: 12,
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Spotlight / empty call to action
            if (!isLive)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 58),
                    child: GestureDetector(
                      onTap: _openCreate,
                      child: LiquidGlass(
                        radius: 999,
                        blur: 16,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.45),
                            AppColors.primary.withValues(alpha: 0.18),
                          ],
                        ),
                        borderColor: Colors.white.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.video_call_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'No reels yet — post the first one',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Right-side action rail (live reels only)
            if (isLive)
              Positioned(
                right: 12,
                bottom: 120,
                child: Column(
                  children: [
                    _LikeButton(
                      key: ValueKey('like-${current.id}'),
                      reelId: current.id,
                      count: current.likeCount,
                      onError: _snack,
                    ),
                    const SizedBox(height: 16),
                    _RailBtn(
                      icon: Icons.mode_comment_rounded,
                      label: formatCount(current.commentCount),
                      onTap: () => showReelCommentsSheet(context, current),
                    ),
                    const SizedBox(height: 16),
                    _RailBtn(
                      icon: Icons.reply_rounded,
                      label: 'Share',
                      onTap: () => _share(current),
                    ),
                  ],
                ),
              ),
            // Position indicator
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: items.length <= 8
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(items.length, (i) {
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
                    )
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${_index + 1} / ${items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
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
}

/// Compact count: 999, 1.2k, 12k, 1.1M.
String formatCount(int count) {
  if (count >= 1000000) {
    final v = count / 1000000;
    return '${v >= 10 ? v.round() : v.toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    final v = count / 1000;
    return '${v >= 10 ? v.round() : v.toStringAsFixed(1)}k';
  }
  return '$count';
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    super.key,
    required this.reelId,
    required this.count,
    required this.onError,
  });

  final String reelId;
  final int count;
  final void Function(String) onError;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late final Stream<bool> _liked = ReelService.instance.watchLiked(
    widget.reelId,
  );
  bool _busy = false;

  Future<void> _toggle(bool liked) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReelService.instance.toggleLike(widget.reelId);
    } catch (error) {
      widget.onError(ReelService.friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _liked,
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return _RailBtn(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? AppColors.accent : Colors.white,
          label: formatCount(widget.count),
          onTap: () => _toggle(liked),
        );
      },
    );
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

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
            child: Icon(icon, color: color, size: 22),
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

class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.reel,
    required this.active,
    this.onOpenCommunity,
  });

  final ReelDoc reel;
  final bool active;
  final VoidCallback? onOpenCommunity;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _paused = false;

  /// Whether the viewer explicitly paused via a tap (vs. autoplay lag).
  bool _userPaused = false;

  /// Whether the viewer has unlocked sound with a tap.
  bool _soundOn = false;

  /// Guards overlapping auto-play attempts.
  bool _playing = false;

  bool get _hasVideo =>
      widget.reel.videoUrl.isNotEmpty && !_failed && _video != null;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.reel.videoUrl;
    if (url.isEmpty) return;
    final VideoPlayerController controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
    } catch (error) {
      debugPrint('ReelsTab: video init failed for ${widget.reel.id}: $error');
      if (mounted) {
        setState(() {
          _failed = true;
          _paused = true;
        });
      }
      return;
    }
    if (!mounted) {
      unawaited(controller.dispose());
      return;
    }
    _video = controller;
    try {
      await controller.setLooping(true);
      // Muted autoplay needs no user gesture; the first tap unlocks sound.
      await controller.setVolume(0);
    } catch (_) {}
    controller.addListener(_onVideoTick);
    if (!mounted) return;
    setState(() {});
    if (widget.active && !_userPaused) {
      setState(() => _paused = false);
      await _autoPlay();
    }
  }

  /// Starts playback, swallowing autoplay-policy rejections — the tick
  /// listener keeps retrying until the platform reports playing.
  Future<void> _autoPlay() async {
    final controller = _video;
    if (_playing ||
        controller == null ||
        !controller.value.isInitialized ||
        !mounted ||
        !widget.active ||
        _userPaused) {
      return;
    }
    _playing = true;
    try {
      await controller.play();
    } catch (error) {
      debugPrint('ReelsTab: autoplay blocked for ${widget.reel.id}: $error');
    } finally {
      _playing = false;
    }
  }

  void _onVideoTick() {
    if (!mounted) return;
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    final playing = controller.value.isPlaying;
    if (playing == _paused) {
      setState(() => _paused = !playing);
    }
    // Recover from blocked/failed autoplay while this reel should be playing.
    if (!playing && widget.active && !_userPaused) {
      _autoPlay();
    }
  }

  Future<void> _togglePlay() async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (!_soundOn) {
        // First tap unlocks sound (browsers require a gesture for this).
        _soundOn = true;
        _userPaused = false;
        await controller.setVolume(1);
        if (!controller.value.isPlaying) {
          setState(() => _paused = false);
          await controller.play();
        }
        return;
      }
      if (controller.value.isPlaying) {
        _userPaused = true;
        setState(() => _paused = true);
        await controller.pause();
      } else {
        _userPaused = false;
        setState(() => _paused = false);
        await controller.play();
      }
    } catch (error) {
      debugPrint('ReelsTab: playback toggle failed: $error');
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active && !old.active) {
      _userPaused = false;
      setState(() => _paused = false);
      unawaited(_autoPlay());
    } else if (!widget.active && old.active) {
      unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    final controller = _video;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      try {
        controller.dispose().catchError((_) {});
      } catch (_) {}
    }
    super.dispose();
  }

  Color get _fallbackColor {
    final palette = const [
      Color(0xFF9F1239),
      Color(0xFF1E3A5F),
      Color(0xFF064E3B),
      Color(0xFF7C3AED),
      Color(0xFFB45309),
    ];
    return palette[widget.reel.id.hashCode.abs() % palette.length];
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text(
          'Delete reel?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReelService.instance.delete(widget.reel.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Reel deleted')));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ReelService.friendlyMessage(error))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final uid = AuthService.instance.currentUser?.uid;
    final isOwn = uid != null && reel.authorUid == uid;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Media
        if (_hasVideo)
          GestureDetector(
            onTap: _togglePlay,
            child: Center(
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio <= 0
                    ? 9 / 16
                    : _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              ),
            ),
          )
        else
          _PosterFallback(reel: reel, color: _fallbackColor),
        // Buffering
        if (_hasVideo && _video!.value.isBuffering)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Colors.white,
            ),
          ),
        // Paused hint
        if (_hasVideo && _paused && !_video!.value.isBuffering)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),
        // Scrims
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xE6000000),
              ],
              stops: [0.0, 0.25, 0.55, 1.0],
            ),
          ),
        ),
        // Meta card
        Positioned(
          left: 16,
          right: 72,
          bottom: 118,
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
                Row(
                  children: [
                    _AuthorAvatar(
                      url: reel.authorAvatarUrl,
                      name: reel.authorName,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reel.authorName.isEmpty ? 'FandomVerse' : reel.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isOwn)
                      GestureDetector(
                        onTap: _confirmDelete,
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    if (widget.onOpenCommunity != null &&
                        reel.communityName != null &&
                        reel.communityName!.isNotEmpty)
                      GestureDetector(
                        onTap: widget.onOpenCommunity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(alpha: 0.14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.26),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.diversity_3_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 96),
                                child: Text(
                                  reel.communityName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (reel.caption.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    reel.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
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

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.reel, required this.color});

  final ReelDoc reel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = reel.thumbnailUrl;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.35), const Color(0xFF0A0A10)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          const Center(
            child: Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white38,
              size: 74,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.url, this.name = ''});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.primaryDark],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: url != null && url!.isNotEmpty
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initial(),
            )
          : _initial(),
    );
  }

  Widget _initial() {
    final letter = name.isEmpty ? 'F' : name.characters.first.toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
