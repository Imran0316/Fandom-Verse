import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/auth_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/post_docs.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/liquid_glass.dart';
import 'post_card.dart';

/// Global fan feed (all posts, newest first).
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _controller = TextEditingController();
  bool _posting = false;
  final _posts = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchFeed(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    // Explore mode: posting requires an account.
    if (!requireSignIn(context, reason: 'Sign in to share a post.')) return;
    setState(() => _posting = true);
    try {
      await PostService.instance.createPost(body: body);
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fan Feed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.forum_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: LiquidGlass(
                    radius: 16,
                    blur: 0,
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: "What's hype in your fandom?",
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _posting ? null : _submit,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: _posting
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<PostDoc>>(
                    stream: _posts(),
                    builder: (context, snap) {
                      final waiting =
                          snap.connectionState == ConnectionState.waiting &&
                              snap.data == null;
                      final posts = snap.data ?? const <PostDoc>[];
                      final showEmpty = !waiting && posts.isEmpty;
                      final placeholder = waiting || showEmpty;
                      return ListView.separated(
                        key: const PageStorageKey<String>('feed_posts'),
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: placeholder ? 1 : posts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (waiting) {
                            return SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (posts.isEmpty) {
                            return SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LiquidGlass(
                                        radius: 24,
                                        blur: 0,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(
                                              alpha: 0.25,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(20),
                                        child: const Icon(
                                          Icons.bolt_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Feed is quiet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Post the first take — hot takes welcome.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          final p = posts[i];
                          return FadeSlideIn(
                            key: ValueKey(p.id),
                            child: PostCard(post: p),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
