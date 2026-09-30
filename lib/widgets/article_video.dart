import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/app_colors.dart';
import 'cached_image.dart';

/// Inline 16:9 video block shown between an article's header and its body.
///
/// Autoplays muted and loops; the speaker button unlocks sound. Any platform
/// failure degrades to a poster placeholder instead of throwing — mirrors the
/// controller lifecycle of `_ReelPage._initVideo` in the reels feed.
class ArticleVideo extends StatefulWidget {
  const ArticleVideo({super.key, required this.url, this.posterUrl});

  /// Direct http(s) link to the clip.
  final String url;

  /// Optional still shown behind the placeholder while loading / on failure.
  final String? posterUrl;

  @override
  State<ArticleVideo> createState() => _ArticleVideoState();
}

class _ArticleVideoState extends State<ArticleVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      // Still inside initState — no setState needed, build reads it next.
      _failed = true;
      return;
    }
    final VideoPlayerController controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setLooping(true);
      // Muted autoplay needs no user gesture; the speaker unlocks sound.
      await controller.setVolume(0);
      await controller.play();
    } catch (error) {
      debugPrint('ArticleVideo: init failed for $url: $error');
      // A controller whose initialise() failed never completes its creation
      // completer, so awaiting dispose() here would hang forever — the
      // half-built instance is simply dropped and the poster takes over.
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      unawaited(controller.dispose().catchError((_) {}));
      return;
    }
    setState(() => _controller = controller);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (error) {
      debugPrint('ArticleVideo: playback toggle failed: $error');
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final muted = !_muted;
    try {
      await controller.setVolume(muted ? 0 : 1);
      if (mounted) setState(() => _muted = muted);
    } catch (error) {
      debugPrint('ArticleVideo: volume toggle failed: $error');
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _failed || !controller.value.isInitialized) {
      return _placeholder(showHint: _failed);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF0B0B12)),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final value = controller.value;
              final total = value.duration.inMilliseconds;
              final played = value.position.inMilliseconds;
              final progress =
                  total > 0 ? (played / total).clamp(0.0, 1.0) : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x40000000),
                          Color(0x00000000),
                          Color(0xA6000000),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Center(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white24),
                      ),
                      child: IconButton(
                        onPressed: _togglePlay,
                        tooltip: value.isPlaying ? 'Pause' : 'Play',
                        iconSize: 34,
                        color: Colors.white,
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white24),
                      ),
                      child: IconButton(
                        onPressed: _toggleMute,
                        tooltip: _muted ? 'Unmute' : 'Mute',
                        iconSize: 18,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        color: Colors.white,
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: SizedBox(
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: const ColoredBox(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Poster/gradient box used while loading and after a failure — the hint
  /// only shows once the platform has actually given up on the clip.
  Widget _placeholder({required bool showHint}) {
    final poster = widget.posterUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1220), Color(0xFF0D0D14)],
                ),
              ),
            ),
            if (poster.isNotEmpty)
              CachedImage(
                url: poster,
                fit: BoxFit.cover,
              ),
            if (showHint) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59000000), Color(0xE6000000)],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Video unavailable',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
